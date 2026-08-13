#!/usr/bin/env bash
set -euo pipefail

# Package a built Chicken install tree into a relocatable tarball.
#
# Usage:
#   package.sh --version 6.0.0 --os linux --arch x64

VERSION=""
OS=""
ARCH=""

while [ $# -gt 0 ]; do
  case "$1" in
    --version) VERSION="$2"; shift 2 ;;
    --os) OS="$2"; shift 2 ;;
    --arch) ARCH="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

: "${VERSION:?--version is required}"
: "${OS:?--os is required}"
: "${ARCH:?--arch is required}"

PREFIX="/opt/chicken"
STAGEDIR=$(mktemp -d)
trap 'rm -rf "$STAGEDIR"' EXIT

echo "Installing Chicken into staging directory..."
make PREFIX="$PREFIX" DESTDIR="$STAGEDIR" install

BINDIR="$STAGEDIR$PREFIX/bin"
REALDIR="$STAGEDIR$PREFIX/libexec/chicken/bin"

mkdir -p "$REALDIR"

# Move every executable from bin/ into libexec/chicken/bin/. Non-executables
# (e.g. READMEs accidentally dropped into bin) are left alone and will still be
# included in the archive.
for item in "$BINDIR"/*; do
  [ -e "$item" ] || continue
  [ -x "$item" ] || continue
  [ -f "$item" ] || continue
  mv "$item" "$REALDIR/"
done

# Create wrapper scripts in bin/ that point back to the real binaries.
for real in "$REALDIR"/*; do
  [ -e "$real" ] || continue
  name=$(basename "$real")
  wrapper="$BINDIR/$name"

  cat > "$wrapper" <<'WRAPPER'
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export CHICKEN_PREFIX="$ROOT"
case "$(uname -s)" in
  Darwin)
    export DYLD_LIBRARY_PATH="$ROOT/lib${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"
    ;;
  *)
    export LD_LIBRARY_PATH="$ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    ;;
esac
exec "$ROOT/libexec/chicken/bin/$(basename "$0")" "$@"
WRAPPER

  chmod +x "$wrapper"
done

# Build the final relocatable tarball with a flat prefix layout.
mkdir -p dist
tarball="dist/chicken-${VERSION}-${OS}-${ARCH}.tar.gz"

tar -czf "$tarball" -C "$STAGEDIR$PREFIX" \
  bin libexec lib include share

echo "Created $tarball"
ls -lh "$tarball"
