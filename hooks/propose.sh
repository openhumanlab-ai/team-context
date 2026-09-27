#!/usr/bin/env bash
# Turn an inbox draft into a pull request that adds it to DECISIONS.md.
# Merging the PR is the approval. Closing it is the rejection.
#
# Usage:
#   hooks/propose.sh inbox/<file>-draft.md             open the PR (needs gh, logged in)
#   hooks/propose.sh --dry-run inbox/<file>-draft.md   show the commit, push nothing
#
# Works in a throwaway git worktree, so your current branch and any
# uncommitted changes are never touched.

set -euo pipefail

DRY=0
[ "${1:-}" = "--dry-run" ] && { DRY=1; shift; }
DRAFT="${1:?usage: propose.sh [--dry-run] inbox/<file>-draft.md}"
[ -f "$DRAFT" ] || { echo "propose: no such draft: $DRAFT" >&2; exit 1; }
DRAFT="$(cd "$(dirname "$DRAFT")" && pwd -P)/$(basename "$DRAFT")"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TOP="$(git -C "$ROOT" rev-parse --show-toplevel 2>/dev/null)" \
  || { echo "propose: $ROOT is not inside a git repo" >&2; exit 1; }
REL="${ROOT#"$TOP"}"; REL="${REL#/}"
DECISIONS="${REL:+$REL/}DECISIONS.md"

if [ "$DRY" = 0 ]; then
  command -v gh >/dev/null 2>&1 || { echo "propose: needs the GitHub CLI (gh). Try --dry-run." >&2; exit 1; }
  git -C "$TOP" fetch -q origin
  BASE_BRANCH="$(git -C "$TOP" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')"
  BASE_BRANCH="${BASE_BRANCH:-main}"
  BASE="origin/$BASE_BRANCH"
else
  BASE="HEAD"
fi

# The note is everything except the DRAFT comment line.
NOTE="$(grep -v '^<!-- DRAFT' "$DRAFT" | sed '/./,$!d')"
TITLE="$(printf '%s\n' "$NOTE" | sed -n 's/^## \(D-[0-9X]*[[:space:]]*\)\{0,1\}[0-9-]*[[:space:]]*//p' | head -1)"
TITLE="${TITLE:-Decision}"
SLUG="$(printf '%s' "$TITLE" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//; s/-$//' | cut -c1-40)"
BRANCH="decision/${SLUG:-note}-$(date +%Y%m%d%H%M%S)"

WT="$(mktemp -d)"
cleanup() {
  git -C "$TOP" worktree remove --force "$WT" >/dev/null 2>&1 || true
  # The pushed branch lives on the remote; the draft stays in inbox/ until the PR opens.
  git -C "$TOP" branch -D "$BRANCH" >/dev/null 2>&1 || true
}
trap cleanup EXIT
git -C "$TOP" worktree add -q -b "$BRANCH" "$WT" "$BASE"

# Number the decision from the branch it will merge into.
LAST="$(sed -n 's/^## D-\([0-9][0-9]*\).*/\1/p' "$WT/$DECISIONS" | sed 's/^0*//' | sort -n | tail -1)"
ID="$(printf 'D-%03d' $(( ${LAST:-0} + 1 )))"
NOTE="$(printf '%s\n' "$NOTE" | sed "s/^## D-XXX/## $ID/")"

# Insert above the "Add new entries above this line" marker if there is one,
# otherwise append at the end.
NOTE_FILE="$WT/.team-context-note"
printf '%s\n\n' "$NOTE" > "$NOTE_FILE"
awk -v nf="$NOTE_FILE" '
  /^<!-- Add new entries above this line/ && !done { while ((getline l < nf) > 0) print l; done = 1 }
  { print }
  END { if (!done) { print ""; while ((getline l < nf) > 0) print l } }
' "$WT/$DECISIONS" > "$WT/$DECISIONS.new"
mv "$WT/$DECISIONS.new" "$WT/$DECISIONS"
rm -f "$NOTE_FILE"

git -C "$WT" add "$DECISIONS"
git -C "$WT" commit -q -m "Decision $ID: $TITLE"

if [ "$DRY" = 1 ]; then
  git -C "$WT" show --stat --patch HEAD
  echo "propose: dry run, nothing pushed, nothing left behind." >&2
  exit 0
fi

git -C "$WT" push -q -u origin "$BRANCH"
BODY="Drafted from a Claude Code session by the team-context hook. Merge to approve, close to reject, or edit the branch if it's half right.

$NOTE

Before merging:
- [ ] A human actually settled this, it isn't just something the AI proposed
- [ ] Ruled out names the real alternatives, with a few words on why
- [ ] Revisit if is something you could actually notice (a number, a date, an event)"
(cd "$WT" && gh pr create --base "$BASE_BRANCH" --head "$BRANCH" --title "Decision $ID: $TITLE" --body "$BODY")
rm -f "$DRAFT"
