#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/home"

output="$(
  DOTFILES_FORCE_FALLBACK_DRY_RUN=1 \
  HOME="$tmpdir/home" \
  PATH="/usr/bin:/bin" \
  "$repo_root/install/bootstrap.sh" --dry-run \
    2>&1
)"

for expected in \
  "DRY-RUN: install uv into" \
  "DRY-RUN: install task into" \
  "DRY-RUN: install micromamba into" \
  "DRY-RUN: install k3d into" \
  "DRY-RUN: mkdir -p" \
  "DRY-RUN: npm install -g @openai/codex" \
  "DRY-RUN: generate task bash completion at" \
  "DRY-RUN: generate k3d bash completion at" \
  "uv" \
  "task" \
  "micromamba" \
  "k3d" \
  "npm" \
  "codex" \
  "bubblewrap"
do
  if ! printf '%s\n' "$output" | grep -F "$expected" >/dev/null; then
    printf 'Expected dry-run output to include: %s\n' "$expected" >&2
    printf '%s\n' "$output" >&2
    exit 1
  fi
done
