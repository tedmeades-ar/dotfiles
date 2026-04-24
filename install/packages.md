# Packages

Install the tools that make the copied configs useful:

- `bash`
- `kitty`
- `zellij`
- `lazygit`
- `yazi`
- `git`
- `ripgrep`
- `fd`
- `fzf`
- `bat`
- `wl-clipboard` on Wayland or `xclip` on X11

Also install the same Nerd Font used by your terminal profile.

`install/bootstrap.sh` attempts to install these using `apt-get`, `pacman`,
`dnf`, or `brew`. Some distributions do not package every tool under the same
name, so the script reports packages it could not install and still configures
the symlinks.
