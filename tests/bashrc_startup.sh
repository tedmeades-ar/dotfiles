#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/home"
mkdir -p "$tmpdir/home/.ssh"
touch "$tmpdir/home/.ssh/id_ed25519" "$tmpdir/home/.ssh/argithub"
mkdir -p "$tmpdir/bin"
printf '#!/usr/bin/env bash\nprintf "KEYCHAIN INVOKED\\n" >&2\n' > "$tmpdir/bin/keychain"
chmod +x "$tmpdir/bin/keychain"

output="$(
  timeout 10s env \
    HOME="$tmpdir/home" \
    PATH="$tmpdir/bin:/usr/bin:/bin" \
    TERM="xterm-256color" \
    bash --noprofile --norc -i -c "source '$repo_root/home/dot_bashrc'; exit" \
    2>&1
)" || status=$?

status="${status:-0}"

if [ "$status" -ne 0 ]; then
  printf 'Expected bashrc startup to exit cleanly, got status %s.\n' "$status" >&2
  printf '%s\n' "$output" >&2
  exit 1
fi

if printf '%s\n' "$output" | grep -E "(No such file or directory|command not found|Command '.+' not found|Enter passphrase|KEYCHAIN INVOKED)" >/dev/null; then
  printf 'Unexpected bashrc startup error output:\n' >&2
  printf '%s\n' "$output" >&2
  exit 1
fi

path_output="$(
  HOME="$tmpdir/home" \
  PATH="$tmpdir/bin:/usr/bin:/bin" \
  TERM="xterm-256color" \
  bash --noprofile --norc -i -c "source '$repo_root/home/dot_bashrc'; printf '%s\n' \"\$PATH\"; exit" \
    2>/dev/null \
  | tail -n 1
)"

case ":$path_output:" in
  *":$tmpdir/home/.npm-global/bin:"*)
    ;;
  *)
    printf 'Expected PATH to include ~/.npm-global/bin, got:\n%s\n' "$path_output" >&2
    exit 1
    ;;
esac
