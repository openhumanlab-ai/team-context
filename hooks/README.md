# The session-end hook

When a Claude Code session ends, `draft-decision.sh` compacts the transcript, asks Claude whether a human settled a trade-off, and if so writes a three line draft into `inbox/`. It never touches `DECISIONS.md`.

Needs `jq` and the `claude` CLI on your PATH. If either is missing the hook exits quietly, so it can never break a session.

## Try it without a real session

```
hooks/digest.sh examples/sample-session.jsonl                          # what the drafter sees, no API call
hooks/draft-decision.sh --transcript examples/sample-session.jsonl     # draft a note from it
```

Point either one at a real transcript in `~/.claude/projects/<your-project>/` to see what it makes of your own sessions.

## Install

`./install.sh <your-project>` from the repo root does all of this. By hand: if this repo is your project root, it's already wired up through `.claude/settings.json`. Otherwise copy the `hooks` block from that file into your project's `.claude/settings.json` and point the path at this script.

## What the drafter sees

A 20KB session becomes about 1KB. `digest.sh` borrows the rules from CliffCompaction (arXiv 2609.26779): drop or truncate by class, never rephrase, and never feed an old summary back in.

- Dropped: tool calls, tool output, thinking, system reminders, slash commands, subagent turns, earlier compaction summaries. Tool output is where most of the bulk is, and it's also where secrets from `.env` files and logs turn up.
- Kept whole: the first message (the task) and the last few turns.
- Truncated: older human messages to 2,000 characters, older AI messages to a short head and tail. Humans make the decisions, so their words get the most room.

The drafter is told that only the human can settle a decision. If the AI suggested Redis and the human said no, Redis goes under "Ruled out", not "Chose".

## Approving a draft

Two ways, pick one per team.

**Inbox (default).** Open the file in `inbox/`. If it's right, paste the block into `DECISIONS.md`, swap D-XXX for the next number, and delete the draft. If it's wrong, delete it. Drafts are gitignored, so only the person who ran the session sees them.

**Pull request.** `export TEAM_CONTEXT_PR=1` and every draft becomes a PR that adds it to `DECISIONS.md` with the next decision number filled in. Merging is approving, closing is rejecting. Needs the GitHub CLI (`gh auth login`). You can also turn a single draft into a PR by hand:

```
hooks/propose.sh --dry-run inbox/<file>-draft.md   # see the commit, push nothing
hooks/propose.sh inbox/<file>-draft.md             # open the PR
```

It works in a throwaway git worktree, so your current branch and uncommitted changes are left alone.

If more than 10 drafts or decision PRs are sitting there unread, approval is the bottleneck, and it's worth a conversation about who owns it.

## Settings

| Variable | Default | What it does |
|---|---|---|
| `TEAM_CONTEXT_PR` | off | `1` opens a PR for every draft |
| `TEAM_CONTEXT_MODEL` | your default | model for the drafter, e.g. `haiku` to keep it cheap |
| `TEAM_CONTEXT_MAX_CHARS` | 40000 | size cap for the digest |
| `TEAM_CONTEXT_RECENT_TURNS` | 6 | turns at the end kept whole |

## What it doesn't do

- Doesn't write to `DECISIONS.md`. A human does that, or merges the PR.
- Doesn't run on every message, only when the session ends.
- Doesn't send your transcript anywhere except to your own Claude CLI. The drafter runs with no tools and isn't saved as a session.

## Codex and other agents

Codex doesn't have the same hook system yet. For now, `AGENTS.md` tells it to draft the note itself at the end of a session. Same template, same inbox. If you know a cleaner way, open a PR.
