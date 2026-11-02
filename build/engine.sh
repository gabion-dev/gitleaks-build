# build/engine.sh
#
# What this repository builds, sourced by every script in build/. The
# values are upstream's own release recipe (.goreleaser.yml at the tag):
# a release binary built here differs from upstream's only in the Go
# release it is built with and in the modules of build/module-upgrades.txt.

# The repository whose release tags are built.
UPSTREAM="gitleaks/gitleaks"

# The release binary and its main package, relative to the source root.
BINARY="gitleaks"
MAIN_PACKAGE="."

# gore2regex selects the RE2 engine (go-re2 over wazero) instead of Go's
# regexp — what upstream's release binaries run.
BUILD_TAGS="gore2regex"

# The ldflags of upstream's release; the version is the tag without its "v".
ldflags() {
  echo "-s -w -X=github.com/zricethezav/gitleaks/v8/version.Version=$1"
}
