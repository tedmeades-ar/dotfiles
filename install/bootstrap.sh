#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=0
SKIP_PACKAGES=0
USE_SYSTEM_PACKAGES=0
BIN_DIR="${DOTFILES_BIN_DIR:-$HOME/.local/bin}"

usage() {
  cat <<'USAGE'
Usage: install/bootstrap.sh [--dry-run] [--skip-packages] [--use-system-packages]

Install core workflow tools where possible, then symlink this repo's dotfiles
into $HOME. Run from any directory inside the cloned dotfiles repo.

By default, tools are installed without sudo into ~/.local/bin.

Options:
  --dry-run              Print package/link actions without changing the system
  --skip-packages        Only configure symlinks
  --use-system-packages  Use apt/pacman/dnf/brew instead of local binaries
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
    --use-system-packages)
      USE_SYSTEM_PACKAGES=1
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
export PATH="$BIN_DIR:$PATH"

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

ensure_bin_dir() {
  run mkdir -p "$BIN_DIR"
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
    packages=(bash git kitty ripgrep fd-find fzf bat wl-clipboard xclip curl ca-certificates tar gzip unzip keychain)
    for package in "${packages[@]}"; do
      if ! run sudo apt-get install -y "$package"; then
        missing_packages+=("$package")
      fi
    done
    report_missing_packages "${missing_packages[@]}"
    return
  fi

  if has pacman; then
    packages=(bash git kitty zellij lazygit yazi ripgrep fd fzf bat wl-clipboard xclip keychain)
    for package in "${packages[@]}"; do
      if ! run sudo pacman -S --needed --noconfirm "$package"; then
        missing_packages+=("$package")
      fi
    done
    report_missing_packages "${missing_packages[@]}"
    return
  fi

  if has dnf; then
    packages=(bash git kitty zellij lazygit ripgrep fd-find fzf bat wl-clipboard xclip curl ca-certificates tar gzip unzip keychain)
    for package in "${packages[@]}"; do
      if ! run sudo dnf install -y "$package"; then
        missing_packages+=("$package")
      fi
    done
    report_missing_packages "${missing_packages[@]}"
    return
  fi

  if has brew; then
    packages=(bash git kitty zellij lazygit yazi ripgrep fd fzf bat keychain)
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

github_arches() {
  case "$(uname -m)" in
    x86_64|amd64)
      GITHUB_RUST_ARCH="x86_64"
      GITHUB_LAZYGIT_ARCH="x86_64"
      GITHUB_FZF_ARCH="amd64"
      ;;
    aarch64|arm64)
      GITHUB_RUST_ARCH="aarch64"
      GITHUB_LAZYGIT_ARCH="arm64"
      GITHUB_FZF_ARCH="arm64"
      ;;
    *)
      GITHUB_RUST_ARCH=""
      GITHUB_LAZYGIT_ARCH=""
      GITHUB_FZF_ARCH=""
      ;;
  esac
}

micromamba_platform() {
  case "$(uname -m)" in
    x86_64|amd64)
      MICROMAMBA_PLATFORM="linux-64"
      ;;
    aarch64|arm64)
      MICROMAMBA_PLATFORM="linux-aarch64"
      ;;
    ppc64le)
      MICROMAMBA_PLATFORM="linux-ppc64le"
      ;;
    *)
      MICROMAMBA_PLATFORM=""
      ;;
  esac
}

latest_github_asset_url() {
  local repo="$1"
  local pattern="$2"

  curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" \
    | sed -n 's/.*"browser_download_url": "\(.*\)".*/\1/p' \
    | grep -E -m 1 "$pattern"
}

latest_github_tarball_url() {
  local repo="$1"

  curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" \
    | sed -n 's/.*"tarball_url": "\(.*\)".*/\1/p' \
    | head -n 1
}

