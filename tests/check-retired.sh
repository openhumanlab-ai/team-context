#!/usr/bin/env bash
# Test hooks/check-retired.sh in both layouts: this repo's, where the files sit
# at the root, and an installed project's, where they sit under context/.
#
# Usage: tests/check-retired.sh

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

# Copies the checker into <dir>/hooks and writes a DECISIONS.md with a format
# example (must be ignored) and one decision retiring two sentences.
setup() {
  mkdir -p "$1/hooks"
  cp "$SRC/hooks/check-retired.sh" "$1/hooks/"
  cat > "$1/DECISIONS.md" <<'EOF'
# Decisions

```
Retires: "the exact sentence this makes false"
```

## D-004  2026-09-28  Postgres queue instead of Redis
Chose: pg-boss on the Postgres we already run.
Ruled out: Redis (one more thing to run).
Revisit if: queue latency matters to a user.
Owner: Ram
Supersedes: D-002
Retires: "We use Redis for the job queue." "Jobs run inside the request." "Redis"
EOF
}

# Runs the checker, saving its output, warnings and exit code.
check() {
  set +e
  OUT="$("$@" 2> "$TMP/err")"
  CODE=$?
  set -e
  ERR="$(cat "$TMP/err")"
}

# 1. Repo layout: sentences still in STATE.md and a file with a space in its name.
R="$TMP/repo"
setup "$R"
printf '# State\n\n- We use Redis for the job queue.\n' > "$R/STATE.md"
mkdir -p "$R/docs" "$R/inbox"
printf 'Note: Jobs run inside the request.\n' > "$R/docs/old notes.md"
printf 'We use Redis for the job queue.\n' > "$R/inbox/x-draft.md"
printf 'We use Redis for the job queue.\n' > "$R/REOPENED.md"

check "$R/hooks/check-retired.sh"
echo "$OUT"
[ "$CODE" = 1 ] || fail "expected exit 1 with retired sentences present, got $CODE"
grep -qF 'STATE.md:3  still says: "We use Redis for the job queue."  (retired by D-004)' <<< "$OUT" \
  || fail "STATE.md hit missing"
grep -qF 'docs/old notes.md:1  still says: "Jobs run inside the request."  (retired by D-004)' <<< "$OUT" \
  || fail "hit in a file name with a space missing"
[ "$(grep -c . <<< "$OUT")" = 2 ] || fail "expected exactly 2 hits (inbox, REOPENED.md, the format example ignored)"
grep -qF 'skips "Redis"' <<< "$ERR" || fail "a short quote should be skipped with a warning"

printf '# State\n\n- Jobs go through pg-boss.\n' > "$R/STATE.md"
rm "$R/docs/old notes.md"
check "$R/hooks/check-retired.sh"
[ "$CODE" = 0 ] && [ -z "$OUT" ] || fail "expected a quiet exit 0 once the sentences are gone, got $CODE: $OUT"

# 2. No Retires lines at all: quiet exit 0.
N="$TMP/none"
mkdir -p "$N/hooks"
cp "$SRC/hooks/check-retired.sh" "$N/hooks/"
cp "$SRC/DECISIONS.md" "$N/DECISIONS.md"
printf 'We use Redis for the job queue.\n' > "$N/STATE.md"
check "$N/hooks/check-retired.sh"
[ "$CODE" = 0 ] && [ -z "$OUT" ] || fail "expected a quiet exit 0 with no Retires lines, got $CODE: $OUT"

# 3. A Retires line with curly quotes quotes nothing: warn and exit 2.
C="$TMP/curly"
setup "$C"
printf '\n## D-005  2026-09-28  Curly\nRetires: \342\200\234Curly quoted sentence here.\342\200\235\n' >> "$C/DECISIONS.md"
check "$C/hooks/check-retired.sh"
[ "$CODE" = 2 ] || fail "expected exit 2 for a Retires line with no straight quotes, got $CODE"
grep -qF 'D-005 has a Retires line with no "quoted" sentences' <<< "$ERR" || fail "curly quote warning missing"

# 4. A Retires line whose only quote is too short to search for: exit 2.
S="$TMP/short"
setup "$S"
printf '\n## D-006  2026-09-28  Short\nRetires: "Redis"\n' >> "$S/DECISIONS.md"
check "$S/hooks/check-retired.sh"
[ "$CODE" = 2 ] || fail "expected exit 2 when every quote on a Retires line is skipped, got $CODE"
grep -qF 'D-006 has a Retires line with no "quoted" sentences' <<< "$ERR" || fail "all-skipped warning missing"

# 5. Installed layout: the checker lives in context/hooks and still searches the
# whole project, so a stale sentence in the project README is found.
P="$TMP/project"
setup "$P/context"
git -C "$P" init -q
printf 'Background work: We use Redis for the job queue.\n' > "$P/README.md"
mkdir -p "$P/src/features/inbox" "$P/node_modules/pkg" "$P/context/inbox"
printf 'Jobs run inside the request.\n' > "$P/src/features/inbox/jobs.md"
printf 'Caf\351: We use Redis for the job queue.\n' > "$P/latin1.md"
printf 'We use Redis for the job queue.\n' > "$P/node_modules/pkg/notes.md"
printf 'We use Redis for the job queue.\n' > "$P/context/inbox/x-draft.md"
printf 'node_modules/\n' > "$P/.gitignore"
check "$P/context/hooks/check-retired.sh"
echo "$OUT"
[ "$CODE" = 1 ] || fail "expected exit 1 in the installed layout, got $CODE"
grep -qF 'README.md:1  still says: "We use Redis for the job queue."  (retired by D-004)' <<< "$OUT" \
  || fail "project README hit missing in the installed layout"
grep -qF 'src/features/inbox/jobs.md:1' <<< "$OUT" || fail "a folder named inbox outside context/ should still be searched"
grep -qF 'latin1.md:1' <<< "$OUT" || fail "a file with a non-UTF-8 byte should still be searched"
[ "$(grep -c . <<< "$OUT")" = 3 ] || fail "expected exactly 3 hits (node_modules is gitignored, context/inbox is skipped)"

echo "ok: check-retired.sh"
