"""Day, week and month totals, flexitime and holiday balance.

A line belongs to the day it was checked in. Ranges are loaded with one query each for
lines and notes, then evaluated per day.
"""
import datetime as dt

from . import rules, settings
from .store import fmt, parse


def _date(s):
    return dt.date.fromisoformat(s) if isinstance(s, str) else s


def _days(start, end):
    d = start
    while d <= end:
        yield d
        d += dt.timedelta(days=1)


def _load(conn, start, end):
    lines, notes = {}, {}
    for row in conn.execute(
            "SELECT s.*, t.name AS task_name, t.color AS task_color, "
            "COALESCE(t.work_factor, 1) AS work_factor, COALESCE(t.target_off, 0) AS target_off, "
            "COALESCE(t.holiday_days, 0) AS holiday_days FROM stamps s "
            "LEFT JOIN tasks t ON t.id = s.task_id "
            "WHERE substr(s.check_in, 1, 10) BETWEEN ? AND ? ORDER BY s.check_in, s.id",
            (start.isoformat(), end.isoformat())):
        lines.setdefault(row["check_in"][:10], []).append(row)
    for row in conn.execute(
            "SELECT n.date, n.note_type_id, n.text, nt.name AS type_name, nt.color AS type_color, "
            "nt.credit_factor, nt.holiday_days FROM day_notes n "
            "LEFT JOIN note_types nt ON nt.id = n.note_type_id WHERE n.date BETWEEN ? AND ?",
            (start.isoformat(), end.isoformat())):
        notes[row["date"]] = dict(row)
    return lines, notes


def _projected_breaks(work, breaks, values, target, running_start):
    """Breaks for a day that is still running, assuming it lasts until the target is met.

    Without this a break would only appear once its threshold is already passed, so a
    12:00 break could never be announced at 12:00.
    """
    actual = rules.day_breaks(work, breaks, values)
    worked = actual["work_min"] - actual["manual_break_min"]
    if worked >= target:
        return actual["auto_breaks"]
    others = [w for w in work if w[0] != running_start]
    now_end = max(e for s, e in work if s == running_start)
    end = now_end + dt.timedelta(minutes=target - worked)
    for _ in range(2):  # extend once more by the breaks the longer day needs
        projected = rules.day_breaks(others + [(running_start, end)], breaks, values)
        end = now_end + dt.timedelta(minutes=target + projected["auto_break_min"] - worked)
    return rules.day_breaks(others + [(running_start, end)], breaks, values)["auto_breaks"]


def _summarize(day, rows, note, values, now):
    date = day.isoformat()
    lines, work, breaks = [], [], []
    running_start = None
    discount = 0  # minutes of lines whose task counts only partly as work
    for row in rows:
        start = parse(row["check_in"])
        running = row["check_out"] is None
        end = max(start, now.replace(second=0, microsecond=0)) if running else parse(row["check_out"])
        duration = rules.minutes(start, end)
        if row["kind"] == "break":
            breaks.append((start, end))
        elif row["work_factor"] > 0:
            # Lines that do not count at all (on call, ...) stay out of the break rules.
            work.append((start, end))
            discount += duration - int(round(duration * row["work_factor"]))
            if running:
                running_start = start
        lines.append({
            "id": row["id"], "check_in": row["check_in"], "check_out": row["check_out"],
            "task_id": row["task_id"], "task_name": row["task_name"] or "",
            "task_color": row["task_color"] or "", "comment": row["comment"],
            "kind": row["kind"], "running": running,
            "work_factor": row["work_factor"],
            "duration_min": duration,
        })
    if not settings.breaks_apply(values, day):
        values = dict(values, **{"break.rules": []})
    if work:
        result = rules.day_breaks(work, breaks, values)
    else:
        result = {"work_min": 0, "manual_break_min": sum(rules.minutes(s, e) for s, e in breaks),
                  "gap_min": 0, "auto_break_min": 0, "auto_breaks": [], "net_min": 0}
    result["net_min"] = max(0, result["net_min"] - discount)

    target = settings.target_for(values, day)
    # A day with only lines of "no target" tasks (public holiday, ...) has no target.
    tasks_lines = [r for r in rows if r["kind"] != "break"]
    if tasks_lines and all(r["target_off"] for r in tasks_lines):
        target = 0
    intervals = result.pop("auto_breaks")
    if running_start is not None and values["break.mode"] != "deduct":
        intervals = _projected_breaks(work, breaks, values, target, running_start)
    # While checked in, breaks are planned; in split mode they become lines at check-out.
    planned = running_start is not None or values["break.mode"] == "split"
    for start, end in intervals:
        lines.append({
            "id": None, "check_in": fmt(start), "check_out": fmt(end),
            "task_id": None, "task_name": "", "task_color": "", "comment": "",
            "kind": "auto_break", "planned": planned, "running": False,
            "work_factor": 1, "duration_min": rules.minutes(start, end),
        })
    lines.sort(key=lambda l: l["check_in"])

    credit = int(round(target * note["credit_factor"])) if note and note["credit_factor"] else 0
    result.update({
        "date": date,
        "lines": lines,
        "target_min": target,
        "credit_min": credit,
        "delta_min": result["net_min"] + credit - target,
        "running": any(l["running"] for l in lines),
        "note": note,
        "holiday_days": max([(note["holiday_days"] or 0) if note else 0]
                            + [r["holiday_days"] for r in tasks_lines]),
    })
    return result


