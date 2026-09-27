# team-context

A small, boring way to stop context getting lost between people and their AI.

This started as a LinkedIn post. I asked if anyone had solved the problem of my Claude knowing how I think, my team's Claude not knowing, and every handoff making it worse. 160+ people replied. Nobody had a finished answer, but together they got closer than any tool I looked at. This repo is what came out of it.

We're a 7 person startup. This is what we're trying. If you think it's wrong, open an issue or a PR.

## Try it in two minutes

You need `jq` and the `claude` CLI.

```
git clone https://github.com/openhumanlab-ai/team-context && cd team-context

hooks/digest.sh examples/sample-session.jsonl                        # what the drafter reads (no API call)
hooks/draft-decision.sh --transcript examples/sample-session.jsonl   # draft a decision from a sample session

./install.sh ~/code/your-project                                     # add it to a real project
```

The sample is a short session where the AI recommends Redis, the human says no, and they settle on a Postgres queue. The draft should say pg-boss was chosen and Redis was ruled out. Then run it on one of your own sessions from `~/.claude/projects/`.

## The problem

When one person uses Claude Code or Codex for weeks, the AI builds up context. The trade-offs, why one thing was chosen over another, what was ruled out.

Then they hand the output to a teammate. The teammate gets the answer, not the thinking.

The teammate takes it to their own AI for the next task. Now the AI is working off a copy of a copy. And each copy sounds more sure than the last, because the hedging gets dropped at every hop.

By the third person the gap is huge. Not because anyone is slow. Because context doesn't travel well.

## What the thread agreed on

Five things came up over and over, from people who didn't know each other.

**1. It's not new.** This is tribal knowledge. Every team has had it. AI just made every handoff compound in a week instead of a year.

**2. Write the decision, not the thinking.** The thinking goes stale in a week. The rejected options don't. Record what you chose, what you ruled out, and what would make you revisit it. Don't try to capture reasoning.

**3. Split by shelf life, not by topic.** One doc rots because it holds two things: judgment that's true for months and state that's wrong by Friday. Once someone hits the stale half they stop trusting the whole file. Keep them apart.

**4. The agent drafts, a human approves.** Nobody writes docs mid-flow. So have the agent draft the note at the end of a session, and treat it like a PR. Nothing goes into shared memory without someone approving it.

**5. Plan before output.** The plan gets written by humans before any AI produces anything. Otherwise the plan ends up describing what exists instead of what was agreed.

And one thing not to share: how each person thinks. Everyone's agent thinking like the founder is a bug, not a feature.

Two smaller points that changed the design:

- The next person needs to know which assumptions are settled and which are still open. That's different from a decision. So `STATE.md` has an open assumptions section.
- Rules files bloat. One person had twelve rules added in a day and a review cut eleven. So a rule needs two real instances before it goes in.

And one challenge nobody in the thread answered: what evidence would show this is a real gain, rather than pushing review and debugging downstream? Escaped defects, rollback time, how often a decision gets re-litigated. We're going to measure the last one, because it's the cheapest. See "How we'll know" below.

## What's in this repo

```
team-context/
├── README.md              this file
├── DECISIONS.md           the log, one entry per decision (long shelf life)
├── STATE.md               what's true right now (short shelf life)
├── REOPENED.md            one line each time a settled decision gets re-argued
├── PLAN.md                what we agreed to build before any AI touched it
├── AGENTS.md              instructions for every agent (Claude Code, Codex, Cursor)
├── CLAUDE.md              imports AGENTS.md and the three files, so Claude always has them loaded
├── install.sh             adds all of this to a project in one step
├── templates/
│   └── decision.md        the three line template
├── hooks/
│   ├── draft-decision.sh  Claude Code hook: drafts a note when a session ends
│   ├── digest.sh          shrinks a transcript to what humans and the AI said
│   ├── propose.sh         turns a draft into a pull request
│   └── README.md          how it works, settings
├── examples/
│   └── sample-session.jsonl   a made-up session to try the hook on
└── .claude/
    └── settings.json      wires the hook into Claude Code
```

## The rules

**One repo. Markdown.** Agent memory and chat history are throwaway. This repo is the memory. If it's not here, it wasn't decided.

**Two files, split by how fast they go stale.**
- `DECISIONS.md` holds things that stay true for months. Append only. Old decisions get marked superseded, never deleted.
- `STATE.md` holds things that are true this week. Overwrite freely. Anyone can update it.

