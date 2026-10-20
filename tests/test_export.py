# SPDX-License-Identifier: GPL-3.0-or-later
import pytest

from timerecord import api, export, settings


def add(store, start, end, task_id=1, kind="work"):
    store.add_stamp({"check_in": "2026-10-15T" + start,
                     "check_out": ("2026-10-15T" + end) if end else None,
                     "task_id": task_id, "kind": kind})


def csv_lines(conn, clock, start="2026-10-15", end="2026-10-15"):
    return export.spx_csv(conn, start, end, clock()).splitlines()


def test_split_day_with_on_call(conn, store, clock):
    # The example from SPX: a gap between work lines is the break, on call has its own type.
    store.add_task("On call", "#009688", {"work_factor": 0})
    on_call = conn.execute("SELECT id FROM tasks WHERE name = 'On call'").fetchone()[0]
    settings.set(conn, "export.spx_task_types", {str(on_call): "Rufbereitschaftseinsatz"})
    clock.set("2026-10-16T08:00")
    add(store, "07:30", "11:30")
    add(store, "12:15", "16:00")
    add(store, "18:00", "18:30", on_call)
    assert csv_lines(conn, clock) == [
        "datum;typ;von;bis",
        "2026-10-15;Normalarbeitszeit;07:30;11:30",
        "2026-10-15;Pause;11:30;12:15",
        "2026-10-15;Normalarbeitszeit;12:15;16:00",
        "2026-10-15;Rufbereitschaftseinsatz;18:00;18:30",
    ]


def test_work_line_is_cut_around_breaks(conn, store, clock):
    settings.set(conn, "break.mode", "insert")
    clock.set("2026-10-16T08:00")
    add(store, "08:00", "17:00")
    add(store, "10:00", "10:15", None, "break")
    assert csv_lines(conn, clock)[1:] == [
        "2026-10-15;Normalarbeitszeit;08:00;10:00",
        "2026-10-15;Pause;10:00;10:15",
        "2026-10-15;Normalarbeitszeit;10:15;12:00",
        "2026-10-15;Pause;12:00;12:15",   # the automatic break tops up to 30 minutes
        "2026-10-15;Normalarbeitszeit;12:15;17:00",
    ]


def test_gaps_only_count_when_set(conn, store, clock):
    settings.set(conn, "break.mode", "deduct")
    settings.set(conn, "break.count_gaps", False)
    clock.set("2026-10-16T08:00")
    add(store, "08:00", "10:00")
    add(store, "10:30", "12:00")
    assert csv_lines(conn, clock)[1:] == [
        "2026-10-15;Normalarbeitszeit;08:00;10:00",
        "2026-10-15;Normalarbeitszeit;10:30;12:00",
    ]


def test_running_day_and_midnight(conn, store, clock):
    clock.set("2026-10-16T08:00")
    store.add_stamp({"check_in": "2026-10-15T22:00", "check_out": "2026-10-16T02:00", "task_id": 1})
    store.add_stamp({"check_in": "2026-10-16T07:00", "check_out": None, "task_id": 1})
    assert csv_lines(conn, clock, "2026-10-15", "2026-10-16")[1:] == [
        "2026-10-15;Normalarbeitszeit;22:00;02:00",   # SPX reads bis <= von as the next day
    ]


def test_type_settings_are_csv_cells(conn):
    settings.set(conn, "export.spx_break_type", " Pause; lang ")
    assert settings.get(conn, "export.spx_break_type") == "Pause lang"
    with pytest.raises(ValueError):
        settings.set(conn, "export.spx_work_type", " ")
    settings.set(conn, "export.spx_task_types", {"2": "Ruf", "3": "  "})
    assert settings.get(conn, "export.spx_task_types") == {"2": "Ruf"}


def test_api_writes_file(tmp_path, clock):
    api._app = api.App(str(tmp_path / "data"), str(tmp_path / "docs"), clock)
    clock.set("2026-10-16T08:00")
    add(api._app.store, "08:00", "12:00")
    result = api.export_spx("2026-10", "2026-10")
    assert result["rows"] == 1
    assert result["path"] == str(tmp_path / "docs" / "timerecord-spx-2026-10.csv")
    with open(result["path"], encoding="utf-8") as f:
        assert f.read() == "datum;typ;von;bis\n2026-10-15;Normalarbeitszeit;08:00;12:00\n"
    assert api.export_spx("2026-09", "2026-11")["path"].endswith("timerecord-spx-2026-09-2026-11.csv")


