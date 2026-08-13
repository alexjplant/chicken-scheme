# Chicken Scheme GitHub Release Builder

Pre-built, relocatable [Chicken Scheme](https://call-cc.org/) 6 releases for Linux (x64 and arm64) and macOS (arm64), designed to be installed via [mise](https://mise.jdx.dev/).

In the interest of full disclosure this was built with a very non-zero amount of assistance from LLM coding assistants. Every effort was made to make it not suck. If it does then please open an issue or PR to fix.

## Usage

Install with [mise](https://mise.jdx.dev/):

```bash
mise use github:alexjplant/chicken-scheme@latest
```

## What is included

Each release contains the standard Chicken toolchain:

- `csi` — interactive interpreter
- `csc` — compiler driver
- `chicken` — compiler
- `chicken-install`, `chicken-status`, `chicken-uninstall` — egg management
- `chicken-profile`, `chicken-do` — utilities
- runtime libraries, headers, and import libraries

The binaries are installed through wrapper scripts that resolve the install root at runtime and set `CHICKEN_PREFIX` and the platform library search path, so the archives work from any mise install directory.

## How it works

A GitHub Actions workflow runs daily and on demand:

1. Discovers stable `6.*` tags from the authoritative Chicken core repository (`https://code.call-cc.org/git/chicken-core.git`).
2. Builds each tag for linux-x64, linux-arm64, and macos-arm64.
3. Packages the toolchain into relocatable tarballs.
4. Publishes the tarballs as GitHub Release assets.

Chicken 6 removed the `CHICKEN_PREFIX` environment variable, so the build applies a small patch to `egg-environment.scm` that reintroduces it. This lets the wrapper scripts resolve the install root at runtime and point each tool at the bundled libraries, headers, and import files.


## Building manually

```bash
.github/workflows/scripts/package.sh --version 6.0.0 --os linux --arch x64
```
