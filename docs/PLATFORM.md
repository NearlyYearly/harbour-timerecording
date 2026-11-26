# Platform notes — Sailfish OS (researched 2026-10-09 … 2026-10-11)

Facts behind the decisions in `DECISIONS.md`. Most were checked directly in the SDK target
image `coderus/sailfishos-platform-sdk-aarch64:5.0.0.43` (paths below are inside its
`/srv/mer/targets/SailfishOS-5.0.0.43-aarch64`). Update when the platform changes.

## OS versions & devices

- Target: Sailfish OS **5.x on aarch64** (Xperia 10 III/IV/V, Jolla C2, Jolla Phone).
- The community SDK image offers targets **5.0.0.43**, **5.1.0.11**, **5.2.0.15**. We build
  against **5.0.0.43**; the package is `noarch` QML + Python, so it does not depend on the
  release it was built against (D-001).

## App framework

- UI: **Qt 5.6 + QML + Sailfish Silica** (`sailfishsilica-qt5` 1.2.140 in the 5.0 target).
  Qt 5.6 means: old `Connections { onFoo: }` syntax, no `topPadding`, no ES6.
- Python: **3.8.18** (`python3-base`). The `sqlite3` module is a **separate package**,
  `python3-sqlite` (it also provides `python3dist(sqlite3)`).
- Bridge: **PyOtherSide 1.5.9** (`pyotherside-qml-plugin-python3-qt5`), import
  `io.thp.pyotherside 1.5`. It **cannot convert JS `null`** to Python (`Cannot convert:
  QVariant(std::nullptr_t)`) and passes JS numbers as floats (D-019).
- Launch: `sailfish-qml harbour-timerecord` loads
  `/usr/share/harbour-timerecord/qml/harbour-timerecord.qml` (`libsailfishapp-launcher`).

## Silica tokens & components (used by the UI rule, D-016)

From `usr/lib64/qt5/qml/Sailfish/Silica/plugins.qmltypes`:

- `Theme`: `primaryColor`, `secondaryColor`, `highlightColor`, `secondaryHighlightColor`,
  `highlightBackgroundColor`, `highlightDimmerColor`, `overlayBackgroundColor`, **`errorColor`**,
  `highlightBackgroundOpacity`, `opacityFaint` / `opacityLow` / `opacityHigh` /
  `opacityOverlay`, `rgba(color, alpha)`, `padding*`, `horizontalPageMargin`, `itemSize*`,
  `iconSize*`, `fontSize*`, `fontFamily`, `fontFamilyHeading`, `buttonWidth*`, `pixelRatio`.
- Components used: `Notices` (singleton, `show(text, duration, anchor)`) with `Notice.Short`
  / `Notice.Long` and `Notice.Top`…; `ColorPickerDialog` (`color`, `colors`);
  `DatePickerDialog`, `TimePickerDialog`, `RemorsePopup`, `ListItem.remorseAction`,
  `DetailItem` (`label`, `value`), …

## Translations

- `libsailfishapp` (used by `sailfish-qml`) installs a `QTranslator` that loads
  `/usr/share/<app>/translations/<app>-<locale>.qm` and falls back to `<app>.qm`; read from
  the library's strings in the 5.0.0.43 target, and sailfish-rag confirms `sailfishapp_i18n`
  catalogues working with `sailfish-qml` on devices.
- `lupdate` / `lrelease` are in the target (`qt5-qttools-linguist`, Qt 5.6.3). `lupdate`
  reads `//% "text"` before a `qsTrId` call and `/*% "text" */` inline, also with a `%n`
  plural (`qsTrId(id, n)`). `lrelease -idbased` without `-nounfinished` puts the `//%`
  text into the `.qm` for untranslated entries; with `-nounfinished` the app shows raw ids.
  A `//%` line before `Item { a: x; text: qsTrId(…) }` is discarded (the comment belongs to
  the first binding), so such lines use the inline form.

## Sandboxing (Sailjail)

- Declared in the desktop file:

  ```ini
  [X-Sailjail]
  OrganizationName=org.timerecord
  ApplicationName=harbour-timerecord
  Permissions=Documents;Notifications
  ```

- Data lives in `~/.local/share/<OrganizationName>/<ApplicationName>`.
- `Documents` → `~/Documents` (backups).
- **`Notifications`** is its own permission (`etc/sailjail/permissions/Notifications.permission`:
  `dbus-user.talk org.freedesktop.Notifications`); without it notifications are blocked.
