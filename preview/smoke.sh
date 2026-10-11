#!/bin/sh
# Headless run of the preview that screenshots every page (see shim Smoke.qml).
set -e
rm -rf /tmp/app /tmp/smokehome && mkdir -p /tmp/app /tmp/smokehome/Documents /shots
cp -r /src/qml /src/python /tmp/app/
find /tmp/app/qml -name '*.qml' -exec sed -i '/EnterKey\./d' {} +
# A made-up Time Recording (Android) backup for the import pages.
python3 -c "import sys; sys.path.insert(0, '/src/tests'); from android_fixture import make_backup; make_backup('/tmp/smokehome/Documents/timerec', gz=True)"
export HOME=/tmp/smokehome QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software
exec qmlscene -I /src/preview/shim /tmp/app/qml/harbour-timerecord.qml --smoke
