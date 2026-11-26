# Plan — harbour-timerecord

See `PLATFORM.md` for the platform facts this plan is based on.

## One-liner

A native Sailfish OS time recorder in the spirit of *Time Recording* for Android: check in and
out, tasks, day notes, automatic breaks by rule, flexitime and vacation balance — on-device.

## Users & jobs

People who track their working time (flexitime, overtime, vacation) and moved from Android to
Sailfish OS. They need to:

- check in/out with one tap, also from the cover,
- fix mistakes fast: tap a line to edit, hold to delete, undo anything,
- have legal breaks applied automatically, the way their employer counts them,
- see the day, the week and the month, and their flexitime and vacation balance,
- keep backups and bring their history over from the Android app.

## Scope

### v0.1–v0.5 — done, in daily use on the phone

- **Day page**: big check-in/out button, task picker (switching task while checked in closes
  the line and starts a new one), lines with tap-to-edit and hold-to-delete with remorse,
  swipe between days, date picker, day note banner, summary (worked / breaks / target / day ±,
  flexitime).
- **Undo/redo** of every change, persisted (D-006); Undo/Redo above the day's lines (D-032).
- **Automatic breaks** by rule, three modes, *check out & in* by default (D-007…D-011).
- **Punch rounding** and a **double-tap guard** (D-012).
- **Day notes** with day types that credit the target and use vacation days; editable types.
- **Week and month views**, per-task totals, **flexitime** (D-013) and **vacation balance** (per year, D-026).
- **Day templates**: save a day, apply it to another.
- **Reminders** while the app runs (D-014); tapping a notification opens the app (D-015).
- **Cover**: state, task, progress to target, day ±, flexitime, next break; check in/out and
  next-task actions.
- **Backup**: JSON export/restore, automatic backups with retention, in `~/Documents`.
- Every tunable is a setting in the UI (D-021).

### v0.6 — Android import — done, used on the phone

- Import a *Time Recording* (dynamicg) backup (`timerec.db.gz`): tasks, lines, day notes,
  templates and optionally settings, with a preview first (D-025).
- Tasks get rules like on Android: share that counts as work, no target, uses vacation.

### v0.7 — Vacation per year — done, in daily use on the phone

- Vacation page (month page pulley), a history of years, own days and carryover per year (D-026).

### v0.8 — SPX export — done, used on the phone

- One or several months as a CSV for the ESS Monatsjournal filler, with business trips and
  on-call standby (D-028, D-029).

### v0.9 — Platform alignment — done, test build used on the phone

