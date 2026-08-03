#!/usr/bin/env bash
# Install the pre-commit hook that blocks oversized GIFs.
# Run once per clone:  bash tools/install-hooks.sh
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
hook="$repo_root/.git/hooks/pre-commit"

cat > "$hook" <<'HOOK'
#!/usr/bin/env bash
# Blocks commits containing GIFs too large to animate in Gmail.
# Bypass with: git commit --no-verify
repo_root="$(git rev-parse --show-toplevel)"
staged=$(git diff --cached --name-only --diff-filter=ACM | grep -iE '\.gif$' || true)
[ -z "$staged" ] && exit 0

echo "Checking staged GIFs for Gmail compatibility..."
# shellcheck disable=SC2086
(cd "$repo_root" && echo "$staged" | tr '\n' '\0' | xargs -0 bash tools/check-gif-sizes.sh)
HOOK

chmod +x "$hook"
echo "Installed $hook"
