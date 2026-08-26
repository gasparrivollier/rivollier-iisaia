# CLAUDE.md

Guidance for Claude Code when working in this repository.

## About this repo

This is the codebase for a plant-identification "pokedex" + virtual garden app, using the Pl@ntNet API for species identification (see `docs/plantnet-api.md` for the API reference). The repo **also doubles as course material for an AI-assisted software development class** — the point is not just to ship the app, but to leave a legible trail of how AI-assisted development actually happened here.

## Action logging (required)

Every session, log what you did to `CLAUDE_ACTIONS_LOG.md` at the repo root. This is not optional busywork — it's the primary teaching artifact of this repo, so treat it with the same care as the code.

**When to log:**
- At the end of a unit of work — a user request that resulted in file changes, research, commits, or any other non-trivial action. Group a whole request/response cycle into one entry rather than logging every individual tool call.
- If a session covers several distinct asks, either add one entry per ask or one entry covering all of them — use judgment, but never let a session end unlogged.
- Purely conversational exchanges that didn't change anything or produce a decision worth remembering (e.g. answering a quick question) don't need an entry.

**How to log — append a new entry at the top of the "entries" area (newest first), directly under the header, using this shape:**

```markdown
## YYYY-MM-DD — Short title of what this session did

**Prompt (paraphrased):** One or two sentences capturing what was asked, in your own words.

**Actions taken:**
1. Numbered, specific steps — what you did, in what order. Name real tools/commands/endpoints, not vague summaries ("ran X", "fetched Y", "edited Z").

**Files changed:**
- `path/to/file` (new / edited / deleted) — one-line description of the change if not obvious.

**Notes / caveats:**
- Anything a reader should know that isn't obvious from the diff: things you tried that failed, assumptions you made, tradeoffs, follow-ups still needed, decisions the user made that steered the approach.
```

Keep entries factual and specific enough that someone could reconstruct the session from the log alone, without re-reading the chat transcript. Prefer naming the actual file paths, endpoints, and commands over paraphrasing what they do.

**Get today's date** from the environment/system context rather than guessing.

**Committing the log:** update `CLAUDE_ACTIONS_LOG.md` in the same commit as the work it describes, when you're the one making the commit. If the user asks you to commit, `CLAUDE_ACTIONS_LOG.md` should be staged alongside the rest of the change.

## Other conventions

- No other project-specific conventions are established yet. As real code/architecture decisions get made, add them here.
