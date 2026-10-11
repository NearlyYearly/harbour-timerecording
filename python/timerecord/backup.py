"""Full JSON backup and restore."""
import datetime as dt
import glob
import json
import os

from . import db, settings

FORMAT = "harbour-timerecord-backup"
PREFIX = "timerecord-backup-"
AUTO_PREFIX = "timerecord-auto-"


def dump(conn):
    tables = {}
    for table in db.TABLES:
        tables[table] = [dict(r) for r in conn.execute("SELECT * FROM %s" % table)]
    return {"format": FORMAT, "schema_version": db.SCHEMA_VERSION, "tables": tables}


def export(conn, directory, now, prefix=PREFIX):
    os.makedirs(directory, exist_ok=True)
    data = dump(conn)
    data["exported_at"] = now.isoformat(timespec="seconds")
    path = os.path.join(directory, prefix + now.strftime("%Y%m%d-%H%M%S") + ".json")
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=1, ensure_ascii=False)
    os.replace(tmp, path)
    return path


def load(path):
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    if data.get("format") != FORMAT:
        raise ValueError("not a Time Recording backup")
    if data.get("schema_version", 0) > db.SCHEMA_VERSION:
        raise ValueError("backup was made by a newer app version")
    return data


def restore(conn, path):
    """Replace all data with the backup content. Clears the undo history."""
    data = load(path)
    conn.commit()
    try:
        conn.execute("PRAGMA foreign_keys = OFF")
        for table in reversed(db.TABLES):
            conn.execute("DELETE FROM %s" % table)
        conn.execute("DELETE FROM undo_log")
        for table in db.TABLES:
            for row in data["tables"].get(table, []):
                names = list(row)
                conn.execute("INSERT INTO %s (%s) VALUES (%s)" % (
                    table, ", ".join(names), ", ".join("?" * len(names))), [row[n] for n in names])
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.execute("PRAGMA foreign_keys = ON")
    return sum(len(v) for v in data["tables"].values())


def list_backups(directory):
    paths = glob.glob(os.path.join(directory, PREFIX + "*.json"))
    paths += glob.glob(os.path.join(directory, AUTO_PREFIX + "*.json"))
    return sorted(paths, key=os.path.getmtime, reverse=True)


def auto_backup(conn, directory, now):
    """Write an automatic backup if the last one is older than backup.auto_days; prune old ones."""
    days = settings.get(conn, "backup.auto_days")
    if days <= 0:
        return None
    existing = sorted(glob.glob(os.path.join(directory, AUTO_PREFIX + "*.json")))
    if existing:
        last = dt.datetime.fromtimestamp(os.path.getmtime(existing[-1]))
        if now - last < dt.timedelta(days=days):
            return None
    path = export(conn, directory, now, AUTO_PREFIX)
    keep = max(1, settings.get(conn, "backup.keep"))
    for old in sorted(glob.glob(os.path.join(directory, AUTO_PREFIX + "*.json")))[:-keep]:
        os.remove(old)
    return path
