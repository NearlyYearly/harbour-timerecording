# Working instructions — harbour-timerecord

Instructions for anyone (human or AI agent) changing this repository. Follow these
unless a decision in `docs/DECISIONS.md` says otherwise.

## Project facts

- App / package name: `harbour-timerecord` (display name *Time Recording*)
- Stack: Qt 5.6 QML + Sailfish Silica UI + Python 3.8 logic via PyOtherSide (D-002)
- Target: Sailfish OS 5.x (aarch64), built against the 5.0.0.43 target, `noarch` RPM (D-001)
- Data: SQLite in `~/.local/share/org.timerecord/harbour-timerecord/`. Local only.
- Distribution: direct RPM install / OpenRepos (D-005); source on GitHub
- License: GPL-3.0-or-later (D-023)

## Golden rules

1. **Local-first.** Never open a network connection. Do not add the `Internet` sailjail
   permission. No analytics, crash reporting or remote config.
2. **Every change is undoable.** All data writes go through `Store` so they land in the undo
   log (D-006). Never write to the database from `api.py` or QML directly.
3. **Tunables are settings.** Thresholds, rates, intervals and lead times live in
   `settings.DEFAULTS` and are editable in the Settings pages — never hardcoded (D-021).
4. **Schema changes need a decision + migration.** Append to `db.MIGRATIONS` and to
   `docs/DECISIONS.md`; never edit a shipped migration.
5. **UI uses platform tokens.** Silica components and `Theme.*` values only — no hardcoded
   colors, sizes or fonts (D-016).
   - Colors: `Theme.primaryColor`, `secondaryColor`, `highlightColor`,
     `secondaryHighlightColor`, `highlightBackgroundColor`, `errorColor`; tints via
     `Theme.rgba(color, Theme.opacity*)`. Running / positive → `highlightColor`,
     negative / warning → `errorColor`.
   - Opacity: `Theme.opacityFaint`, `opacityLow`, `opacityHigh`, `opacityOverlay`,
     `highlightBackgroundOpacity` (plain `0` / `1` for hidden / shown are fine).
   - Sizes: `Theme.padding*`, `itemSize*`, `iconSize*`, `fontSize*`, `horizontalPageMargin`,
     `buttonWidth*`. Ratios that split space (`width / 4`) are layout, not sizes.
   - Prefer Silica components (`Notices`, `ColorPickerDialog`, `ValueButton`, …) over custom ones.
   - Exception: task and day-type colors are user data (stored in the database), not UI style.
   - Enforced by `tests/test_qml_tokens.py`; the preview stand-ins in `preview/shim` are exempt.
6. **All user-visible text is translatable** via `qsTr()`.
7. **Qt 5.6 only.** Old `Connections { onFoo: }` syntax, no `topPadding`, no ES6
   (`let`, `const`, arrow functions).
8. **PyOtherSide cannot pass JS `null`.** Send `-1` / `""` for "none" (`Backend.optId`,
   `api._opt`); JS numbers arrive as floats (`api._clean`) (D-019).
9. **Use allowed APIs.** If a module, permission or package is not in `docs/PLATFORM.md`,
   record a decision before adding it.

## Definition of done (per change)

- [ ] `docker compose run --rm test` green (logic, API, token rule)
- [ ] `docker compose run --rm qmltest` green if `preview/shim` changed
- [ ] `docker compose run --rm smoke` prints only `SMOKE …` lines (no QML warnings)
- [ ] `docker compose run --rm build` produces the RPM
- [ ] New logic has a unit test in `tests/`
- [ ] Strings wrapped for translation
- [ ] No new permission, package or dependency without a `docs/DECISIONS.md` entry;
      dependencies pinned (`requirements.in` → `requirements.txt` with hashes, images by digest)
- [ ] `docs/TODO.md` and/or `docs/DECISIONS.md` updated if scope changed
- [ ] No data loss on app update; backup and restore still work

## Repo layout

