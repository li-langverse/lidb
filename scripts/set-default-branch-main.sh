#!/usr/bin/env bash
# WP-H0 helper: set li-langverse/lidb default branch to main (requires gh auth + admin).
set -euo pipefail
REPO="${1:-li-langverse/lidb}"
TARGET="${2:-main}"

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI required" >&2
  exit 1
fi

current="$(gh api "repos/${REPO}" --jq .default_branch)"
echo "current default: ${current}"
if [[ "$current" == "$TARGET" ]]; then
  echo "already ${TARGET}"
  exit 0
fi

gh api "repos/${REPO}" -X PATCH -f "default_branch=${TARGET}"
echo "default branch set to ${TARGET}"
