# SPDX-License-Identifier: GPL-3.0-or-later
"""Entry points called from QML through PyOtherSide. Everything returns JSON-friendly values."""
import datetime as dt
import json
import os

from . import android, backup, calc, db, reminders, settings
from .store import Store

_app = None


class App:
    def __init__(self, data_dir, docs_dir, now=dt.datetime.now):
        os.makedirs(data_dir, exist_ok=True)
        self.conn = db.connect(os.path.join(data_dir, "timerecord.sqlite"))
        self.docs_dir = docs_dir
        self.now = now
        self.store = Store(self.conn, now)


def _clean(value):
    """JS numbers arrive as floats; turn integral ones back into ints, recursively."""
    if isinstance(value, float) and value.is_integer():
        return int(value)
    if isinstance(value, dict):
        return {k: _clean(v) for k, v in value.items()}
    if isinstance(value, list):
        return [_clean(v) for v in value]
    return value


def _opt(value):
    """PyOtherSide cannot pass JS null, so QML sends -1 or "" for "none"."""
    value = _clean(value)
    return None if value in (None, -1, "") else value


def _stamp_data(data):
    data = _clean(data)
    for key in ("task_id", "check_out"):
        if key in data:
            data[key] = _opt(data[key])
    return data


def _a():
    if _app is None:
        raise RuntimeError("init() not called")
    return _app


def init(data_dir, docs_dir):
    global _app
    _app = App(os.path.expanduser(data_dir), os.path.expanduser(docs_dir))
    try:
        backup.auto_backup(_app.conn, _app.docs_dir, _app.now())
    except OSError:
        pass
    return status()


def status():
    a = _a()
    now = a.now()
    today = now.date().isoformat()
    day = calc.day_summary(a.conn, today, now)
    running = a.store.running()
    names = {r["id"]: r["name"] for r in a.conn.execute("SELECT id, name FROM tasks")}
    last_task = settings.get(a.conn, "ui.last_task_id")
    upcoming = [l for l in day["lines"]
                if l["kind"] == "auto_break" and l["check_out"] > now.isoformat(timespec="minutes")]
    return {
        "today": today,
        "running_task_name": names.get(running["task_id"], "") if running else "",
        "last_task_name": names.get(last_task, ""),
        "next_break": "%s–%s" % (upcoming[0]["check_in"][11:16], upcoming[0]["check_out"][11:16]) if upcoming else "",
        "remind_enabled": settings.get(a.conn, "remind.enabled"),
        "remind_interval_sec": settings.get(a.conn, "remind.interval_sec"),
        "now": now.isoformat(timespec="minutes"),
        "running": running,
        "today_net_min": day["net_min"],
        "today_target_min": day["target_min"],
        "today_delta_min": day["delta_min"],
        "balance_min": calc.balance(a.conn, today, now),
        "last_task_id": settings.get(a.conn, "ui.last_task_id"),
        "undo": a.store.undo_state(),
    }


def day(date):
    a = _a()
    now = a.now()
    result = calc.day_summary(a.conn, date, now)
    result["balance_min"] = calc.balance(a.conn, date, now)
    return result


def days(start, end):
    """Day rows (without lines) from start to end, for editing several days."""
    a = _a()
    return calc.day_rows(a.conn, start, end, a.now())


def week(date):
    a = _a()
    return calc.week_summary(a.conn, date, a.now())


def month(year, month_):
    a = _a()
    return calc.month_summary(a.conn, int(year), int(month_), a.now())


def vacation(year):
    a = _a()
    return calc.vacation(a.conn, int(year), a.now())


def vacation_years():
    a = _a()
    return calc.vacation_years(a.conn, a.now())


def vacation_days(year):
    return calc.vacation_days(_a().conn, int(year))


def set_vacation_year(year, days, carryover):
    _a().store.set_vacation_year(_clean(year), days, carryover)
    return vacation_years()


def delete_vacation_year(year):
    _a().store.delete_vacation_year(_clean(year))
    return vacation_years()


def punch(task_id):
    a = _a()
    task_id = _opt(task_id)
    if task_id is not None:
        settings.set(a.conn, "ui.last_task_id", task_id)
    changed = a.store.punch(task_id)
    result = status()
    result["ignored"] = changed is None
    return result


def punch_at(at, task_id):
    """Check in or out at a chosen time today (forgotten punch)."""
    a = _a()
    task_id = _opt(task_id)
    if task_id is not None and a.store.running() is None:
        settings.set(a.conn, "ui.last_task_id", task_id)
    a.store.punch_at(at, task_id)
    return status()


def switch_task(task_id):
    a = _a()
    task_id = _opt(task_id)
    if task_id is not None:
        settings.set(a.conn, "ui.last_task_id", task_id)
    a.store.switch_task(task_id)
    return status()


