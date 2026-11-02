#!/usr/bin/env bash
# build/build.sh <prepared source> <upstream tag> <output directory>
#
# Builds the release binary for every platform of a release from the
# source build/prepare-source.sh left, and packs each one as upstream's
# release does: gitleaks_<version>_<os>_<x64|arm64>.tar.gz holding the
# binary, upstream's LICENSE and README.md — the names Gabion's installer
# downloads. Every archive gets a .sha256 file; the module files the
# binaries were built from go beside them.
#
# Go cross-compiles a program without cgo, so the four binaries come from
# one machine and one toolchain. Each is checked before it is packed: it
# names the pinned Go, the tag's commit and the release's build tags, and
# a Linux binary is static (no program interpreter), so it needs nothing
# from the host. The archives are byte-for-byte reproducible from the
# same source and Go: sorted entries, fixed owners, the commit's time
# (GNU tar and coreutils — the script runs on Linux).

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
. "${HERE}/engine.sh"
. "${HERE}/versions.sh"

SOURCE="$(cd "$1" && pwd)"
TAG="$2"
OUT="$(mkdir -p "$3" && cd "$3" && pwd)"
VERSION="${TAG#v}"

require_pinned_go
COMMIT="$(git -C "${SOURCE}" rev-parse HEAD)"
COMMIT_TIME="$(git -C "${SOURCE}" log -1 --format=%ct)"

for target in linux/amd64 linux/arm64 darwin/amd64 darwin/arm64; do
  goos="${target%/*}"
  goarch="${target#*/}"
  arch="${goarch}"
  [ "${goarch}" = "amd64" ] && arch="x64"
  archive="${BINARY}_${VERSION}_${goos}_${arch}.tar.gz"
  work="$(mktemp -d)"

  CGO_ENABLED=0 GOOS="${goos}" GOARCH="${goarch}" go build -C "${SOURCE}" \
    -trimpath -tags "${BUILD_TAGS}" -ldflags "$(ldflags "${VERSION}")" -o "${work}/${BINARY}" "${MAIN_PACKAGE}"

  info="$(go version -m "${work}/${BINARY}")"
  grep -q "^${work}/${BINARY}: go${GO_VERSION}\$" <<<"${info}" \
    || { echo "ERROR: ${target}: not built with go${GO_VERSION}" >&2; exit 1; }
  grep -qxF "$(printf '\tbuild\tvcs.revision=%s' "${COMMIT}")" <<<"${info}" \
    || { echo "ERROR: ${target}: does not record the tag's commit ${COMMIT}" >&2; exit 1; }
  grep -qxF "$(printf '\tbuild\t-tags=%s' "${BUILD_TAGS}")" <<<"${info}" \
    || { echo "ERROR: ${target}: not built with the tags ${BUILD_TAGS}" >&2; exit 1; }
  if [ "${goos}" = "linux" ] && readelf -l "${work}/${BINARY}" | grep -q 'INTERP'; then
    echo "ERROR: ${target}: the binary asks for a program interpreter — it is not static" >&2
    exit 1
  fi

  cp "${SOURCE}/LICENSE" "${SOURCE}/README.md" "${work}/"
  chmod 0755 "${work}/${BINARY}"
  chmod 0644 "${work}/LICENSE" "${work}/README.md"
  tar --sort=name --owner=0 --group=0 --numeric-owner --mtime="@${COMMIT_TIME}" \
    -C "${work}" -cf - LICENSE README.md "${BINARY}" | gzip -n > "${OUT}/${archive}"
  (cd "${OUT}" && sha256sum "${archive}" > "${archive}.sha256")
  rm -rf "${work}"
  echo "${target}: $(cat "${OUT}/${archive}.sha256")"
done

cp "${SOURCE}/go.mod" "${SOURCE}/go.sum" "${OUT}/"
