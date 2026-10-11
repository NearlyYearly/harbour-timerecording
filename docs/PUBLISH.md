# Publishing — OpenRepos / Storeman

The first public target is **OpenRepos**, installed through **Storeman** or as a plain RPM.
No Harbour/Jolla Store submission: the validator needs a C++ launcher (D-005).

## Versioning

Bump `Version:` in `rpm/harbour-timerecord.spec` for each release (`MAJOR.MINOR.PATCH`,
RPM release `-1`) and update the version in `README.md`. A `%changelog` is still to be added
(`TODO.md`, P6).

## Build

```sh
docker compose run --rm test && docker compose run --rm qmltest && docker compose run --rm smoke
docker compose run --rm build
# -> RPMS/harbour-timerecord-<version>-1.noarch.rpm
```

Sanity check before uploading (inside the SDK image, which has `rpm`):

```sh
docker run --rm -v "$PWD":/s:ro --entrypoint bash \
  coderus/sailfishos-platform-sdk-aarch64:5.0.0.43 -c '
    rpm -qip /s/RPMS/harbour-timerecord-*.rpm     # name, version, licence, summary
    rpm -qlp /s/RPMS/harbour-timerecord-*.rpm     # files
    rpm -qRp /s/RPMS/harbour-timerecord-*.rpm     # dependencies
    desktop-file-validate /s/harbour-timerecord.desktop'
```

## Signing (optional, recommended)

OpenRepos accepts unsigned packages, but Storeman warns about untrusted software. To sign,
create a GPG key and add `%_signature gpg` / `%_gpg_name <key>` to `~/.rpmmacros` in the build
container, then `rpm --addsign RPMS/harbour-timerecord-*.noarch.rpm` and check with `rpm -K`.
Publish the public key (`gpg --armor --export <id>`). Name and email for the key are your
choice; nothing in the build sends them anywhere.

## OpenRepos listing

1. Create a project at <https://openrepos.net>.
2. Package name **harbour-timerecord**; category *Applications* (or *Utilities*).
3. Upload the `.rpm` (noarch).
4. Paste the description below, add screenshots and the changelog.

Screenshots: take them on the phone (P6); `preview/shots/` are from the desktop stand-in and
not suitable for the store.

### Summary

```
Time recording with automatic breaks for Sailfish OS
```

### Description

```
Time Recording keeps track of your working time on Sailfish OS, in the spirit of the
Time Recording app for Android. Everything stays on your phone: no account, no network.

What it does:
- Check in and out with one tap, also from the cover; switch task while checked in.
- Tap a line to edit it, hold to delete, undo and redo every change.
- Automatic breaks by rule (e.g. more than 6 hours → 30 minutes), at an exact time or after
  hours worked, booked as a real check-out and check-in.
- Punch rounding and a guard against accidental double taps.
- Day notes for vacation, sickness, public holidays and comp time.
- Week and month views, flexitime balance, holiday balance, totals per task.
- Day templates for your usual day.
- Reminders: still checked in, target reached, break time, not checked in yet.
- JSON backups, also automatic.

Notes:
- Reminders work while the app runs (also on the cover); closing the app stops them.
- Built with heavy use of AI assistance.
```

## Storeman

Users add the OpenRepos repository in Storeman and install **Time Recording**, or install the
RPM directly (Settings > Untrusted software, then open it in the File Browser).

## Checklist

- [ ] version bumped (spec, README) and changelog updated
- [ ] `test`, `qmltest`, `smoke` green; `build` succeeds
- [ ] license decided, `LICENSE` added (D-023)
- [ ] installed and run through the device checklist (`TODO.md`, P5)
- [ ] (optional) RPM signed and key published
- [ ] OpenRepos project created, RPM + description + screenshots uploaded