def add_stamp(data):
    _a().store.add_stamp(_stamp_data(data))
    return status()


def update_stamp(stamp_id, data):
    _a().store.update_stamp(_clean(stamp_id), _stamp_data(data))
    return status()


def delete_stamp(stamp_id):
    _a().store.delete_stamp(_clean(stamp_id))
    return status()


def undo():
    _a().store.undo()
    return status()


def redo():
    _a().store.redo()
    return status()


def set_day_note(date, note_type_id, text):
    _a().store.set_day_note(date, _opt(note_type_id), text)
    return status()


def set_day_notes(dates, note_type_id, text):
    _a().store.set_day_notes(list(dates), _opt(note_type_id), text)
    return status()


def tasks(include_archived=False):
    sql = "SELECT * FROM tasks %s ORDER BY archived, sort, name" % (
        "" if include_archived else "WHERE archived = 0")
    return [dict(r) for r in _a().conn.execute(sql)]


def add_task(name, color, data=None):
    _a().store.add_task(name, color, _clean(data or {}))
    return tasks(True)


def update_task(task_id, data):
    _a().store.update_task(_clean(task_id), _clean(data))
    return tasks(True)


def archive_task(task_id, archived):
    _a().store.archive_task(_clean(task_id), bool(archived))
    return tasks(True)


def note_types(include_archived=False):
    sql = "SELECT * FROM note_types %s ORDER BY archived, sort, name" % (
        "" if include_archived else "WHERE archived = 0")
    return [dict(r) for r in _a().conn.execute(sql)]


def add_note_type(data):
    _a().store.add_note_type(_clean(data))
    return note_types(True)


def update_note_type(type_id, data):
    _a().store.update_note_type(_clean(type_id), _clean(data))
    return note_types(True)


def templates():
    rows = []
    for r in _a().conn.execute("SELECT * FROM templates ORDER BY name"):
        row = dict(r)
        row["lines"] = json.loads(row["lines"])
        rows.append(row)
    return rows


def save_template(name, date):
    _a().store.save_template(name, date)
    return templates()


def apply_template(template_id, date):
    _a().store.apply_template(_clean(template_id), date)
    return status()


def apply_template_days(template_id, dates):
    _a().store.apply_template_days(_clean(template_id), list(dates))
    return status()


def rename_template(template_id, name):
    _a().store.rename_template(_clean(template_id), name)
    return templates()


def delete_template(template_id):
    _a().store.delete_template(_clean(template_id))
    return templates()


def due_reminders():
    """Reminders to show now; each occasion is returned only once per day."""
    a = _a()
    now = a.now()
    today = now.date().isoformat()
    values = settings.get_all(a.conn)
    sent = values["ui.reminders_sent"]
    keys = sent.get("keys", []) if sent.get("date") == today else []
    day_ = calc.day_summary(a.conn, today, now, values)
    fresh = [r for r in reminders.due(values, now, day_, a.store.running()) if r["key"] not in keys]
    if fresh:
        settings.set(a.conn, "ui.reminders_sent", {"date": today, "keys": keys + [r["key"] for r in fresh]})
        a.conn.commit()
    return fresh


def select_task(task_id):
    """Pick the task for the next check-in (cover action), switching if checked in."""
    a = _a()
    task_id = _opt(task_id)
    if a.store.running():
        return switch_task(task_id)
    settings.set(a.conn, "ui.last_task_id", task_id)
    a.conn.commit()
    return status()


def get_settings():
    return settings.get_all(_a().conn)


def set_setting(key, value):
    a = _a()
    settings.set(a.conn, key, _clean(value))
    a.conn.commit()
    return settings.get_all(a.conn)


def export_backup():
    a = _a()
    return backup.export(a.conn, a.docs_dir, a.now())


def list_backups():
    return [{"path": p, "name": os.path.basename(p),
             "mtime": dt.datetime.fromtimestamp(os.path.getmtime(p)).isoformat(timespec="minutes")}
            for p in backup.list_backups(_a().docs_dir)]


def restore_backup(path):
    a = _a()
    backup.export(a.conn, a.docs_dir, a.now(), "timerecord-before-restore-")
    return backup.restore(a.conn, path)


def android_backups():
    """Time Recording (Android) backups found in Documents."""
    return [{"path": p, "name": os.path.basename(p),
             "mtime": dt.datetime.fromtimestamp(os.path.getmtime(p)).isoformat(timespec="minutes")}
            for p in android.find_backups(_a().docs_dir)]


def android_preview(path):
    a = _a()
    return android.preview(a.conn, android.read(path))


def android_import(path, with_settings):
    a = _a()
    data = android.read(path)
    backup.export(a.conn, a.docs_dir, a.now(), "timerecord-before-import-")
    return android.apply(a.store, data, bool(with_settings))
