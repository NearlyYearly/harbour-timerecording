"""Import from *Time Recording* for Android (dynamicg): its database backup `timerec.db(.gz)`.

The backup is the app's own SQLite database. What is used:

- `T_CATEGORY_1` tasks. TIME_ACCUMULATION (percent) and TIME_SUM_OFF give the share that
  counts as work, TARGET_OFF a day without target, balance trackers named like "Urlaub"
  the holiday days (D-025).
- `T_STAMP_3` single check-in (10, with task) and check-out (20) events per day (ASOFDATE);
  they are paired into lines.
- `T_NOTE_1` day notes (free text).
- `T_DAY_TEMPLATE_1` template names; a template's lines are the lines of its ASOFDATE.
- Settings: daily/weekday targets, auto breaks, the flexitime carryover and the holiday
  corrections per year.

`read()` parses without touching our database, `preview()` compares with it, `apply()`
writes everything as one undo step.
"""
import collections
import datetime as dt
import gzip
import itertools
import json
import os
import re
import shutil
import sqlite3
import tempfile

from . import settings
from .store import fmt

CHECK_IN, CHECK_OUT = 10, 20
HOLIDAY_NAME = re.compile(r"urlaub|vacation|holiday|ferien|cong", re.I)
# Task colours are user data; Time Recording keeps none in this table, so give each a
# distinct one the user can change later.
PALETTE = ["#4caf50", "#2196f3", "#ff9800", "#9c27b0", "#f44336", "#009688", "#795548",
           "#607d8b", "#e91e63", "#3f51b5"]
WEEKDAY_KEYS = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]  # Android: 0 = Sunday


def _open(path):
    """Open the backup read-only; a .gz is unpacked to a temporary file first."""
    tmp = None
    with open(path, "rb") as f:
        packed = f.read(2) == b"\x1f\x8b"
    if packed:
        fd, tmp = tempfile.mkstemp(suffix=".db")
        with os.fdopen(fd, "wb") as out, gzip.open(path, "rb") as src:
            shutil.copyfileobj(src, out)
        path = tmp
    conn = sqlite3.connect("file:%s?mode=ro" % path, uri=True)
    try:
        names = {r[0] for r in conn.execute("SELECT name FROM sqlite_master WHERE type = 'table'")}
    except sqlite3.DatabaseError:
        conn.close()
        _remove(tmp)
        raise ValueError("not a Time Recording backup")
    if not {"T_STAMP_3", "T_CATEGORY_1"} <= names:
        conn.close()
        _remove(tmp)
        raise ValueError("not a Time Recording backup")
    return conn, names, tmp


def _remove(path):
    if path:
        try:
            os.remove(path)
        except OSError:
            pass


def _ts(value):
    return dt.datetime.strptime(value[:19], "%Y-%m-%d %H:%M:%S")


def _minutes(hhmm):
    h, m = hhmm.strip().split(":")
    return int(h) * 60 + int(m)


def _settings(conn, names):
    rows = {}
    if "T_SETTINGS_TMP" in names:
        for key, item in conn.execute("SELECT KEY, ITEM FROM T_SETTINGS_TMP"):
            # ITEM is "<type>|<key>=<value>"
            if item and "=" in item:
                rows[key] = item.split("=", 1)[1]
    return rows


def _domain(conn, names):
    rows = collections.defaultdict(list)
    if "T_DOMAIN_VALUE_1" in names:
        for domain, key, v1, v2, v3 in conn.execute(
                "SELECT DOMAIN, KEY, VALUE, VALUE2, VALUE3 FROM T_DOMAIN_VALUE_1"):
            rows[domain].append((key, v1, v2, v3))
    return rows


def _holiday_tasks(domain):
    """Task ids counted by a balance tracker whose label reads like "holiday"."""
    ids = set()
    trackers = {key for key, label, _, _ in domain.get("BalanceTracker.Label", [])
                if label and HOLIDAY_NAME.search(label)}
    for tracker in trackers:
        for _, rule, _, _ in domain.get("BalanceTracker.Filter.%s" % tracker, []):
            # "a:0_<task id>"
            m = re.match(r"a:\d+_(\d+)$", rule or "")
            if m:
                ids.add(int(m.group(1)))
    return ids, trackers


