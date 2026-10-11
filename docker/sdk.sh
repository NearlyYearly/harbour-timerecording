#!/bin/bash
# Build the RPM inside the Sailfish platform SDK image. Runs as root (with the mersdk
# sb2 configuration) so the result can be handed back to the host user.
set -euo pipefail
NAME=harbour-timerecord
TARGET=${TARGET:-SailfishOS-5.0.0.43-aarch64}
export HOME=/home/mersdk

VERSION=$(sed -n 's/^Version: *//p' /src/rpm/$NAME.spec)
TOP=/home/mersdk/rpmbuild
mkdir -p $TOP/SOURCES $TOP/SPECS /src/RPMS
cp /src/rpm/$NAME.spec $TOP/SPECS/
tar -C /src --exclude-vcs --exclude='__pycache__' --transform "s,^,$NAME-$VERSION/," \
    -cjf $TOP/SOURCES/$NAME-$VERSION.tar.bz2 qml python icons dbus $NAME.desktop
sb2 -t "$TARGET" rpmbuild --define "_topdir $TOP" -bb $TOP/SPECS/$NAME.spec
cp $TOP/RPMS/noarch/*.rpm /src/RPMS/
chown -R "${HOST_UID:-1000}:${HOST_GID:-1000}" /src/RPMS
ls -l /src/RPMS
