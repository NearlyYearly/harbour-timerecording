# SPDX-License-Identifier: GPL-3.0-or-later
import datetime as dt
import sqlite3

import pytest

from timerecord import calc, db, settings
from timerecord.store import Store


def lines(conn):
    return [(r["check_in"][11:], r["check_out"][11:] if r["check_out"] else None, r["task_id"])
            for r in conn.execute("SELECT * FROM stamps ORDER BY check_in, id")]


# --- automatic break as check-out / check-in ------------------------------------

def test_checkout_splits_line_at_break(conn, store, clock):
    clock.set("2026-10-05T08:00")
    store.punch(1)
    clock.set("2026-10-05T16:30")
    store.punch()
    assert lines(conn) == [("08:00", "12:00", 1), ("12:30", "16:30", 1)]
    day = calc.day_summary(conn, "2026-10-05", clock())
    assert day["net_min"] == 480 and day["auto_break_min"] == 0 and day["gap_min"] == 30


def test_undo_checkout_removes_split(conn, store, clock):
    store.punch(1)
    clock.set("2026-10-05T16:30")
    store.punch()
    assert store.undo() == "Check out"
    assert lines(conn) == [("08:00", None, 1)]
    store.redo()
    assert lines(conn) == [("08:00", "12:00", 1), ("12:30", "16:30", 1)]


def test_split_at_exact_rule_times(conn, store, clock):
    settings.set(conn, "break.rules", [{"after_min": 360, "break_min": 30, "at": "12:00"},
                                       {"after_min": 540, "break_min": 45, "at": "15:00"}])
    store.add_stamp({"check_in": "2026-10-05T07:00", "check_out": "2026-10-05T17:00", "task_id": 1})
    assert lines(conn) == [("07:00", "12:00", 1), ("12:30", "15:00", 1), ("15:15", "17:00", 1)]
    assert calc.day_summary(conn, "2026-10-05", clock())["net_min"] == 555
    store.undo()
    assert lines(conn) == []


def test_split_at_global_fixed_time(conn, store, clock):
    settings.set(conn, "break.placement", "fixed")
    settings.set(conn, "break.fixed_time", "12:15")
    store.add_stamp({"check_in": "2026-10-05T08:00", "check_out": "2026-10-05T16:30"})
    assert lines(conn) == [("08:00", "12:15", None), ("12:45", "16:30", None)]


def test_split_keeps_task_and_comment(conn, store):
    store.add_stamp({"check_in": "2026-10-05T08:00", "check_out": "2026-10-05T16:30",
                     "task_id": 1, "comment": "x"})
    rows = conn.execute("SELECT task_id, comment FROM stamps").fetchall()
    assert [tuple(r) for r in rows] == [(1, "x"), (1, "x")]


def test_split_when_break_reaches_line_end(conn, store, clock):
    # Break after 6:30 of work does not fit before 14:40: it ends at the check-out,
    # so it is recorded as a break line rather than a gap.
    settings.set(conn, "break.after_worked_min", 390)
    store.add_stamp({"check_in": "2026-10-05T08:00", "check_out": "2026-10-05T14:40"})
    kinds = [r["kind"] for r in conn.execute("SELECT kind FROM stamps ORDER BY check_in")]
    assert lines(conn) == [("08:00", "14:40", None), ("14:10", "14:40", None)] and kinds == ["work", "break"]
    assert calc.day_summary(conn, "2026-10-05", clock())["net_min"] == 370


def test_existing_lunch_gap_prevents_split(conn, store):
    store.add_stamp({"check_in": "2026-10-05T08:00", "check_out": "2026-10-05T12:00"})
    store.add_stamp({"check_in": "2026-10-05T12:45", "check_out": "2026-10-05T17:00"})
    assert len(lines(conn)) == 2


def test_running_day_shows_planned_break(conn, store, clock):
    store.punch(1)
    clock.set("2026-10-05T15:00")
    day = calc.day_summary(conn, "2026-10-05", clock())
    planned = [l for l in day["lines"] if l["kind"] == "auto_break"]
    assert len(planned) == 1 and planned[0]["planned"]
    assert len(lines(conn)) == 1  # nothing written while running


def test_insert_mode_does_not_split(conn, store):
    settings.set(conn, "break.mode", "insert")
    store.add_stamp({"check_in": "2026-10-05T08:00", "check_out": "2026-10-05T16:30"})
    assert len(lines(conn)) == 1


