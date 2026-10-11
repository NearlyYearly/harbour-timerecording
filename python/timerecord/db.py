"""SQLite storage and schema migrations."""
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
]

SCHEMA_VERSION = len(MIGRATIONS)

# Tables in dependency order; used by backup/restore.
TABLES = ["tasks", "note_types", "stamps", "day_notes", "templates", "settings"]


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
        conn.executescript(
            "BEGIN;" + MIGRATIONS[i] + "PRAGMA user_version = %d; COMMIT;" % (i + 1))


def row_dict(row):
    return dict(row) if row is not None else None
