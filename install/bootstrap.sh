#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=0
SKIP_PACKAGES=0

usage() {
  cat <<'USAGE'
Usage: install/bootstrap.sh [--dry-run] [--skip-packages]

Install core workflow tools where possible, then symlink this repo's dotfiles
into $HOME. Run from any directory inside the cloned dotfiles repo.

Options:
  --dry-run        Print package/link actions without changing the system
  --skip-packages  Only configure symlinks
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      ;;
    --skip-packages)
      SKIP_PACKAGES=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

say() {
  printf '%s\n' "$*"
}

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    say "DRY-RUN: $*"
  else
    "$@"
  fi
}

has() {
  command -v "$1" >/dev/null 2>&1
}

install_packages() {
  local packages=()
  local missing_packages=()

  if [ "$SKIP_PACKAGES" -eq 1 ]; then
    say "Skipping package installation."
    return
  fi

  if has apt-get; then
    run sudo apt-get update
    packages=(bash git kitty zellij lazygit yazi ripgrep fd-find fzf bat wl-clipboard xclip)
    for package in "${packages[@]}"; do
      if ! run sudo apt-get install -y "$package"; then
        missing_packages+=("$package")
      fi
    done
    report_missing_packages "${missing_packages[@]}"
    return
  fi

  if has pacman; then
    packages=(bash git kitty zellij lazygit yazi ripgrep fd fzf bat wl-clipboard xclip)
    for package in "${packages[@]}"; do
      if ! run sudo pacman -S --needed --noconfirm "$package"; then
        missing_packages+=("$package")
      fi
    done
    report_missing_packages "${missing_packages[@]}"
    return
  fi

  if has dnf; then
    packages=(bash git kitty zellij lazygit yazi ripgrep fd-find fzf bat wl-clipboard xclip)
    for package in "${packages[@]}"; do
      if ! run sudo dnf install -y "$package"; then
        missing_packages+=("$package")
      fi
    done
    report_missing_packages "${missing_packages[@]}"
    return
  fi

  if has brew; then
    packages=(bash git kitty zellij lazygit yazi ripgrep fd fzf bat)
    for package in "${packages[@]}"; do
      if ! run brew install "$package"; then
        missing_packages+=("$package")
      fi
    done
    report_missing_packages "${missing_packages[@]}"
    return
  fi

  say "No supported package manager found. Install packages from install/packages.md, then rerun:"
  say "  ./install/bootstrap.sh --skip-packages"
}

report_missing_packages() {
  if [ "$#" -eq 0 ]; then
    return
  fi

  say "Some packages were not installed by the system package manager:"
  printf '  %s\n' "$@"
  say "Install those manually if the matching command is missing."
}

report_tool_status() {
  local missing=()

  has git || missing+=("git")
  has bash || missing+=("bash")
  has kitty || missing+=("kitty")
  has zellij || missing+=("zellij")
  has lazygit || missing+=("lazygit")
  has yazi || missing+=("yazi")
  has rg || missing+=("ripgrep")
  { has fd || has fdfind; } || missing+=("fd/fdfind")
  has fzf || missing+=("fzf")
  { has bat || has batcat; } || missing+=("bat/batcat")
  { has wl-copy || has xclip || has pbcopy; } || missing+=("clipboard tool")

  if [ "${#missing[@]}" -eq 0 ]; then
    say "All expected commands are available."
    return
  fi

  say "These expected commands were not found after package installation:"
  printf '  %s\n' "${missing[@]}"
}

install_packages
report_tool_status

if [ "$DRY_RUN" -eq 1 ]; then
  "$SCRIPT_DIR/link.sh" --dry-run
else
  "$SCRIPT_DIR/link.sh"
fi
