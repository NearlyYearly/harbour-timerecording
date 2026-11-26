#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copy the app, drop Sailfish-only attached properties the shim cannot provide, run it.
set -e
rm -rf /tmp/app && mkdir -p /tmp/app
cp -r /src/qml /src/python /tmp/app/
find /tmp/app/qml -name '*.qml' -exec sed -i '/EnterKey\./d' {} +
# qsTrId shows its id without a catalogue; the default one carries the English text.
/usr/lib/qt5/bin/lrelease -idbased -silent /src/translations/harbour-timerecord.ts -qm /tmp/app/harbour-timerecord.qm
mkdir -p "$HOME/Documents"
exec qmlscene -translation /tmp/app/harbour-timerecord.qm -I /src/preview/shim /tmp/app/qml/harbour-timerecord.qml
