# TODO — harbour-timerecord

Ordered task list. Check items off as they land. Keep one "Now" section at the top.
New tasks go in the phase they belong to.

## Now

- [ ] P5 — install 0.8.0 on the phone, import the Android backup there, run the device checklist

## P1 — Core

- [x] Project skeleton, `docker compose` services, pinned images and requirements (D-004)
- [x] SQLite schema + migrations (D-003)
- [x] Check in/out with task, switch task while checked in
- [x] Lines: add, tap to edit, hold to delete with remorse
- [x] Undo/redo of every change, persisted, depth setting (D-006)
- [x] Day notes with day types
- [x] Break rules: show line / deduct (D-007, D-009, D-010)
- [x] Punch rounding (D-012)
- [x] Settings pages: targets, break rules, rounding, backup & general
- [x] JSON backup/restore, automatic backups (D-020)
- [x] Day page with swipe between days, date picker, summary
- [x] Cover basics
- [x] RPM build in the SDK container (D-005)
- [x] Desktop preview + headless smoke run (D-017)

## P1b — Changes after the first review

- [x] Break mode *check out & in*, default (D-007)
- [x] Exact break time per rule (D-008)
- [x] Double-tap guard (D-012)
- [x] Undo button and Week/Month in a bottom bar

## P2 — Views & balances

- [x] Week page (swipe weeks, tap a day)
- [x] Month page (calendar grid, totals, holidays, per-task totals)
- [x] Flexitime from the first recorded day, opening balance (D-013)
- [x] Holiday entitlement, carryover, taken/planned/remaining
- [x] Editable/archivable day types (D-018)
- [x] Day templates: save, apply, rename, delete
- [x] Schema v2 migration (`note_types.archived`)

## P3 — Reminders & cover

- [x] Reminders: still checked in, target reached, break starts, not checked in (D-014)
- [x] Planned breaks while checked in (D-011)
- [x] Reminders settings page (interval and every reminder editable)
- [x] Full cover: state, task, progress, day ±, flexitime, next break; next-task action
- [x] Notification tap opens the app; D-Bus service file; `Notifications` permission (D-015)
- [x] Preview: pulley gesture, swipe back / dialog accept-cancel, QML tests

## P3b — Platform tokens

- [x] UI uses Silica components and `Theme.*` only (D-016)
- [x] `Notices` instead of the custom banner, `ColorPickerDialog` instead of the palette
- [x] Token rule test (`tests/test_qml_tokens.py`)

## P3c — Docs

- [x] `docs/` in the harbour-dollfin layout (plan, platform, decisions, todo, build, publish)
- [x] Working instructions in `AGENTS.md`; `CLAUDE.md` imports it (D-024)

## P4 — Android import

- [x] Get a sample *Time Recording* backup (Q1)
- [x] Parser for its database (tasks, check-in/out events, day notes, templates, settings)
- [x] Preview: counts, period, days/notes kept, settings, what is not imported
- [x] Import as one undo step; backup before; settings optional
- [x] Per-task rules (schema v3): counts as work, no target, uses holiday (D-025)
- [x] `break.since`: history keeps its totals
- [x] Tests against a made-up database in the same format; balances checked against the real one

## P4b — Vacation

- [x] "Vacation" in the UI, "Public holiday" stays for statutory days (D-026)
- [x] Vacation page in the day pulley: years with days, carryover, taken, planned, left
- [x] Add past years; days and carryover per year; days taken per year
- [x] Schema v4 (`vacation_years`), migration and old backups convert the settings
- [x] Android import writes vacation years (one undo step)

## P4c — Several days, today

- [x] Edit several days: range with « », tick days, set/clear day notes, apply a template (one undo step)
- [x] Day page jumps to today when the app comes to the front
- [x] Past midnight, the day page follows to the new day when unused since the last check-out
- [x] Push-up menu on the day page: Edit several days, Vacation (preview stand-in + QML test)
- [x] Check in/out at a chosen time (pulley, today only; exact, no rounding)

## P5 — Device test

- [ ] Install via File Browser and via `pkcon` (`BUILD.md`)
- [ ] App starts from the launcher; data dir created under `org.timerecord/`
- [ ] Check in/out from page and cover; double tap is ignored
- [ ] Edit/delete a line, remorse, undo/redo
- [ ] While checked in: hold a line, menu stays open; delete and change check-in/out from it
- [ ] Long day: check-out splits at the break; undo restores one line
- [ ] Swipe days; week/month navigation; swipe back from a line
- [ ] Edit several days: vacation on a week sets Mon–Fri only; undo removes all of them
- [ ] Bring the app to the front from the launcher/cover: day page shows today
- [ ] Forgot to check in: *Check in at…* 07:50, later check out normally
- [ ] Change a break rule and see totals update
- [ ] Reminder arrives with the display off (app on the cover)
- [ ] Tapping a notification opens the app; with the app closed, it starts it (D-015)
- [ ] Backup lands in `~/Documents`; restore works
- [ ] Import `timerec.db.gz` from `~/Documents`; balance and vacation match Android
- [ ] Updating from 0.6.0 keeps the vacation numbers (schema v4 migration)
- [ ] Colours follow a light and a dark ambience (D-016)

## P6 — Polish

- [ ] German translation (`qsTr` already in place; `lupdate`/`lrelease` wiring)
- [ ] UI Definition of Done pass
- [ ] Screenshots from the phone
- [ ] Changelog (`%changelog` in the spec)

## P7 — Publish

See [`PUBLISH.md`](PUBLISH.md).

- [x] Decide the license (D-023, GPL-3.0-or-later), add `LICENSE`
- [ ] OpenRepos project, RPM, description, screenshots
- [ ] (optional) sign the RPM

## Backlog

- [ ] Reminders with the app closed via `Nemo.Alarms` / `timed` (Q3)
- [ ] Timesheet export (CSV/HTML) per week/month
- [ ] C++ launcher for Harbour (D-005)
- [ ] SailfishOS:Chum build
