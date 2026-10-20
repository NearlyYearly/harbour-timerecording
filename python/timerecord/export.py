# SPDX-License-Identifier: GPL-3.0-or-later
"""CSV export for SPX (the ESS Monatsjournal filler): one row per interval.

    datum;typ;von;bis
    2026-10-15;Normalarbeitszeit;07:30;11:30
    2026-10-15;Pause;11:30;12:15

Work lines are cut around breaks, so intervals never overlap. Breaks are the break lines,
the automatic breaks and, when gaps count as breaks, the gaps between work lines. A line
past midnight keeps its clock time; SPX reads bis <= von as the next day (D-028).

Day notes: a business trip day gets fixed times, an on-call day a standby row up to the
next day (D-029). Both are found by day type or note text.
"""
import datetime as dt
import os

from . import calc, rules, settings
from .store import parse

HEADER = "datum;typ;von;bis"


def _merge(intervals):
    merged = []
    for start, end in sorted(intervals):
        if merged and start <= merged[-1][1]:
            merged[-1] = (merged[-1][0], max(merged[-1][1], end))
        else:
            merged.append((start, end))
    return merged


def _subtract(start, end, pauses):
    parts = []
    for p_start, p_end in pauses:
        if p_end <= start or p_start >= end:
            continue
        if p_start > start:
            parts.append((start, p_start))
        start = max(start, p_end)
    if start < end:
        parts.append((start, end))
    return parts


def _note_is(note, name):
    """Whether a day note means `name`: its day type or its text, ignoring case."""
    name = name.strip().lower()
    return bool(note and name) and name in (
        (note.get("type_name") or "").strip().lower(), (note.get("text") or "").strip().lower())


def _at(date, hhmm):
    return dt.datetime.combine(dt.date.fromisoformat(date), dt.time(*(int(x) for x in hhmm.split(":"))))


def _trip_rows(date, values):
    """The fixed day of a business trip: work, break, work."""
    work, pause = values["export.spx_work_type"], values["export.spx_break_type"]
    times = [_at(date, values[k]) for k in ("export.spx_trip_start", "export.spx_trip_break_start",
                                            "export.spx_trip_break_end", "export.spx_trip_end")]
    return [(times[0], work, times[1]), (times[1], pause, times[2]), (times[2], work, times[3])]


def _line_rows(day, values, task_lines_only=False):
    task_types = values["export.spx_task_types"]
    lines = [l for l in day["lines"] if l["check_out"]]
    work = [l for l in lines if l["kind"] == "work"]
    if task_lines_only:
        # A business trip replaces the day's own work and breaks; lines of a task with
        # its own type (on-call work, ...) stay.
        lines = work = [l for l in work if task_types.get(str(l["task_id"]))]
    pauses = [(parse(l["check_in"]), parse(l["check_out"])) for l in lines if l["kind"] != "work"]
    if rules.counts_gaps(values) and not task_lines_only:
        # Only lines that count as work leave a gap that is a break (as in calc).
        counted = sorted((parse(l["check_in"]), parse(l["check_out"]))
                         for l in work if l["work_factor"] > 0)
        pauses += [(prev_end, next_start) for (_, prev_end), (next_start, _)
                   in zip(counted, counted[1:]) if next_start > prev_end]
    pauses = _merge(pauses)

    rows = [(start, values["export.spx_break_type"], end) for start, end in pauses]
    for line in work:
        typ = task_types.get(str(line["task_id"])) or values["export.spx_work_type"]
        for start, end in _subtract(parse(line["check_in"]), parse(line["check_out"]), pauses):
            rows.append((start, typ, end))
    return rows


def _rows(day, values):
    """[(start, typ, end)] of one day from calc.days, without on-call standby."""
    if day["running"]:
        return []
    if _note_is(day["note"], values["export.spx_trip_note"]):
        return _trip_rows(day["date"], values) + _line_rows(day, values, task_lines_only=True)
    return _line_rows(day, values)


def _oncall_row(day, rows, next_rows, values):
    """On-call standby: Mon-Fri from the day's last work to the next day's first work,
    Sat/Sun from handover to handover (and handover where a day has no work)."""
    work = values["export.spx_work_type"]
    handover = values["export.spx_oncall_handover"]
    next_date = (dt.date.fromisoformat(day["date"]) + dt.timedelta(days=1)).isoformat()
    start, end = _at(day["date"], handover), _at(next_date, handover)
    if dt.date.fromisoformat(day["date"]).weekday() < 5:
        ends = [e for _, typ, e in rows if typ == work]
        starts = [s for s, typ, _ in next_rows if typ == work]
        start = max(ends) if ends else start
        end = min(starts) if starts else end
    return start, values["export.spx_oncall_type"], end


def spx_rows(conn, start, end, now):
    """[(date, typ, start, end)] for start..end (ISO dates)."""
    values = settings.get_all(conn)
    # One day more: on-call standby ends with the next day's first work.
    last = (dt.date.fromisoformat(end) + dt.timedelta(days=1)).isoformat()
    day_list = calc.days(conn, start, last, now, values)
    rows = [_rows(d, values) for d in day_list]
    out = []
    for i, day in enumerate(day_list[:-1]):
        day_rows = list(rows[i])
        if not day["running"] and _note_is(day["note"], values["export.spx_oncall_note"]):
            day_rows.append(_oncall_row(day, rows[i], rows[i + 1], values))
        out += [(day["date"], typ, s, e) for s, typ, e in sorted(day_rows) if e > s]
    return out


def spx_csv(conn, start, end, now):
    out = [HEADER] + ["%s;%s;%s;%s" % (date, typ, s.strftime("%H:%M"), e.strftime("%H:%M"))
                      for date, typ, s, e in spx_rows(conn, start, end, now)]
    return "\n".join(out) + "\n"


def month_range(first, last):
    """First and last day of the months first..last ("YYYY-MM")."""
    start = dt.date.fromisoformat(first + "-01")
    end = dt.date.fromisoformat(last + "-01")
    if end < start:
        raise ValueError("last month is before the first")
    end = (end.replace(day=28) + dt.timedelta(days=4)).replace(day=1) - dt.timedelta(days=1)
    return start.isoformat(), end.isoformat()


def export_spx(conn, directory, first, last, now):
    """Write the SPX CSV of the months first..last ("YYYY-MM") to `directory`.

    Returns the path and the number of rows.
    """
    start, end = month_range(first, last)
    text = spx_csv(conn, start, end, now)
    os.makedirs(directory, exist_ok=True)
    name = first if first == last else "%s-%s" % (first, last)
    path = os.path.join(directory, "timerecord-spx-%s.csv" % name)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8", newline="") as f:
        f.write(text)
    os.replace(tmp, path)
    return {"path": path, "rows": text.count("\n") - 1}