- Owning a D-Bus name: the `sailjail` binary contains `--dbus-user.own=%s.%s`, i.e. an app may
  own **`<OrganizationName>.<ApplicationName>`** → `org.timerecord.harbour-timerecord`.
- `sailjail` also knows an `ExecDBus` desktop key, but `desktop-file-validate` rejects it
  (non-standard key without `X-`), so we do not use it (D-015).

## Background work & notifications

- `Nemo.KeepAlive 1.2` → `BackgroundJob` (`libkeepalive`): `enabled`, `frequency`
  (enum in seconds: `ThirtySeconds` = 30, `TwoAndHalfMinutes` = 150, `FiveMinutes` = 300,
  `TenMinutes` = 600 …), `triggeredOnEnable`, `triggered()`, must call `finished()`.
  Wakes the device while the **app is running** (also in the background, display off).
- `Nemo.Notifications 1.0` (`nemo-qml-plugin-notifications-qt5`) → `Notification`:
  `summary`, `body`, `previewSummary`, `previewBody`, `appName`, `appIcon`,
  `remoteActions`, `isTransient`, `publish()`.
- A closed app runs nothing. Reliable reminders with the app closed would need `timed`
  (e.g. `Nemo.Alarms`, alarms then show in the Clock app). Not used yet (D-014).

## Notification tap → app

- A tap runs the notification's `default` remote action: a D-Bus call
  (`service`, `path`, `iface`, `method`).
- Receiver: `Nemo.DBus 2.0` → `DBusAdaptor` (`service`, `path`, `iface`, `xml`;
  `nemo-qml-plugin-dbus-qt5`), QML functions named like the methods are called.
- Start when closed: a D-Bus service file. System apps use
  `invoker --type=silica-qt5 --desktop-file=<app>.desktop -s …`; `invoker --help` documents
  `-F/--desktop-file` and `-I/--id` ("sandboxing id"). Ours:
  `Exec=/usr/bin/invoker --type=silica-qt5 --desktop-file=harbour-timerecord.desktop
  --id=harbour-timerecord -s /usr/bin/sailfish-qml harbour-timerecord`.

## Packaging & Harbour

- `rpmbuild` inside the target (`sb2`), `BuildArch: noarch`.
- `rpmvalidation -t SailfishOS-5.0.0.43-aarch64` (Harbour suite), re-run 2026-11-26 on
  0.8.4, fails on:
  - `Exec=/usr/bin/sailfish-qml harbour-timerecord`: the validator does not recognise the
    launcher with a path, so it asks for `Exec=harbour-timerecord`, an ELF binary
    `/usr/bin/harbour-timerecord`, and rejects `Requires: libsailfishapp-launcher`.
  - `X-Sailjail` permission **`Notifications`**: not in the validator's
    `allowed_permissions.conf` (Audio Bluetooth Camera Internet Location MediaIndexing
    Microphone NFC RemovableMedia UserDirs WebView Documents Downloads Music Pictures
    PublicDir Videos Compatibility Secrets Contacts Accounts).
  - the D-Bus service file in `/usr/share/dbus-1/services/` (D-015) and the license in
    `/usr/share/licenses/`: "Installation not allowed in this location".
- The same build with **`Exec=sailfish-qml harbour-timerecord`** (no path) is reported as
  "Application is a QML-only app (sailfish-qml launcher)", and the binary, `Exec` and
  `Requires` errors are gone: Harbour does **not** need a C++ launcher. PyOtherSide, the
  Python modules and all current `Requires` pass. What is left for Harbour is the
  `Notifications` permission, the D-Bus service file and the license location.
  (Checked in a scratch build only; the shipped desktop file still has the path.)

## Desktop preview

- Silica is closed-source and exists only on the device and in the SDK emulator (VirtualBox).
- The preview runs the real QML and Python on Debian bookworm's Qt 5.15 with a stand-in
  `Sailfish.Silica` / `Nemo.*` in `preview/shim` (D-017). Debian packages come from a fixed
  `snapshot.debian.org` date.
- Qt 5.15 specifics found while building it: `TestCase` needs `qmltestrunner`
  (`qtdeclarative5-dev-tools`); a `DragHandler` on an overlay swallows taps, on the parent it
  does not; a hidden parent makes children report `visible: false`; `Flickable.DragOverBounds`
  moves the content at about half the finger speed.
