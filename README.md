# Personal Dotfiles

Minimal workflow config for making a new main machine feel like this one.

## Included

- Bash: `home/dot_bashrc`
- Kitty: `home/dot_config/kitty`
- Zellij: `home/dot_config/zellij`
- Lazygit: `home/dot_config/lazygit`
- Yazi: `home/dot_config/yazi`
- Codex: `home/dot_codex/config.toml` and `home/dot_codex/prompts`
- Claude: `home/dot_claude/settings.json`, commands, skills, plugin metadata, and statusline scripts
- SSH client config: `home/dot_ssh/config`

## Excluded

Do not commit auth files, private keys, sessions, logs, browser profiles, caches,
or generated history. Re-authenticate tools on the new machine instead.

## Install On A New Machine

Clone the repo, then run the bootstrap script:

```bash
git clone git@github.com:tedmeades-ar/dotfiles.git ~/Documents/dotfiles
cd ~/Documents/dotfiles
./install/bootstrap.sh
```

The bootstrap script installs common workflow tools into `~/.local/bin` without
sudo where prebuilt binaries are available, then symlinks the tracked files into
`$HOME`.

Preview link changes without touching the machine:

```bash
./install/bootstrap.sh --dry-run
```

Skip package installation and only configure symlinks:

```bash
./install/bootstrap.sh --skip-packages
```

Use your OS package manager instead:

```bash
./install/bootstrap.sh --use-system-packages
```

Existing files that are not already the right symlink are moved aside to a
timestamped backup path before linking.

## Editing Workflow

After bootstrap, the active config files point back into this repo. Edit the
normal config paths, then commit from the repo:

```bash
vim ~/.config/yazi/yazi.toml
cd ~/Documents/dotfiles
git diff
git add .
git commit -m "Update yazi config"
git push
```

Review `home/dot_ssh/config` before using it on another machine, especially
hostnames, usernames, and key paths.
