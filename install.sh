#!/usr/bin/env bash
# Add team-context to a project in one step.
#
#   ./install.sh ~/code/my-project
#
# Copies the shared files into <project>/context/, wires the session-end hook
# into <project>/.claude/settings.json, and points the project's CLAUDE.md and
# AGENTS.md at the shared files. Safe to run twice: it never overwrites a
# file that already exists, and it skips any step that's already done.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TARGET="$(cd "${1:?usage: ./install.sh <project-dir>}" && pwd -P)"
NAME="${TEAM_CONTEXT_DIR:-context}"
DEST="$TARGET/$NAME"
MARK="<!-- team-context -->"

command -v jq >/dev/null 2>&1 || { echo "install: needs jq (brew install jq, or apt install jq)" >&2; exit 1; }
[ "$TARGET" != "$SRC" ] || { echo "install: this repo is already set up, just open Claude Code here." >&2; exit 0; }

echo "Installing team-context into $DEST"

mkdir -p "$DEST/inbox"
for f in AGENTS.md PLAN.md DECISIONS.md STATE.md REOPENED.md .gitignore; do
  [ -e "$DEST/$f" ] || cp "$SRC/$f" "$DEST/$f"
done
[ -e "$DEST/inbox/README.md" ] || cp "$SRC/inbox/README.md" "$DEST/inbox/"
for d in templates hooks; do
  mkdir -p "$DEST/$d"
  for f in "$SRC/$d"/*; do [ -e "$DEST/$d/$(basename "$f")" ] || cp -p "$f" "$DEST/$d/"; done
done
chmod +x "$DEST"/hooks/*.sh

# Hook: add it to the project's settings unless it's already there.
SETTINGS="$TARGET/.claude/settings.json"
CMD="bash \"\$CLAUDE_PROJECT_DIR/$NAME/hooks/draft-decision.sh\""
mkdir -p "$TARGET/.claude"
[ -s "$SETTINGS" ] || echo '{}' > "$SETTINGS"
if grep -q 'draft-decision.sh' "$SETTINGS"; then
  echo "  hook already in .claude/settings.json"
else
  jq --arg cmd "$CMD" '.hooks.SessionEnd += [{hooks: [{type: "command", command: $cmd, timeout: 120}]}]' \
    "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
  echo "  added the session-end hook to .claude/settings.json"
fi

# CLAUDE.md: import the shared files so Claude loads them every session.
if grep -qF "$MARK" "$TARGET/CLAUDE.md" 2>/dev/null; then
  echo "  CLAUDE.md already imports team-context"
else
  printf '\n%s\n## Team context\n@%s/AGENTS.md\n@%s/PLAN.md\n@%s/DECISIONS.md\n@%s/STATE.md\n' \
    "$MARK" "$NAME" "$NAME" "$NAME" "$NAME" >> "$TARGET/CLAUDE.md"
  echo "  CLAUDE.md now imports $NAME/"
fi

# AGENTS.md: Codex and others don't follow imports, so leave a pointer.
if grep -qF "$MARK" "$TARGET/AGENTS.md" 2>/dev/null; then
  echo "  AGENTS.md already points at team-context"
else
  printf '\n%s\n## Team context\nBefore starting, read `%s/AGENTS.md` and follow it. It points you at `%s/PLAN.md`, `%s/DECISIONS.md` and `%s/STATE.md`.\n' \
    "$MARK" "$NAME" "$NAME" "$NAME" "$NAME" >> "$TARGET/AGENTS.md"
  echo "  AGENTS.md now points at $NAME/"
fi

cat <<EOF

Done. Next:
  1. Fill in $NAME/PLAN.md with your team, before anyone opens Claude.
  2. Change the Owner lines and "Last updated" in $NAME/DECISIONS.md and $NAME/STATE.md.
  3. Commit: git -C "$TARGET" add $NAME .claude/settings.json CLAUDE.md AGENTS.md
  4. Work as usual. When a session ends, drafts land in $NAME/inbox/.
     Want each draft as a pull request instead? export TEAM_CONTEXT_PR=1 (needs gh).
EOF
