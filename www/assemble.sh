#!/bin/sh
# www/assemble.sh -- build the Jekyll source tree for the website out of www/
# and docs/, without putting front matter into docs/ itself.
#
# The documents under docs/ are read on GitHub as often as on the site, and
# YAML front matter renders there as a stray table at the top of every page.
# So it is added here, at build time, along with the link rewriting a site
# needs and a repository does not: `manual.md` becomes `manual.html`, and a
# link that leaves docs/ becomes a link to GitHub.
#
# Run from the repository root. Writes _site_src/.

set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
out=$root/_site_src
repo=https://github.com/hansolovkarlsson/Phoenix/blob/main

rm -rf "$out"
mkdir -p "$out"

# The landing page, the layout and the stylesheet, as they stand.
cp    "$root/www/_config.yml" "$out/"
cp    "$root/www/index.html"  "$out/"
cp -R "$root/www/_layouts"    "$out/"
cp -R "$root/www/assets"      "$out/"

for f in "$root"/docs/*.md; do
    name=$(basename "$f" .md)

    # The title is the document's own first heading, which every one of them
    # has, so that the tab and the breadcrumb say what the page is called
    # rather than what its file is called.
    title=$(sed -n 's/^# //p' "$f" | head -1)
    [ -n "$title" ] || title=$name

    {
        printf -- '---\n'
        printf -- 'layout: doc\n'
        printf -- 'title: "%s"\n' "$(printf '%s' "$title" | sed 's/"/\\"/g')"
        printf -- 'source: %s.md\n' "$name"
        printf -- '---\n\n'

        # Liquid is off for the body of every document, and has to be. The
        # notation writes a literal brace as `{{`, so a page explaining `of`
        # is full of what Liquid reads as the start of a variable -- and it
        # said so: *Variable '{{\n{}' was not properly terminated*. Nothing
        # under docs/ wants templating, so none of it gets any.
        printf -- '{%% raw %%}\n'

        # Two rewrites, in this order. A link out of docs/ goes to GitHub and
        # keeps its .md; a link within docs/ becomes the page beside it. The
        # second cannot touch the first, because a URL has characters the
        # filename pattern does not allow.
        sed -E \
            -e "s@\]\(\.\./([^)]+)\)@](${repo}/\1)@g" \
            -e 's@\]\(([A-Za-z0-9._-]+)\.md(#[^)]*)?\)@](\1.html\2)@g' \
            "$f"

        printf -- '\n{%% endraw %%}\n'
    } > "$out/$name.md"
done

printf 'assembled %s pages into %s\n' "$(ls "$out"/*.md | wc -l | tr -d ' ')" "$out"