**Every decision has three lines.**
- What we chose
- What we ruled out
- What would make us revisit it

That third line is the one that matters. A decision with an exit condition can be questioned later. A decision without one becomes "we've always done it this way."

**The agent drafts, a human approves.** The hook in `hooks/` fires when a Claude Code session ends and drafts a decision note into `inbox/`. Someone reads it and moves it into `DECISIONS.md`, or deletes it. Or set `TEAM_CONTEXT_PR=1` and each draft arrives as a pull request, so approving is merging. Nothing goes in automatically.

**The drafter reads what people said, not what tools printed.** Tool calls and their output are dropped before anything is drafted, and old turns are cut short rather than summarised. The idea comes from CliffCompaction (arXiv 2609.26779): summaries of summaries drift, cutting doesn't. Details in `hooks/README.md`.

**Plan before code, and humans keep the plan.** `PLAN.md` gets written in a conversation between humans, before anyone opens Claude. When something changes, humans sit down, update it, and record why in `DECISIONS.md`. The agent reads the plan. It doesn't write it.

**A rule needs two real instances.** Before anything goes into `PLAN.md` under constraints, it has to have bitten twice. One incident is an anecdote. Rules files bloat otherwise and nobody reads them.

**Personal preferences stay personal.** How you like code explained, which shortcuts you use, how terse you want the agent to be. That lives in your own user memory, not here. If you find yourself needing memory to make the agent behave, that's usually a sign something in the plan or constraints should be explicit and isn't.

## How we'll know

We'll count one thing: how often a decision that's already in `DECISIONS.md` gets re-opened in a session or a conversation because someone didn't know it was decided. Each one is a line in `REOPENED.md`, which is append-only so the history survives. If that number doesn't drop, this isn't working.

If you're running this and can measure escaped defects or rollback time before and after, that would be a much better signal. Please share it.

## How to use it

1. Run `./install.sh <your-project>`. It copies the files into `<your-project>/context/`, wires up the hook, and points your `CLAUDE.md` and `AGENTS.md` at the shared files. It never overwrites anything that's already there.
2. Sit down with your team and fill in `context/PLAN.md`. Commit.
3. Have a conversation, agree on something, write it in `DECISIONS.md` using the template. Three lines. Takes a minute.
4. When a session ends, check `inbox/` (or your open PRs, if you turned that on). Approve or delete.

## What we don't know yet

- Whether people keep doing this past week three. Every documentation habit dies around then. One person in the thread said the only thing that ever made it stick was a founder requiring it.
- Whether the split between DECISIONS and STATE stays clean or whether state creeps back in.
- What to do about decisions made on a call or in Slack, where no agent is present to draft anything.
- Whether this works for non-engineering decisions. Pricing, hiring, what to say to a customer. Someone already piloting a repo like this reports real friction for non-technical people using the GitHub UI.

If you've solved any of those, that's the PR I most want.

## Tools people pointed at

If you'd rather buy than build, these came up in the thread. I haven't tried most of them. No endorsement, just a list so you don't have to dig.

Shared context for agent teams: SageOx (open-source `ox` CLI), P30.ai, ArtifactBridge, OzBrain, Nimble, Gbrain, Makina, The Memory Company.
Memory layers: Mem0, supermemory.ai, honcho.
Git-level context: entire.io, repopact, Tencent teamai-cli, chakramcp.
Skills worth a look: Matt Pocock's /teach and /handoff.

## Credit

This came from a LinkedIn thread with 160+ comments. The people whose ideas are in here: Charlie Lambropoulos, Zeeshan Ahmad, Ankit Parasher, Hamza Khan, Matthew Mathison, Manik Arya, Lev Goriachev, Aaron Xie, Arnab Mandal, Noor Imran, Andrew Graham, Mokshit Jain, Haggai Guggenheimer, Sinuhé Coronel Salinas, Bart Schuijt, Lucas Daniel, Ganesh Vaideeswaran, Max Tappenden, Jeremy Falcon, Mahadevan B, Niall Moran, Nikita Savchenko, Colin Smillie, John Wilkinson, Muhammad Farooq, Kaya Kinli, Rishab Motgi, Jarrod De Lange, and many others.

Maintained by Ramanujam MV, openhuman. MIT licence, do what you want with it.
