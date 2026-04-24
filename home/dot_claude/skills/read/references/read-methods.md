# Read Methods Reference

## Fetch Cascade

All methods run locally — no third-party proxy services. Try in order. Success = non-empty output with readable content (more than 5 lines). If a method returns empty or errors, try the next:

### 1. defuddle CLI (primary — local, best quality)

```bash
npx defuddle@0.15.0 parse "{url}" --markdown
```

Fetches the URL directly from your machine and extracts readable content locally. No data sent to any proxy. Best output quality with YAML-style metadata.

### 2. curl + html2text (if installed)

```bash
pip install html2text  # one-time setup
curl -sL "{url}" | python3 -c "import html2text,sys; h=html2text.HTML2Text(); print(h.handle(sys.stdin.read()))"
```

### 3. curl + Python stdlib (always available, basic)

```bash
curl -sL "{url}" | python3 -c "from html.parser import HTMLParser; ..."
```

Strips scripts/styles/nav, outputs plain paragraphs. No dependencies beyond Python 3.

### 4. Web search plugin reader (if available)

If a web search plugin is installed (e.g., PipeLLM), use its reader tool. Handles JavaScript-rendered pages better than static fetch.

## GitHub URLs

GitHub file URLs (`github.com/user/repo/blob/...`) render heavy HTML. The proxy cascade often returns partial or nav-heavy content. Prefer:

```bash
# Raw file content (fastest)
curl -sL "https://raw.githubusercontent.com/{user}/{repo}/{branch}/{path}"

# Via gh CLI (works with private repos)
gh api repos/{user}/{repo}/contents/{path} --jq '.content' | base64 -d
```

Use the proxy cascade only as a fallback for GitHub pages that are not raw file views (e.g., issue threads, README renders).

## PDF to Markdown

### Remote PDF URL

r.jina.ai handles PDF URLs directly:

```bash
curl -sL "https://r.jina.ai/{pdf_url}"
```

If that fails, download and extract locally:

```bash
curl -sL "{pdf_url}" -o /tmp/input.pdf
pdftotext -layout /tmp/input.pdf -
```

### Local PDF file

```bash
# Best quality (requires: pip install marker-pdf)
marker_single /path/to/file.pdf --output_dir ~/Downloads/

# Fast, text-heavy PDFs (requires: brew install poppler)
pdftotext -layout /path/to/file.pdf - | sed 's/\f/\n---\n/g'

# No-dependency fallback
python3 -c "
import pypdf, sys
r = pypdf.PdfReader(sys.argv[1])
print('\n\n'.join(p.extract_text() for p in r.pages))
" /path/to/file.pdf
```

Use `marker` when layout matters (papers, tables). Use `pdftotext` for speed.

## Feishu / Lark Document

Built-in script at `$CLAUDE_SKILL_DIR/scripts/fetch_feishu.py`. Requires `requests` and Feishu app credentials:

```bash
pip install requests  # one-time setup
export FEISHU_APP_ID=your_app_id
export FEISHU_APP_SECRET=your_app_secret
python3 "$CLAUDE_SKILL_DIR/scripts/fetch_feishu.py" "{url}"
```

Supports: docx, legacy docs, wiki pages. App needs `docx:document:readonly` and `wiki:wiki:readonly` permissions.
Output: YAML frontmatter (title, document_id, url) + Markdown body.

## WeChat Public Account

Use the proxy cascade (r.jina.ai / defuddle.md). Works for most articles without any extra tools.

If the proxy is blocked, use the built-in Playwright script as a last resort (requires ~300 MB one-time install):

```bash
pip install playwright beautifulsoup4 lxml && playwright install chromium
python3 "$CLAUDE_SKILL_DIR/scripts/fetch_weixin.py" "{url}"
```
