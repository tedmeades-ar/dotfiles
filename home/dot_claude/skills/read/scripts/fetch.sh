#!/usr/bin/env bash
# Fetch a URL as Markdown using local tools only — no third-party proxy services.
# Special thanks to joeseesun for the excellent qiaomu-markdown-proxy project,
# which inspired the original proxy cascade design.
# https://github.com/joeseesun/qiaomu-markdown-proxy
# Usage: fetch.sh <url> [proxy_url]
# Example: fetch.sh https://example.com http://127.0.0.1:7890
set -euo pipefail

URL="${1:?Usage: fetch.sh <url> [proxy_url]}"
PROXY="${2:-}"

_curl() {
  if [ -n "$PROXY" ]; then
    https_proxy="$PROXY" http_proxy="$PROXY" curl -sfL "$@"
  else
    curl -sfL "$@"
  fi
}

_has_content() {
  [ "$(echo "$1" | wc -l)" -gt 5 ]
}

# 1. defuddle CLI - local article extraction, no remote proxy
if command -v npx >/dev/null 2>&1; then
  if [ -n "$PROXY" ]; then
    OUT=$(https_proxy="$PROXY" http_proxy="$PROXY" npx defuddle@0.15.0 parse "$URL" --markdown 2>/dev/null || true)
  else
    OUT=$(npx defuddle@0.15.0 parse "$URL" --markdown 2>/dev/null || true)
  fi
  if _has_content "$OUT"; then echo "$OUT"; exit 0; fi
fi

# 2. curl + html2text (if installed: pip install html2text)
if python3 -c "import html2text" 2>/dev/null; then
  HTML=$(_curl "$URL" 2>/dev/null || true)
  if [ -n "$HTML" ]; then
    OUT=$(printf '%s' "$HTML" | python3 -c "
import html2text, sys
h = html2text.HTML2Text()
h.ignore_links = False
h.body_width = 0
print(h.handle(sys.stdin.read()))
" 2>/dev/null || true)
    if _has_content "$OUT"; then echo "$OUT"; exit 0; fi
  fi
fi

# 3. curl + Python stdlib HTML stripper (always available, basic text output)
HTML=$(_curl "$URL" 2>/dev/null || true)
if [ -n "$HTML" ]; then
  OUT=$(printf '%s' "$HTML" | python3 -c "
from html.parser import HTMLParser
import sys

class _Strip(HTMLParser):
    def __init__(self):
        super().__init__()
        self._skip = 0
        self.parts = []
    def handle_starttag(self, tag, attrs):
        if tag in ('script', 'style', 'nav', 'header', 'footer', 'aside'):
            self._skip += 1
    def handle_endtag(self, tag):
        if tag in ('script', 'style', 'nav', 'header', 'footer', 'aside') and self._skip:
            self._skip -= 1
    def handle_data(self, data):
        if not self._skip:
            text = data.strip()
            if text:
                self.parts.append(text)

p = _Strip()
p.feed(sys.stdin.read())
print('\n\n'.join(p.parts))
" 2>/dev/null || true)
  if _has_content "$OUT"; then echo "$OUT"; exit 0; fi
fi

echo "ERROR: All fetch methods failed for: $URL" >&2
exit 1
