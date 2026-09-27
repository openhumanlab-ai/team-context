#!/usr/bin/env bash
# Claude Code hook: when a session ends, draft a decision note into inbox/.
# A human approves it into DECISIONS.md or deletes it. Nothing is written
# into DECISIONS.md automatically.
#
# As a SessionEnd hook, Claude Code passes JSON on stdin with transcript_path.
# To try it by hand on any transcript:
#   hooks/draft-decision.sh --transcript examples/sample-session.jsonl
#
# Settings (environment variables, all optional):
#   TEAM_CONTEXT_PR=1       also open a pull request with the draft (needs gh)
#   TEAM_CONTEXT_MODEL=...  model for the drafter, e.g. sonnet or haiku

set -euo pipefail

# The drafter below is itself a Claude session. Without this guard its own
# SessionEnd would run this hook again.
[ -n "${TEAM_CONTEXT_DRAFTING:-}" ] && exit 0

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HOOK_DIR/.." && pwd)"
INBOX="$REPO_ROOT/inbox"
TEMPLATE="$REPO_ROOT/templates/decision.md"

MANUAL=0
if [ "${1:-}" = "--transcript" ]; then
  TRANSCRIPT="${2:?usage: draft-decision.sh --transcript <file.jsonl>}"
  MANUAL=1
else
  command -v jq >/dev/null 2>&1 || exit 0
  TRANSCRIPT="$(jq -r '.transcript_path // empty' 2>/dev/null || true)"
fi

say() { [ "$MANUAL" = 1 ] && echo "team-context: $*" >&2; return 0; }

# The hook should never break a session, so missing tools mean a quiet exit.
for tool in jq claude; do
  command -v "$tool" >/dev/null 2>&1 || { say "needs $tool on PATH"; exit 0; }
done
[ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ] || { say "no transcript at '$TRANSCRIPT'"; exit 0; }

CONTEXT="$("$HOOK_DIR/digest.sh" "$TRANSCRIPT" || true)"
[ -n "$CONTEXT" ] || { say "nothing a human said in that transcript"; exit 0; }

OWNER="$(git -C "$REPO_ROOT" config user.name 2>/dev/null || true)"
OWNER="${OWNER:-unknown}"
TODAY="$(date +%Y-%m-%d)"

PROMPT="You are drafting a decision note from a coding session. Below is a digest of the session: HUMAN lines are what the person typed, AI lines are what the assistant said. Tool calls and outputs have been removed.

A decision counts only if the HUMAN settled it: they chose something and something else was ruled out. An option the AI suggested that the human did not accept is not a decision. Neither is routine implementation work.

If there is a decision, fill in this template. Three lines plus Owner. No reasoning, no summary of the session.

$(sed '/^<!--/,/^-->/d' "$TEMPLATE")

Use the date $TODAY. Owner is $OWNER. Leave D-XXX exactly as written, the number is assigned when a human approves it.

Output only the filled template as plain text. No commentary, no code fences.

If no decision was settled, reply with exactly: NO_DECISION

Session digest:
$CONTEXT"

MODEL_ARGS=()
[ -n "${TEAM_CONTEXT_MODEL:-}" ] && MODEL_ARGS=(--model "$TEAM_CONTEXT_MODEL")

say "asking claude whether a decision was made..."
RESULT="$(printf '%s' "$PROMPT" | TEAM_CONTEXT_DRAFTING=1 claude -p \
  --tools "" --no-session-persistence --output-format text ${MODEL_ARGS[@]+"${MODEL_ARGS[@]}"} \
  2>/dev/null || true)"

if [ -z "$RESULT" ] || printf '%s' "$RESULT" | grep -q 'NO_DECISION'; then
  say "no decision in that session, nothing drafted"
  exit 0
fi
# Drop anything that isn't shaped like the template rather than file junk.
if ! printf '%s' "$RESULT" | grep -q '^Chose:' || ! printf '%s' "$RESULT" | grep -q '^## '; then
  say "drafter returned something that isn't a decision note, discarded"
  exit 0
fi

mkdir -p "$INBOX"
OUT="$INBOX/$(date +%Y-%m-%d-%H%M%S)-draft.md"
{
  echo "<!-- DRAFT. Drafted by the session-end hook. Read it, then move into DECISIONS.md or delete. -->"
  echo
  printf '%s\n' "$RESULT"
} > "$OUT"

if [ "$MANUAL" = 1 ]; then
  cat "$OUT"
  echo
  echo "team-context: saved to inbox/$(basename "$OUT")" >&2
fi

if [ "${TEAM_CONTEXT_PR:-}" = 1 ]; then
  "$HOOK_DIR/propose.sh" "$OUT" >&2 || say "could not open a PR, the draft is still in inbox/"
fi
