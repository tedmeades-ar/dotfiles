# Packages

Install the tools that make the copied configs useful:

- `bash`
- `kitty`
- `zellij`
- `lazygit`
- `yazi`
- `git`
- `keychain`
- `ripgrep`
- `fd`
- `fzf`
- `bat`
- `wl-clipboard` on Wayland or `xclip` on X11

Also install the same Nerd Font used by your terminal profile.

`install/bootstrap.sh` installs most CLI tools into `~/.local/bin` from
prebuilt upstream releases by default. Use `--use-system-packages` to prefer
`apt-get`, `pacman`, `dnf`, or `brew` instead.

Clipboard utilities are still best installed by the OS package manager.
