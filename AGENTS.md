# Read this before you do anything

This project keeps its shared context in three files, in the same folder as this one. If they aren't already in your context, read them in this order before starting work:

1. `PLAN.md`: what we agreed to build and what we're not building. If the code disagrees with the plan, the plan wins until a human changes it.
2. `DECISIONS.md`: what we chose, what we ruled out, and what would make us revisit. Do not undo a decision listed here. If you think one is wrong, say so and stop. Don't work around it.
3. `STATE.md`: what's true this week. Active work, handoffs, open questions. May be slightly stale. If something in it looks wrong, flag it.

## When you finish a session

Claude Code: skip this paragraph, the session-end hook drafts the note for you. Codex, Cursor and anything else without that hook: if a trade-off was settled during this session, write a draft decision note into `inbox/` using `templates/decision.md`, leaving the number as D-XXX. Three lines. What was chosen, what was ruled out, what would make us revisit it. A human will approve or delete it. Do not write directly into `DECISIONS.md`.

If you changed something that `STATE.md` describes, update `STATE.md` directly. That file is meant to be overwritten.

If you notice a decision already in `DECISIONS.md` being questioned or re-made in this session, say so, and append one line to `REOPENED.md`: the date, the decision number, and what happened. That log is how we know whether this repo is working.

## What not to do

- Don't infer the team's preferences from one person's style. Personal preferences live in personal memory, not here.
- Don't summarise your reasoning into these files. Reasoning goes stale. Decisions and rejected options don't.
- Don't delete entries from `DECISIONS.md`. Mark them superseded.