- Checked against sailfish-rag (Jolla's design guide and app notes): menus of at most four
  items and Undo above the day's lines instead of a bottom bar (D-032), id-based translations
  with a shipped catalogue (D-031), placeholders, scroll indicators, Enter keys, the colour
  signal; *Check in at…* takes a later time. What was checked on the phone is in the README
  and the device checklist (`TODO.md`, P5).

### Backlog (not now)

- German translation (UI strings use `qsTrId`; `translations/` is wired up, D-031).
- Reminders with the app closed via `Nemo.Alarms` / `timed` (D-014).
- Timesheet export (CSV/HTML) per week/month (the SPX CSV per month exists, D-028).
- Harbour submission (the validator refuses the `Notifications` permission, the D-Bus service
  file and the license location; no C++ launcher needed, D-005).
- Signed releases on OpenRepos, then Chum.

### Non-goals

Cloud sync, accounts, team features, payroll, invoicing, telemetry, network access.

### How it differs from Time Recording (Android)

- Breaks are rules you edit (thresholds, minutes, exact times) and can become real
  check-out/check-in pairs, not only a deduction.
- Undo covers every change and survives restarts.
- Fully offline; no `Internet` permission.

## Architecture

```
QML UI (Sailfish Silica, Theme.* tokens only — D-016)
        │  Backend.qml: async calls, dataChanged() signal
PyOtherSide (io.thp.pyotherside 1.5)
        │
Python 3.8 package `timerecord` (stdlib only)
   api ─ store (all writes + undo log) ─ rules (breaks, rounding) ─ calc (day/week/month,
   balances) ─ reminders ─ backup ─ android (import) ─ settings
        │
SQLite (stdlib sqlite3) — ~/.local/share/org.timerecord/harbour-timerecord/timerecord.sqlite
```

- Logic lives in Python so it is unit-tested in a plain container; QML stays thin.
- `Reminders.qml` (Nemo.KeepAlive + Nemo.Notifications) asks Python what is due.
- `DBusActivation.qml` (Nemo.DBus) receives notification taps.

## Data model (schema v4)

| Table | Key fields |
|-------|-----------|
| `tasks` | id, name, color, archived, sort, work_factor, target_off, holiday_days |
| `stamps` | id, check_in, check_out (NULL = running), task_id, comment, kind (work/break), raw_check_in, raw_check_out |
| `note_types` | id, name, credit_factor, holiday_days, color, sort, archived |
| `day_notes` | date, note_type_id, text |
| `templates` | id, name, lines (json) |
| `vacation_years` | year, days, carryover |
| `settings` | key, value (json) |
| `undo_log` | seq, label, changes (json), undone |

Rules: local ISO times, minute resolution; raw punch times keep seconds. A line belongs to the
day it was checked in. Automatic breaks in *show line* / *deduct* modes are computed, never
stored. Tasks and day types are archived, never deleted (D-018). Schema changes are appended
to `db.MIGRATIONS` and get a `DECISIONS.md` entry.

## Phases & milestones

| Phase | Outcome |
|-------|---------|
| **P1 Core** | Data layer, check in/out, lines, undo, notes, break rules, rounding, settings, backup, day page, cover basics. *(done)* |
| **P2 Views & balances** | Week, month, flexitime, vacation, day types, templates, task totals. *(done)* |
| **P3 Reminders** | Notifications, background job, full cover, notification tap opens the app. *(done)* |
| **P4 Android import** | Importer with preview, per-task rules. *(done)* |
| **P5 Device test** | Install on the phone, run the device checklist in `TODO.md`. |
| **P6 Polish** | Translation, UI Definition of Done pass, screenshots. |
| **P7 Publish** | OpenRepos listing (see `PUBLISH.md`). |

A phase is done when its `TODO.md` items are checked, the tests are green and the change
follows the definition of done in `../AGENTS.md`.

## Risks

| ID | Risk | Mitigation |
|----|------|-----------|
| R1 | Reminders do not fire with the app closed | Documented limit; `Nemo.Alarms`/`timed` in the backlog (D-014) |
| R2 | Sandbox blocks the notification tap (bus name) | Name follows the sandbox rule `<Org>.<App>` (D-015); verify on the device |
| R3 | Preview stand-in hides a Silica difference | Stand-in only for the desktop; device test before release (D-017) |
| R4 | Qt 5.6 limits QML features | Old `Connections` syntax, no ES6; checked by `tests/test_qml_qt56.py` |
| R5 | Android backup format undocumented | Built against a real backup, balances compared to the minute; preview first (D-025) |
| R6 | Break rules differ per employer/country | Everything editable; defaults only seed ArbZG values (D-007) |

## Release & publishing

1. Bump `Version:` in `rpm/harbour-timerecord.spec` and the file names in `README.md`.
2. Install and test a build on the phone (`BUILD.md`).
3. Write `docs/releases/<ver>.md`: who tested on what, known quirks, changes (`PUBLISH.md`).
4. `./release.sh`: tests, build, then tag and GitHub release after asking (D-027, D-033).

## Quality bar

- Unit tests for rules, store/undo, calc, reminders, backup, API (`docker compose run --rm test`).
- QML tests for the preview gestures (`qmltest`), headless smoke run over every page (`smoke`).
- Token rule enforced by `tests/test_qml_tokens.py`.
- No data loss across updates: migrations are append-only; backups before every restore.
