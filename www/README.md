# The website

[hansolovkarlsson.github.io/Phoenix](https://hansolovkarlsson.github.io/Phoenix/)
— the front page, and every document under [`../docs/`](../docs/) rendered.

**Nothing here is committed built.** `.github/workflows/pages.yml` runs
[`assemble.sh`](assemble.sh) on every push that touches `docs/` or `www/`, and
the site is deployed from what that produces — so the site cannot fall behind
the documentation, and there is no generated HTML in the history to review.

| | |
| --- | --- |
| [`index.html`](index.html) | the front page. Plain HTML, copied through untouched — Jekyll only processes a file with front matter, and this one has none |
| [`_layouts/doc.html`](_layouts/doc.html) | the frame every rendered document gets |
| [`assets/phoenix.css`](assets/phoenix.css) | the whole of the look, in one file, with no webfonts |
| [`assemble.sh`](assemble.sh) | joins `www/` and `docs/` into `_site_src/` |
| [`_config.yml`](_config.yml) | kramdown, GFM, no theme |

## What `assemble.sh` does, and why it is a script

Two things a repository does not want and a site cannot do without.

**Front matter.** Jekyll renders a Markdown file only if it begins with a YAML
block — and GitHub renders that block as a stray table at the top of the page.
The documents under `docs/` are read in both places, so the front matter is
added at build time and never committed.

**Links.** `[manual.md](manual.md)` is right in a repository and wrong on a
site, where the page beside it is `manual.html`. A link that *leaves* `docs/` —
at `../lib/expression.phx`, say — has no page to point at, so it becomes a link
to the file on GitHub. Both are one `sed` each, and the second cannot damage
the first because a URL has characters a filename pattern does not allow.

## Working on it

```sh
./www/assemble.sh          # writes _site_src/, which is gitignored
```

That is what the build sees. Rendering it needs Jekyll; the fastest check that
does not is to open `www/index.html` in a browser, since the front page is
static and the stylesheet is beside it.