install_github_binaries() {
  local repo="$1"
  local pattern="$2"
  local label="$3"
  shift 3

  local archive
  local found
  local tmpdir
  local url

  if [ "$(uname -s)" != "Linux" ]; then
    say "Skipping $label fallback: GitHub binary fallback is only configured for Linux."
    return
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    say "DRY-RUN: install $label into $BIN_DIR from GitHub release ${repo} matching ${pattern}"
    return
  fi

  if ! has curl; then
    say "Skipping $label fallback: curl is not installed."
    return
  fi

  url="$(latest_github_asset_url "$repo" "$pattern")"
  if [ -z "$url" ]; then
    say "Skipping $label fallback: no matching release asset found for pattern ${pattern}."
    return
  fi

  tmpdir="$(mktemp -d)"
  archive="$tmpdir/archive"

  ensure_bin_dir
  say "Installing $label into $BIN_DIR from $url"
  curl -fsSL "$url" -o "$archive"

  case "$url" in
    *.tar.gz|*.tgz)
      tar -xzf "$archive" -C "$tmpdir"
      ;;
    *.zip)
      unzip -q "$archive" -d "$tmpdir"
      ;;
    *)
      say "Skipping $label fallback: unsupported archive type: $url"
      rm -rf "$tmpdir"
      return
      ;;
  esac

  for binary in "$@"; do
    found="$(find "$tmpdir" -type f -name "$binary" -print -quit)"
    if [ -z "$found" ]; then
      say "Could not find $binary in $label archive."
      continue
    fi
    run install -m 0755 "$found" "$BIN_DIR/$binary"
  done

  rm -rf "$tmpdir"
}

install_github_asset_binary() {
  local repo="$1"
  local pattern="$2"
  local label="$3"
  local binary="$4"

  local archive
  local tmpdir
  local url

  if [ "$(uname -s)" != "Linux" ]; then
    say "Skipping $label fallback: GitHub binary fallback is only configured for Linux."
    return
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    say "DRY-RUN: install $label into $BIN_DIR from GitHub release ${repo} matching ${pattern}"
    return
  fi

  if ! has curl; then
    say "Skipping $label fallback: curl is not installed."
    return
  fi

  url="$(latest_github_asset_url "$repo" "$pattern")"
  if [ -z "$url" ]; then
    say "Skipping $label fallback: no matching release asset found for pattern ${pattern}."
    return
  fi

  tmpdir="$(mktemp -d)"
  archive="$tmpdir/$binary"

  ensure_bin_dir
  say "Installing $label into $BIN_DIR from $url"
  curl -fsSL "$url" -o "$archive"
  run install -m 0755 "$archive" "$BIN_DIR/$binary"
  rm -rf "$tmpdir"
}

install_github_source_file() {
  local repo="$1"
  local label="$2"
  local filename="$3"

  local archive
  local found
  local tmpdir
  local url

  if [ "$DRY_RUN" -eq 1 ]; then
    say "DRY-RUN: install $label into $BIN_DIR from ${repo} source release"
    return
  fi

  if ! has curl; then
    say "Skipping $label: curl is required to download release source."
    return
  fi

  url="$(latest_github_tarball_url "$repo")"
  if [ -z "$url" ]; then
    say "Skipping $label: no source tarball found."
    return
  fi

  tmpdir="$(mktemp -d)"
  archive="$tmpdir/source.tar.gz"

  ensure_bin_dir
  say "Installing $label into $BIN_DIR from $url"
  curl -fsSL "$url" -o "$archive"
  tar -xzf "$archive" -C "$tmpdir"
  found="$(find "$tmpdir" -type f -name "$filename" -print -quit)"

  if [ -z "$found" ]; then
    say "Could not find $filename in $label source archive."
    rm -rf "$tmpdir"
    return
  fi

  run install -m 0755 "$found" "$BIN_DIR/$filename"
  rm -rf "$tmpdir"
}

