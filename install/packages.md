# Packages

Install the tools that make the copied configs useful:

- `bash`
- `kitty`
- `micromamba`
- `zellij`
- `lazygit`
- `yazi`
- `uv` and `uvx`
- `task`
- `k3d`
- `git`
- `keychain`
- `ripgrep`
- `fd`
- `fzf`
- `bat`
- `npm`
- `codex`
- `bubblewrap`
- `wl-clipboard` on Wayland or `xclip` on X11

Also install the same Nerd Font used by your terminal profile.

Optional shell integrations are enabled when present:

- Linuxbrew

`install/bootstrap.sh` installs most CLI tools into `~/.local/bin` from
prebuilt upstream releases by default. Use `--use-system-packages` to prefer
`apt-get`, `pacman`, `dnf`, or `brew` instead.

Clipboard utilities are still best installed by the OS package manager.
