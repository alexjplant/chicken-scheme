#!/usr/bin/env bash
set -euo pipefail

# Discover stable Chicken 6 tags that do not yet have a GitHub Release in this repo.
# Default output is one tag per line. Use --json to emit a JSON array.

JSON=false
DRY_RUN=false

while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

SOURCE_REPO="https://code.call-cc.org/git/chicken-core.git"

# List all tags from the authoritative source, keeping only annotated/lightweight tag refs.
mapfile -t all_tags < <(
  git ls-remote --tags "$SOURCE_REPO" |
    awk '/refs\/tags\/[^{}]+$/ { sub("refs/tags/", "", $2); print $2 }' |
    sort -V
)

stable_tags=()
for tag in "${all_tags[@]}"; do
  # Include only 6.* tags.
  case "$tag" in
    6.*) ;;
    *) continue ;;
  esac

  # Exclude pre-releases, release candidates, and the bootstrap tag.
  lowered="${tag,,}"
  case "$lowered" in
    *pre*|*rc*|*bootstrap*) continue ;;
  esac

  stable_tags+=("$tag")
done

# Filter out tags that already have a release in the current GitHub repository.
missing_tags=()
for tag in "${stable_tags[@]}"; do
  if ! gh release view "$tag" >/dev/null 2>&1; then
    missing_tags+=("$tag")
  fi
done

if $JSON; then
  printf '%s\n' "${missing_tags[@]}" | jq -R . | jq -s .
elif $DRY_RUN; then
  printf '%s\n' "${missing_tags[@]}"
else
  printf '%s\n' "${missing_tags[@]}"
fi
