# CLAUDE.md

Guidance for Claude Code when working in this repository.

## About this repo

This repo hosts coursework for an AI-assisted software development class, organized as separate TPs (assignments) in their own top-level directories:

- `tp-1/` — see `tp-1/CLAUDE.md` for specifics (once populated).
- `tp-2/` — no specific guidance yet.
- `tp-final/` — the Yvoty plant-identification app. See `tp-final/CLAUDE.md` for details.

The point of the repo is not just to ship whatever each TP asks for — it's to leave a legible trail of how AI-assisted development actually happened, for each TP independently.

When a request only makes sense in the context of one TP, prefer putting TP-specific conventions, architecture notes, and API references in that TP's own `CLAUDE.md` rather than here. Keep this file for conventions that apply across all TPs.

## Action logging (required)

Every session, log what you did to `CLAUDE_ACTIONS_LOG.md` at the root of the TP directory you're working in (e.g. `tp-final/CLAUDE_ACTIONS_LOG.md` for work on the Yvoty app). This is not optional busywork — it's the primary teaching artifact of this repo, so treat it with the same care as the code.

**When to log:**
- At the end of a unit of work — a user request that resulted in file changes, research, commits, or any other non-trivial action. Group a whole request/response cycle into one entry rather than logging every individual tool call.
- If a session covers several distinct asks, either add one entry per ask or one entry covering all of them — use judgment, but never let a session end unlogged.
- Purely conversational exchanges that didn't change anything or produce a decision worth remembering (e.g. answering a quick question) don't need an entry.
- Purely "meta" requests about these instructions themselves (e.g. reorganizing CLAUDE.md files) don't need an entry.

**How to log — append a new entry at the bottom of the "entries" area (oldest first, chronological), using this shape:**

```markdown
## YYYY-MM-DD — Short title of what this session did

**Prompt (verbatim):** The user's exact original wording, copied as-is — not paraphrased or summarized. If the unit of work spans multiple user messages, include each verbatim (e.g. as a short list).

**Actions taken:**
1. Numbered, specific steps — what you did, in what order. Name real tools/commands/endpoints, not vague summaries ("ran X", "fetched Y", "edited Z").

**Files changed:**
- `path/to/file` (new / edited / deleted) — one-line description of the change if not obvious.

**Notes / caveats:**
- Anything a reader should know that isn't obvious from the diff: things you tried that failed, assumptions you made, tradeoffs, follow-ups still needed, decisions the user made that steered the approach.
```

Keep entries factual and specific enough that someone could reconstruct the session from the log alone, without re-reading the chat transcript. Prefer naming the actual file paths, endpoints, and commands over paraphrasing what they do.

**Get today's date** from the environment/system context rather than guessing.

**Committing the log:** update the relevant TP's `CLAUDE_ACTIONS_LOG.md` in the same commit as the work it describes, when you're the one making the commit. If the user asks you to commit, that log file should be staged alongside the rest of the change.

## Other conventions

- No other cross-TP conventions are established yet. As real conventions emerge that apply across all TPs, add them here. Anything specific to a single TP (architecture, APIs, stack choices) belongs in that TP's own `CLAUDE.md`.