install_micromamba_local() {
  local archive
  local tmpdir
  local url

  if [ "$(uname -s)" != "Linux" ]; then
    say "Skipping micromamba local install: use the platform installer for $(uname -s)."
    return
  fi

  micromamba_platform
  if [ -z "$MICROMAMBA_PLATFORM" ]; then
    say "Skipping micromamba local install: unsupported CPU architecture $(uname -m)."
    return
  fi

  url="https://micro.mamba.pm/api/micromamba/${MICROMAMBA_PLATFORM}/latest"

  if [ "$DRY_RUN" -eq 1 ]; then
    say "DRY-RUN: install micromamba into $BIN_DIR from $url"
    return
  fi

  if ! has curl; then
    say "Skipping micromamba: curl is required to download the installer."
    return
  fi

  tmpdir="$(mktemp -d)"
  archive="$tmpdir/micromamba.tar.bz2"

  ensure_bin_dir
  say "Installing micromamba into $BIN_DIR from $url"
  curl -fsSL "$url" -o "$archive"
  tar -xjf "$archive" -C "$tmpdir" bin/micromamba
  run install -m 0755 "$tmpdir/bin/micromamba" "$BIN_DIR/micromamba"
  rm -rf "$tmpdir"
}

install_kitty_local() {
  local installer
  local tmpdir

  if has kitty; then
    return
  fi

  if [ "$(uname -s)" != "Linux" ]; then
    say "Skipping kitty local install: use the platform installer for $(uname -s)."
    return
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    say "DRY-RUN: install kitty to ~/.local/kitty.app and symlink kitty/kitten into $BIN_DIR"
    return
  fi

  if ! has curl; then
    say "Skipping kitty: curl is required to download the installer."
    return
  fi

  tmpdir="$(mktemp -d)"
  installer="$tmpdir/kitty-installer.sh"
  ensure_bin_dir
  curl -fsSL https://sw.kovidgoyal.net/kitty/installer.sh -o "$installer"
  sh "$installer" launch=n
  ln -sf "$HOME/.local/kitty.app/bin/kitty" "$BIN_DIR/kitty"
  ln -sf "$HOME/.local/kitty.app/bin/kitten" "$BIN_DIR/kitten"
  rm -rf "$tmpdir"
}

install_bash_completions() {
  local k3d_completion_dir="$HOME/.local/share/bash-completion/completions/k3d"
  local k3d_completion_file="$k3d_completion_dir/k3d_completion.sh"
  local task_completion_dir="$HOME/.bash-completion/completions"
  local task_completion_file="$task_completion_dir/task.bash"
  local tmpfile

  if [ "$SKIP_PACKAGES" -eq 1 ]; then
    return
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    say "DRY-RUN: generate task bash completion at $task_completion_file"
    say "DRY-RUN: generate k3d bash completion at $k3d_completion_file"
    return
  fi

  if has task; then
    run mkdir -p "$task_completion_dir"
    tmpfile="$(mktemp)"
    if task --completion bash > "$tmpfile"; then
      run install -m 0644 "$tmpfile" "$task_completion_file"
    else
      say "Skipping task completion: task --completion bash failed."
    fi
    rm -f "$tmpfile"
  fi

  if has k3d; then
    run mkdir -p "$k3d_completion_dir"
    tmpfile="$(mktemp)"
    if k3d completion bash > "$tmpfile"; then
      run install -m 0644 "$tmpfile" "$k3d_completion_file"
    else
      say "Skipping k3d completion: k3d completion bash failed."
    fi
    rm -f "$tmpfile"
  fi
}

