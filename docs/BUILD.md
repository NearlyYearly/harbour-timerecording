# Building harbour-timerecord

How to test and produce the `harbour-timerecord` RPM. Everything runs through
`docker compose` (D-004); no SDK install, no venv, no sudo.

## Option 1 — container build (default)

```sh
docker compose run --rm build
```

Output: `RPMS/harbour-timerecord-<version>-1.noarch.rpm`.

The service runs the community **Sailfish Platform SDK** image
[`coderus/sailfishos-platform-sdk-aarch64`](https://hub.docker.com/r/coderus/sailfishos-platform-sdk-aarch64/tags)
(tag 5.0.0.43, pinned by digest in `docker-compose.yml`) with `docker/sdk.sh`, which packs
`qml/`, `python/`, `icons/`, `dbus/` and the desktop file and calls `rpmbuild` inside the
`SailfishOS-5.0.0.43-aarch64` target (`sb2`).

Requirements:

- Docker with compose.
- ~6 GB free for the image.

Why the script does odd things: the image's build user `mersdk` has UID 100000, so it cannot
write to the bind-mounted project, and `su`/`sudo` fail inside the image (PAM session errors).
The script therefore runs as **root with `HOME=/home/mersdk`** (so `sb2` finds mersdk's target
config), builds under `/home/mersdk/rpmbuild` (paths outside it are not visible inside `sb2`),
and `chown`s the RPM to your UID/GID at the end.

### Targets

The image has a **5.0.0.43** aarch64 target; images for 5.1.0.11 and 5.2.0.15 exist too
(`TARGET=` in `docker/sdk.sh`). The package is `noarch`, so the target only matters for the
dependency names (D-001).

## Tests

```sh
docker compose run --rm test      # pytest: logic, API, token rule (Python 3.8)
docker compose run --rm qmltest   # QML tests for the preview stand-ins (gestures)
docker compose run --rm smoke     # headless run over every page → preview/shots/*.png
```

The smoke run fills sample data, opens every page, checks the double-tap guard, a reminder
and a notification tap, and logs any QML warning. A clean run prints only `SMOKE …` lines.
`preview/check-smoke.sh` checks a saved log (`docker compose run --rm smoke > smoke.log 2>&1`)
and fails on anything else, or when the run did not finish.

## GitHub Actions and releases

`.github/workflows/ci.yml` (D-027) runs `test`, `qmltest`, `smoke` + `check-smoke.sh` on every
push to `main` and every pull request; the screenshots and the smoke log are kept as the run's
`screenshots` artifact. The RPM is not built on GitHub.

A release is built locally and uploaded:

```sh
./release.sh    # main clean and pushed, tag v<spec version> new; tests, build, asks, then
                # tags, pushes the tag and creates the GitHub Release with the RPM (gh)
```

## Testing on the phone

### One-time: prepare the phone

Without developer mode: **Settings > Untrusted software** → allow. Enough to install the RPM
from the File Browser.

For SSH, in **Settings > Developer tools**:

1. Turn on **Developer mode**.
2. Turn on **Remote connection**.
3. **Set password for SSH and root access** — also the `devel-su` password.

### Connect

- **USB:** choose **Developer mode** in the USB dialog; the phone is at **192.168.2.15**.
- **WLAN:** the IP is shown in Settings > Developer tools.

The user is `defaultuser` on Sailfish OS 5.x.

### Copy, install

```sh
./deploy.sh                  # copies RPMS/<this version>.rpm and installs it over USB
./deploy.sh 192.168.1.40     # another IP (WLAN); user@host works too
./deploy.sh --build [ip]     # build the RPM first
```

It asks for the SSH password once and then the `devel-su` password. By hand:

```sh
scp RPMS/harbour-timerecord-<version>-1.noarch.rpm defaultuser@192.168.2.15:
ssh defaultuser@192.168.2.15 devel-su pkcon install-local -y harbour-timerecord-<version>-1.noarch.rpm
```

`pkcon` pulls the dependencies (PyOtherSide, `python3-sqlite`, Nemo notifications, keepalive,
D-Bus plugins) from the Jolla repositories. Installing a newer RPM keeps the data.

### Logs

```sh
ssh defaultuser@192.168.2.15 "devel-su journalctl -f _COMM=sailfish-qml"
```

Python errors show up there as `python: …` warnings from `Backend.qml`.

### Data on the phone

- Database: `~/.local/share/org.timerecord/harbour-timerecord/timerecord.sqlite`
- Backups: `~/Documents/timerecord-*.json`

## Option 2 — full Sailfish SDK (emulator)

Only needed for the emulator (VirtualBox) or `sfdk deploy`; not used so far. See
[docs.sailfishos.org/Tools/Sailfish_SDK](https://docs.sailfishos.org/Tools/Sailfish_SDK/).

## Test the sandbox

Launched from a terminal, the sandbox is off. On the phone, test the real profile:

```sh
sailjail -p harbour-timerecord.desktop -- /usr/bin/sailfish-qml harbour-timerecord
```
