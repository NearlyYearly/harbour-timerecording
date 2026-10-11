# SPDX-License-Identifier: GPL-3.0-or-later
"""SQLite storage and schema migrations."""
import json
import sqlite3

# Each entry migrates from version i to i+1. Never edit a shipped entry; append.
MIGRATIONS = [
    """
    CREATE TABLE tasks (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        color TEXT NOT NULL DEFAULT '#4caf50',
        archived INTEGER NOT NULL DEFAULT 0,
        sort INTEGER NOT NULL DEFAULT 0
    );
    CREATE TABLE stamps (
        id INTEGER PRIMARY KEY,
        check_in TEXT NOT NULL,
        check_out TEXT,
        task_id INTEGER REFERENCES tasks(id) ON DELETE SET NULL,
        comment TEXT NOT NULL DEFAULT '',
        kind TEXT NOT NULL DEFAULT 'work' CHECK (kind IN ('work', 'break')),
        raw_check_in TEXT,
        raw_check_out TEXT
    );
    CREATE INDEX stamps_check_in ON stamps(check_in);
    CREATE TABLE note_types (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        credit_factor REAL NOT NULL DEFAULT 0,
        holiday_days REAL NOT NULL DEFAULT 0,
        color TEXT NOT NULL DEFAULT '#2196f3',
        sort INTEGER NOT NULL DEFAULT 0
    );
    CREATE TABLE day_notes (
        date TEXT PRIMARY KEY,
        note_type_id INTEGER REFERENCES note_types(id) ON DELETE SET NULL,
        text TEXT NOT NULL DEFAULT ''
    );
    CREATE TABLE templates (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        lines TEXT NOT NULL DEFAULT '[]'
    );
    CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
    );
    CREATE TABLE undo_log (
        seq INTEGER PRIMARY KEY,
        label TEXT NOT NULL,
        changes TEXT NOT NULL,
        undone INTEGER NOT NULL DEFAULT 0
    );
    INSERT INTO tasks (name, color, sort) VALUES ('Work', '#4caf50', 0);
    INSERT INTO note_types (name, credit_factor, holiday_days, color, sort) VALUES
        ('Vacation', 1, 1, '#2196f3', 0),
        ('Half vacation', 0.5, 0.5, '#64b5f6', 1),
        ('Sick', 1, 0, '#f44336', 2),
        ('Public holiday', 1, 0, '#9c27b0', 3),
        ('Comp time', 0, 0, '#ff9800', 4);
    """,
    """
    ALTER TABLE note_types ADD COLUMN archived INTEGER NOT NULL DEFAULT 0;
    """,
    # v3: per-task rules, as in Time Recording for Android (D-025).
    """
    ALTER TABLE tasks ADD COLUMN work_factor REAL NOT NULL DEFAULT 1;
    ALTER TABLE tasks ADD COLUMN target_off INTEGER NOT NULL DEFAULT 0;
    ALTER TABLE tasks ADD COLUMN holiday_days REAL NOT NULL DEFAULT 0;
    """,
    # v4: vacation per year (D-026). The old holiday settings move into the table.
    lambda conn: (conn.execute(
        "CREATE TABLE vacation_years (year INTEGER PRIMARY KEY, days REAL NOT NULL, "
        "carryover REAL NOT NULL DEFAULT 0)"), holiday_settings_to_years(conn)),
]

SCHEMA_VERSION = len(MIGRATIONS)

# Tables in dependency order; used by backup/restore.
TABLES = ["tasks", "note_types", "stamps", "day_notes", "templates", "settings", "vacation_years"]


def connect(path):
    conn = sqlite3.connect(path)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    migrate(conn)
    return conn


def migrate(conn):
    version = conn.execute("PRAGMA user_version").fetchone()[0]
    if version > SCHEMA_VERSION:
        raise RuntimeError("database schema %d is newer than app (%d)" % (version, SCHEMA_VERSION))
    for i in range(version, SCHEMA_VERSION):
        step = MIGRATIONS[i]
        if callable(step):
            # Python steps for data that SQL alone cannot move (JSON settings).
            conn.commit()
            try:
                step(conn)
                conn.execute("PRAGMA user_version = %d" % (i + 1))
                conn.commit()
            except Exception:
                conn.rollback()
                raise
        else:
            conn.executescript(
                "BEGIN;" + step + "PRAGMA user_version = %d; COMMIT;" % (i + 1))


def holiday_settings_to_years(conn):
    """Move the pre-v4 settings holiday.entitlement / holiday.carryover into vacation_years.

    Also run after restoring an older backup. Years that already have a row are kept.
    """
    def setting(key):
        row = conn.execute("SELECT value FROM settings WHERE key = ?", (key,)).fetchone()
        return json.loads(row[0]) if row else None

    entitlement = setting("holiday.entitlement")
    carryover = setting("holiday.carryover") or {}
    days = float(entitlement) if entitlement is not None else 30.0
    for year, amount in carryover.items():
        conn.execute("INSERT OR IGNORE INTO vacation_years (year, days, carryover) VALUES (?, ?, ?)",
                     (int(year), days, float(amount)))
    if entitlement is not None:
        conn.execute("INSERT OR REPLACE INTO settings (key, value) VALUES ('vacation.default_days', ?)",
                     (json.dumps(days),))
    conn.execute("DELETE FROM settings WHERE key IN ('holiday.entitlement', 'holiday.carryover')")


def row_dict(row):
    return dict(row) if row is not None else None
