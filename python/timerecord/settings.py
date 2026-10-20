# SPDX-License-Identifier: GPL-3.0-or-later
"""Operator-editable settings. DEFAULTS are seed values only; the Settings UI edits them."""
import datetime
import json

WEEKDAYS = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]

DEFAULTS = {
    # Target minutes per weekday.
    "target.mon": 480,
    "target.tue": 480,
    "target.wed": 480,
    "target.thu": 480,
    "target.fri": 480,
    "target.sat": 0,
    "target.sun": 0,
    # Break rules: worked more than after_min => at least break_min break in total.
    # Optional "at": "HH:MM" places the part this rule adds at that time.
    "break.rules": [{"after_min": 360, "break_min": 30, "at": ""},
                    {"after_min": 540, "break_min": 45, "at": ""}],
    # Missing break: "split" checks out at the break start and in again at its end,
    # "insert" shows a computed break line, "deduct" only subtracts it from the total.
    "break.mode": "split",
    # Where an automatic break goes unless its rule has a time: "after_worked"
    # (after break.after_worked_min of work) or "fixed" (at break.fixed_time).
    "break.placement": "after_worked",
    "break.after_worked_min": 240,
    "break.fixed_time": "12:00",
    # Never let the auto break push net work time below the rule threshold (6:10 -> 6:00).
    "break.cap_at_threshold": True,
    # Days before this date ("YYYY-MM-DD", "" = all days) get no automatic breaks, so
    # imported history keeps the totals of the app it came from.
    "break.since": "",
    # Gaps between check-out and next check-in on the same day count as break.
    "break.count_gaps": True,
    # Punch rounding: step in minutes (0/1 = off), direction "up" | "down" | "nearest".
    "round.in_step": 0,
    "round.in_dir": "nearest",
    "round.out_step": 0,
    "round.out_dir": "nearest",
    # Flexitime balance. Empty start = from the first day with any line or note.
    "balance.start": "",
    "balance.opening_min": 0,
    # Vacation days for a year without its own entry and no earlier year to copy from.
    # Per-year days and carryover live in the vacation_years table (D-026).
    "vacation.default_days": 30.0,
    # Ignore a check-in/out this soon after the previous one (double taps).
    "punch.debounce_sec": 10,
    # Reminders (notifications while the app runs, also in the background/on the cover).
    "remind.enabled": True,
    "remind.interval_sec": 150,          # how often to check: 30, 150, 300 or 600
    "remind.checkout_after_min": 600,    # still checked in after this long (0 = off)
    "remind.target_reached": True,
    "remind.checkin_time": "",           # "HH:MM" on workdays when not checked in ("" = off)
    "remind.break": True,                # when an automatic break starts
    # Undo depth and automatic backups.
    "undo.depth": 50,
    "backup.auto_days": 7,
    "backup.keep": 10,
    # SPX CSV export (D-028): type of work lines, of breaks, and per task {"<task id>": type}.
    "export.spx_work_type": "Normalarbeitszeit",
    "export.spx_break_type": "Pause",
    "export.spx_task_types": {},
    # Day note (day type or text) of a business trip and its fixed times (D-029).
    "export.spx_trip_note": "Dienstreise",
    "export.spx_trip_start": "06:30",
    "export.spx_trip_break_start": "11:30",
    "export.spx_trip_break_end": "12:00",
    "export.spx_trip_end": "14:42",
    # Day note of on-call standby, its type, and the handover time on weekends (D-029).
    "export.spx_oncall_note": "Rufbereitschaft",
    "export.spx_oncall_type": "Rufbereitschaft TVL",
    "export.spx_oncall_handover": "07:00",
    # UI.
    "ui.last_task_id": 1,
    # Reminders already sent today: {"date": "YYYY-MM-DD", "keys": [...]}.
    "ui.reminders_sent": {},
}

SPX_TIMES = ("export.spx_trip_start", "export.spx_trip_break_start", "export.spx_trip_break_end",
             "export.spx_trip_end", "export.spx_oncall_handover")


def get(conn, key):
    row = conn.execute("SELECT value FROM settings WHERE key = ?", (key,)).fetchone()
    if row is None:
        return DEFAULTS.get(key)
    return json.loads(row["value"])


def get_all(conn):
    values = dict(DEFAULTS)
    for row in conn.execute("SELECT key, value FROM settings"):
        values[row["key"]] = json.loads(row["value"])
    return values


def set(conn, key, value):
    if key not in DEFAULTS:
        raise KeyError("unknown setting %r" % key)
    expected = type(DEFAULTS[key])
    if expected is float and isinstance(value, int):
        value = float(value)
    elif expected is int and isinstance(value, float) and value.is_integer():
        value = int(value)
    if not isinstance(value, expected) or (expected is int and isinstance(value, bool)):
        raise ValueError("setting %r expects %s" % (key, expected.__name__))
    if key == "break.rules":
        value = [_rule(r) for r in value]
    if key in ("remind.checkin_time", "break.fixed_time") and value \
            or key in SPX_TIMES:
        value = _hhmm(value)
    if key in ("break.since", "balance.start") and value:
        value = _date(value)
    if key in ("export.spx_work_type", "export.spx_break_type", "export.spx_oncall_type"):
        value = _csv_cell(value)
        if not value:
            raise ValueError("type must not be empty")
    if key in ("export.spx_trip_note", "export.spx_oncall_note"):
        value = value.strip()
    if key == "export.spx_task_types":
        value = {str(k): _csv_cell(v) for k, v in value.items() if isinstance(v, str) and _csv_cell(v)}
    conn.execute("INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)",
                 (key, json.dumps(value)))


def _rule(rule):
    after, length, at = rule.get("after_min"), rule.get("break_min"), rule.get("at") or ""
    if isinstance(after, float) and after.is_integer():
        after = int(after)
    if isinstance(length, float) and length.is_integer():
        length = int(length)
    if not isinstance(after, int) or not isinstance(length, int) or after < 0 or length <= 0:
        raise ValueError("break rule needs after_min >= 0 and break_min > 0")
    return {"after_min": after, "break_min": length, "at": _hhmm(at) if at else ""}


def _hhmm(value):
    parts = value.split(":")
    if len(parts) != 2 or not all(p.isdigit() for p in parts) \
            or not (0 <= int(parts[0]) < 24 and 0 <= int(parts[1]) < 60):
        raise ValueError("time must be HH:MM")
    return "%02d:%02d" % (int(parts[0]), int(parts[1]))


def _csv_cell(value):
    # One cell of a ;-separated CSV line.
    return " ".join(value.replace(";", " ").split())


def _date(value):
    try:
        return datetime.date.fromisoformat(value).isoformat()
    except ValueError:
        raise ValueError("date must be YYYY-MM-DD")


def breaks_apply(values, day):
    """Whether automatic breaks are evaluated for `day` (a date)."""
    return not values["break.since"] or day.isoformat() >= values["break.since"]


def target_for(values, day):
    return values["target." + WEEKDAYS[day.weekday()]]