def _pair(events):
    """Pair one day's check-in/out events into lines.

    Events at the same minute are matched so that an open line is closed first and a
    check-in followed by a check-out at the same time gives a zero-length line
    (Time Recording uses those for public holidays and comp time).
    """
    lines, problems = [], []
    open_ = None
    for at, group in itertools.groupby(events, key=lambda e: e["at"]):
        group = list(group)
        ins = [e for e in group if e["action"] == CHECK_IN]
        outs = [e for e in group if e["action"] == CHECK_OUT]
        while ins or outs:
            if open_ is not None and outs:
                out = outs.pop(0)
                comment = " ".join(c for c in (open_["comment"], out["comment"]) if c)
                lines.append({"check_in": open_["at"], "check_out": at,
                              "android_task": open_["task"], "comment": comment})
                open_ = None
            elif ins:
                if open_ is not None:
                    problems.append({"date": fmt(open_["at"])[:10], "time": fmt(open_["at"])[11:],
                                     "problem": "check-in without check-out"})
                open_ = ins.pop(0)
            else:
                outs.pop(0)
                problems.append({"date": fmt(at)[:10], "time": fmt(at)[11:],
                                 "problem": "check-out without check-in"})
    return lines, open_, problems


def read(path):
    """Parse a Time Recording backup into plain data."""
    conn, names, tmp = _open(path)
    try:
        return _read(conn, names)
    finally:
        conn.close()
        _remove(tmp)


def _read(conn, names):
    domain = _domain(conn, names)
    prefs = _settings(conn, names)
    holiday_ids, holiday_trackers = _holiday_tasks(domain)

    tasks = []
    for i, (tid, name, sort, inactive, accumulation, target_off, sum_off) in enumerate(conn.execute(
            "SELECT ID, NAME, SORTNR, INACTIVE_FG, TIME_ACCUMULATION, TARGET_OFF, TIME_SUM_OFF "
            "FROM T_CATEGORY_1 ORDER BY SORTNR, ID")):
        try:
            factor = float(accumulation) / 100 if accumulation not in (None, "") else 1.0
        except ValueError:
            factor = 1.0
        if sum_off:
            factor = 0.0
        tasks.append({
            "android_id": tid, "name": (name or "").strip() or "Task %d" % tid,
            "color": PALETTE[i % len(PALETTE)], "sort": sort or 0,
            "archived": int(bool(inactive)),
            "work_factor": min(1.0, max(0.0, factor)),
            "target_off": int(bool(target_off)),
            "holiday_days": 1.0 if tid in holiday_ids else 0.0,
        })

    by_day = collections.defaultdict(list)
    for asof, stamp, action, seq, task, comment in conn.execute(
            "SELECT ASOFDATE, STAMP_DATE_STR, CHECK_ACTION, SEQNR, CATEGORY_ID, COMMENT FROM T_STAMP_3 "
            "ORDER BY ASOFDATE, STAMP_DATE_STR, SEQNR"):
        if action not in (CHECK_IN, CHECK_OUT):
            continue
        by_day[asof[:10]].append({"at": _ts(stamp), "action": action, "task": task or None,
                                  "comment": (comment or "").strip()})
    lines, problems, open_lines = [], [], []
    for day in sorted(by_day):
        day_lines, open_, day_problems = _pair(by_day[day])
        lines += day_lines
        problems += day_problems
        if open_ is not None:
            open_lines.append({"check_in": open_["at"], "check_out": None,
                               "android_task": open_["task"], "comment": open_["comment"]})
    # Only the very last line may still be running; earlier open ones are mistakes.
    running = None
    if open_lines and (not lines or open_lines[-1]["check_in"] >= lines[-1]["check_in"]):
        running = open_lines.pop()
    for line in open_lines:
        problems.append({"date": fmt(line["check_in"])[:10], "time": fmt(line["check_in"])[11:],
                         "problem": "check-in without check-out"})

    notes = []
    if "T_NOTE_1" in names:
        for date, text in conn.execute("SELECT NOTE_DATE_STR, NOTE_TEXT FROM T_NOTE_1 ORDER BY 1"):
            text = (text or "").strip()
            if text:
                notes.append({"date": date[:10], "text": text})

    day_lines = collections.defaultdict(list)
    for line in lines:
        day_lines[fmt(line["check_in"])[:10]].append(line)
    templates = []
    if "T_DAY_TEMPLATE_1" in names:
        for name, asof in conn.execute("SELECT TEXT, ASOFDATE FROM T_DAY_TEMPLATE_1 ORDER BY ID"):
            source = day_lines.get((asof or "")[:10], [])
            if name and source:
                templates.append({"name": name.strip(), "lines": [{
                    "start": fmt(l["check_in"])[11:], "end": fmt(l["check_out"])[11:],
                    "android_task": l["android_task"], "kind": "work", "comment": l["comment"],
                } for l in source]})

    mapped = _map_settings(conn, names, prefs, domain, holiday_trackers)
    last = max([l["check_in"] for l in lines] + ([running["check_in"]] if running else []), default=None)
    if last is not None:
        # Time Recording only adds breaks while punching, so its history has none added
        # afterwards; keep it that way here (D-025).
        mapped["break.since"] = (last.date() + dt.timedelta(days=1)).isoformat()
    return {
        "tasks": tasks,
        "lines": lines,
        "running": running,
        "notes": notes,
        "templates": templates,
        "problems": problems,
        "settings": mapped,
        "not_imported": _not_imported(conn, names, prefs, domain),
    }