```
python/timerecord/           # logic: db, store (writes + undo), rules, calc, reminders,
                             #        backup, android (import), settings, api (PyOtherSide)
qml/                         # QML: harbour-timerecord.qml, pages/, components/, cover/
  components/Backend.qml     # the only bridge to Python
tests/                       # pytest, incl. the QML token rule
preview/                     # desktop preview: shim/ (Silica + Nemo stand-ins), tests/, smoke
dbus/                        # D-Bus service file (notification tap starts the app)
docker/                      # Dockerfiles and the SDK build script
rpm/                         # .spec
icons/                       # launcher icons (rendered from the SVG)
harbour-timerecord.desktop   # launcher + [X-Sailjail] permissions
deploy.sh                    # copy + install the RPM on the phone (run by the phone's owner)
docs/                        # plan, todo, decisions, platform notes, build, publish
```

## Build & run

Everything runs in containers (D-004). Details and phone setup are in
[`docs/BUILD.md`](docs/BUILD.md).

```sh
docker compose run --rm test      # pytest (Python 3.8, like SFOS 5)
docker compose run --rm qmltest   # QML tests for the preview stand-ins
docker compose run --rm smoke     # headless run over every page -> preview/shots/
docker compose run --rm preview   # run the app on the desktop (Wayland)
docker compose run --rm icons     # render icons from icons/harbour-timerecord.svg
docker compose run --rm build     # -> RPMS/harbour-timerecord-<ver>-1.noarch.rpm
```

Install on the phone (hand these to the phone's owner; do not run against a device yourself):

```sh
./deploy.sh [--build] [ip]  # copy + install the spec's version (default IP: USB)
scp RPMS/harbour-timerecord-<ver>-1.noarch.rpm defaultuser@192.168.2.15:
ssh defaultuser@192.168.2.15 devel-su pkcon install-local -y harbour-timerecord-<ver>-1.noarch.rpm
```

Sandboxing is **off** when launched from a terminal. To test real permissions on the phone:

```sh
sailjail -p harbour-timerecord.desktop -- /usr/bin/sailfish-qml harbour-timerecord
```

## Conventions

- Logic in `python/timerecord/`, UI in `qml/`, tests in `tests/`.
- QML calls Python only through `Backend.run()` (reads) and `Backend.mutate()` (writes,
  refreshes status and emits `dataChanged()`).
- An accepted or cancelled dialog is destroyed right away, before an async callback returns.
  A callback started from `onAccepted` must not use the dialog's ids or properties: copy
  `backend` and any text into local variables first (see `ImportDialog.qml`).
- Python stays stdlib-only and Python 3.8 compatible.
- Times are local ISO strings at minute resolution; a line belongs to its check-in day.
- Versioning: `MAJOR.MINOR.PATCH`, RPM release `-1`; bump the spec and the README together.
- License GPL-3.0-or-later (D-023): new source files start with
  `SPDX-License-Identifier: GPL-3.0-or-later` (after a shebang or `.pragma library`).
- Commit messages: `area: short summary`
  (e.g. `breaks: merge touching parts`).

## Where things go

| You have... | Put it in... |
|-------------|--------------|
| A new or reversed decision | `docs/DECISIONS.md` |
| A task to do | `docs/TODO.md` |
| A platform fact / API behaviour | `docs/PLATFORM.md` |
| A scope change | `docs/PLAN.md` |
| A new tunable | `settings.DEFAULTS` + a Settings page |

## Do not

- Add dependencies for a few lines of code.
- Add networking, analytics or crash reporting.
- Store data outside the app's sandboxed directory (backups go to `~/Documents`).
- Delete tasks or day types — archive them (D-018).
- Probe or install on a phone yourself; hand over the command.

## Escalation points

- **Closed-app reminders** — reminders only run while the app runs (D-014). Reliable
  closed-app reminders need `timed` (`Nemo.Alarms`, entries show in the Clock app): decide
  first (Q3).
- **Notification tap / sandbox** — the bus name must stay `<OrganizationName>.<ApplicationName>`
  (D-015); changing identifiers breaks data paths and updates (D-022).
- **Harbour validation** — needs a C++ launcher binary and fewer `Requires` (D-005).
- **Android import** — the mapping was checked against a real backup (D-025). Never commit
  a real backup or data from it; tests use `tests/android_fixture.py`.
