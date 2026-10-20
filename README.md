# harbour-timerecord

Time recording for SailfishOS (Silica UI, Python logic via PyOtherSide), modelled on
*Time Recording* for Android: check in/out, tasks, day notes, automatic break rules,
punch rounding, undo/redo, week/month views, flexitime and vacation per year, day
templates and JSON backups.

> **Note:** This app was coded and created entirely with AI. Its functionality has been
> tested. Feedback, issues and pull requests are greatly appreciated.

Automatic breaks (Settings → Break rules), three modes:
- **Check out & in** (default): on check-out, a missing break becomes a real check-out at the
  break start and check-in at its end. Each rule can have its own exact time
  (e.g. > 6:00 → 30 min at 12:00, > 9:00 → 45 min at 15:00); otherwise the general placement
  applies (after hours worked, or an exact time). While checked in the break shows as planned.
  If a break would end exactly at the check-out, it is stored as a break line instead.
- **Show break line**: computed break shown in the list, lines untouched.
- **Deduct only**: subtracted from the total.

Several days at once (day page push-up menu at the bottom → *Edit several days*): a week is preselected, *From*/*To*
change the range and « » move it by its length. The working days are ticked; set or clear a
day note on all of them or add a template, each as one undo step.

Day page menus: the pulley (top) holds the actions for the shown day: *Set day type* (one tap
per type, keeps the note text), day note, add line, and today *Check in at… / Check out at…*
for a forgotten punch (exact time, no rounding). The push-up menu (bottom) opens *Edit several
days*, *Vacation* and *Flexitime*.

The day page opens on today, also when the running app comes to the front. Left open past
midnight, it moves on to the new day unless you are checked in or looking at another day.

A check-in/out within *n* seconds of the previous one is ignored (Settings → Backup & general).

While checked in, planned breaks assume the day lasts until the target is reached, so a
12:00 break shows (and is announced) from the morning on; totals only deduct what is due.

Reminders (Settings → Reminders): still checked in after *n* hours, target reached, automatic
break starts, not checked in by a time. They run while the app is open, also in the
background/on the cover with the display off (Nemo.KeepAlive); closing the app stops them.
Tapping a notification opens the app (D-Bus name `org.timerecord.harbour-timerecord`,
started via `dbus/org.timerecord.harbour-timerecord.service` when not running).

Import from Android (Settings → Import from Android): copy the *Time Recording* backup
`timerec.db.gz` to `~/Documents`, pick it, check the preview, import. Tasks, lines, day notes,
templates, vacation per year and (optionally) targets, break rules and the flexitime
carryover come over;
days that already have lines here are left alone. One undo step removes the import again.
Tasks keep Android's rules (Settings → Tasks): share that counts as work (on call = 0 %),
no target (public holiday) and uses vacation.

SPX export (push-up menu → SPX export): one month, or several, as a CSV for the ESS
Monatsjournal filler, `~/Documents/timerecord-spx-<YYYY-MM>.csv`:

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

Vacation (day page push-up menu → Vacation): one entry per year with its own days and carryover;
add past years, see the days taken and planned per year. A year without an entry gets the
days of the latest earlier year. Days come from day types and tasks that use vacation.

Cover: state and task, worked vs. target with a progress bar, day ± and flexitime, next break;
actions check in/out and next task (switches task when checked in).

Everything runs in containers:

| Command | What it does |
|---|---|
| `docker compose run --rm test` | pytest for the Python logic (Python 3.8, like SFOS 5) |
| `docker compose run --rm preview` | runs the app on the desktop (Wayland); data in `preview/home` |
| `docker compose run --rm smoke` | headless run, screenshots of every page into `preview/shots` |
| `docker compose run --rm qmltest` | QML tests for the preview stand-ins (pulley, push-up menu, swipe gestures) |
| `docker compose run --rm icons` | renders `icons/*/harbour-timerecord.png` from the SVG |
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
    scp RPMS/harbour-timerecord-0.8.3-1.noarch.rpm defaultuser@<phone-ip>:
    ssh defaultuser@<phone-ip> devel-su pkcon install-local -y harbour-timerecord-0.8.3-1.noarch.rpm

Data: `~/.local/share/org.timerecord/harbour-timerecord/timerecord.sqlite`.
Backups (manual and automatic): `~/Documents/timerecord-*.json`.

The package starts through `sailfish-qml`, so it installs fine by hand or from
OpenRepos/Chum. Harbour (the Jolla Store) would additionally need a small C++ launcher binary.

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
