# Decision log — harbour-timerecord

A running record of decisions and *why* they were made, so nobody relitigates settled
questions. **Append-only:** once a decision is `Accepted`, never edit it; add a new one that
supersedes it. (Draft `Proposed`/`Open` entries may be finalised in place.)

## How to use this log

1. Copy the template below to the end of the list.
2. Give it the next `D-0NN` id and today's date.
3. Set a status:
   - `Open` — raised, not decided
   - `Proposed` — recommendation on the table, awaiting confirmation
   - `Accepted` — current decision
   - `Rejected` — considered and declined
   - `Superseded by D-0NN` — replaced
4. Keep it to a few lines: Context / Decision / Consequences.
5. If a decision touches the schema, code or scope, also update `PLAN.md` / `TODO.md`.

Template:

```md
### D-0NN — Title
- **Date:** YYYY-MM-DD · **Status:** Proposed
- **Context:** why this came up
- **Decision:** what we chose
- **Consequences:** what follows, including the downside
```

---

## Decisions

### D-001 — Platform target
- **Date:** 2026-10-09 · **Status:** Accepted
- **Context:** The phone is an aarch64 device on Sailfish OS 5.x.
- **Decision:** Target Sailfish OS 5.x, **aarch64**, built against the **5.0.0.43** SDK target.
  The package is `noarch` (QML + Python), so it also installs on 5.1/5.2.
- **Consequences:** No armv7hl build. Building against 5.0 keeps 5.0 phones supported.

### D-002 — UI and logic stack
- **Date:** 2026-10-09 · **Status:** Accepted
- **Context:** Options were QML/Silica with Python (PyOtherSide), with C++, or pure QML/JS.
- **Decision:** **QML/Silica UI + Python 3.8 logic via PyOtherSide.** Python uses the stdlib
  only (`sqlite3`, `json`, `datetime`), so there are no runtime dependencies to package.
- **Consequences:** Logic is unit-tested with pytest in a plain container. No compile step.
  Python is discouraged for Harbour (see D-005). PyOtherSide quirks: D-019.

### D-003 — Storage
- **Date:** 2026-10-09 · **Status:** Accepted
- **Context:** Need durable, migratable storage inside the sandbox.
- **Decision:** **SQLite** via Python's `sqlite3`, file
  `~/.local/share/org.timerecord/harbour-timerecord/timerecord.sqlite`. Versioned migrations
  in `db.MIGRATIONS` (`PRAGMA user_version`), append-only.
- **Consequences:** Needs `python3-sqlite` on the phone (separate package on SFOS).

### D-004 — Everything runs in containers
- **Date:** 2026-10-09 · **Status:** Accepted
- **Context:** Workstation rule: no local venvs or SDK installs; dependencies pinned.
- **Decision:** `docker compose` services `test`, `qmltest`, `smoke`, `preview`, `icons`,
  `build`. Images pinned by digest; pytest pinned with hashes in `requirements.txt`; preview
  Debian packages from a fixed `snapshot.debian.org` date.
- **Consequences:** ~6 GB for the SDK image. The SDK build runs as root with mersdk's sb2
  config because `su`/`sudo` fail inside the image (PAM); see `BUILD.md`.

### D-005 — Packaging and launcher
- **Date:** 2026-10-09 · **Status:** Accepted
- **Context:** Harbour requires an ELF binary named like the package; a QML app normally
  starts through `sailfish-qml`.
- **Decision:** `noarch` RPM started by **`sailfish-qml`**. Distribute by direct install /
  OpenRepos, not Harbour.
- **Consequences:** `rpmvalidation` (Harbour) fails on the missing binary and on the
  `libsailfishapp-launcher` requirement. Harbour later needs a small C++ launcher.

### D-006 — Undo and redo
- **Date:** 2026-10-09 · **Status:** Accepted
- **Context:** Undo of added/deleted times was a core requirement.
- **Decision:** Every change goes through `Store`, which records row-level changes
  (`table`, `pk`, `before`, `after`) in `undo_log`. Undo writes `before` rows in reverse,
  redo writes `after`. Persisted; depth is a setting. Restores use UPDATE-then-INSERT, never
  `INSERT OR REPLACE`, so foreign keys are not nulled.