install_missing_upstream_tools() {
  local forced="${DOTFILES_FORCE_FALLBACK_DRY_RUN:-0}"

  if [ "$SKIP_PACKAGES" -eq 1 ]; then
    return
  fi

  ensure_bin_dir
  github_arches
  if [ -z "$GITHUB_RUST_ARCH" ] || [ -z "$GITHUB_LAZYGIT_ARCH" ] || [ -z "$GITHUB_FZF_ARCH" ]; then
    say "Skipping GitHub binary fallbacks: unsupported CPU architecture $(uname -m)."
    return
  fi

  install_kitty_local

  if ! has micromamba || [ "$forced" = "1" ]; then
    install_micromamba_local
  fi

  if ! has keychain || [ "$forced" = "1" ]; then
    install_github_source_file \
      "danielrobbins/keychain" \
      "keychain" \
      keychain
  fi

  if ! has lazygit || [ "$forced" = "1" ]; then
    install_github_binaries \
      "jesseduffield/lazygit" \
      "Linux_${GITHUB_LAZYGIT_ARCH}\\.tar\\.gz$" \
      "lazygit" \
      lazygit
  fi

  if ! has uv || ! has uvx || [ "$forced" = "1" ]; then
    install_github_binaries \
      "astral-sh/uv" \
      "uv-${GITHUB_RUST_ARCH}-unknown-linux-gnu\\.tar\\.gz$" \
      "uv" \
      uv uvx
  fi

  if ! has task || [ "$forced" = "1" ]; then
    install_github_binaries \
      "go-task/task" \
      "task_linux_${GITHUB_FZF_ARCH}\\.tar\\.gz$" \
      "task" \
      task
  fi

  if ! has k3d || [ "$forced" = "1" ]; then
    install_github_asset_binary \
      "k3d-io/k3d" \
      "k3d-linux-${GITHUB_FZF_ARCH}$" \
      "k3d" \
      k3d
  fi

  if ! has zellij || [ "$forced" = "1" ]; then
    install_github_binaries \
      "zellij-org/zellij" \
      "${GITHUB_RUST_ARCH}.*linux.*\\.tar\\.gz$" \
      "zellij" \
      zellij
  fi

  if ! has yazi || [ "$forced" = "1" ]; then
    install_github_binaries \
      "sxyazi/yazi" \
      "yazi-${GITHUB_RUST_ARCH}.*linux.*\\.(zip|tar\\.gz)$" \
      "yazi" \
      yazi ya
  fi

  if ! has rg || [ "$forced" = "1" ]; then
    install_github_binaries \
      "BurntSushi/ripgrep" \
      "ripgrep-.*-${GITHUB_RUST_ARCH}-unknown-linux-(gnu|musl)\\.tar\\.gz$" \
      "ripgrep" \
      rg
  fi

  if ! has fd && ! has fdfind || [ "$forced" = "1" ]; then
    install_github_binaries \
      "sharkdp/fd" \
      "fd-v.*-${GITHUB_RUST_ARCH}-unknown-linux-(gnu|musl)\\.tar\\.gz$" \
      "fd" \
      fd
  fi

  if ! has fzf || [ "$forced" = "1" ]; then
    install_github_binaries \
      "junegunn/fzf" \
      "fzf-.*-linux_${GITHUB_FZF_ARCH}\\.tar\\.gz$" \
      "fzf" \
      fzf
  fi

  if ! has bat && ! has batcat || [ "$forced" = "1" ]; then
    install_github_binaries \
      "sharkdp/bat" \
      "bat-v.*-${GITHUB_RUST_ARCH}-unknown-linux-(gnu|musl)\\.tar\\.gz$" \
      "bat" \
      bat
  fi
}

report_tool_status() {
  local missing=()

  has git || missing+=("git")
  has bash || missing+=("bash")
  has keychain || missing+=("keychain")
  has kitty || missing+=("kitty")
  has micromamba || missing+=("micromamba")
  has zellij || missing+=("zellij")
  has lazygit || missing+=("lazygit")
  has yazi || missing+=("yazi")
  has uv || missing+=("uv")
  has uvx || missing+=("uvx")
  has task || missing+=("task")
  has k3d || missing+=("k3d")
  has rg || missing+=("ripgrep")
  { has fd || has fdfind; } || missing+=("fd/fdfind")
  has fzf || missing+=("fzf")
  { has bat || has batcat; } || missing+=("bat/batcat")
  { has wl-copy || has xclip || has pbcopy; } || missing+=("clipboard tool")

  if [ "${#missing[@]}" -eq 0 ]; then
    say "All expected commands are available."
    return
  fi

  say "These expected commands were not found:"
  printf '  %s\n' "${missing[@]}"
}

if [ "$USE_SYSTEM_PACKAGES" -eq 1 ]; then
  install_packages
fi
install_missing_upstream_tools
install_bash_completions
report_tool_status

if [ "$DRY_RUN" -eq 1 ]; then
  "$SCRIPT_DIR/link.sh" --dry-run
else
  "$SCRIPT_DIR/link.sh"
fi
