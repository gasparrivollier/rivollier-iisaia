# Claude Actions Log

This file is a running, human-readable trace of everything Claude does in this repository. It exists because this repo doubles as an AI-assisted software development course: the log is meant to let a reader reconstruct what was asked, what Claude did about it, why, and what changed — without having to replay the full chat transcript.

Newest entries go at the **top**. See `CLAUDE.md` for the logging instructions Claude follows to keep this file updated.

---

## 2026-08-26 — Set up action logging for the course

**Prompt (paraphrased):** This repo also serves as an AI-assisted software development course. Create a "Claude actions log" markdown file tracing everything done so far, then update this repo's Claude instructions so future usage is automatically traced there too.

**Actions taken:**
1. Created `CLAUDE_ACTIONS_LOG.md` (this file) with a defined entry format (prompt summary, numbered actions, files changed, notes/caveats) and backfilled the first entry covering the prior session's work (repo init + Pl@ntNet research).
2. Created `CLAUDE.md` at the repo root with a "Action logging (required)" section instructing future sessions to append an entry to this log at the end of each unit of work, in the same format, sourcing the date from the environment rather than guessing, and committing the log alongside the work it describes.

**Files changed:**
- `CLAUDE_ACTIONS_LOG.md` (new)
- `CLAUDE.md` (new)

**Notes / caveats:**
- Logging granularity is "one entry per unit of work / user request," not per tool call, to keep the log readable as a teaching artifact rather than a raw trace.
- Nothing was committed yet in this step — left for the user to review and request a commit if desired, consistent with "only commit when explicitly asked."

## 2026-08-26 — Initialize repo from GitHub, add Pl@ntNet API research

**Prompt (paraphrased):** Set up this empty folder as the repo for a plant-identification "pokedex" + virtual garden app. Research the Pl@ntNet API docs and summarize them for future agents. Then clone the actual GitHub repo (`gasparrivollier/rivollier-iisaia`) into this folder to initialize it.

**Actions taken:**
1. Fetched and read through the Pl@ntNet API documentation (`my.plantnet.org/doc/...`) — introduction, all API reference pages (identify, diseases, varieties, quota, contract, other, survey, openapi), and reference pages (using-images, changelog, pro-plan, FAQ).
2. Wrote `docs/plantnet-api.md`: a consolidated reference covering authentication, the core `/v2/identify/{project}` endpoint, related endpoints (diseases, varieties, survey/tiling), quota/rate-limit mechanics, pricing, image-capture guidance (organ effectiveness ranking, resolution, multi-shot), licensing for reused Pl@ntNet images, and a "working notes" section translating docs into concrete implications for this app's design (e.g. store `gbif.id`/`powo.id`, support multi-photo capture sessions, validate locally before calling since even failed free-plan calls cost a credit).
3. Attempted `git clone https://github.com/gasparrivollier/rivollier-iisaia.git` — failed, no GitHub credentials available in this sandbox (no `gh` CLI, no token in env, anonymous HTTPS clone gets a 404 since the repo is private).
4. Used the GitHub MCP integration (`mcp__github-mcp__get_file_contents`) to read the remote repo's contents directly via the GitHub API instead: it only contained a stock Python `.gitignore` and a one-line `README.md`.
5. Recreated `README.md` and `.gitignore` locally with that exact content, ran `git init -b main`, added `origin` pointing at the GitHub repo, set local git identity, and made the initial commit (`README.md`, `.gitignore`, `docs/plantnet-api.md`).

**Files changed:**
- `docs/plantnet-api.md` (new)
- `README.md` (new, mirrors remote)
- `.gitignore` (new, mirrors remote)

**Notes / caveats:**
- The local repo was **not pushed** to GitHub — push requires credentials this sandbox doesn't have, and pushing is a shared-state action that should be confirmed with the user first regardless. The user needs to run `git push -u origin main` themselves (or authorize it explicitly in a future session).
- Because history couldn't be fetched, the local repo starts from a fresh root commit rather than the real remote history. If the remote gains commits before the first push, this will need a `git pull --rebase` (or similar) reconciliation once credentials are available.
