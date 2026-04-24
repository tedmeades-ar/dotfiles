#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=0
BACKUP_STAMP="${DOTFILES_BACKUP_STAMP:-$(date +%Y%m%d-%H%M%S)}"

usage() {
  cat <<'USAGE'
Usage: install/link.sh [--dry-run]

Symlink the tracked dotfiles into $HOME. Existing files that are not already the
right symlink are moved aside to <path>.backup-YYYYMMDD-HHMMSS.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
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
REPO_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

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

ensure_dir() {
  local dir="$1"
  if [ -d "$dir" ]; then
    return
  fi
  run mkdir -p "$dir"
}

is_link_to() {
  local target="$1"
  local source="$2"

  [ -L "$target" ] || return 1
  [ "$(readlink "$target")" = "$source" ] && return 0

  local resolved_target
  local resolved_source
  resolved_target="$(readlink -f "$target" 2>/dev/null || true)"
  resolved_source="$(readlink -f "$source" 2>/dev/null || true)"
  [ -n "$resolved_target" ] && [ "$resolved_target" = "$resolved_source" ]
}

backup_existing() {
  local target="$1"
  local backup="${target}.backup-${BACKUP_STAMP}"

  if [ ! -e "$target" ] && [ ! -L "$target" ]; then
    return
  fi

  if [ -e "$backup" ] || [ -L "$backup" ]; then
    echo "Backup path already exists: $backup" >&2
    exit 1
  fi

  say "Backing up $target -> $backup"
  run mv "$target" "$backup"
}

link_path() {
  local source="$1"
  local target="$2"

  if [ ! -e "$source" ] && [ ! -L "$source" ]; then
    echo "Missing source: $source" >&2
    exit 1
  fi

  ensure_dir "$(dirname "$target")"

  if is_link_to "$target" "$source"; then
    say "Already linked: $target -> $source"
    return
  fi

  backup_existing "$target"
  say "Linking $target -> $source"
  run ln -s "$source" "$target"
}

ensure_dir "$HOME/.config"
ensure_dir "$HOME/.codex"
ensure_dir "$HOME/.claude"
ensure_dir "$HOME/.ssh"

link_path "$REPO_DIR/home/dot_bashrc" "$HOME/.bashrc"

link_path "$REPO_DIR/home/dot_config/kitty" "$HOME/.config/kitty"
link_path "$REPO_DIR/home/dot_config/zellij" "$HOME/.config/zellij"
link_path "$REPO_DIR/home/dot_config/lazygit" "$HOME/.config/lazygit"
link_path "$REPO_DIR/home/dot_config/yazi" "$HOME/.config/yazi"

link_path "$REPO_DIR/home/dot_codex/config.toml" "$HOME/.codex/config.toml"
link_path "$REPO_DIR/home/dot_codex/prompts" "$HOME/.codex/prompts"

link_path "$REPO_DIR/home/dot_claude/settings.json" "$HOME/.claude/settings.json"
link_path "$REPO_DIR/home/dot_claude/commands" "$HOME/.claude/commands"
link_path "$REPO_DIR/home/dot_claude/skills" "$HOME/.claude/skills"
link_path "$REPO_DIR/home/dot_claude/plugins" "$HOME/.claude/plugins"
link_path "$REPO_DIR/home/dot_claude/statusline-command.sh" "$HOME/.claude/statusline-command.sh"
link_path "$REPO_DIR/home/dot_claude/statusline.sh" "$HOME/.claude/statusline.sh"
link_path "$REPO_DIR/home/dot_claude/usage-log-hook.sh" "$HOME/.claude/usage-log-hook.sh"

link_path "$REPO_DIR/home/dot_ssh/config" "$HOME/.ssh/config"

if [ "$DRY_RUN" -eq 0 ]; then
  chmod 700 "$HOME/.ssh"
  chmod 600 "$HOME/.ssh/config"
  say "Dotfile links are configured."
else
  say "Dry run complete; no links were changed."
fi
