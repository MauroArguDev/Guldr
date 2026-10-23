#!/bin/sh
# Copies the privacy policy and the support page from docs/ into a checkout of the gh-pages branch,
# which GitHub Pages serves at https://mauroargudev.github.io/Guldr/ (v1 plan, 33.7).
# Usage: scripts/publish-pages.sh <path to a gh-pages worktree>
# Then commit and push in that worktree. docs/ on main stays the only place to edit the pages.
set -eu

pages="${1:?Usage: scripts/publish-pages.sh <path to a gh-pages worktree>}"
root="$(cd "$(dirname "$0")/.." && pwd)"

publish() {
    source="$1"; name="$2"; title="$3"; description="$4"
    {
        printf -- '---\nlayout: page\ntitle: "%s"\ndescription: "%s"\npermalink: /%s/\n---\n\n' \
            "$title" "$description" "$name"
        # Links between the Markdown files become links between the published pages.
        sed -e 's|(PRIVACY\.md)|({{ "/privacy/" \| relative_url }})|g' \
            -e 's|(SUPPORT\.md)|({{ "/support/" \| relative_url }})|g' "$root/docs/$source"
    } > "$pages/$name.md"
    echo "Wrote $pages/$name.md"
}

publish PRIVACY.md privacy "Privacy policy" "Guldr keeps your finances on your iPhone: no account, no servers, no tracking."
publish SUPPORT.md support "Support" "Contact and frequently asked questions for Guldr."
