#!/usr/bin/env bash
# Turn a Claude Code session transcript into a short digest for the drafter.
#
# Compaction in the style of CliffCompaction (arXiv 2609.26779): content is
# dropped or truncated by class, never rephrased, and a prior compaction
# summary is never folded forward.
#
#   dropped    tool calls, tool results, thinking, images, system reminders,
#              slash-command noise, subagent (sidechain) turns, compaction summaries
#   kept       first human message (the task), up to FIRST_MAX chars
#              last RECENT turns, up to RECENT_MAX chars each
#   truncated  older human turns to HUMAN_MAX chars (humans make the decisions)
#              older AI turns to a 300 char head + 200 char tail
#
# If the result is still over MAX_CHARS, the oldest turns after the first
# message are dropped until it fits.
#
# Usage: hooks/digest.sh path/to/transcript.jsonl

set -euo pipefail

TRANSCRIPT="${1:?usage: digest.sh <transcript.jsonl>}"
command -v jq >/dev/null 2>&1 || { echo "digest.sh needs jq" >&2; exit 1; }

MAX_CHARS="${TEAM_CONTEXT_MAX_CHARS:-40000}"
RECENT="${TEAM_CONTEXT_RECENT_TURNS:-6}"
FIRST_MAX=8000
RECENT_MAX=4000
HUMAN_MAX=2000

# Pass 1, line by line: keep only what a human typed and what the AI said.
jq -R -c '
  fromjson? // empty
  | select(.type == "user" or .type == "assistant")
  | select((.isMeta // false | not) and (.isSidechain // false | not) and (.isCompactSummary // false | not))
  | .message as $m
  | (if ($m.content | type) == "string" then $m.content
     else [ $m.content[]? | select(.type == "text") | .text ] | join("\n") end)
  | gsub("<system-reminder>[\\s\\S]*?</system-reminder>"; "")
  | gsub("^\\s+|\\s+$"; "")
  | select(. != "")
  | select(test("^<(command-|local-command-)|^\\[Request interrupted") | not)
  | { r: (if $m.role == "user" then "HUMAN" else "AI" end), t: . }
' "$TRANSCRIPT" |
# Pass 2, whole session: truncate by class, then fit the budget.
jq -s -r \
  --argjson max "$MAX_CHARS" --argjson recent "$RECENT" \
  --argjson first_max "$FIRST_MAX" --argjson recent_max "$RECENT_MAX" --argjson human_max "$HUMAN_MAX" '
  def clip($head; $tail):
    if length <= $head + $tail then . else .[:$head] + " [...] " + .[-$tail:] end;
  def fit($max):
    . as $a
    | if length == 0 then [] else
        reduce ($a[1:] | reverse)[] as $s ({keep: [], used: ($a[0] | length), full: false};
          if .full then .
          elif .used + ($s | length) <= $max then .keep = [$s] + .keep | .used += ($s | length)
          else .full = true end)
        | [$a[0]] + (if .full then ["[... earlier turns dropped to fit ...]"] else [] end) + .keep
      end;

  . as $all | length as $n
  | [ range(0; $n) as $i | $all[$i] as $x
      | ( if $i == 0 then $x.t | clip($first_max - 1000; 1000)
          elif $i >= $n - $recent then $x.t | clip($recent_max - 1000; 1000)
          elif $x.r == "HUMAN" then $x.t | clip($human_max - 500; 500)
          else $x.t | clip(300; 200) end ) as $t
      | "\($x.r): \($t)" ]
  | fit($max)
  | join("\n\n")
'
