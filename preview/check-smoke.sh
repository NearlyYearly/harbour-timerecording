#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Check a smoke log (docker compose run --rm smoke > log 2>&1): it must finish and print
# nothing but the expected lines, so any QML warning or Python error fails.
#   preview/check-smoke.sh smoke.log
set -eu
log=${1:?usage: $0 smoke.log}

if ! grep -q '^qml: SMOKE done$' "$log"; then
    echo "smoke run did not finish" >&2
    exit 1
fi

# Expected: SMOKE lines, what the preview stand-ins print instead of the real
# notices/notifications/D-Bus, Qt's note about the runtime dir, and compose's own lines.
unexpected=$(grep -v -E \
    -e '^qml: (SMOKE|NOTICE|NOTIFICATION|DBUS) ' \
    -e "^QStandardPaths: XDG_RUNTIME_DIR not set" \
    -e '^ ?Container .* (Creating|Created|Starting|Started|Stopping|Stopped|Removing|Removed) *$' \
    -e '^$' "$log" || true)
if [ -n "$unexpected" ]; then
    echo "unexpected output in the smoke run:" >&2
    echo "$unexpected" >&2
    exit 1
fi
echo "smoke ok: $(grep -c '^qml: SMOKE' "$log") SMOKE lines"
