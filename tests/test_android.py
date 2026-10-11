"""Import from Time Recording for Android. The fixture is a made-up database in its format."""
import sqlite3

import pytest

from android_fixture import make_backup
from timerecord import android, calc, settings


@pytest.fixture
def backup_file(tmp_path):
    return make_backup(tmp_path / "timerec", gz=True)


def test_read_pairs_events(backup_file):
    data = android.read(backup_file)
    got = [(android.fmt(l["check_in"]), android.fmt(l["check_out"]), l["android_task"]) for l in data["lines"]]
    assert got[:3] == [("2026-01-05T06:30", "2026-01-05T11:30", 1),
                       ("2026-01-05T12:00", "2026-01-05T15:00", 1),
                       ("2026-01-06T07:00", "2026-01-06T07:00", 6)]
    assert ("2026-01-09T22:00", "2026-01-10T01:30", 4) in got  # over midnight, same day
    assert data["lines"][0]["comment"] == "Deploy"
    assert android.fmt(data["running"]["check_in"]) == "2026-01-13T06:30"
    assert data["problems"] == [{"date": "2026-01-11", "time": "10:00", "problem": "check-out without check-in"}]


def test_read_tasks_and_rules(backup_file):
    tasks = {t["name"]: t for t in android.read(backup_file)["tasks"]}
    assert tasks["Office"]["work_factor"] == 1 and not tasks["Office"]["target_off"]
    assert tasks["On call"]["work_factor"] == 0 and tasks["On call"]["target_off"] == 1
    assert tasks["Paid overtime"]["work_factor"] == 0  # TIME_SUM_OFF
    assert tasks["Leave"]["holiday_days"] == 1  # counted by the "Urlaub" tracker
    assert tasks["Office"]["holiday_days"] == 0  # other tracker
    assert tasks["Old project"]["archived"] == 1


def test_read_settings(backup_file):
    data = android.read(backup_file)
    s = data["settings"]
    assert s["target.mon"] == 462 and s["target.sat"] == 0 and s["target.sun"] == 0
    assert s["break.rules"] == [{"after_min": 360, "break_min": 30, "at": "11:30"},
                                {"after_min": 540, "break_min": 45, "at": "11:30"}]
    assert s["balance.start"] == "2026-01-01" and s["balance.opening_min"] == 600
    assert not any(k.startswith("holiday.") for k in s)
    assert data["vacation_years"] == [{"year": 2025, "days": 30, "carryover": 0},
                                      {"year": 2026, "days": 30, "carryover": 4.5}]
    assert s["break.since"] == "2026-01-14"
    assert {"what": "week_targets", "value": 1} in data["not_imported"]
    assert {"what": "rounding", "value": "30"} in data["not_imported"]
    assert {"what": "reminders", "value": 1} in data["not_imported"]
    assert data["templates"] == [{"name": "Leave day", "lines": [
        {"start": "07:00", "end": "14:42", "android_task": 2, "kind": "work", "comment": ""}]}]
    assert [n["date"] for n in data["notes"]] == ["2026-01-09", "2026-01-10"]  # blank note dropped


def test_not_a_backup(tmp_path):
    p = tmp_path / "x.db"
    p.write_bytes(b"hello")
    with pytest.raises(ValueError):
        android.read(str(p))
    other = sqlite3.connect(str(tmp_path / "y.db"))
    other.execute("CREATE TABLE foo (a)")
    other.close()
    with pytest.raises(ValueError):
        android.read(str(tmp_path / "y.db"))


def test_import_balances_match_android_rules(conn, store, clock, backup_file):
    clock.set("2026-01-13T08:00")
    result = android.apply(store, android.read(backup_file), True)
    assert result["lines"] == 10 and result["notes"] == 2 and result["templates"] == 1
    days = {d["date"]: d for d in calc.days(conn, "2026-01-05", "2026-01-12", clock())}
    assert days["2026-01-05"]["delta_min"] == 480 - 462
    assert days["2026-01-06"]["target_min"] == 0 and days["2026-01-06"]["delta_min"] == 0  # holiday
    assert days["2026-01-07"]["delta_min"] == -462  # comp time
    assert days["2026-01-08"]["delta_min"] == 0  # leave
    # 10 h without a break: history keeps Android's totals (no automatic break), on call 0
    assert days["2026-01-09"]["net_min"] == 600 and days["2026-01-09"]["auto_break_min"] == 0
    assert days["2026-01-10"]["target_min"] == 0 and days["2026-01-10"]["net_min"] == 0
    assert days["2026-01-12"]["target_min"] == 0 and days["2026-01-12"]["net_min"] == 0
    assert store.running()["check_in"] == "2026-01-13T06:30"
    # opening on Jan 1; Jan 1 and 2 have no lines (-2 x 462); then Mon +18, Wed -462, Fri +138
    assert calc.balance(conn, "2026-01-12", clock()) == 600 - 2 * 462 + 18 - 462 + 138
    vac = calc.vacation(conn, 2026, clock())
    assert vac["taken"] == 1 and vac["carryover"] == 4.5 and vac["remaining"] == 33.5


