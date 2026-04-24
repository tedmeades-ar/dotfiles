# Personal Dotfiles

Minimal workflow config for making a new main machine feel like this one.

## Included

- Bash: `home/dot_bashrc`
- Kitty: `home/dot_config/kitty`
- Zellij: `home/dot_config/zellij`
- Lazygit: `home/dot_config/lazygit`
- Yazi: `home/dot_config/yazi` is reserved for remote/imported config
- Codex: `home/dot_codex/config.toml` and `home/dot_codex/prompts`
- Claude: `home/dot_claude/settings.json`, commands, skills, plugin metadata, and statusline scripts
- SSH client config: `home/dot_ssh/config`

## Excluded

Do not commit auth files, private keys, sessions, logs, browser profiles, caches,
or generated history. Re-authenticate tools on the new machine instead.

## Restore Sketch

This repo uses chezmoi-style names under `home/`, but it has not been wired to
chezmoi yet. To restore manually, copy files into place:

```bash
cp home/dot_bashrc ~/.bashrc
cp -a home/dot_config/zellij ~/.config/
cp -a home/dot_config/kitty ~/.config/
cp -a home/dot_config/lazygit ~/.config/
cp -a home/dot_codex ~/.codex
cp -a home/dot_claude ~/.claude
cp home/dot_ssh/config ~/.ssh/config
```

Review `home/dot_ssh/config` before using it on another machine, especially
hostnames, usernames, and key paths.