def _map_settings(conn, names, prefs, domain, holiday_trackers):
    out = {}
    daily = prefs.get("DailyTargetTime")
    if daily:
        try:
            base = _minutes(daily)
            for i, key in enumerate(WEEKDAY_KEYS):
                value = prefs.get("WeekdayTargetTime.%d" % i)
                out["target." + key] = _minutes(value) if value else base
        except ValueError:
            pass

    rules = []
    for i in range(10):
        raw = prefs.get("AutoBreak.%d" % i)
        if not raw:
            continue
        # "after|length|at/..|..|weekday mask", e.g. "06:00|00:30|11:30/0|0|0"
        parts = raw.split("|")
        try:
            rule = {"after_min": _minutes(parts[0]), "break_min": _minutes(parts[1]), "at": ""}
            at = parts[2].split("/")[0] if len(parts) > 2 else ""
            if re.match(r"^\d{1,2}:\d{2}$", at):
                rule["at"] = settings._hhmm(at)
        except (ValueError, IndexError):
            continue
        if rule["break_min"] > 0:
            rules.append(rule)
    if rules:
        out["break.rules"] = sorted(rules, key=lambda r: r["after_min"])

    if "T_FLEXTIME_D_1" in names:
        # Group 2 holds the yearly carryover ("Vorjahr"); the latest one is the start.
        row = conn.execute("SELECT ASOFDATE, VALUE_S FROM T_FLEXTIME_D_1 WHERE GROUP_ID = 2 "
                           "ORDER BY ASOFDATE DESC LIMIT 1").fetchone()
        if row:
            out["balance.start"] = row[0][:10]
            out["balance.opening_min"] = int(round((row[1] or 0) / 60.0))

    per_year = collections.defaultdict(float)
    entries = []
    for domain_name, rows in domain.items():
        m = re.match(r"BalanceTracker\.Correction\.(\d+)\.(\d{4})$", domain_name)
        if not m or m.group(1) not in holiday_trackers:
            continue
        for _, _, amount, _ in rows:
            try:
                per_year[m.group(2)] += float(amount)
                entries.append((m.group(2), float(amount)))
            except (TypeError, ValueError):
                pass
    if per_year:
        latest = max(per_year)
        entitlement = max(a for y, a in entries if y == latest)
        out["holiday.entitlement"] = entitlement
        out["holiday.carryover"] = {y: round(v - entitlement, 2) for y, v in sorted(per_year.items())
                                    if round(v - entitlement, 2) != 0}
    return out


def _not_imported(conn, names, prefs, domain):
    """Things the backup has that this app does not take over, for the preview."""
    items = []
    if "T_TARGET_PER_WEEK_1" in names:
        count = conn.execute("SELECT COUNT(*) FROM T_TARGET_PER_WEEK_1").fetchone()[0]
        if count:
            items.append({"what": "week_targets", "value": count})
    if prefs.get("PunchNowRoundingSlot") not in (None, "", "0"):
        items.append({"what": "rounding", "value": prefs["PunchNowRoundingSlot"]})
    if domain.get("customAlarm"):
        items.append({"what": "reminders", "value": len(domain["customAlarm"])})
    if "T_PUNCH_RULE_1" in names:
        count = conn.execute("SELECT COUNT(*) FROM T_PUNCH_RULE_1").fetchone()[0]
        if count:
            items.append({"what": "punch_rules", "value": count})
    return items


# --- comparing with and writing to our database ---------------------------------------


def _existing_tasks(conn):
    return {r["name"].strip().lower(): r["id"] for r in conn.execute("SELECT id, name FROM tasks")}