def days(conn, start, end, now, values=None):
    values = values or settings.get_all(conn)
    start, end = _date(start), _date(end)
    lines, notes = _load(conn, start, end)
    return [_summarize(d, lines.get(d.isoformat(), []), notes.get(d.isoformat()), values, now)
            for d in _days(start, end)]


def day_summary(conn, date, now, values=None):
    return days(conn, date, date, now, values)[0]


def balance(conn, until, now, values=None):
    """Flexitime: opening balance plus every day's delta from balance.start up to `until`.

    Days after today never count, so future targets do not show up as minus hours.
    """
    values = values or settings.get_all(conn)
    start = tracking_start(conn, values)
    if start is None:
        return values["balance.opening_min"]
    end = min(_date(until), now.date())
    if end < start:
        return values["balance.opening_min"]
    return values["balance.opening_min"] + sum(d["delta_min"] for d in days(conn, start, end, now, values))


def first_day(conn):
    row = conn.execute(
        "SELECT MIN(d) FROM (SELECT MIN(substr(check_in, 1, 10)) AS d FROM stamps "
        "UNION ALL SELECT MIN(date) FROM day_notes)").fetchone()
    return _date(row[0]) if row and row[0] else None


def tracking_start(conn, values):
    """First day that counts for balances and totals."""
    return _date(values["balance.start"]) if values["balance.start"] else first_day(conn)


def _counted(conn, values, day_list, now):
    # Totals only cover days from the tracking start up to today.
    start = tracking_start(conn, values)
    return [d for d in day_list
            if start is not None and start <= _date(d["date"]) <= now.date()]


def _totals(day_list):
    return {
        "net_min": sum(d["net_min"] for d in day_list),
        "target_min": sum(d["target_min"] for d in day_list),
        "credit_min": sum(d["credit_min"] for d in day_list),
        "delta_min": sum(d["delta_min"] for d in day_list),
        "break_min": sum(d["manual_break_min"] + d["gap_min"] + d["auto_break_min"] for d in day_list),
        "work_days": sum(1 for d in day_list if d["net_min"] > 0),
    }


def _compact(day):
    # Week/month rows do not need the individual lines.
    out = {k: v for k, v in day.items() if k != "lines"}
    out["line_count"] = sum(1 for l in day["lines"] if l["kind"] != "auto_break")
    return out


def task_totals(day_list):
    """Minutes per task (work lines; automatic deductions are not attributed to tasks)."""
    totals = {}
    for day in day_list:
        for line in day["lines"]:
            if line["kind"] != "work":
                continue
            key = line["task_id"]
            entry = totals.setdefault(key, {"task_id": key, "name": line["task_name"],
                                            "color": line["task_color"], "minutes": 0})
            entry["minutes"] += line["duration_min"]
    return sorted(totals.values(), key=lambda t: -t["minutes"])


def week_summary(conn, any_day, now, values=None):
    values = values or settings.get_all(conn)
    day = _date(any_day)
    start = day - dt.timedelta(days=day.weekday())
    end = start + dt.timedelta(days=6)
    day_list = days(conn, start, end, now, values)
    return {
        "start": start.isoformat(),
        "end": end.isoformat(),
        "week": start.isocalendar()[1],
        "days": [_compact(d) for d in day_list],
        "totals": _totals(_counted(conn, values, day_list, now)),
        "plan_target_min": sum(d["target_min"] for d in day_list),
        "tasks": task_totals(day_list),
        "balance_min": balance(conn, end, now, values),
    }


def month_summary(conn, year, month, now, values=None):
    values = values or settings.get_all(conn)
    start = dt.date(year, month, 1)
    end = (start.replace(day=28) + dt.timedelta(days=4)).replace(day=1) - dt.timedelta(days=1)
    day_list = days(conn, start, end, now, values)
    return {
        "year": year,
        "month": month,
        "start": start.isoformat(),
        "end": end.isoformat(),
        "days": [_compact(d) for d in day_list],
        "totals": _totals(_counted(conn, values, day_list, now)),
        "plan_target_min": sum(d["target_min"] for d in day_list),
        "tasks": task_totals(day_list),
        "balance_min": balance(conn, end, now, values),
        "holidays": holidays(conn, year, now, values),
    }


def holidays(conn, year, now, values=None):
    """Holiday balance of a year: entitlement + carryover - used/planned.

    A day uses the holiday days of its day type or of a task it has a line of
    (whichever is larger), so a day is never counted twice.
    """
    values = values or settings.get_all(conn)
    used = {}
    for row in conn.execute(
            "SELECT n.date AS d, nt.holiday_days AS h FROM day_notes n "
            "JOIN note_types nt ON nt.id = n.note_type_id "
            "WHERE substr(n.date, 1, 4) = ? AND nt.holiday_days > 0 "
            "UNION ALL SELECT substr(s.check_in, 1, 10), t.holiday_days FROM stamps s "
            "JOIN tasks t ON t.id = s.task_id "
            "WHERE substr(s.check_in, 1, 4) = ? AND t.holiday_days > 0 AND s.kind = 'work'",
            (str(year), str(year))):
        used[row["d"]] = max(used.get(row["d"], 0), row["h"])
    today = now.date().isoformat()
    taken = sum(h for d, h in used.items() if d <= today)
    planned = sum(h for d, h in used.items() if d > today)
    entitlement = float(values["holiday.entitlement"])
    carryover = float(values["holiday.carryover"].get(str(year), 0))
    return {
        "year": year,
        "entitlement": entitlement,
        "carryover": carryover,
        "taken": taken,
        "planned": planned,
        "remaining": entitlement + carryover - taken - planned,
    }
