# SPDX-License-Identifier: GPL-3.0-or-later
import json

import pytest

from timerecord import api, backup, calc, settings
from timerecord.store import Store


def lines(conn):
    return [dict(r) for r in conn.execute("SELECT * FROM stamps ORDER BY id")]


def test_punch_in_and_out_with_rounding(conn, store, clock):
    settings.set(conn, "round.in_step", 15)
    settings.set(conn, "round.in_dir", "down")
    settings.set(conn, "round.out_step", 15)
    settings.set(conn, "round.out_dir", "up")
    clock.set("2026-10-05T08:07:30")
    store.punch(1)
    assert store.running()["check_in"] == "2026-10-05T08:00"
    assert store.running()["raw_check_in"] == "2026-10-05T08:07:30"
    clock.set("2026-10-05T16:31")
    store.punch()
    row = lines(conn)[-1]  # the day was split by the automatic break
    assert row["check_out"] == "2026-10-05T16:45"
    assert store.running() is None


def test_checkout_never_before_checkin(conn, store, clock):
    settings.set(conn, "round.out_step", 15)
    settings.set(conn, "round.out_dir", "down")
    clock.set("2026-10-05T08:07")
    store.punch(1)
    clock.set("2026-10-05T08:10")
    store.punch()
    assert lines(conn)[0]["check_out"] == "2026-10-05T08:07"


def test_switch_task(conn, store, clock):
    store.add_task("Meeting", "#ff0000")
    store.punch(1)
    clock.set("2026-10-05T10:00")
    store.switch_task(2)
    rows = lines(conn)
    assert rows[0]["check_out"] == "2026-10-05T10:00"
    assert rows[1]["check_in"] == "2026-10-05T10:00" and rows[1]["task_id"] == 2
    store.undo()
    assert len(lines(conn)) == 1 and store.running()["task_id"] == 1


def test_validation(store):
    with pytest.raises(ValueError):
        store.add_stamp({"check_in": "2026-10-05T10:00", "check_out": "2026-10-05T09:00"})
    store.punch(1)
    with pytest.raises(ValueError):
        store.add_stamp({"check_in": "2026-10-05T10:00"})


def test_undo_redo_add_edit_delete(conn, store):
    store.add_stamp({"check_in": "2026-10-05T08:00", "check_out": "2026-10-05T12:00", "task_id": 1})
    sid = lines(conn)[0]["id"]
    store.update_stamp(sid, {"check_out": "2026-10-05T13:00", "comment": "x"})
    store.delete_stamp(sid)
    assert lines(conn) == []

    assert store.undo() == "Delete line"
    assert lines(conn)[0]["check_out"] == "2026-10-05T13:00"
    assert store.undo() == "Edit line"
    assert lines(conn)[0]["check_out"] == "2026-10-05T12:00"
    assert store.undo() == "Add line"
    assert lines(conn) == []
    assert store.undo() is None

    assert store.redo() == "Add line"
    assert store.redo() == "Edit line"
    assert lines(conn)[0]["comment"] == "x"
    assert store.redo() == "Delete line"
    assert lines(conn) == []
    assert store.redo() is None


def test_new_action_clears_redo(store):
    store.add_stamp({"check_in": "2026-10-05T08:00", "check_out": "2026-10-05T09:00"})
    store.undo()
    store.add_stamp({"check_in": "2026-10-05T10:00", "check_out": "2026-10-05T11:00"})
    assert store.undo_state() == {"undo": "Add line", "redo": ""}


def test_undo_depth(conn, store):
    settings.set(conn, "undo.depth", 2)
    for h in range(8, 12):
        store.add_stamp({"check_in": "2026-10-05T%02d:00" % h, "check_out": "2026-10-05T%02d:30" % h})
    assert store.undo() and store.undo()
    assert store.undo() is None
    assert len(lines(conn)) == 2


def test_undo_day_note_and_task(conn, store):
    store.set_day_note("2026-10-05", 1, "Beach")
    store.set_day_note("2026-10-05", 1, "Mountains")
    store.set_day_note("2026-10-05", None, "")
    assert conn.execute("SELECT COUNT(*) FROM day_notes").fetchone()[0] == 0
    store.undo()
    assert conn.execute("SELECT text FROM day_notes").fetchone()[0] == "Mountains"
    store.undo()
    assert conn.execute("SELECT text FROM day_notes").fetchone()[0] == "Beach"

    store.archive_task(1)
    store.undo()
    assert conn.execute("SELECT archived FROM tasks WHERE id = 1").fetchone()[0] == 0


