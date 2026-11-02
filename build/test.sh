#!/usr/bin/env bash
# build/test.sh <prepared source>
#
# Upstream's tests on the prepared source with the pinned Go, in two runs:
#
# 1. upstream's own test command (`go test ./... --race`, no build tags —
#    what upstream's CI runs) over every package;
# 2. the packages the release binary is built from, with the release's
#    build tags — the code that ships, RE2 engine included.
#
# The second run is limited to those packages on purpose: with gore2regex
# upstream's rule generator (cmd/generate/config, the `go generate` program
# that writes config/gitleaks.toml, not part of the binary) does not
# compile — two of its rules build Go's regexp where the tag expects RE2's.

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
. "${HERE}/engine.sh"
. "${HERE}/versions.sh"

cd "$1"
require_pinned_go

echo "::group::upstream's test command"
go test ./... -race
echo "::endgroup::"

PACKAGES="$(go list -tags "${BUILD_TAGS}" -deps -f '{{if and .Module .Module.Main}}{{.ImportPath}}{{end}}' "${MAIN_PACKAGE}")"
echo "::group::the binary's packages with the build tags ${BUILD_TAGS}"
# shellcheck disable=SC2086 # one package path per word
go test -tags "${BUILD_TAGS}" -race ${PACKAGES}
echo "::endgroup::"
