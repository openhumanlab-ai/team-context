# team-context

Shared context for a team where everyone works with their own AI agent.

My Claude knew how I think. My team's Claude didn't, and every handoff lost more. I asked on LinkedIn how people handle this. 70+ people replied. This repo is what I took from the thread. We're a 7 person team trying it now.

## How it works

- `PLAN.md`: what we're building and not building. Written by humans before any AI output. Agents read it, never write it.
- `DECISIONS.md`: append-only. Each entry is what we chose, what we ruled out, and what would make us revisit.
- `STATE.md`: what's true this week. Overwrite freely.
- `REOPENED.md`: one line each time a settled decision gets argued again. The one number we track.
- A Claude Code hook drafts a decision note when a session ends. A human approves it (inbox, or a PR with `TEAM_CONTEXT_PR=1`). Nothing goes in automatically.

`CLAUDE.md` imports these files so Claude always has them loaded. `AGENTS.md` has the same instructions for Codex and Cursor.

## Try it

Needs `jq` and the `claude` CLI.

```
git clone https://github.com/openhumanlab-ai/team-context && cd team-context

hooks/digest.sh examples/sample-session.jsonl                        # what the drafter reads, no API call
hooks/draft-decision.sh --transcript examples/sample-session.jsonl   # draft a decision from it
```

In the sample, the AI recommends Redis, the human says no, and they pick a Postgres queue. The draft should say pg-boss chosen, Redis ruled out.

## Install

```
./install.sh ~/code/your-project
```

Copies the files into `your-project/context/`, adds the hook to `.claude/settings.json`, and points your `CLAUDE.md` and `AGENTS.md` at them. Never overwrites existing files. Then fill in `context/PLAN.md` with your team and commit. More on the hook in `hooks/README.md`.

## Rules we took from the thread

1. Record the decision, not the reasoning. Reasoning goes stale. Rejected options don't.
2. Split by shelf life. Long-lived decisions and this week's state in one file means people stop trusting all of it.
3. Every decision needs a "revisit if". Without one it becomes a rule nobody can question.
4. The agent drafts, a human approves.
5. Humans write the plan before the AI produces anything.
6. A rule goes into the plan only after it has bitten twice. Rules files bloat otherwise.
7. Personal preferences stay in personal memory. Everyone's agent thinking like one person is a bug.

The drafter drops tool calls and output, and cuts old turns instead of summarising them, following CliffCompaction (arXiv 2609.26779).

## Open questions

- Does anyone keep this up past week three?
- Decisions made on calls or in Slack, where no agent is present.
- Non-engineering decisions, and non-technical people using GitHub.
- Better evidence than the re-opened count, like escaped defects or rollback time.

PRs on any of these welcome.

## Tools people mentioned

Not tried, not endorsed. Shared context: SageOx (`ox` CLI), P30.ai, ArtifactBridge, OzBrain, Nimble, Gbrain, Makina, The Memory Company. Memory layers: Mem0, supermemory.ai, honcho. Git-level: entire.io, repopact, Tencent teamai-cli, chakramcp. Skills: Matt Pocock's /teach and /handoff.

## Credit

Ideas from Charlie Lambropoulos, Zeeshan Ahmad, Ankit Parasher, Hamza Khan, Matthew Mathison, Manik Arya, Lev Goriachev, Aaron Xie, Arnab Mandal, Noor Imran, Andrew Graham, Mokshit Jain, Haggai Guggenheimer, Sinuhé Coronel Salinas, Bart Schuijt, Lucas Daniel, Ganesh Vaideeswaran, Max Tappenden, Jeremy Falcon, Mahadevan B, Niall Moran, Nikita Savchenko, Colin Smillie, John Wilkinson, Muhammad Farooq, Kaya Kinli, Rishab Motgi, Jarrod De Lange, and others in the thread.

MIT licence. Maintained by Ramanujam MV, openhuman.