def test_day_notes_on_several_days(conn, store):
    store.set_day_note("2026-10-06", None, "keep me?")
    store.set_day_notes(["2026-10-05", "2026-10-06", "2026-10-07"], 1, " Trip ")
    rows = conn.execute("SELECT date, note_type_id, text FROM day_notes ORDER BY date").fetchall()
    assert [tuple(r) for r in rows] == [("2026-10-05", 1, "Trip"), ("2026-10-06", 1, "Trip"),
                                        ("2026-10-07", 1, "Trip")]
    assert store.undo() == "Day notes"
    assert [tuple(r) for r in conn.execute("SELECT date, text FROM day_notes")] == [("2026-10-06", "keep me?")]
    store.redo()
    store.set_day_notes(["2026-10-05", "2026-10-06", "2026-10-07"], None, "")  # clear
    assert conn.execute("SELECT COUNT(*) FROM day_notes").fetchone()[0] == 0
    store.undo()
    assert conn.execute("SELECT COUNT(*) FROM day_notes").fetchone()[0] == 3
    with pytest.raises(ValueError):
        store.set_day_notes([], 1, "")
    with pytest.raises(ValueError):
        store.set_day_notes(["5.10.2026"], 1, "")


def test_api_day_notes_on_several_days(tmp_path, clock):
    api._app = api.App(str(tmp_path / "data"), str(tmp_path / "docs"), clock)
    st = api.set_day_notes(["2026-10-05", "2026-10-06"], -1, "Trip")
    assert st["undo"]["undo"] == "Day notes"
    assert [r["note"]["text"] for r in api.days("2026-10-05", "2026-10-06")] == ["Trip", "Trip"]


def test_undo_restore_keeps_task_reference(conn, store):
    # Undo writes rows with UPDATE, so restoring a task must not null its lines' task_id.
    store.add_stamp({"check_in": "2026-10-05T08:00", "check_out": "2026-10-05T09:00", "task_id": 1})
    store.update_task(1, {"name": "Renamed"})
    store.undo()
    assert lines(conn)[0]["task_id"] == 1


def test_day_summary(conn, store, clock):
    settings.set(conn, "break.mode", "insert")
    store.add_stamp({"check_in": "2026-10-05T08:00", "check_out": "2026-10-05T16:30", "task_id": 1})
    day = calc.day_summary(conn, "2026-10-05", clock())
    assert day["net_min"] == 480 and day["target_min"] == 480 and day["delta_min"] == 0
    kinds = [l["kind"] for l in day["lines"]]
    assert kinds == ["work", "auto_break"]
    assert day["lines"][0]["task_name"] == "Work"


def test_running_line_uses_now(conn, store, clock):
    store.punch(1)
    clock.set("2026-10-05T10:30")
    day = calc.day_summary(conn, "2026-10-05", clock())
    assert day["running"] and day["net_min"] == 150


def test_midnight_line_belongs_to_checkin_day(conn, store, clock):
    store.add_stamp({"check_in": "2026-10-05T22:00", "check_out": "2026-10-06T02:00"})
    assert calc.day_summary(conn, "2026-10-05", clock())["net_min"] == 240
    assert calc.day_summary(conn, "2026-10-06", clock())["net_min"] == 0


def test_vacation_credits_target(conn, store, clock):
    store.set_day_note("2026-10-05", 1, "")  # Vacation
    day = calc.day_summary(conn, "2026-10-05", clock())
    assert day["credit_min"] == 480 and day["delta_min"] == 0
    store.set_day_note("2026-10-05", 2, "")  # Half vacation
    store.add_stamp({"check_in": "2026-10-05T08:00", "check_out": "2026-10-05T12:00"})
    day = calc.day_summary(conn, "2026-10-05", clock())
    assert day["credit_min"] == 240 and day["delta_min"] == 0
    store.set_day_note("2026-10-06", 5, "")  # Comp time
    assert calc.day_summary(conn, "2026-10-06", clock())["delta_min"] == -480