def test_month_range():
    assert export.month_range("2026-02", "2026-02") == ("2026-02-01", "2026-02-28")
    assert export.month_range("2026-11", "2027-01") == ("2026-11-01", "2027-01-31")
    with pytest.raises(ValueError):
        export.month_range("2026-03", "2026-02")


# --- day notes: business trip and on-call standby (D-029) -----------------------

def note(conn, store, date, type_name="", text=""):
    type_id = -1
    if type_name:
        store.add_note_type({"name": type_name})
        type_id = conn.execute("SELECT MAX(id) FROM note_types").fetchone()[0]
    store.set_day_note(date, type_id if type_id > 0 else None, text)


def test_business_trip_has_fixed_times(conn, store, clock):
    store.add_task("On call", "#009688", {"work_factor": 0})
    on_call = conn.execute("SELECT id FROM tasks WHERE name = 'On call'").fetchone()[0]
    settings.set(conn, "export.spx_task_types", {str(on_call): "Rufbereitschaftseinsatz"})
    clock.set("2026-10-16T08:00")
    note(conn, store, "2026-10-15", "Dienstreise")
    add(store, "08:00", "17:00")                  # replaced by the trip times
    add(store, "20:00", "20:30", on_call)         # kept: the task has its own type
    assert csv_lines(conn, clock)[1:] == [
        "2026-10-15;Normalarbeitszeit;06:30;11:30",
        "2026-10-15;Pause;11:30;12:00",
        "2026-10-15;Normalarbeitszeit;12:00;14:42",
        "2026-10-15;Rufbereitschaftseinsatz;20:00;20:30",
    ]


def test_on_call_weekday_runs_to_next_work(conn, store, clock):
    clock.set("2026-10-20T08:00")
    note(conn, store, "2026-10-15", text="Rufbereitschaft")      # Thursday
    note(conn, store, "2026-10-16", "Dienstreise")              # Friday: trip starts 06:30
    add(store, "07:30", "15:10")                                # split by the automatic break
    assert csv_lines(conn, clock, "2026-10-15", "2026-10-16")[1:] == [
        "2026-10-15;Normalarbeitszeit;07:30;11:30",
        "2026-10-15;Pause;11:30;12:00",
        "2026-10-15;Normalarbeitszeit;12:00;15:10",
        "2026-10-15;Rufbereitschaft TVL;15:10;06:30",
        "2026-10-16;Normalarbeitszeit;06:30;11:30",
        "2026-10-16;Pause;11:30;12:00",
        "2026-10-16;Normalarbeitszeit;12:00;14:42",
    ]


def test_on_call_weekend_and_days_without_work(conn, store, clock):
    clock.set("2026-10-20T08:00")
    # The Dienstreise day type also says on call in its text.
    note(conn, store, "2026-10-16", "Dienstreise", "Rufbereitschaft")   # Friday, next day no work
    note(conn, store, "2026-10-17", text="rufbereitschaft")             # Saturday
    assert csv_lines(conn, clock, "2026-10-16", "2026-10-17")[1:] == [
        "2026-10-16;Normalarbeitszeit;06:30;11:30",
        "2026-10-16;Pause;11:30;12:00",
        "2026-10-16;Normalarbeitszeit;12:00;14:42",
        "2026-10-16;Rufbereitschaft TVL;14:42;07:00",
        "2026-10-17;Rufbereitschaft TVL;07:00;07:00",   # SPX: bis <= von is the next day
    ]


def test_day_note_settings(conn, clock, store):
    settings.set(conn, "export.spx_trip_start", "6:15")
    assert settings.get(conn, "export.spx_trip_start") == "06:15"
    with pytest.raises(ValueError):
        settings.set(conn, "export.spx_oncall_handover", "")
    settings.set(conn, "export.spx_trip_note", "")      # empty: no business trip days
    clock.set("2026-10-16T08:00")
    note(conn, store, "2026-10-15", text="Dienstreise")
    assert csv_lines(conn, clock) == ["datum;typ;von;bis"]
