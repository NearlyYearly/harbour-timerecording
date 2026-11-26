# harbour-timerecord

Time recording for SailfishOS (Silica UI, Python logic via PyOtherSide), modelled on
*Time Recording* for Android: check in/out, tasks, day notes, automatic break rules,
punch rounding, undo/redo, week/month views, flexitime and vacation per year, day
templates and JSON backups.

> **LLM-assisted app; no human has reviewed the code.** An LLM (Anthropic's Claude, through
> Claude Code) wrote the code, the tests and these docs. The author decides what the app does
> and how it behaves, uses it every day on their phone and tries new builds there, but has not
> reviewed the code. Keep backups (Settings → Backup & general) and expect bugs that the tests
> and daily use have not found. Issues and pull requests are welcome.

Releases are normal GitHub releases, not pre-releases ([D-033](docs/DECISIONS.md)). Every
commit ends with LLMGD disclosure lines that grade how it was made and tested
([D-030](docs/DECISIONS.md)). For the app as a whole, as of 2026-11-26 (origin weighted by the
lines each commit changed):

    Disclosure: LLMGD-2 · origin O1 (the author set the features and tests them in daily use on their phone; an LLM wrote all code, tests and docs; no human has reviewed the code)
    LLMGD: v0.3; assurance=A2; flags=T; origin={O0:.06,O1:.94}; origin_headline=O1; scope=code+tests+build+docs; graded-by=claude-opus-5-5; retrieval=self-claimed

## How it was tested

Each section below ends with *What was checked, and what was not*. What they share:

- **Phone:** the author's daily use on a Jolla Phone (2026) with Sailfish OS 5.2.0.22. Each
  section names what the author has used there (reported 2026-11-26).
- **Tests:** `pytest` on the Python logic under Python 3.8, as on the phone, and rules on the
  QML (platform tokens, Qt 5.6 syntax, translations). CI runs them on every push to `main`.
- **Desktop preview:** a headless run opens every page, takes screenshots and fails on any QML
  warning. It runs the real QML and Python, but on Qt 5.15 with a stand-in for Silica
  (`preview/shim`), so it shows layout and logic, not how Silica behaves on the phone.
- **Not done anywhere:** a human code review, a run in the Sailfish SDK emulator, another
  phone or Sailfish OS release, a language other than English.

## Day page

Check in and out with one tap, also from the cover, and switch the task while checked in. Tap
a line to edit it, hold it to delete it (with a remorse timer). Swipe left and right between
days.

Menus: the pulley (top) holds *Settings* and the actions for the shown day: *Day type & note*
(one tap per type, keeps the note text; its pulley opens the note), add line, and today *Check
in at… / Check out at…* for a forgotten punch (exact time, no rounding), on other days *Go to
today*. The push-up menu (bottom) opens *Week*, *Month*, *Templates* and *Edit several days*.
*Undo* sits above the day's lines whenever there is a step to undo, with the step's name;
right after an undo, *Redo* appears beside it.

The day page opens on today, also when the running app comes to the front. Left open past
midnight, it moves on to the new day unless you are checked in or looking at another day.
A check-in/out within *n* seconds of the previous one is ignored (Settings → Backup & general).

**What was checked, and what was not**
- On the phone: checking in and out from the page and the cover, editing and deleting lines,
  undo and redo; the current menus and the Undo row in the test build 0.8.4-1.test1.
- Tests: `test_store.py` (punching with rounding, a chosen time, switching task, undo/redo and
  its depth); QML tests of the stand-in's pulley, push-up menu and swipe gestures; the desktop
  run opens both day menus.
- Not checked on the phone: switching task while checked in, the double-tap guard, moving on
  past midnight, coming back to today when the app comes to the front, landscape.

## Automatic breaks

Settings → Break rules, three modes:
- **Check out & in** (default): on check-out, a missing break becomes a real check-out at the
  break start and check-in at its end. Each rule can have its own exact time
  (e.g. > 6:00 → 30 min at 12:00, > 9:00 → 45 min at 15:00); otherwise the general placement
  applies (after hours worked, or an exact time). While checked in the break shows as planned.
  If a break would end exactly at the check-out, it is stored as a break line instead.
- **Show break line**: computed break shown in the list, lines untouched.
- **Deduct only**: subtracted from the total.

While checked in, planned breaks assume the day lasts until the target is reached, so a
12:00 break shows (and is announced) from the morning on; totals only deduct what is due.

**What was checked, and what was not**
- On the phone: *Check out & in* splitting a long day at the break; totals following a changed
  break rule.
- Tests: `test_rules.py` (thresholds, placement, gaps, each mode) and `test_breaks_and_views.py`
  (splitting at check-out and undoing it, exact rule times, planned breaks while checked in).
