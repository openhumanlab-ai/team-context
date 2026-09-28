#!/usr/bin/env bash
# Find sentences that a decision retired but that are still sitting somewhere.
#
# A decision that makes existing text false quotes that text on a Retires line:
#   Retires: "The old sentence, word for word." "A second one, if there is one."
# This script takes every quoted sentence from those lines in DECISIONS.md and
# searches the project for it, word for word. Each hit is a place someone can
# still read the old choice and act on it. Quote with straight double quotes,
# no double quotes inside, and pick a phrase that sits on one line of the file.
#
# Usage: hooks/check-retired.sh [project-dir]
#
# project-dir defaults to the git repo this folder lives in, so an installed
# copy in your-project/context/ searches all of your-project, not just context/.
# In a git repo, files ignored by .gitignore are skipped.
# Exits 0 if nothing is left, 1 if a retired sentence is still there, 2 on an
# error such as a Retires line with nothing quoted.

set -euo pipefail

CTX="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
ROOT="${1:-$(git -C "$CTX" rev-parse --show-toplevel 2>/dev/null || echo "$CTX")}"
DECISIONS="$CTX/DECISIONS.md"

[ -f "$DECISIONS" ] || { echo "check-retired: no DECISIONS.md in $CTX" >&2; exit 2; }
[ -d "$ROOT" ] || { echo "check-retired: no such directory: $ROOT" >&2; exit 2; }
ROOT="$(cd "$ROOT" && pwd -P)"

# One "D-00N<TAB>sentence" per quote. Skips the format example in the code
# fence at the top, and anything not under a numbered decision. Quotes too
# short to match safely, or cut in two by a quote inside, are skipped with a
# warning. A Retires line left with nothing usable to search for is an error.
RETIRED="$(awk '
  { sub(/\r$/, "") }
  # An unclosed fence hides the rest of the file, the same way it renders.
  /^```/ { fence = !fence; next }
  fence { next }
  /^## D-[0-9]+/ { id = $2; next }
  /^(\*\*)?Retires:(\*\*)?/ && id {
    line = $0; n = 0
    while (match(line, /"[^"]*"/)) {
      s = substr(line, RSTART + 1, RLENGTH - 2)
      line = substr(line, RSTART + RLENGTH)
      if (length(s) < 12 || s !~ /[A-Za-z]/ || s ~ /^ | $/)
        print "check-retired: " id " skips \"" s "\", too short or cut by a quote inside it" > "/dev/stderr"
      else {
        print id "\t" s; n++
      }
    }
    if (!n) { print "check-retired: " id " has a Retires line with no \"quoted\" sentences" > "/dev/stderr"; bad = 1 }
  }
  END { exit bad ? 2 : 0 }
' "$DECISIONS")" || exit 2

[ -n "$RETIRED" ] || exit 0

# The context files themselves quote retired sentences on purpose.
case "$CTX/" in
  "$ROOT"/*) REL="${CTX#"$ROOT"}/"; REL="${REL#/}" ;;
  *) REL="//none/" ;;
esac

# Lists files containing the sentence, NUL separated so any file name works.
# git grep skips what .gitignore ignores. -l --null prints the same on GNU and
# BSD grep, unlike -Z, which BSD grep reads as decompress. LC_ALL=C keeps a
# file with a stray non-UTF-8 byte from being treated as binary and missed.
files_with() {
  if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$ROOT" grep -lIF --untracked --null -e "$1" -- . || true
  else
    (cd "$ROOT" && LC_ALL=C grep -rlIF --null --exclude-dir=.git -e "$1" . || true)
  fi
}

FOUND=0
while IFS=$'\t' read -r id sentence; do
  while IFS= read -r -d '' file; do
    file="${file#./}"
    case "$file" in
      "${REL}DECISIONS.md" | "${REL}DECISIONS-archive.md" | "${REL}REOPENED.md" | "${REL}inbox/"*) continue ;;
    esac
    while IFS=: read -r line _; do
      echo "$file:$line  still says: \"$sentence\"  (retired by $id)"
      FOUND=1
    done < <(LC_ALL=C grep -anF -e "$sentence" -- "$ROOT/$file")
  done < <(files_with "$sentence")
done <<< "$RETIRED"

exit "$FOUND"
