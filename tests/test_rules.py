import datetime as dt

import pytest

from timerecord import rules


def t(s):
    return dt.datetime.fromisoformat("2026-10-05T" + s)


@pytest.mark.parametrize("raw,step,direction,expected", [
    ("08:07:45", 0, "nearest", "08:07"),
    ("08:07", 15, "nearest", "08:00"),
    ("08:08", 15, "nearest", "08:15"),
    ("08:07", 15, "down", "08:00"),
    ("08:01", 15, "up", "08:15"),
    ("08:15", 15, "up", "08:15"),
    ("23:55", 15, "up", "00:00"),
])
def test_round_time(raw, step, direction, expected):
    got = rules.round_time(t(raw), step, direction)
    assert got.strftime("%H:%M") == expected


def test_round_up_crosses_midnight():
    assert rules.round_time(t("23:55"), 15, "up") == dt.datetime(2026, 10, 6, 0, 0)


@pytest.mark.parametrize("end,auto", [
    ("13:59", 0),     # 5:59 worked
    ("14:00", 0),     # exactly 6:00 is not "more than"
    ("14:01", 1),     # 6:01, capped at threshold -> 6:00 net
    ("14:40", 30),    # 6:40 -> 30 min break
    ("17:01", 30),    # 9:01, after 30 min deduction 8:31 -> only first rule applies
    ("17:50", 45),    # 9:50 -> 9:05 net with 45 min
])
def test_break_thresholds(values, end, auto):
    r = rules.day_breaks([(t("08:00"), t(end))], [], values)
    assert r["auto_break_min"] == auto


def test_break_without_cap(values):
    values["break.cap_at_threshold"] = False
    r = rules.day_breaks([(t("08:00"), t("14:01"))], [], values)
    assert r["auto_break_min"] == 30
    assert r["net_min"] == 331


def test_gap_counts_as_break(values):
    work = [(t("08:00"), t("12:00")), (t("12:20"), t("16:00"))]
    r = rules.day_breaks(work, [], values)
    assert r["gap_min"] == 20
    assert r["auto_break_min"] == 10
    assert r["net_min"] == 450


def test_gaps_ignored_when_disabled(values):
    values["break.mode"] = "insert"
    values["break.count_gaps"] = False
    work = [(t("08:00"), t("12:00")), (t("12:20"), t("16:00"))]
    assert rules.day_breaks(work, [], values)["auto_break_min"] == 30


def test_manual_break_counts(values):
    r = rules.day_breaks([(t("08:00"), t("16:30"))], [(t("12:00"), t("12:30"))], values)
    assert r["manual_break_min"] == 30
    assert r["auto_break_min"] == 0
    assert r["net_min"] == 480


def test_insert_after_worked(values):
    r = rules.day_breaks([(t("08:00"), t("16:30"))], [], values)
    assert r["auto_breaks"] == [(t("12:00"), t("12:30"))]


def test_insert_after_worked_second_segment(values):
    work = [(t("07:00"), t("09:00")), (t("09:05"), t("16:00"))]
    r = rules.day_breaks(work, [], values)
    assert r["auto_breaks"] == [(t("11:05"), t("11:30"))]


def test_insert_fixed_time(values):
    values["break.placement"] = "fixed"
    values["break.fixed_time"] = "12:30"
    r = rules.day_breaks([(t("08:00"), t("16:30"))], [], values)
    assert r["auto_breaks"] == [(t("12:30"), t("13:00"))]


def test_fixed_time_outside_work_falls_back(values):
    values["break.placement"] = "fixed"
    values["break.fixed_time"] = "06:00"
    r = rules.day_breaks([(t("08:00"), t("16:30"))], [], values)
    assert r["auto_breaks"] == [(t("12:00"), t("12:30"))]


def test_deduct_mode_has_no_line(values):
    values["break.mode"] = "deduct"
    r = rules.day_breaks([(t("08:00"), t("16:30"))], [], values)
    assert r["auto_breaks"] == []
    assert r["net_min"] == 480


def test_rules_editable(values):
    values["break.rules"] = [{"after_min": 240, "break_min": 15}]
    r = rules.day_breaks([(t("08:00"), t("13:00"))], [], values)
    assert r["auto_break_min"] == 15


def test_gaps_always_count_in_split_mode(values):
    values["break.count_gaps"] = False
    work = [(t("08:00"), t("12:00")), (t("12:30"), t("16:30"))]
    assert rules.day_breaks(work, [], values)["auto_break_min"] == 0


def test_rule_time_per_part(values):
    values["break.rules"] = [{"after_min": 360, "break_min": 30, "at": "12:00"},
                             {"after_min": 540, "break_min": 45, "at": "15:00"}]
    r = rules.day_breaks([(t("07:00"), t("17:00"))], [], values)  # 10:00 worked
    assert r["auto_break_min"] == 45
    assert r["auto_breaks"] == [(t("12:00"), t("12:30")), (t("15:00"), t("15:15"))]


def test_rule_time_outside_work_uses_global_placement(values):
    values["break.rules"] = [{"after_min": 360, "break_min": 30, "at": "05:00"}]
    r = rules.day_breaks([(t("08:00"), t("16:30"))], [], values)
    assert r["auto_breaks"] == [(t("12:00"), t("12:30"))]


def test_overlapping_parts_are_laid_out_in_sequence(values):
    values["break.rules"] = [{"after_min": 360, "break_min": 30, "at": "12:00"},
                             {"after_min": 540, "break_min": 45, "at": "12:10"}]
    r = rules.day_breaks([(t("07:00"), t("17:00"))], [], values)
    assert r["auto_breaks"] == [(t("12:00"), t("12:45"))]
