# Decisions

Things that stay true for months. Append only. When a decision changes, add a new entry and mark the old one superseded. Never delete. When this file gets long, move superseded entries to DECISIONS-archive.md so agents only load what's live.

Each decision gets the next number (D-001, D-002, ...) so agents and people can point at it exactly. Each entry is three lines plus a header. If you're writing more than that, you're capturing thinking, and thinking goes stale. Stop.

Format:

```
## D-XXX  YYYY-MM-DD  Short title
Chose: what we decided
Ruled out: what we didn't, and the one line why
Revisit if: the condition that would reopen this
Owner: who to ask
```

Two optional lines. When a decision replaces an old one, add `Supersedes: D-00N`. When it makes a sentence elsewhere false, add a `Retires:` line quoting it word for word, for example `Retires: "We use Redis for the job queue."`. `hooks/check-retired.sh` finds any of those sentences still sitting in the project.

---

## D-001  2026-09-24  Context lives in this repo, not in agent memory
Chose: this repo is the shared memory for humans and agents. Agent memory and chat history are throwaway.
Ruled out: a shared memory tool (too early to pay for one, want to know what we actually need first). Sharing personal Claude memory files (makes everyone's agent think like one person).
Revisit if: the repo stops being updated for two weeks, or we go past 15 people.
Owner: Ram

## D-002  2026-09-24  Split decisions from state
Chose: DECISIONS.md for things true for months, STATE.md for things true this week.
Ruled out: one file (it rots, the stale half makes people stop trusting the good half).
Revisit if: state keeps leaking into DECISIONS.md, or nobody reads STATE.md.
Owner: Ram

## D-003  2026-09-24  Agent drafts, human approves
Chose: a session-end hook drafts a decision note into inbox/. A person moves it into DECISIONS.md or deletes it.
Ruled out: auto-commit from the agent (nobody trusts what they didn't read). No hook at all (nobody writes mid-flow, so nothing gets written).
Revisit if: inbox/ has more than 10 unread notes, which means approval is the bottleneck.
Owner: Ram

<!-- Add new entries above this line. Newest at the bottom of the list. -->
