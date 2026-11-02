# gitleaks-build (Linux and macOS, amd64 / arm64)

[gitleaks](https://github.com/gitleaks/gitleaks) rebuilt from its own release
tags with a supported Go release, for the secret checker of the
[Gabion](https://github.com/gabion-dev) framework. Gabion downloads these
archives itself; the archives do not need Gabion.

This project is not affiliated with, endorsed by, or sponsored by the gitleaks
authors.

## Why a rebuild

A Go program carries the standard library of the Go release it was built
with. Upstream's v8.30.1 binaries were built with Go 1.24.11, a Go line that
no longer receives security fixes, and with a version of
`github.com/ulikunitz/xz` that has a known vulnerability; govulncheck finds
vulnerable functions of both called by that build. Rebuilt from the same tag
with the Go of [`build/versions.sh`](build/versions.sh) and the module of
[`build/module-upgrades.txt`](build/module-upgrades.txt), it calls none.

The rest is upstream's release recipe (`.goreleaser.yml` at the tag): the
linker flags and the version string, the build tags (`gore2regex` — the RE2
engine upstream's binaries run), no cgo, the archive names and their
contents. Two differences, both about what the binary records of its build:
`-trimpath` leaves out the paths of the build machine, and the main package
is built as a package rather than as the file `main.go`, so the binary
records the commit of the tag (`go version -m`). The language version of the
tag's `go.mod` stays, and with it the runtime defaults upstream's code was
written for.

## Releases

A release tag is `<upstream tag>-r<revision>`, for example `v8.30.1-r1`:
gitleaks v8.30.1, revision 1 of this recipe for it. A new Go release or a new
module upgrade for the same upstream tag is a new revision; a published
revision is never rebuilt.

Each release has four archives, each with a `.sha256` file next to it:

- `gitleaks_<version>_linux_x64.tar.gz` — Linux x64, static
- `gitleaks_<version>_linux_arm64.tar.gz` — Linux ARM64, static
- `gitleaks_<version>_darwin_x64.tar.gz` — macOS 13+, Intel
- `gitleaks_<version>_darwin_arm64.tar.gz` — macOS 13+, Apple Silicon

An archive holds `gitleaks`, upstream's `LICENSE` and `README.md`, as
upstream's archives do. `go.mod` and `go.sum` next to them are the module
files every binary was built from: the upstream tag with these two files is
the source of the release. The archives carry a build provenance
attestation:

```sh
gh attestation verify gitleaks_8.30.1_linux_x64.tar.gz --repo gabion-dev/gitleaks-build
```

## How a release is made

The workflow [Build gitleaks](.github/workflows/build.yml) runs by hand from
the Actions tab with the upstream tag and the revision. The scripts in
[`build/`](build/) do the work, in the workflow and on a developer machine
alike:

1. `prepare-source.sh` clones the upstream tag, raises the modules of
   `module-upgrades.txt` and tidies the module files;
2. `vulnerability-gate.sh` runs govulncheck over the release binary's main
   package for linux and darwin and stops the release when any bulletin's
   vulnerable function is called — naming the bulletin, the module and the
   version that fixes it;
3. `build.sh` builds the four binaries without cgo on one Linux machine,
   checks that each names the pinned Go, the tag's commit and the build
   tags, and that the Linux ones are static, then packs reproducible
   archives;
4. `test.sh` runs upstream's tests on the same source, on Ubuntu 24.04 and
   macOS 15: upstream's own test command over every package, then the
   packages the binary is built from with the release's build tags, both
   with the race detector;
5. `launch-check.sh` starts every binary on a machine of its own system and
   architecture: it must report the tag's version and find a planted secret
   in a directory scan. Linux x64 and ARM64 run on the runner and in clean
   Ubuntu 22.04, Debian 13, Fedora and Alpine containers; macOS on 15 and 26,
   Apple Silicon and Intel.

Only then is the release published.

## Source and license

gitleaks is MIT-licensed; its license text is inside every archive. The
scripts and workflow of this repository are under the [MIT License](LICENSE)
as well.