- **Consequences:** Multi-row actions (check-out with break split, templates) undo as one step.
  Restoring a backup clears the history.

### D-007 — Automatic break modes
- **Date:** 2026-10-09 · **Status:** Accepted
- **Context:** Breaks should follow rules (seeded with German ArbZG: > 6:00 → 30 min,
  > 9:00 → 45 min); the user wanted real check-out/check-in pairs at the break.
- **Decision:** Three modes: **check out & in** (default: at check-out the missing break
  becomes a gap between two lines), **show break line** (computed line), **deduct only**.
  Split mode always counts gaps as break. When a break would end exactly at the check-out
  there is no gap to create, so it is stored as an explicit break line.
- **Consequences:** Split runs on check-out and when lines of a finished day are added or
  edited; never while a line is running. Undo of the check-out undoes the split.

### D-008 — Break placement and exact times
- **Date:** 2026-10-09 · **Status:** Accepted
- **Context:** The user wanted to set an exact time for a break.
- **Decision:** Each rule may have its own `at` time; otherwise a global placement applies
  (after N hours worked, or an exact time of day). Parts that overlap are laid out in
  sequence; touching parts merge into one break.
- **Consequences:** Rules are cumulative: the second rule adds only its extra minutes.

### D-009 — Cap breaks at the threshold
- **Date:** 2026-10-09 · **Status:** Accepted
- **Context:** Working 6:10 without a break would lose 30 minutes and end at 5:40.
- **Decision:** By default never deduct more than the time beyond the rule threshold
  (6:10 → 6:00). A setting turns this off.
- **Consequences:** Matches common employer practice; strict deduction is still available.

### D-010 — Gaps count as break
- **Date:** 2026-10-09 · **Status:** Accepted
- **Context:** A lunch check-out/check-in is a break.
- **Decision:** Gaps between lines on the same day count towards the break minimum (setting;
  always on in split mode, see D-007).
- **Consequences:** A long gap (e.g. evening return) also shows in "breaks".

### D-011 — Planned breaks while checked in
- **Date:** 2026-10-09 · **Status:** Accepted
- **Context:** A break is only required after 6:00 worked, so a 12:00 break could never be shown
  or announced at 12:00.
- **Decision:** While checked in, planned breaks are computed as if the day lasts until the
  target is met. Totals still deduct only what is actually due.
- **Consequences:** The planned break shows from check-in; the real split still follows the
  actual time worked at check-out.

### D-012 — Double-tap guard and rounding
- **Date:** 2026-10-09 · **Status:** Accepted
- **Context:** Accidental double taps checked in and out again.
- **Decision:** A check-in/out within `punch.debounce_sec` (default 10 s) of the previous
  punch is ignored and the UI says so. Raw punch times keep seconds; rounding (step and
  direction per in/out) is applied at punch time.
- **Consequences:** Two real punches within the window need the edit dialog.

### D-013 — Flexitime starts at the first recorded day
- **Date:** 2026-10-09 · **Status:** Accepted
- **Context:** A fixed default start (1 Jan) produced −1601:15, every untracked workday −8:00.
- **Decision:** Default start = first day with any line or note; a fixed date and an opening
  balance are settings. Week/month totals use the same start; days after today never count.
- **Consequences:** Importing older data moves the start back automatically.

### D-014 — Reminders while the app runs
- **Date:** 2026-10-09 · **Status:** Accepted
- **Context:** Reminders: forgot to check out, target reached, break starts, not checked in.
- **Decision:** `Nemo.KeepAlive` `BackgroundJob` (interval is a setting) asks Python which
  reminders are due and publishes them with `Nemo.Notifications`; each occasion once per day.
- **Consequences:** Closing the app stops reminders. Closed-app reminders would need `timed`
  (`Nemo.Alarms`, alarms visible in the Clock app) — backlog.