def test_rule_validation(conn):
    with pytest.raises(ValueError):
        settings.set(conn, "break.rules", [{"after_min": 360, "break_min": 0}])
    with pytest.raises(ValueError):
        settings.set(conn, "break.rules", [{"after_min": 360, "break_min": 30, "at": "25:00"}])
    settings.set(conn, "break.rules", [{"after_min": 360.0, "break_min": 30, "at": "9:5"}])
    assert settings.get(conn, "break.rules") == [{"after_min": 360, "break_min": 30, "at": "09:05"}]


# --- double-tap guard ------------------------------------------------------------

def test_punch_debounce(conn, store, clock):
    clock.set("2026-10-05T08:00:00")
    assert store.punch(1) is not None
    clock.set("2026-10-05T08:00:05")
    assert store.punch() is None
    assert store.running() is not None
    clock.set("2026-10-05T08:00:11")
    assert store.punch() is not None
    assert store.running() is None
    clock.set("2026-10-05T08:00:15")
    assert store.punch(1) is None


def test_debounce_setting(conn, store, clock):
    settings.set(conn, "punch.debounce_sec", 0)
    store.punch(1)
    assert store.punch() is not None


# --- week, month, balance, holidays ---------------------------------------------

def week_of_work(store):
    # Mon..Fri 2026-10-05..09, 8:30 each with a 30 min lunch gap -> 8:00 net
    for d in range(5, 10):
        store.add_stamp({"check_in": "2026-10-%02dT08:00" % d, "check_out": "2026-10-%02dT12:00" % d, "task_id": 1})
        store.add_stamp({"check_in": "2026-10-%02dT12:30" % d, "check_out": "2026-10-%02dT16:30" % d, "task_id": 1})


def test_week_summary(conn, store, clock):
    week_of_work(store)
    store.add_stamp({"check_in": "2026-10-09T16:30", "check_out": "2026-10-09T17:30", "task_id": 1})
    clock.set("2026-10-11T20:00")
    week = calc.week_summary(conn, "2026-10-08", clock())
    assert week["start"] == "2026-10-05" and week["end"] == "2026-10-11" and week["week"] == 41
    assert week["totals"]["net_min"] == 5 * 480 + 60
    assert week["totals"]["target_min"] == 5 * 480
    assert week["totals"]["delta_min"] == 60
    assert week["tasks"][0]["minutes"] == 5 * 480 + 60
    assert "lines" not in week["days"][0] and week["days"][0]["line_count"] == 2


def test_balance_counts_only_past_days(conn, store, clock):
    settings.set(conn, "balance.start", "2026-10-05")
    settings.set(conn, "balance.opening_min", 120)
    week_of_work(store)
    clock.set("2026-10-07T20:00")  # Wednesday evening
    assert calc.balance(conn, "2026-10-07", clock()) == 120
    assert calc.balance(conn, "2026-12-31", clock()) == 120  # future days ignored
    clock.set("2026-10-12T20:00")  # next Monday, nothing worked -> -8:00
    assert calc.balance(conn, "2026-10-12", clock()) == 120 - 480


def test_balance_from_first_recorded_day(conn, store, clock):
    # Default: no fixed start, so days before the first line do not count as minus hours.
    store.add_stamp({"check_in": "2026-10-05T08:00", "check_out": "2026-10-05T12:00"})
    store.add_stamp({"check_in": "2026-10-05T12:30", "check_out": "2026-10-05T16:30"})
    clock.set("2026-10-05T20:00")
    assert calc.balance(conn, "2026-10-05", clock()) == 0


def test_balance_without_data_is_opening(conn, clock):
    settings.set(conn, "balance.opening_min", -15)
    assert calc.balance(conn, "2026-10-05", clock()) == -15


def test_balance_before_start_is_opening(conn, store, clock):
    settings.set(conn, "balance.start", "2026-11-01")
    settings.set(conn, "balance.opening_min", 30)
    assert calc.balance(conn, "2026-10-05", clock()) == 30


def test_month_and_vacation(conn, store, clock):
    store.set_vacation_year(2026, 30, 2.5)
    store.set_day_note("2026-10-01", 1, "")   # vacation, past
    store.set_day_note("2026-10-02", 2, "")   # half, past
    store.set_day_note("2026-12-28", 1, "")   # planned
    store.set_day_note("2026-10-06", 3, "")   # sick: no vacation
    clock.set("2026-10-05T12:00")
    month = calc.month_summary(conn, 2026, 10, clock())
    assert len(month["days"]) == 31 and month["end"] == "2026-10-31"
    h = month["vacation"]
    assert (h["taken"], h["planned"], h["remaining"]) == (1.5, 1.0, 30)
    # Oct 1 (Thu) vacation credits the full target, Oct 2 (Fri) half vacation half of it.
    oct1, oct2 = month["days"][0], month["days"][1]
    assert oct1["delta_min"] == 0 and oct2["delta_min"] == -240