def test_breaks_apply_again_after_the_import(conn, store, clock, backup_file):
    clock.set("2026-01-20T08:00")
    android.apply(store, android.read(backup_file), True)
    store.update_stamp(store.running()["id"], {"check_out": "2026-01-13T16:30"})
    store.add_stamp({"check_in": "2026-01-14T06:00", "check_out": "2026-01-14T16:00", "task_id": 1})
    days = {d["date"]: d for d in calc.days(conn, "2026-01-13", "2026-01-14", clock())}
    assert days["2026-01-13"]["auto_break_min"] == 0  # imported day
    assert days["2026-01-14"]["net_min"] == 600 - 45  # split at the imported 11:30 rule


def test_import_is_one_undo_step_and_skips_busy_days(conn, store, clock, backup_file):
    clock.set("2026-01-20T08:00")
    store.add_stamp({"check_in": "2026-01-05T08:00", "check_out": "2026-01-05T09:00", "task_id": 1})
    store.set_day_note("2026-01-09", None, "mine")
    data = android.read(backup_file)
    preview = android.preview(conn, data)
    assert preview["skipped_days"] == ["2026-01-05"]
    assert preview["skipped_notes"] == 1
    assert preview["lines"] == 7 and preview["new_tasks"] == 7
    assert preview["first"] == "2026-01-05" and preview["last"] == "2026-01-12"
    before = conn.execute("SELECT COUNT(*) FROM stamps").fetchone()[0]
    android.apply(store, data, False)
    assert conn.execute("SELECT COUNT(*) FROM stamps").fetchone()[0] == before + 8
    assert settings.get(conn, "target.mon") == 480  # settings left alone
    assert conn.execute("SELECT text FROM day_notes WHERE date = '2026-01-09'").fetchone()[0] == "mine"
    assert conn.execute("SELECT COUNT(*) FROM vacation_years").fetchone()[0] == 2  # data, not settings
    assert store.undo() == "Import from Android"
    assert conn.execute("SELECT COUNT(*) FROM stamps").fetchone()[0] == before
    assert conn.execute("SELECT COUNT(*) FROM vacation_years").fetchone()[0] == 0
    assert conn.execute("SELECT COUNT(*) FROM tasks").fetchone()[0] == 1


def test_same_task_name_is_reused(conn, store, clock, backup_file):
    store.add_task("office", "#000000")
    data = android.read(backup_file)
    assert android.preview(conn, data)["matched_tasks"] == ["office"]
    android.apply(store, data, False)
    assert conn.execute("SELECT COUNT(*) FROM tasks WHERE lower(name) = 'office'").fetchone()[0] == 1


def test_running_line_not_imported_when_already_checked_in(conn, store, clock, backup_file):
    clock.set("2026-10-05T08:00")
    store.punch(1)
    preview = android.preview(conn, android.read(backup_file))
    assert preview["running"] == "" and "2026-01-13" in preview["skipped_days"]


def test_find_backups(tmp_path):
    make_backup(tmp_path / "timerec", gz=True)
    (tmp_path / "other.json").write_text("{}")
    names = sorted(p.split("/")[-1] for p in android.find_backups(str(tmp_path)))
    assert names == ["timerec.db", "timerec.db.gz"]


def test_task_rules_validated(store):
    with pytest.raises(ValueError):
        store.add_task("X", "#000000", {"work_factor": 2})
    store.add_task("On call", "#000000", {"work_factor": 0, "target_off": True, "holiday_days": 0})
    row = store.conn.execute("SELECT * FROM tasks WHERE name = 'On call'").fetchone()
    assert row["work_factor"] == 0 and row["target_off"] == 1


def test_partial_work_factor(conn, store, clock):
    store.add_task("Travel", "#000000", {"work_factor": 0.5})
    tid = conn.execute("SELECT id FROM tasks WHERE name = 'Travel'").fetchone()[0]
    store.add_stamp({"check_in": "2026-10-05T08:00", "check_out": "2026-10-05T12:00", "task_id": tid})
    assert calc.day_summary(conn, "2026-10-05", clock())["net_min"] == 120


def test_existing_vacation_year_is_kept(conn, store, clock, backup_file):
    store.set_vacation_year(2026, 28, 0)
    data = android.read(backup_file)
    assert android.preview(conn, data)["skipped_years"] == [2026]
    android.apply(store, data, False)
    assert calc.vacation(conn, 2026, clock())["days"] == 28