### D-015 — Notification tap opens the app
- **Date:** 2026-10-09 · **Status:** Accepted (verify on device)
- **Context:** Notifications without a default action do nothing when tapped.
- **Decision:** `DBusAdaptor` on `org.timerecord.harbour-timerecord`
  (`/org/timerecord/TimeRecording`, `activate`), used as the notifications' `default` action;
  D-Bus service file starts the app via `invoker --desktop-file … --id …`. Add the
  `Notifications` sandbox permission. No `ExecDBus` key (fails `desktop-file-validate`).
- **Consequences:** The bus name follows the sandbox rule `<Org>.<App>`; whether a tap starts a
  closed app is only verifiable on the device.

### D-016 — UI uses platform tokens
- **Date:** 2026-10-11 · **Status:** Accepted
- **Context:** Hardcoded greens/reds and sizes ignore the ambience and screen scale.
- **Decision:** Silica components and `Theme.*` values only — no hardcoded colors, sizes or
  fonts. Running/positive → `highlightColor`, negative/warning → `errorColor`; tints via
  `Theme.rgba`; `Notices` instead of a custom banner; `ColorPickerDialog` instead of a palette.
- **Consequences:** Enforced by `tests/test_qml_tokens.py`. Task and day-type colors are user
  data, not UI style. The look follows the user's ambience.

### D-017 — Desktop preview with a Silica stand-in
- **Date:** 2026-10-09 · **Status:** Accepted
- **Context:** Silica only exists on the device/emulator; the emulator is a VirtualBox VM.
- **Decision:** `preview/shim` reimplements the Silica/Nemo pieces we use on Qt 5.15, with the
  same gestures (pulley, swipe back, dialog accept/cancel). Real QML and Python run unchanged
  (only `EnterKey` lines are stripped). Covered by QML tests and a headless smoke run.
- **Consequences:** Looks close to, not exactly like, the device; the phone stays the reference.

### D-018 — Archive instead of delete
- **Date:** 2026-10-09 · **Status:** Accepted
- **Context:** Deleting a task nulls `task_id` on its lines (FK `SET NULL`), and undo could not
  restore that.
- **Decision:** Tasks and day types are archived, never deleted.
- **Consequences:** Archived entries stay in history and totals; hidden from pickers.

