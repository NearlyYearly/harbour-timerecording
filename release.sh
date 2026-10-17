#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Release the spec's version: test and build locally, then tag and upload the RPM as a
# GitHub Release (D-027). Needs a clean main that is already pushed, and a logged-in `gh`.
#
#   ./release.sh            asks before tagging and uploading
set -eu

cd "$(dirname "$0")"
NAME=harbour-timerecord

version=$(sed -n 's/^Version:[[:space:]]*//p' rpm/$NAME.spec)
release=$(sed -n 's/^Release:[[:space:]]*//p' rpm/$NAME.spec)
tag=v$version
rpm=RPMS/$NAME-$version-$release.noarch.rpm

fail() { echo "release: $*" >&2; exit 1; }

# The tag must point at a commit that is on GitHub, with nothing left out.
[ "$(git rev-parse --abbrev-ref HEAD)" = main ] || fail "not on main"
[ -z "$(git status --porcelain)" ] || fail "uncommitted changes"
git fetch --quiet origin main --tags
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || fail "main differs from origin/main: push (or pull) first"
if git rev-parse -q --verify "refs/tags/$tag" >/dev/null || git ls-remote --exit-code --tags origin "refs/tags/$tag" >/dev/null; then
    fail "$tag already exists: bump Version in rpm/$NAME.spec and README.md"
fi
grep -q "$NAME-$version-$release.noarch.rpm" README.md || fail "README.md does not mention $version"
gh auth status >/dev/null 2>&1 || fail "gh is not logged in (gh auth login)"

# Docker never reads the terminal, so the answer below is the only input.
echo "== tests"
docker compose run --rm test </dev/null
docker compose run --rm qmltest </dev/null
mkdir -p preview/shots
log=$(mktemp)
trap 'rm -f "$log"' EXIT
docker compose build smoke </dev/null >/dev/null
docker compose run --rm smoke </dev/null >"$log" 2>&1 || { cat "$log"; fail "smoke run failed"; }
preview/check-smoke.sh "$log"

echo "== build"
rm -f "$rpm"
docker compose run --rm build </dev/null
[ -f "$rpm" ] || fail "$rpm was not built"

echo
echo "Ready: $rpm"
echo "This creates the tag $tag on $(git rev-parse --short HEAD), pushes it and publishes a GitHub Release."
printf "Publish? [y/N] "
read -r answer || answer=""
[ "$answer" = y ] || [ "$answer" = Y ] || fail "cancelled; nothing tagged or uploaded"

git tag -a "$tag" -m "$version"
git push origin "$tag"
gh release create "$tag" "$rpm" --verify-tag --title "$version" --generate-notes
