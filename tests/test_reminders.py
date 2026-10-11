# SPDX-License-Identifier: GPL-3.0-or-later
import datetime as dt

from timerecord import api, calc, reminders, settings


def due(conn, store, clock):
    values = settings.get_all(conn)
    day = calc.day_summary(conn, clock().date().isoformat(), clock(), values)
    return {r["key"] for r in reminders.due(values, clock(), day, store.running())}


def test_forgot_checkout(conn, store, clock):
    store.punch(1)
    clock.set("2026-10-05T17:59")
    assert not any(k.startswith("checkout") for k in due(conn, store, clock))
    clock.set("2026-10-05T18:00")
    assert any(k.startswith("checkout") for k in due(conn, store, clock))
    settings.set(conn, "remind.checkout_after_min", 0)
    assert not any(k.startswith("checkout") for k in due(conn, store, clock))


def test_target_reached(conn, store, clock):
    store.punch(1)
    clock.set("2026-10-05T16:29")  # 8:29 gross, 7:59 after the 30 min planned break
    assert "target" not in due(conn, store, clock)
    clock.set("2026-10-05T16:30")
    assert "target" in due(conn, store, clock)


def test_checkin_reminder(conn, store, clock):
    settings.set(conn, "remind.checkin_time", "8:30")
    assert settings.get(conn, "remind.checkin_time") == "08:30"
    clock.set("2026-10-05T08:29")
    assert "checkin" not in due(conn, store, clock)
    clock.set("2026-10-05T08:31")
    assert "checkin" in due(conn, store, clock)
    store.set_day_note("2026-10-05", 1, "")  # vacation: no reminder
    assert "checkin" not in due(conn, store, clock)
    clock.set("2026-10-10T09:00")  # Saturday, no target
    assert "checkin" not in due(conn, store, clock)


def test_break_reminder_at_planned_time(conn, store, clock):
    # Checked in at 8:00 with an 8:00 target: the 30 min break is planned for 12:00
    # (after 4:00 worked) and announced then, before the 6:00 threshold is reached.
    store.punch(1)
    clock.set("2026-10-05T11:59")
    assert not any(k.startswith("break") for k in due(conn, store, clock))
    clock.set("2026-10-05T12:00")
    assert "break:12:00" in due(conn, store, clock)
    clock.set("2026-10-05T12:30")
    assert not any(k.startswith("break") for k in due(conn, store, clock))


def test_break_reminder_at_rule_time(conn, store, clock):
    settings.set(conn, "break.rules", [{"after_min": 360, "break_min": 30, "at": "14:20"}])
    store.punch(1)
    clock.set("2026-10-05T14:30")
    assert "break:14:20" in due(conn, store, clock)


def test_disabled(conn, store, clock):
    settings.set(conn, "remind.enabled", False)
    store.punch(1)
    clock.set("2026-10-05T23:00")
    assert due(conn, store, clock) == set()


def test_api_sends_each_reminder_once_per_day(tmp_path, clock):
    api._app = api.App(str(tmp_path / "data"), str(tmp_path / "docs"), clock)
    api.punch(1)
    clock.set("2026-10-05T18:30")
    first = {r["key"] for r in api.due_reminders()}
    assert {"target"} <= first and any(k.startswith("checkout") for k in first)
    assert api.due_reminders() == []
    clock.set("2026-10-06T18:30")  # new day: state resets (still running -> reminded again)
    assert any(r["key"].startswith("checkout") for r in api.due_reminders())


def test_status_fields(tmp_path, clock):
    api._app = api.App(str(tmp_path / "data"), str(tmp_path / "docs"), clock)
    api.add_task("Meetings", "#123456")
    st = api.punch(1)
    assert st["running_task_name"] == "Work"
    assert api.status()["next_break"] == "12:00–12:30"  # planned from check-in on
    st = api.select_task(2)
    assert st["running_task_name"] == "Meetings"
    api.punch(-1)
    clock.set("2026-10-05T15:00")
    assert api.select_task(1)["last_task_name"] == "Work"