### D-019 — PyOtherSide argument conventions
- **Date:** 2026-10-09 · **Status:** Accepted
- **Context:** PyOtherSide cannot pass JS `null` and passes numbers as floats.
- **Decision:** QML sends `-1` / `""` for "none" (`Backend.optId`); `api._opt` maps them to
  `None`, `api._clean` turns integral floats into ints. The QML wrapper is `Backend.run()`
  (naming it `call()` shadowed PyOtherSide's own and recursed).
- **Consequences:** `-1` is never a valid id.

### D-020 — Backup format
- **Date:** 2026-10-09 · **Status:** Accepted
- **Context:** Backups must survive updates and be restorable.
- **Decision:** JSON dump of all tables with `format` and `schema_version`, written atomically
  to `~/Documents/timerecord-backup-*.json`. Automatic backups every N days, keep M. A restore
  first saves the current data (`timerecord-before-restore-*`), runs in one transaction and
  clears the undo history.
- **Consequences:** Backups from newer app versions are refused.

### D-021 — Tunables are settings
- **Date:** 2026-10-09 · **Status:** Accepted
- **Context:** Workstation rule: thresholds, rates, intervals are operator-editable.
- **Decision:** Every tunable is in `settings.DEFAULTS` (seed values only) and editable in the
  Settings pages; types are validated on write.
- **Consequences:** Internal state uses the `ui.` prefix and is not shown in the UI.

### D-022 — Identifiers
- **Date:** 2026-10-09 · **Status:** Accepted
- **Context:** Package, sandbox identity and bus name must be stable.
- **Decision:** Package/binary name **`harbour-timerecord`**, display name *Time Recording*
  (*Zeiterfassung* in German), `OrganizationName=org.timerecord`,
  `ApplicationName=harbour-timerecord`, bus name `org.timerecord.harbour-timerecord`.
- **Consequences:** Changing them later moves the data directory and breaks updates.

### D-023 — License
- **Date:** 2026-10-11 · **Status:** Accepted (was: MIT placeholder, 2026-10-09)
- **Context:** The app replaces a closed, paid Android app and is published on GitHub.
- **Decision:** **GPL-3.0-or-later.** Changed versions that are shipped must stay open;
  common for Sailfish community apps. Silica is a system library under GPLv3's definition,
  PyOtherSide (ISC) and the Nemo plugins are compatible.
- **Consequences:** `LICENSE` holds the GPLv3 text and is packaged (`%license`); the spec
  says `GPL-3.0-or-later`; every source file starts with an
  `SPDX-License-Identifier: GPL-3.0-or-later` line.

### D-024 — Working instructions in AGENTS.md
- **Date:** 2026-10-11 · **Status:** Accepted
- **Context:** Rules were in `CLAUDE.md`, which only Claude Code reads; the reference project
  (harbour-dollfin) keeps them in `AGENTS.md` for humans and any agent.
- **Decision:** All working instructions live in `AGENTS.md`. `CLAUDE.md` only contains
  `@AGENTS.md` so Claude Code loads the same file.
- **Consequences:** One source of truth; edit `AGENTS.md`, never `CLAUDE.md`.

---

### D-025 — Android import and per-task rules

- **Context:** *Time Recording* (Android) backups are its SQLite database (`timerec.db.gz`).
  It marks absences and on call with tasks, not day notes: a task has a share that counts as
  work (TIME_ACCUMULATION, TIME_SUM_OFF), "no target" (TARGET_OFF) and a holiday tracker.
  Checked against a real backup: its flexitime = lines × share; a day has no target only when
  *all* its lines are of "no target" tasks; no automatic break is added to history (breaks
  only exist where they were punched).
- **Decision:** Schema v3 gives tasks `work_factor`, `target_off` and `holiday_days`,
  editable in the task dialog. Lines with factor 0 stay out of the break rules. New setting
  `break.since`: days before it get no automatic breaks; the import sets it to the day after
  the last imported line. The importer (`android.py`) pairs check-in/out events per day
  (same-minute pairs give zero-length lines, as Android uses them for public holidays),
  keeps day notes as text, rebuilds templates from the day they were saved from, and maps
  targets, break rules, the latest flexitime carryover and the holiday corrections.
  Days that already have lines and dates that already have a note are left alone; tasks
  with the same name are reused. One undo step; a backup is written first. Settings are
  optional and not undoable, like every settings change.
- **Not imported:** weekly target overrides, punch rounding codes, reminders, punch rules
  (formats unclear or no equivalent); the preview lists them.
- **Consequences:** Imported balances match Android to the minute (checked for every
  month-end in 2026). The real backup never enters the repo; tests use a made-up database
  (`tests/android_fixture.py`).

### D-026 — Vacation per year, "vacation" instead of "holiday"

- **Context:** "Holiday" meant both the user's days off and public holidays, which also exist
  as a day type and a task rule. Vacation was one entitlement in Settings plus a carryover
  map; past years could not have their own number of days.
- **Decision:** The UI says **Vacation** for days off and **Public holiday** for statutory
  days. Vacation has its own page in the day pulley, not in Settings. Schema v4 adds
  `vacation_years(year, days, carryover)`; each year has its own days and carryover, past
  years can be added, changes are undoable and part of backups. A year without an entry
  gets the days of the latest earlier entry (else the setting `vacation.default_days`) and
  no carryover. Adding a year suggests what the previous year left as carryover.
  The v4 migration (a Python step) moves `holiday.entitlement` / `holiday.carryover` into
  the table; restoring an older backup does the same. The Android import writes its
  per-year corrections as rows (largest entry = days, rest = carryover) inside the undo step.
- **Not renamed:** the columns `tasks.holiday_days` and `note_types.holiday_days` keep their
  name; renaming needs SQLite 3.25+ on the phone and changes nothing for the user.

## Open questions

| # | Question | When |
|---|----------|------|
| Q1 | ~~A sample *Time Recording* backup for the importer~~ — received, see D-025 | P4 |
| Q2 | ~~License~~ — GPL-3.0-or-later (D-023) | P7 |
| Q3 | Reminders with the app closed: accept the limit or use `Nemo.Alarms` (Clock app entries)? | after P5 |
| Q4 | German translation for v1? | P6 |
