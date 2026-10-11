# SPDX-License-Identifier: GPL-3.0-or-later
"""Punch rounding and automatic break rules. Pure functions, no database access."""
import datetime as dt


def round_time(t, step, direction):
    """Round a datetime to a multiple of `step` minutes; seconds are always dropped."""
    t = t.replace(second=0, microsecond=0)
    if step is None or step <= 1:
        return t
    midnight = t.replace(hour=0, minute=0)
    minutes = (t - midnight).seconds // 60
    rest = minutes % step
    if rest == 0:
        return t
    if direction == "down" or (direction == "nearest" and rest * 2 < step):
        minutes -= rest
    else:
        minutes += step - rest
    return midnight + dt.timedelta(minutes=minutes)


def minutes(start, end):
    return max(0, int((end - start).total_seconds() // 60))


def required_breaks(worked, taken, rules, cap_at_threshold):
    """Break minutes still missing, split into the part each rule adds.

    worked: minutes of work (manual breaks already removed)
    taken: minutes of break already taken (manual breaks and gaps)
    Returns [(minutes, rule), ...]; the sum is the total to deduct.
    """
    deduct = 0
    parts = []
    for rule in sorted(rules, key=lambda r: r["after_min"]):
        after, needed = rule["after_min"], rule["break_min"]
        if worked - deduct <= after or taken + deduct >= needed:
            continue
        want = needed - taken
        if cap_at_threshold:
            want = min(want, worked - after)
        if want > deduct:
            parts.append((want - deduct, rule))
            deduct = want
    return parts


def required_deduction(worked, taken, rules, cap_at_threshold):
    return sum(m for m, _ in required_breaks(worked, taken, rules, cap_at_threshold))


def counts_gaps(values):
    # Split mode turns breaks into gaps, so gaps must count or rules would never be met.
    return values["break.count_gaps"] or values["break.mode"] == "split"


def day_breaks(work, breaks, values):
    """Evaluate one day.

    work, breaks: lists of (start, end) datetimes, end already resolved for running lines.
    Returns minutes and the automatic break intervals (empty in deduct mode).
    """
    work = sorted(work)
    work_min = sum(minutes(s, e) for s, e in work)
    manual = sum(minutes(s, e) for s, e in breaks)
    gaps = 0
    if counts_gaps(values):
        for (_, prev_end), (next_start, _) in zip(work, work[1:]):
            gaps += minutes(prev_end, next_start)
    worked = max(0, work_min - manual)
    taken = manual + gaps
    parts = required_breaks(worked, taken, values["break.rules"], values["break.cap_at_threshold"])
    auto = sum(m for m, _ in parts)
    intervals = []
    if parts and values["break.mode"] in ("insert", "split"):
        intervals = place_breaks(work, parts, values)
    return {
        "work_min": work_min,
        "manual_break_min": manual,
        "gap_min": gaps,
        "auto_break_min": auto,
        "auto_breaks": intervals,
        "net_min": worked - auto,
    }


def _fit(segment, at, length):
    start, end = segment
    if at + dt.timedelta(minutes=length) > end:
        at = end - dt.timedelta(minutes=length)
    at = max(at, start)
    return at, at + dt.timedelta(minutes=length)


def _segment_at(work, at):
    for segment in work:
        if segment[0] <= at < segment[1]:
            return segment
    return None


def _after_worked(work, worked_min):
    """Point in time after `worked_min` minutes of work, and its segment."""
    remaining = worked_min
    for start, end in work:
        span = minutes(start, end)
        if remaining <= span:
            return (start, end), start + dt.timedelta(minutes=remaining)
        remaining -= span
    return work[-1], work[-1][1]


def _at_time(work, hhmm):
    hour, minute = (int(x) for x in hhmm.split(":"))
    for start, end in work:
        at = start.replace(hour=hour, minute=minute, second=0, microsecond=0)
        if start <= at < end:
            return (start, end), at
    return None


def place_breaks(work, parts, values):
    """Place each rule's break part: at the rule's own time, else at the global placement.

    Parts that would overlap are laid out one after the other.
    """
    placed = []
    for length, rule in parts:
        target = None
        if rule.get("at"):
            target = _at_time(work, rule["at"])
        if target is None and values["break.placement"] == "fixed":
            target = _at_time(work, values["break.fixed_time"])
        if target is None:
            target = _after_worked(work, values["break.after_worked_min"])
        placed.append((target[1], length, target[0]))
    placed.sort(key=lambda p: p[0])

    intervals = []
    for at, length, segment in placed:
        if intervals and at < intervals[-1][1]:
            at = intervals[-1][1]
            segment = _segment_at(work, at) or segment
        start, end = _fit(segment, at, length)
        if intervals and start == intervals[-1][1]:
            # Touching parts form one break (one check-out/check-in pair).
            intervals[-1] = (intervals[-1][0], end)
        else:
            intervals.append((start, end))
    return intervals
