# SPDX-License-Identifier: GPL-3.0-or-later
"""Vacation per year (D-026)."""
import json
import sqlite3

import pytest

from timerecord import backup, calc, db, settings


def test_years_fall_back_to_the_previous_year(conn, store, clock):
    settings.set(conn, "vacation.default_days", 25.0)
    assert calc.vacation(conn, 2026, clock())["days"] == 25  # nothing yet: default
    store.set_vacation_year(2024, 28, 3)
    store.set_vacation_year(2026, 30, 5)
    v = {y["year"]: y for y in calc.vacation_years(conn, clock())}
    assert (v[2024]["days"], v[2024]["carryover"], v[2024]["own_entry"]) == (28, 3, True)
    assert calc.vacation(conn, 2025, clock())["days"] == 28  # copies 2024
    assert calc.vacation(conn, 2025, clock())["carryover"] == 0
    assert calc.vacation(conn, 2025, clock())["own_entry"] is False
    assert calc.vacation(conn, 2023, clock())["days"] == 25


def test_year_list_covers_entries_usage_and_this_year(conn, store, clock):
    store.set_vacation_year(2020, 30, 0)
    store.set_day_note("2022-07-01", 1, "")
    years = [y["year"] for y in calc.vacation_years(conn, clock())]
    assert years == [2026, 2022, 2020]


def test_vacation_days_lists_notes_and_tasks(conn, store, clock):
    store.add_task("Leave", "#000000", {"holiday_days": 1})
    tid = conn.execute("SELECT id FROM tasks WHERE name = 'Leave'").fetchone()[0]
    store.add_stamp({"check_in": "2026-03-02T07:00", "check_out": "2026-03-02T14:42", "task_id": tid})
    store.set_day_note("2026-03-02", 2, "")  # half vacation on the same day: counted once
    store.set_day_note("2026-03-03", 2, "")
    assert calc.vacation_days(conn, 2026) == [
        {"date": "2026-03-02", "days": 1, "name": "Leave"},
        {"date": "2026-03-03", "days": 0.5, "name": "Half vacation"}]
    assert calc.vacation(conn, 2026, clock())["taken"] == 1.5


def test_year_edit_and_delete_are_undoable(conn, store, clock):
    store.set_vacation_year(2026, 30, 2)
    store.set_vacation_year(2026, 30, 4)
    assert calc.vacation(conn, 2026, clock())["carryover"] == 4
    store.undo()
    assert calc.vacation(conn, 2026, clock())["carryover"] == 2
    store.delete_vacation_year(2026)
    assert calc.vacation(conn, 2026, clock())["own_entry"] is False
    store.undo()
    assert calc.vacation(conn, 2026, clock())["own_entry"] is True
    with pytest.raises(ValueError):
        store.set_vacation_year(2026, 400, 0)


def _v3_database(path):
    c = sqlite3.connect(path)
    for step in db.MIGRATIONS[:3]:
        c.executescript(step)
    c.execute("PRAGMA user_version = 3")
    c.execute("INSERT INTO settings VALUES ('holiday.entitlement', '28.0')")
    c.execute("""INSERT INTO settings VALUES ('holiday.carryover', '{"2025": 2.0, "2026": 4.5}')""")
    c.commit()
    c.close()


def test_migration_moves_holiday_settings(tmp_path, clock):
    path = str(tmp_path / "old.sqlite")
    _v3_database(path)
    conn = db.connect(path)
    assert conn.execute("PRAGMA user_version").fetchone()[0] == db.SCHEMA_VERSION
    rows = [tuple(r) for r in conn.execute("SELECT year, days, carryover FROM vacation_years ORDER BY year")]
    assert rows == [(2025, 28.0, 2.0), (2026, 28.0, 4.5)]
    assert settings.get(conn, "vacation.default_days") == 28.0
    assert conn.execute("SELECT COUNT(*) FROM settings WHERE key LIKE 'holiday.%'").fetchone()[0] == 0


def test_restore_of_an_older_backup_converts_vacation(conn, tmp_path):
    data = backup.dump(conn)
    data["schema_version"] = 3
    del data["tables"]["vacation_years"]
    data["tables"]["settings"] = [{"key": "holiday.entitlement", "value": "27.0"},
                                  {"key": "holiday.carryover", "value": json.dumps({"2026": 1.5})},
                                  {"key": "gone.setting", "value": "1"}]
    path = tmp_path / "old.json"
    path.write_text(json.dumps(data))
    backup.restore(conn, str(path))
    assert [tuple(r) for r in conn.execute("SELECT * FROM vacation_years")] == [(2026, 27.0, 1.5)]
    assert conn.execute("SELECT COUNT(*) FROM settings WHERE key = 'gone.setting'").fetchone()[0] == 0