def test_february_month_length(conn, clock):
    assert len(calc.month_summary(conn, 2028, 2, clock())["days"]) == 29


# --- templates and note types ----------------------------------------------------

def test_template_round_trip(conn, store, clock):
    store.add_stamp({"check_in": "2026-10-05T08:00", "check_out": "2026-10-05T12:00", "task_id": 1})
    store.add_stamp({"check_in": "2026-10-05T12:30", "check_out": "2026-10-05T16:30", "task_id": 1})
    store.save_template("Standard", "2026-10-05")
    tid = conn.execute("SELECT id FROM templates").fetchone()[0]
    store.apply_template(tid, "2026-10-06")
    assert [l for l in lines(conn) if True][2:] == [("08:00", "12:00", 1), ("12:30", "16:30", 1)]
    assert store.undo() == "Apply template"
    assert len(lines(conn)) == 2
    store.rename_template(tid, "Normal")
    store.delete_template(tid)
    store.undo()
    assert conn.execute("SELECT name FROM templates").fetchone()[0] == "Normal"


def test_template_needs_finished_lines(store):
    with pytest.raises(ValueError):
        store.save_template("Empty", "2026-10-05")


def test_note_types(conn, store):
    store.add_note_type({"name": "Training", "credit_factor": 1, "holiday_days": 0, "color": "#123456"})
    tid = conn.execute("SELECT id FROM note_types WHERE name = 'Training'").fetchone()[0]
    store.update_note_type(tid, {"archived": 1})
    assert conn.execute("SELECT archived FROM note_types WHERE id = ?", (tid,)).fetchone()[0] == 1
    store.undo()
    assert conn.execute("SELECT archived FROM note_types WHERE id = ?", (tid,)).fetchone()[0] == 0
    with pytest.raises(ValueError):
        store.update_note_type(tid, {"credit_factor": 2})


def test_migration_from_v1(tmp_path):
    path = str(tmp_path / "old.sqlite")
    raw = sqlite3.connect(path)
    raw.executescript("BEGIN;" + db.MIGRATIONS[0] + "PRAGMA user_version = 1; COMMIT;")
    raw.execute("INSERT INTO stamps (check_in, check_out) VALUES ('2026-10-05T08:00', '2026-10-05T09:00')")
    raw.commit()
    raw.close()
    conn = db.connect(path)
    assert conn.execute("PRAGMA user_version").fetchone()[0] == db.SCHEMA_VERSION
    assert conn.execute("SELECT COUNT(*) FROM stamps").fetchone()[0] == 1
    assert conn.execute("SELECT archived FROM note_types LIMIT 1").fetchone()[0] == 0


def test_month_totals_start_at_first_recorded_day(conn, store, clock):
    store.add_stamp({"check_in": "2026-10-08T08:00", "check_out": "2026-10-08T12:00"})
    clock.set("2026-10-08T20:00")
    month = calc.month_summary(conn, 2026, 10, clock())
    assert month["totals"]["target_min"] == 480 and month["totals"]["delta_min"] == -240
    assert month["balance_min"] == -240


def test_planned_break_shown_from_check_in(conn, store, clock):
    store.punch(1)
    clock.set("2026-10-05T09:00")  # only 1:00 worked, nothing deducted yet
    day = calc.day_summary(conn, "2026-10-05", clock())
    planned = [(l["check_in"][11:], l["check_out"][11:]) for l in day["lines"] if l["kind"] == "auto_break"]
    assert planned == [("12:00", "12:30")]
    assert day["net_min"] == 60 and day["auto_break_min"] == 0


def test_planned_breaks_for_long_target(conn, store, clock):
    settings.set(conn, "target.mon", 570)  # 9:30 target -> both rules apply
    store.punch(1)
    clock.set("2026-10-05T09:00")
    day = calc.day_summary(conn, "2026-10-05", clock())
    planned = [(l["check_in"][11:], l["check_out"][11:]) for l in day["lines"] if l["kind"] == "auto_break"]
    assert planned == [("12:00", "12:45")]
