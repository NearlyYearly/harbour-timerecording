# SPDX-License-Identifier: GPL-3.0-or-later
"""All data changes go through Store so every user action can be undone and redone.

An undo entry is a list of row changes {table, pk, before, after}; undo writes the
`before` rows in reverse order, redo writes the `after` rows.
"""
import datetime as dt
import json

from . import rules, settings
from .db import row_dict

PK = {"day_notes": "date", "vacation_years": "year"}
EDITABLE = {
    "stamps": ["check_in", "check_out", "task_id", "comment", "kind", "raw_check_in", "raw_check_out"],
    "tasks": ["name", "color", "archived", "sort", "work_factor", "target_off", "holiday_days"],
    "day_notes": ["date", "note_type_id", "text"],
    "note_types": ["name", "credit_factor", "holiday_days", "color", "sort", "archived"],
    "templates": ["name", "lines"],
    "vacation_years": ["year", "days", "carryover"],
}


def fmt(t):
    return t.isoformat(timespec="minutes") if t is not None else None


def fmt_raw(t):
    # Exact punch time, kept next to the rounded one; seconds for the double-tap guard.
    return t.replace(microsecond=0).isoformat()


def parse(s):
    return dt.datetime.fromisoformat(s) if s else None


class Store:
    def __init__(self, conn, now=dt.datetime.now):
        self.conn = conn
        self.now = now

    # --- low level ---------------------------------------------------------------

    def _pk(self, table):
        return PK.get(table, "id")

    def _get(self, table, pk):
        return row_dict(self.conn.execute(
            "SELECT * FROM %s WHERE %s = ?" % (table, self._pk(table)), (pk,)).fetchone())

    def _write(self, table, pk, row):
        key = self._pk(table)
        if row is None:
            self.conn.execute("DELETE FROM %s WHERE %s = ?" % (table, key), (pk,))
            return
        cols = [c for c in row if c != key]
        cur = self.conn.execute(
            "UPDATE %s SET %s WHERE %s = ?" % (table, ", ".join(c + " = ?" for c in cols), key),
            [row[c] for c in cols] + [pk])
        if cur.rowcount == 0:
            names = list(row)
            self.conn.execute(
                "INSERT INTO %s (%s) VALUES (%s)" % (table, ", ".join(names), ", ".join("?" * len(names))),
                [row[c] for c in names])

    def _insert(self, table, values):
        names = list(values)
        cur = self.conn.execute(
            "INSERT INTO %s (%s) VALUES (%s)" % (table, ", ".join(names), ", ".join("?" * len(names))),
            [values[c] for c in names])
        pk = values.get(self._pk(table), cur.lastrowid)
        return {"table": table, "pk": pk, "before": None, "after": self._get(table, pk)}

    def _update(self, table, pk, values):
        before = self._get(table, pk)
        if before is None:
            raise KeyError("%s %r not found" % (table, pk))
        after = dict(before)
        after.update({k: v for k, v in values.items() if k in EDITABLE[table]})
        self._write(table, pk, after)
        return {"table": table, "pk": pk, "before": before, "after": self._get(table, pk)}

    def _delete(self, table, pk):
        before = self._get(table, pk)
        if before is None:
            raise KeyError("%s %r not found" % (table, pk))
        self._write(table, pk, None)
        return {"table": table, "pk": pk, "before": before, "after": None}

    def _commit(self, label, changes):
        changes = [c for c in changes if c["before"] != c["after"]]
        if changes:
            self.conn.execute("DELETE FROM undo_log WHERE undone = 1")
            self.conn.execute("INSERT INTO undo_log (label, changes) VALUES (?, ?)",
                              (label, json.dumps(changes)))
            depth = settings.get(self.conn, "undo.depth")
            self.conn.execute(
                "DELETE FROM undo_log WHERE seq NOT IN "
                "(SELECT seq FROM undo_log ORDER BY seq DESC LIMIT ?)", (max(1, depth),))
        self.conn.commit()

    def _run(self, label, fn):
        try:
            changes = fn()
        except Exception:
            self.conn.rollback()
            raise
        self._commit(label, changes)
        return changes

    # --- undo / redo -----------------------------------------------------------

    def undo_state(self):
        undo = self.conn.execute(
            "SELECT label FROM undo_log WHERE undone = 0 ORDER BY seq DESC LIMIT 1").fetchone()
        redo = self.conn.execute(
            "SELECT label FROM undo_log WHERE undone = 1 ORDER BY seq ASC LIMIT 1").fetchone()
        return {"undo": undo["label"] if undo else "", "redo": redo["label"] if redo else ""}

    def undo(self):
        row = self.conn.execute(
            "SELECT seq, label, changes FROM undo_log WHERE undone = 0 ORDER BY seq DESC LIMIT 1").fetchone()
        if row is None:
            return None
        for change in reversed(json.loads(row["changes"])):
            self._write(change["table"], change["pk"], change["before"])
        self.conn.execute("UPDATE undo_log SET undone = 1 WHERE seq = ?", (row["seq"],))
        self.conn.commit()
        return row["label"]

    def redo(self):
        row = self.conn.execute(
            "SELECT seq, label, changes FROM undo_log WHERE undone = 1 ORDER BY seq ASC LIMIT 1").fetchone()
        if row is None:
            return None
        for change in json.loads(row["changes"]):
            self._write(change["table"], change["pk"], change["after"])
        self.conn.execute("UPDATE undo_log SET undone = 0 WHERE seq = ?", (row["seq"],))
        self.conn.commit()
        return row["label"]

    # --- stamps ------------------------------------------------------------------

    def running(self):
        return row_dict(self.conn.execute(
            "SELECT * FROM stamps WHERE check_out IS NULL ORDER BY check_in DESC LIMIT 1").fetchone())

    def _validate_stamp(self, row):
        check_in, check_out = parse(row["check_in"]), parse(row.get("check_out"))
        if check_in is None:
            raise ValueError("check-in time missing")
        if check_out is not None and check_out < check_in:
            raise ValueError("check-out is before check-in")
        if row.get("kind", "work") not in ("work", "break"):
            raise ValueError("unknown line kind")
        if check_out is None:
            other = self.running()
            if other is not None and other.get("id") != row.get("id"):
                raise ValueError("another line is already running")

    def last_punch(self):
        row = self.conn.execute(
            "SELECT MAX(t) FROM (SELECT raw_check_in AS t FROM stamps "
            "UNION ALL SELECT raw_check_out FROM stamps)").fetchone()
        return parse(row[0]) if row and row[0] else None

    def punch(self, task_id=None):
        """Check in if nothing is running, otherwise check out the running line.

        Returns None (and changes nothing) when the previous punch was less than
        punch.debounce_sec ago, so a double tap does not check in and out again.
        """
        now = self.now()
        values = settings.get_all(self.conn)
        last = self.last_punch()
        if last is not None and dt.timedelta(0) <= now - last < dt.timedelta(seconds=values["punch.debounce_sec"]):
            return None
        current = self.running()
        if current is None:
            check_in = rules.round_time(now, values["round.in_step"], values["round.in_dir"])
            row = {"check_in": fmt(check_in), "check_out": None, "task_id": task_id,
                   "comment": "", "kind": "work", "raw_check_in": fmt_raw(now)}
            return self._run("Check in", lambda: [self._insert("stamps", row)])
        check_out = rules.round_time(now, values["round.out_step"], values["round.out_dir"])
        check_out = max(check_out, parse(current["check_in"]))

        def change():
            changes = [self._update("stamps", current["id"],
                                    {"check_out": fmt(check_out), "raw_check_out": fmt_raw(now)})]
            return changes + self._auto_split(current["check_in"][:10])
        return self._run("Check out", change)

    def switch_task(self, task_id):
        """Close the running line and continue immediately with another task."""
        current = self.running()
        if current is None:
            return self.punch(task_id)
        now = self.now()
        at = fmt(max(now.replace(second=0, microsecond=0), parse(current["check_in"])))

        def change():
            return [
                self._update("stamps", current["id"], {"check_out": at, "raw_check_out": fmt_raw(now)}),
                self._insert("stamps", {"check_in": at, "check_out": None, "task_id": task_id,
                                        "comment": "", "kind": "work", "raw_check_in": fmt_raw(now)}),
            ]
        return self._run("Switch task", change)

    def add_stamp(self, data):
        row = {"check_in": data["check_in"], "check_out": data.get("check_out") or None,
               "task_id": data.get("task_id"), "comment": data.get("comment", ""),
               "kind": data.get("kind", "work")}
        self._validate_stamp(row)
        return self._run("Add line", lambda: [self._insert("stamps", row)]
                         + self._auto_split(row["check_in"][:10]))

    def update_stamp(self, stamp_id, data):
        current = self._get("stamps", stamp_id)
        if current is None:
            raise KeyError("line %r not found" % stamp_id)
        merged = dict(current)
        merged.update({k: v for k, v in data.items() if k in EDITABLE["stamps"]})
        if "check_out" in data and not data["check_out"]:
            merged["check_out"] = None
        if "task_id" in data and data["task_id"] is None:
            merged["task_id"] = None
        self._validate_stamp(merged)
        days = sorted({current["check_in"][:10], merged["check_in"][:10]})
        return self._run("Edit line", lambda: [self._update("stamps", stamp_id, merged)]
                         + [c for d in days for c in self._auto_split(d)])

    def _auto_split(self, date):
        """In split mode, turn missing breaks of a finished day into check-out/check-in pairs."""
        values = settings.get_all(self.conn)
        if values["break.mode"] != "split" or not settings.breaks_apply(values, dt.date.fromisoformat(date)):
            return []
        changes = []
        # Each split changes the day, so re-evaluate until no break is missing.
        for _ in range(len(values["break.rules"]) + 1):
            rows = [dict(r) for r in self.conn.execute(
                "SELECT s.*, COALESCE(t.work_factor, 1) AS work_factor FROM stamps s "
                "LEFT JOIN tasks t ON t.id = s.task_id "
                "WHERE substr(s.check_in, 1, 10) = ? ORDER BY s.check_in, s.id", (date,))]
            if not rows or any(r["check_out"] is None for r in rows):
                return changes
            # Lines of tasks that do not count as work (on call, ...) need no break.
            work = [(parse(r["check_in"]), parse(r["check_out"]), r) for r in rows
                    if r["kind"] == "work" and r["work_factor"] > 0]
            breaks = [(parse(r["check_in"]), parse(r["check_out"])) for r in rows if r["kind"] == "break"]
            result = rules.day_breaks([(s, e) for s, e, _ in work], breaks, values)
            if not result["auto_breaks"]:
                return changes
            start, end = result["auto_breaks"][0]
            for s, e, row in work:
                if s <= start < e:
                    changes += self._split(row, s, e, start, min(end, e))
                    break
            else:
                return changes
        return changes

    def _split(self, row, s, e, start, end):
        if start == s or end >= e:
            # No work left before or after the break: a gap would not exist, so record the
            # break as an explicit break line inside the work line instead.
            return [self._insert("stamps", {
                "check_in": fmt(start), "check_out": fmt(end), "task_id": None,
                "comment": "", "kind": "break"})]
        return [
            self._update("stamps", row["id"], {"check_out": fmt(start)}),
            self._insert("stamps", {
                "check_in": fmt(end), "check_out": row["check_out"], "task_id": row["task_id"],
                "comment": row["comment"], "kind": "work"}),
        ]

    def delete_stamp(self, stamp_id):
        return self._run("Delete line", lambda: [self._delete("stamps", stamp_id)])

    # --- day notes ---------------------------------------------------------------

    def set_day_note(self, date, note_type_id, text):
        text = (text or "").strip()
        existing = self._get("day_notes", date)

        def change():
            if note_type_id is None and not text:
                return [self._delete("day_notes", date)] if existing else []
            row = {"date": date, "note_type_id": note_type_id, "text": text}
            if existing:
                return [self._update("day_notes", date, row)]
            return [self._insert("day_notes", row)]
        return self._run("Day note", change)

    # --- tasks -------------------------------------------------------------------

    def _task_row(self, data):
        row = {k: data[k] for k in EDITABLE["tasks"] if k in data}
        if "name" in row:
            row["name"] = str(row["name"]).strip()
            if not row["name"]:
                raise ValueError("task name is empty")
        for key in ("work_factor", "holiday_days"):
            if key in row and not 0 <= float(row[key]) <= 1:
                raise ValueError("%s must be between 0 and 1" % key)
        if "target_off" in row:
            row["target_off"] = int(bool(row["target_off"]))
        return row

    def add_task(self, name, color, data=None):
        row = self._task_row(dict(data or {}, name=name, color=color))
        row.setdefault("sort", self.conn.execute("SELECT COALESCE(MAX(sort), -1) + 1 FROM tasks").fetchone()[0])
        return self._run("Add task", lambda: [self._insert("tasks", row)])

    def update_task(self, task_id, data):
        return self._run("Edit task", lambda: [self._update("tasks", task_id, self._task_row(data))])

    # --- note types --------------------------------------------------------------

    def _note_type_row(self, data):
        row = {k: data[k] for k in EDITABLE["note_types"] if k in data}
        if "name" in row and not str(row["name"]).strip():
            raise ValueError("name is empty")
        for key in ("credit_factor", "holiday_days"):
            if key in row and not 0 <= float(row[key]) <= 1:
                raise ValueError("%s must be between 0 and 1" % key)
        return row

    def add_note_type(self, data):
        row = self._note_type_row(data)
        row.setdefault("sort", self.conn.execute(
            "SELECT COALESCE(MAX(sort), -1) + 1 FROM note_types").fetchone()[0])
        return self._run("Add day type", lambda: [self._insert("note_types", row)])

    def update_note_type(self, type_id, data):
        return self._run("Edit day type", lambda: [self._update("note_types", type_id, self._note_type_row(data))])

    # --- vacation years ----------------------------------------------------------

    def set_vacation_year(self, year, days, carryover):
        year, days, carryover = int(year), float(days), float(carryover)
        if not 1900 <= year <= 2200:
            raise ValueError("year out of range")
        if not 0 <= days <= 366 or not -366 <= carryover <= 366:
            raise ValueError("days out of range")
        row = {"year": year, "days": days, "carryover": carryover}

        def change():
            if self._get("vacation_years", year):
                return [self._update("vacation_years", year, row)]
            return [self._insert("vacation_years", row)]
        return self._run("Vacation %d" % year, change)

    def delete_vacation_year(self, year):
        return self._run("Delete vacation %d" % int(year), lambda: [self._delete("vacation_years", int(year))])

    # --- templates ---------------------------------------------------------------

    def save_template(self, name, date):
        """Store the finished lines of a day as a reusable template."""
        if not name.strip():
            raise ValueError("template name is empty")
        lines = []
        for r in self.conn.execute(
                "SELECT * FROM stamps WHERE substr(check_in, 1, 10) = ? AND check_out IS NOT NULL "
                "ORDER BY check_in", (date,)):
            lines.append({"start": r["check_in"][11:16], "end": r["check_out"][11:16],
                          "task_id": r["task_id"], "kind": r["kind"], "comment": r["comment"]})
        if not lines:
            raise ValueError("the day has no finished lines")
        return self._run("Save template", lambda: [self._insert(
            "templates", {"name": name.strip(), "lines": json.dumps(lines)})])

    def apply_template(self, template_id, date):
        template = self._get("templates", template_id)
        if template is None:
            raise KeyError("template not found")
        day = dt.date.fromisoformat(date)
        rows = []
        for line in json.loads(template["lines"]):
            start = dt.datetime.combine(day, dt.time.fromisoformat(line["start"]))
            end = dt.datetime.combine(day, dt.time.fromisoformat(line["end"]))
            if end < start:
                end += dt.timedelta(days=1)
            task_id = line.get("task_id")
            if task_id is not None and self._get("tasks", task_id) is None:
                task_id = None
            rows.append({"check_in": fmt(start), "check_out": fmt(end), "task_id": task_id,
                         "comment": line.get("comment", ""), "kind": line.get("kind", "work")})
        for row in rows:
            self._validate_stamp(row)
        return self._run("Apply template", lambda: [self._insert("stamps", r) for r in rows]
                         + self._auto_split(date))

    def rename_template(self, template_id, name):
        if not name.strip():
            raise ValueError("template name is empty")
        return self._run("Rename template", lambda: [self._update("templates", template_id, {"name": name.strip()})])

    def delete_template(self, template_id):
        return self._run("Delete template", lambda: [self._delete("templates", template_id)])

    def archive_task(self, task_id, archived=True):
        # Tasks are archived, never deleted, so lines keep their task.
        return self._run("Archive task" if archived else "Restore task",
                         lambda: [self._update("tasks", task_id, {"archived": int(archived)})])
