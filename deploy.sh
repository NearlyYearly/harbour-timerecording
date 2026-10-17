#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copy the RPM for the spec's version to the phone and install it (docs/BUILD.md).
#
#   ./deploy.sh                   install RPMS/harbour-timerecord-<version>-1.noarch.rpm
#   ./deploy.sh 192.168.1.40      on another address (WLAN); user@host works too
#   ./deploy.sh --build [ip]      build it first (docker compose run --rm build)
#
# Without an address: $PHONE, else USB (defaultuser@192.168.2.15).
#
# Asks for the SSH password once (shared connection) and for the devel-su password.
set -eu

cd "$(dirname "$0")"
PHONE=${PHONE:-defaultuser@192.168.2.15}
build=no

for arg in "$@"; do
    case $arg in
        --build) build=yes ;;
        -*) echo "usage: $0 [--build] [ip | user@host]" >&2; exit 2 ;;
        *@*) PHONE=$arg ;;
        *) PHONE=defaultuser@$arg ;;
    esac
done

if [ "$build" = yes ]; then
    docker compose run --rm build
fi

version=$(sed -n 's/^Version:[[:space:]]*//p' rpm/harbour-timerecord.spec)
release=$(sed -n 's/^Release:[[:space:]]*//p' rpm/harbour-timerecord.spec)
rpm=harbour-timerecord-$version-$release.noarch.rpm
if [ ! -f "RPMS/$rpm" ]; then
    echo "RPMS/$rpm not found; run: $0 --build" >&2
    exit 1
fi

# One SSH connection for copy and install, so the password is asked only once.
control=$(mktemp -d)
trap 'ssh -o ControlPath="$control/c" -O exit "$PHONE" 2>/dev/null || true; rm -rf "$control"' EXIT
ssh_opts="-o ControlMaster=auto -o ControlPath=$control/c -o ControlPersist=60 -o ConnectTimeout=10"

echo "Copying $rpm to $PHONE"
# shellcheck disable=SC2086
scp $ssh_opts "RPMS/$rpm" "$PHONE:"
echo "Installing (devel-su password)"
# shellcheck disable=SC2086
ssh -t $ssh_opts "$PHONE" "devel-su pkcon install-local -y '$rpm' && rm -f '$rpm'"
echo "Installed $rpm"
