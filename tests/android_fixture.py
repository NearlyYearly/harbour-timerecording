"""A made-up Time Recording (Android) backup, for the tests and the preview smoke run."""
import gzip
import shutil
import sqlite3

SCHEMA = """
CREATE TABLE T_CATEGORY_1 ( ID INTEGER, NAME TEXT, CUSTOMER TEXT, SORTNR INTEGER, INACTIVE_FG INTEGER,
    HOURLY_RATE FLOAT, UNPAID INTEGER, TARGET_OFF INTEGER, FIXED_AMT_WORK_UNIT FLOAT, FIXED_AMT_DAY FLOAT,
    TIME_SUM_OFF INTEGER, EXTRA1 TEXT, EXTRA2 TEXT, TIME_ACCUMULATION TEXT, COLOR_CODES TEXT,
    EXTRA3 TEXT, EXTRA4 TEXT);
CREATE TABLE T_STAMP_3 ( MDT INTEGER, ASOFDATE TEXT, STAMP_DATE_STR TEXT, CHECK_ACTION INTEGER,
    SEQNR INTEGER, CATEGORY_ID INTEGER, OVERTIME_FLAG INTEGER, COMMENT TEXT, VALUE1 FLOAT, VALUE2 FLOAT,
    VALUE_A TEXT, VALUE_B TEXT, VALUE_C TEXT, VALUE_D TEXT);
CREATE TABLE T_NOTE_1 ( NOTE_DATE_STR TEXT, NOTE_TEXT TEXT);
CREATE TABLE T_DAY_TEMPLATE_1 ( ID INTEGER PRIMARY KEY, TEXT TEXT, ASOFDATE TEXT);
CREATE TABLE T_DOMAIN_VALUE_1 ( DOMAIN TEXT, KEY TEXT, VALUE TEXT, VALUE2 TEXT, VALUE3 TEXT, VALUE4 TEXT);
CREATE TABLE T_FLEXTIME_D_1 ( YEAR INTEGER, GROUP_ID INTEGER, ASOFDATE TEXT, VALUE_S INTEGER, DESCRIPTION TEXT);
CREATE TABLE T_SETTINGS_TMP (KEY text, ITEM text);
CREATE TABLE T_TARGET_PER_WEEK_1 ( WEEK INTEGER PRIMARY KEY, TARGET_TIME FLOAT);
"""

TASKS = [  # id, name, sort, inactive, target_off, sum_off, accumulation
    (1, "Office", 10, 0, 0, 0, "100.0"),
    (2, "Leave", 20, 0, 0, 0, "100.0"),
    (3, "Comp time", 30, 0, 0, 0, "100.0"),
    (4, "On call", 40, 0, 1, 0, "0.0"),
    (5, "Paid overtime", 50, 0, 1, 1, "100.0"),
    (6, "Public holiday", 60, 0, 1, 0, "100.0"),
    (7, "Old project", 70, 1, 0, 0, "100.0"),
]

STAMPS = [  # asof, time, action, seq, task, comment
    # Mon: normal day with a lunch gap; comment on the check-in
    ("2026-01-05", "2026-01-05 06:30", 10, 1, 1, "Deploy"),
    ("2026-01-05", "2026-01-05 11:30", 20, 3, 0, None),
    ("2026-01-05", "2026-01-05 12:00", 10, 4, 1, None),
    ("2026-01-05", "2026-01-05 15:00", 20, 2, 0, None),
    # Tue: public holiday as a zero-length line (in and out at the same minute)
    ("2026-01-06", "2026-01-06 07:00", 10, 5, 6, None),
    ("2026-01-06", "2026-01-06 07:00", 20, 6, 0, None),
    # Wed: comp time, zero-length line, target stays
    ("2026-01-07", "2026-01-07 07:00", 10, 7, 3, None),
    ("2026-01-07", "2026-01-07 07:00", 20, 8, 0, None),
    # Thu: leave, full target as a line
    ("2026-01-08", "2026-01-08 07:00", 10, 9, 2, None),
    ("2026-01-08", "2026-01-08 14:42", 20, 10, 0, None),
    # Fri: work 10 h without any break, plus on call into the next day
    ("2026-01-09", "2026-01-09 06:00", 10, 11, 1, None),
    ("2026-01-09", "2026-01-09 16:00", 20, 12, 0, None),
    ("2026-01-09", "2026-01-09 22:00", 10, 13, 4, None),
    ("2026-01-09", "2026-01-10 01:30", 20, 14, 0, None),
    # Sat: only on call -> no target, nothing counts
    ("2026-01-10", "2026-01-10 09:00", 10, 15, 4, None),
    ("2026-01-10", "2026-01-10 20:00", 20, 16, 0, None),
    # Sun: a stray check-out
    ("2026-01-11", "2026-01-11 10:00", 20, 17, 0, None),
    # Mon: paid overtime only (does not count, no target)
    ("2026-01-12", "2026-01-12 07:00", 10, 18, 5, None),
    ("2026-01-12", "2026-01-12 15:00", 20, 19, 0, None),
    # Tue: still checked in (last line)
    ("2026-01-13", "2026-01-13 06:30", 10, 20, 1, "running"),
]