- Not checked on the phone: the *Show break line* and *Deduct only* modes.

## Week, month, flexitime and vacation

*Week* and *Month* (push-up menu) swipe like the day page; tapping a day opens it on the day
page. The month page shows a calendar grid, the month's totals, the year's vacation and the
totals per task. Its pulley opens *Flexitime* (the balance counts from the first recorded day,
plus an opening balance), *Vacation* and *SPX export*.

Vacation: one entry per year with its own days and carryover; add past years, see the days
taken and planned per year. A year without an entry gets the days of the latest earlier year.
Days come from day types and tasks that use vacation.

**What was checked, and what was not**
- On the phone: the week and month pages, the flexitime balance and the vacation page.
- Tests: `test_breaks_and_views.py` (week summary, month totals, flexitime from the first
  recorded day) and `test_vacation.py` (years, fallback, days taken, undo, the schema
  migration, older backups).
- Not checked on the phone: updating from 0.6.0 or older with its vacation numbers (the
  migration is tested on the desktop only).

## Several days and templates

*Edit several days* (push-up menu): a week is preselected, *From*/*To* change the range and
« » move it by its length. The working days are ticked; set or clear a day note on all of them
or add a template, each as one undo step.

*Templates* (push-up menu): save a day with finished lines as a template (pulley), rename or
delete it, tap it to add it to the shown day.

**What was checked, and what was not**
- On the phone: setting day notes or a template on a range of days.
- Tests: `test_store.py` (day notes on several days, also through the API) and
  `test_breaks_and_views.py` (templates saved and applied, on several days as one undo step).
- Not checked on the phone: undoing such a change in one step; that the preselected week
  ticks only the working days.

## Reminders and cover

Reminders (Settings → Reminders): still checked in after *n* hours, target reached, automatic
break starts, not checked in by a time. They run while the app is open, also in the
background/on the cover with the display off (Nemo.KeepAlive); closing the app stops them.
Tapping a notification opens the app (D-Bus name `org.timerecord.harbour-timerecord`,
started via `dbus/org.timerecord.harbour-timerecord.service` when not running).

Cover: state and task, worked vs. target with a progress bar, day ± and flexitime, next break;
actions check in/out and next task (switches task when checked in).

**What was checked, and what was not**
- On the phone: reminders arriving, also with the display off and the app on the cover;
  tapping one opened the app; checking in and out from the cover.
- Tests: `test_reminders.py` (each kind, its time, once per day, switched off); the desktop
  run shows the cover and words one reminder.
- Not checked on the phone: tapping a notification while the app is closed (the D-Bus start),
  the cover's next-task action.

## Import from Android

Settings → Import from Android: copy the *Time Recording* backup `timerec.db.gz` to
`~/Documents`, pick it, check the preview, import. Tasks, lines, day notes, templates,
vacation per year and (optionally) targets, break rules and the flexitime carryover come over;
days that already have lines here are left alone. One undo step removes the import again.
Tasks keep Android's rules (Settings → Tasks): share that counts as work (on call = 0 %),
no target (public holiday) and uses vacation.

**What was checked, and what was not**
- On the phone: importing `timerec.db.gz`; balance and vacation matched the Android app.
- Tests: `test_android.py` on a made-up database in the same format
  (`tests/android_fixture.py`); the mapping and the balances were compared with a real backup
  on the desktop (D-025), which is not in the repository.
- Not checked: backups from other versions of the Android app than the one tried.

## SPX export

Month page pulley → SPX export: one month, or several, as a CSV for the ESS Monatsjournal
filler, `~/Documents/timerecord-spx-<YYYY-MM>.csv`:

    datum;typ;von;bis
    2026-10-15;Normalarbeitszeit;07:30;11:30
    2026-10-15;Pause;11:30;12:15
    2026-10-15;Normalarbeitszeit;12:15;16:00
    2026-10-15;Rufbereitschaftseinsatz;18:00;18:30

Work lines are cut around breaks (break lines, automatic breaks, gaps when they count as
breaks). The type of work, of breaks and of each task is set on the same page; days still
checked in are left out. Day notes (day type or note text, names and times on the same page):

- *Dienstreise*: 06:30–11:30 work, 11:30–12:00 break, 12:00–14:42 work, instead of the
  day's own work and breaks (lines of a task with its own type stay).
- *Rufbereitschaft*: a `Rufbereitschaft TVL` row, Mon–Fri from the day's last work to the
  next day's first work, Sat/Sun 07:00 to 07:00.

**What was checked, and what was not**
- On the phone: exporting a month and filling the Monatsjournal with the CSV.
- Tests: `test_export.py` (work cut around breaks, gaps, running days, business trips, on-call
  standby, the type settings).
- Not checked on the phone: exporting several months at once.

## Backups

Settings → Backup & general: export a backup now, or automatically every *n* days keeping the
latest *n*, as JSON in `~/Documents/timerecord-*.json`. *Restore* replaces all data with one
of them; the current data is saved first.

**What was checked, and what was not**
- On the phone: a backup landing in `~/Documents`, and a restore.
- Tests: `test_store.py` (round trip, foreign files refused, automatic interval and pruning)
  and `test_vacation.py` (older backups convert).
- Not checked on the phone: restoring a backup from an older app version.

## Languages

The app is in English. Its texts are id-based (`qsTrId`, D-031):
`translations/harbour-timerecord.ts` is the English catalogue, and a language is added as
`translations/harbour-timerecord-<lang>.ts`.

**What was checked, and what was not**
- On the phone: the first build with the catalogue (0.8.4-1.test1) worked; had the catalogue
  not loaded, the app would show ids instead of text.
- Tests: `test_translations.py` (every text has an id and an English source, the catalogue is
  current, texts made in Python are translated in QML).
- Not checked: any other language; none exists yet.

## Develop

Everything runs in containers:

| Command | What it does |
|---|---|
| `docker compose run --rm test` | pytest for the Python logic (Python 3.8, like SFOS 5) |
| `docker compose run --rm preview` | runs the app on the desktop (Wayland); data in `preview/home` |
| `docker compose run --rm smoke` | headless run, screenshots of every page into `preview/shots` |
| `docker compose run --rm qmltest` | QML tests for the preview stand-ins (pulley, push-up menu, swipe gestures) |
| `docker compose run --rm icons` | renders `icons/*/harbour-timerecord.png` from the SVG |
| `docker compose run --rm i18n` | updates `translations/*.ts` after UI texts changed |
| `docker compose run --rm build` | builds `RPMS/harbour-timerecord-<version>.noarch.rpm` with the Sailfish SDK |

The preview uses a small stand-in for Sailfish Silica (`preview/shim`), so it looks close
to, not exactly like, the device. Pull the page down from the top for the pulley menu, up past the end for the push-up menu (or tap the strip at the top / bottom),
swipe right to go back (in a dialog: cancel; swipe left accepts), or the button top-left / Escape; the cover is shown on the right.

## Install on the phone

Without developer mode: allow Settings → Untrusted software, copy the RPM to the phone
(e.g. `~/Downloads`), open it in the File Browser and tap Install. Dependencies come from
the Jolla repositories automatically; installing a newer RPM keeps the data.

With developer mode (Settings → Developer tools, set a password), from the host:

    ./deploy.sh <phone-ip>      # or by hand:
    scp RPMS/harbour-timerecord-0.9.0-1.noarch.rpm defaultuser@<phone-ip>:
    ssh defaultuser@<phone-ip> devel-su pkcon install-local -y harbour-timerecord-0.9.0-1.noarch.rpm

Data: `~/.local/share/org.timerecord/harbour-timerecord/timerecord.sqlite`.
Backups (manual and automatic): `~/Documents/timerecord-*.json`.

The package starts through `sailfish-qml`, so it installs fine by hand or from
OpenRepos/Chum. Harbour (the Jolla Store) refuses it as it is: its validator does not allow the
`Notifications` permission, the D-Bus service file or the license location
([`docs/PLATFORM.md`](docs/PLATFORM.md)). A C++ launcher is not needed.

## Docs

- [`AGENTS.md`](AGENTS.md) — working instructions: rules, definition of done, layout

- [`docs/PLAN.md`](docs/PLAN.md) — scope, architecture, data model, phases, risks
- [`docs/PLATFORM.md`](docs/PLATFORM.md) — Sailfish OS facts the decisions rest on
- [`docs/DECISIONS.md`](docs/DECISIONS.md) — decision log (append-only)
- [`docs/TODO.md`](docs/TODO.md) — task list per phase, device checklist
- [`docs/BUILD.md`](docs/BUILD.md) — build, test, preview, install on the phone
- [`docs/PUBLISH.md`](docs/PUBLISH.md) — OpenRepos / Storeman release runbook

## Layout

- `python/timerecord/` — `db` (schema/migrations), `store` (all changes + undo log),
  `rules` (breaks, rounding), `calc` (day totals), `backup`, `export` (SPX CSV), `settings` (all tunables), `api` (QML entry points)
- `qml/` — `pages/`, `components/` (`Backend.qml` is the Python bridge), `cover/`
- `rpm/`, `harbour-timerecord.desktop`, `icons/`, `docker/`, `preview/`

## License

GPL-3.0-or-later, see [`LICENSE`](LICENSE).