def test_settings_validation(conn):
    with pytest.raises(KeyError):
        settings.set(conn, "nope", 1)
    with pytest.raises(ValueError):
        settings.set(conn, "target.mon", "eight")
    with pytest.raises(ValueError):
        settings.set(conn, "break.count_gaps", 1)
    settings.set(conn, "target.mon", 420.0)
    assert settings.get(conn, "target.mon") == 420


def test_backup_round_trip(conn, store, tmp_path, clock):
    store.add_task("Meeting", "#ff0000")
    store.add_stamp({"check_in": "2026-10-05T08:00", "check_out": "2026-10-05T12:00", "task_id": 2,
                     "comment": "Grüße"})
    store.set_day_note("2026-10-06", 1, "off")
    settings.set(conn, "target.fri", 360)
    conn.commit()
    before = backup.dump(conn)
    path = backup.export(conn, str(tmp_path / "docs"), clock())

    conn.execute("DELETE FROM stamps")
    conn.execute("DELETE FROM day_notes")
    conn.commit()
    backup.restore(conn, path)
    assert backup.dump(conn) == before
    assert Store(conn, clock).undo_state() == {"undo": "", "redo": ""}


def test_restore_rejects_foreign_file(conn, tmp_path):
    p = tmp_path / "x.json"
    p.write_text(json.dumps({"format": "other"}))
    with pytest.raises(ValueError):
        backup.restore(conn, str(p))


def test_auto_backup_interval_and_prune(conn, tmp_path, clock):
    import datetime as dt
    import os
    docs = str(tmp_path / "docs")
    settings.set(conn, "backup.keep", 2)
    assert backup.auto_backup(conn, docs, clock())
    assert backup.auto_backup(conn, docs, clock()) is None
    for i in range(3):
        clock.t += dt.timedelta(days=8)
        for p in os.listdir(docs):  # age existing files
            os.utime(os.path.join(docs, p), (0, 0))
        assert backup.auto_backup(conn, docs, clock())
    assert len(os.listdir(docs)) == 2


def test_api_flow(tmp_path, clock):
    api._app = api.App(str(tmp_path / "data"), str(tmp_path / "docs"), clock)
    st = api.punch(1)
    assert st["running"]["task_id"] == 1 and st["undo"]["undo"] == "Check in"
    clock.set("2026-10-05T12:00")
    st = api.punch(None)
    assert st["running"] is None and st["today_net_min"] == 240
    assert api.day("2026-10-05")["lines"][0]["check_out"] == "2026-10-05T12:00"
    assert api.set_setting("target.mon", 300)["target.mon"] == 300
    assert api.export_backup().endswith(".json")
    assert len(api.list_backups()) == 1


def test_api_accepts_js_floats(tmp_path, clock):
    api._app = api.App(str(tmp_path / "data"), str(tmp_path / "docs"), clock)
    api.add_stamp({"check_in": "2026-10-05T08:00", "check_out": "2026-10-05T09:00", "task_id": 1.0})
    sid = api.day("2026-10-05")["lines"][0]["id"]
    api.update_stamp(float(sid), {"comment": "c"})
    rules = api.set_setting("break.rules", [{"after_min": 300.0, "break_min": 20.0}])["break.rules"]
    assert rules == [{"after_min": 300, "break_min": 20, "at": ""}]
    assert api.day("2026-10-05")["lines"][0]["task_id"] == 1


def test_api_none_sentinels(tmp_path, clock):
    # QML sends -1 / "" because PyOtherSide cannot pass null.
    api._app = api.App(str(tmp_path / "data"), str(tmp_path / "docs"), clock)
    api.add_stamp({"check_in": "2026-10-05T08:00", "check_out": "", "task_id": -1, "kind": "work"})
    line = api.day("2026-10-05")["lines"][0]
    assert line["running"] and line["task_id"] is None
    api.update_stamp(line["id"], {"check_out": "2026-10-05T09:00", "task_id": 1})
    api.update_stamp(line["id"], {"task_id": -1})
    assert api.day("2026-10-05")["lines"][0]["task_id"] is None
    api.set_day_note("2026-10-05", -1, "text only")
    assert api.day("2026-10-05")["note"]["note_type_id"] is None
    assert api.punch(-1)["running"]["task_id"] is None