def _plan(conn, data):
    """Decide what gets written: days that already have lines and dates that already
    have a note in this app are left alone."""
    busy = {r[0] for r in conn.execute("SELECT DISTINCT substr(check_in, 1, 10) FROM stamps")}
    noted = {r[0] for r in conn.execute("SELECT date FROM day_notes")}
    lines = [l for l in data["lines"] if fmt(l["check_in"])[:10] not in busy]
    skipped_days = sorted({fmt(l["check_in"])[:10] for l in data["lines"]} & busy)
    running = data["running"]
    if running is not None and (fmt(running["check_in"])[:10] in busy or conn.execute(
            "SELECT 1 FROM stamps WHERE check_out IS NULL").fetchone()):
        skipped_days = sorted(set(skipped_days) | {fmt(running["check_in"])[:10]})
        running = None
    notes = [n for n in data["notes"] if n["date"] not in noted]
    existing = _existing_tasks(conn)
    names = {t["name"].lower() for t in data["tasks"]}
    templates = [t for t in data["templates"]
                 if t["name"].lower() not in {r[0].lower() for r in conn.execute("SELECT name FROM templates")}]
    return {
        "lines": lines, "running": running, "notes": notes, "templates": templates,
        "skipped_days": skipped_days,
        "skipped_notes": len(data["notes"]) - len(notes),
        "matched_tasks": sorted(n for n in names if n in existing),
    }


def preview(conn, data):
    plan = _plan(conn, data)
    dates = [fmt(l["check_in"])[:10] for l in data["lines"]]
    current = settings.get_all(conn)
    changes = []
    for key, value in sorted(data["settings"].items()):
        if current.get(key) != value:
            changes.append({"key": key, "old": current.get(key), "new": value})
    running = plan["running"]
    return {
        "first": min(dates) if dates else "",
        "last": max(dates) if dates else "",
        "tasks": len(data["tasks"]),
        "new_tasks": len(data["tasks"]) - len(plan["matched_tasks"]),
        "matched_tasks": plan["matched_tasks"],
        "lines": len(plan["lines"]),
        "running": fmt(running["check_in"]) if running else "",
        "notes": len(plan["notes"]),
        "templates": len(plan["templates"]),
        "skipped_days": plan["skipped_days"],
        "skipped_notes": plan["skipped_notes"],
        "problems": data["problems"],
        "settings": changes,
        "not_imported": data["not_imported"],
    }


def apply(store, data, with_settings):
    """Write the import as one undo step. Settings are written separately (they are not
    part of the undo history, like every settings change)."""
    conn = store.conn
    plan = _plan(conn, data)
    existing = _existing_tasks(conn)

    def change():
        changes, ids = [], {}
        sort = conn.execute("SELECT COALESCE(MAX(sort), -1) + 1 FROM tasks").fetchone()[0]
        for task in data["tasks"]:
            key = task["name"].lower()
            if key in existing:
                ids[task["android_id"]] = existing[key]
                continue
            row = {k: task[k] for k in ("name", "color", "archived", "work_factor", "target_off",
                                        "holiday_days")}
            row["sort"] = sort
            sort += 1
            change_ = store._insert("tasks", row)
            changes.append(change_)
            ids[task["android_id"]] = existing[key] = change_["pk"]
        rows = list(plan["lines"]) + ([plan["running"]] if plan["running"] else [])
        for line in rows:
            changes.append(store._insert("stamps", {
                "check_in": fmt(line["check_in"]), "check_out": fmt(line["check_out"]),
                "task_id": ids.get(line["android_task"]), "comment": line["comment"],
                "kind": "work", "raw_check_in": line["check_in"].isoformat(),
                "raw_check_out": line["check_out"].isoformat() if line["check_out"] else None}))
        for note in plan["notes"]:
            changes.append(store._insert("day_notes", {"date": note["date"], "note_type_id": None,
                                                       "text": note["text"]}))
        for template in plan["templates"]:
            lines = [{"start": l["start"], "end": l["end"], "task_id": ids.get(l["android_task"]),
                      "kind": l["kind"], "comment": l["comment"]} for l in template["lines"]]
            changes.append(store._insert("templates", {"name": template["name"],
                                                       "lines": json.dumps(lines)}))
        return changes

    changes = store._run("Import from Android", change)
    if with_settings:
        for key, value in data["settings"].items():
            if key == "break.since" and settings.get(conn, key) > value:
                continue  # never move it back
            settings.set(conn, key, value)
        conn.commit()
    return {
        "tasks": sum(1 for c in changes if c["table"] == "tasks"),
        "lines": sum(1 for c in changes if c["table"] == "stamps"),
        "notes": sum(1 for c in changes if c["table"] == "day_notes"),
        "templates": sum(1 for c in changes if c["table"] == "templates"),
        "settings": len(data["settings"]) if with_settings else 0,
    }


def find_backups(directory):
    """Time Recording backups in a directory (newest first)."""
    try:
        names = os.listdir(directory)
    except OSError:
        return []
    paths = [os.path.join(directory, n) for n in names
             if re.match(r"^timerec.*\.db(\.gz)?$", n, re.I)]
    return sorted(paths, key=os.path.getmtime, reverse=True)
