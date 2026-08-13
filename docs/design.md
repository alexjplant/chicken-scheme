# Chicken Scheme GitHub Release Builder — Design

## Authoritative source

The official Chicken Scheme core repository is hosted at:

```text
https://code.call-cc.org/git/chicken-core.git
```

All builds check out a specific tag from that repository. No source code is vendored in this repository.

## Tag filter rules

Only stable Chicken 6 releases are built.

- Include tags matching `6.*`.
- Exclude any tag whose name contains `pre`, `rc`, or `bootstrap` (case-insensitive).
- Exclude tags for which a GitHub Release already exists in this repository.

Examples:

- `6.0.0` → included
- `6.1.0` → included
- `6.0.0-pre1` → excluded
- `6.0.0rc1` → excluded
- `6.0.0-bootstrap` → excluded
- `5.3.0`, `7.0.0` → excluded

## Platform matrix

| Runner label          | OS     | Arch   | Asset name example                 |
|-----------------------|--------|--------|-------------------------------------|
| `ubuntu-latest`       | linux  | x64    | `chicken-6.0.0-linux-x64.tar.gz`   |
| `ubuntu-24.04-arm`    | linux  | arm64  | `chicken-6.0.0-linux-arm64.tar.gz` |
| `macos-14`            | macos  | arm64  | `chicken-6.0.0-macos-arm64.tar.gz` |

Each platform is built in its own matrix job and produces a single artifact.

## Bootstrap strategy

Chicken 6 is bootstrapped from the checked-out tag using the upstream `scripts/bootstrap.sh` script. This downloads a development snapshot tarball containing generated C sources, builds a temporary Chicken, and produces a `chicken-boot` binary. The main build then reconfigures to use `chicken-boot` and compiles the full Chicken toolchain.

No external Chicken binary or platform package manager is required.

## Build commands

For each platform:

```bash
git clone --branch "$TAG" https://code.call-cc.org/git/chicken-core.git
sh ./scripts/bootstrap.sh
./configure --chicken ./chicken-boot --prefix /opt/chicken
make
make PREFIX=/opt/chicken DESTDIR="$STAGEDIR" install
```

The authoritative git server does not support shallow clones, so the full repository is cloned. Linux runners install `build-essential`, `git`, and `wget`. macOS runners rely on the pre-installed Xcode command line tools and ensure `wget` is available (the bootstrap script uses it to fetch the snapshot).

Linux runners install `build-essential` explicitly. macOS runners rely on the pre-installed Xcode command line tools.

## Archive layout

The final tarball contains a flat prefix layout:

```text
bin/
  csi
  csc
  chicken
  chicken-install
  chicken-status
  chicken-uninstall
  chicken-profile
  chicken-do
libexec/chicken/bin/
  csi          (real binary)
  csc          (real script)
  chicken      (real binary)
  ...
lib/
  libchicken.*
  chicken/
include/chicken/
share/chicken/
```

`bin/` contains relocatable wrapper scripts. `libexec/chicken/bin/` contains the real binaries and scripts installed by Chicken. This separation lets the wrappers set environment variables before delegating to the real tools.

## Wrapper-script approach

Each wrapper script:

1. Resolves the install root from its own location (`bin/..`).
2. Sets `CHICKEN_PREFIX` to the install root so Chicken finds its libraries, headers, and import libraries.
3. Prepends the install `lib/` directory to the platform library search path (`LD_LIBRARY_PATH` on Linux, `DYLD_LIBRARY_PATH` on macOS).
4. `exec`s the corresponding real binary with all original arguments.

Example wrapper:

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export CHICKEN_PREFIX="$ROOT"
case "$(uname -s)" in
  Darwin) export DYLD_LIBRARY_PATH="$ROOT/lib${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}" ;;
  *)      export LD_LIBRARY_PATH="$ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" ;;
esac
exec "$ROOT/libexec/chicken/bin/$(basename "$0")" "$@"
```

## Asset naming

```text
chicken-{VERSION}-{OS}-{ARCH}.tar.gz
```

`{OS}` is `linux` or `macos`. `{ARCH}` is `x64` or `arm64`. This naming convention matches the tokens that the mise GitHub backend auto-detects.

## Release publishing

After all matrix jobs finish:

1. Download every platform artifact.
2. For each tag, check whether a release exists and already contains all four expected assets.
3. If not, create the release (or reuse the existing one) and upload the missing assets.

This makes the workflow idempotent: re-running it for an already-published tag is a no-op.

## Triggers

- Daily cron at `0 6 * * *` UTC.
- Manual `workflow_dispatch` with an optional tag override.

## mise GitHub backend conventions

mise installs tools from GitHub releases by matching asset names to the current platform. The asset names above use the OS/arch tokens that mise recognizes, and the archives extract into a flat layout with executable files under `bin/`. Wrapper scripts ensure the toolchain works regardless of where mise extracts the archive.