def make_backup(path, gz=False):
    db_path = str(path) + ".db"
    c = sqlite3.connect(db_path)
    c.executescript(SCHEMA)
    for tid, name, sort, inactive, toff, soff, acc in TASKS:
        c.execute("INSERT INTO T_CATEGORY_1 (ID, NAME, CUSTOMER, SORTNR, INACTIVE_FG, TARGET_OFF, TIME_SUM_OFF, "
                  "TIME_ACCUMULATION) VALUES (?, ?, '', ?, ?, ?, ?, ?)", (tid, name, sort, inactive, toff, soff, acc))
    for asof, t, action, seq, task, comment in STAMPS:
        c.execute("INSERT INTO T_STAMP_3 (MDT, ASOFDATE, STAMP_DATE_STR, CHECK_ACTION, SEQNR, CATEGORY_ID, COMMENT) "
                  "VALUES (0, ?, ?, ?, ?, ?, ?)", (asof + " 00:00:00", t + ":00", action, seq, task, comment))
    c.executemany("INSERT INTO T_NOTE_1 VALUES (?, ?)", [
        ("2026-01-09 00:00:00", "On call week"), ("2026-01-10 00:00:00", "On call week"),
        ("2026-01-12 00:00:00", "  ")])
    c.execute("INSERT INTO T_DAY_TEMPLATE_1 VALUES (1, 'Leave day', '2026-01-08 00:00:00')")
    c.execute("INSERT INTO T_DAY_TEMPLATE_1 VALUES (2, 'Empty', '2025-01-01 00:00:00')")
    c.executemany("INSERT INTO T_DOMAIN_VALUE_1 (DOMAIN, KEY, VALUE, VALUE2, VALUE3) VALUES (?, ?, ?, ?, ?)", [
        ("BalanceTracker.Label", "0", "Urlaub", None, "11"),
        ("BalanceTracker.Label", "1", "Business trips", None, "12"),
        ("BalanceTracker.Filter.0", "1000", "a:0_2", "-1", "0"),
        ("BalanceTracker.Filter.1", "1000", "a:0_1", "-1", "0"),
        ("BalanceTracker.Correction.0.2025", "1000", "2025-01-01", "30", ""),
        ("BalanceTracker.Correction.0.2026", "1000", "2026-01-01", "30.0", ""),
        ("BalanceTracker.Correction.0.2026", "1001", "2026-01-01", "4.5", "rest"),
        ("BalanceTracker.Correction.1.2026", "1000", "2026-01-01", "99", ""),
        ("customAlarm", "1002", "1|A1|...", "Check-in reminder", None),
    ])
    c.executemany("INSERT INTO T_FLEXTIME_D_1 VALUES (?, ?, ?, ?, ?)", [
        (2025, 2, "2025-01-01", 3600, "Vorjahr"),
        (2026, 2, "2026-01-01", 36000, "Vorjahr"),
        (2026, 3, "2026-01-31", 99999, None),
    ])
    c.executemany("INSERT INTO T_SETTINGS_TMP VALUES (?, ?)", [
        ("DailyTargetTime", "S|DailyTargetTime=07:42"),
        ("WeekdayTargetTime.0", "S|WeekdayTargetTime.0=00:00"),
        ("WeekdayTargetTime.6", "S|WeekdayTargetTime.6=00:00"),
        ("AutoBreak.0", "S|AutoBreak.0=06:00|00:30|11:30/0|0|0"),
        ("AutoBreak.1", "S|AutoBreak.1=09:00|00:45|11:30/0|0|0"),
        ("PunchNowRoundingSlot", "I|PunchNowRoundingSlot=30"),
    ])
    c.execute("INSERT INTO T_TARGET_PER_WEEK_1 VALUES (800, 30.8)")
    c.commit()
    c.close()
    if not gz:
        return db_path
    with open(db_path, "rb") as src, gzip.open(db_path + ".gz", "wb") as out:
        shutil.copyfileobj(src, out)
    return db_path + ".gz"
