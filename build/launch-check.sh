#!/bin/sh
# build/launch-check.sh <binary> <version>
#
# The launch check of a release binary, on a machine of its own system and
# architecture: it must report the version of the tag it was built from
# and find a secret — a GitHub token in a plain file — the way Gabion's
# secret checker runs it: a directory scan without git, a JSON report.
# POSIX sh and no tool beyond grep, so it runs in a bare container too.
# The token is assembled here so that no file of this repository carries
# one.

set -eu

BINARY="$1"
VERSION="$2"

REPORTED="$("${BINARY}" version)"
if [ "${REPORTED}" != "${VERSION}" ]; then
  echo "ERROR: the binary reports version '${REPORTED}', the tag is ${VERSION}" >&2
  exit 1
fi
echo "version: ${REPORTED}"

WORK="$(mktemp -d)"
mkdir "${WORK}/project"
printf 'GITHUB_TOKEN=%s%s%s\n' "ghp" "_" "k7Qm2Xv9Rt4Lp8Wzk7Qm2Xv9Rt4Lp8Wzk7Qm" > "${WORK}/project/settings.env"

STATUS=0
"${BINARY}" detect --no-git --source "${WORK}/project" --report-format json \
  --report-path "${WORK}/report.json" --exit-code 7 --no-banner || STATUS=$?
if [ "${STATUS}" -ne 7 ]; then
  echo "ERROR: the scan exited ${STATUS}, a finding exits 7" >&2
  exit 1
fi
if ! grep -q '"RuleID": "github-pat"' "${WORK}/report.json"; then
  echo "ERROR: the report does not name the GitHub token:" >&2
  cat "${WORK}/report.json" >&2
  exit 1
fi
echo "the scan found the GitHub token"
rm -rf "${WORK}"
