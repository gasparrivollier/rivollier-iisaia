# CLAUDE_ACTIONS_LOG.md — tp-1

## 2026-09-02 — Initial README, architecture, and working complaint form

**Prompt (verbatim):** "In this session we will be working on tp-1. The idea of this project is a UI that is particularly annoying to use. Generate the inital readme for this repo. And let's start discussing architecture. Let's keep it simple since this will only be a front-end solution"

**Actions taken:**
1. Asked the user clarifying questions (via AskUserQuestion) on: the underlying app concept, tech stack, and what "annoying" means for grading purposes.
2. User decided: a standard (correctly-behaving, for now) complaint form for the Buenos Aires Subte; plain HTML/CSS/JS, no framework/build step; usability will be intentionally broken in a later pass.
3. Wrote `tp-1/README.md` describing the assignment, stack, and how to run it.
4. Wrote `tp-1/CLAUDE.md` with architecture notes (3 static files, no backend, simulated submission) and the current field list.
5. Scaffolded `tp-1/index.html`, `tp-1/style.css`, `tp-1/app.js`: a Subte complaint form (line, station, datetime, complaint type, description, contact info) with client-side validation and a simulated ticket-number confirmation on submit (no backend/network call).
6. Verified via `python3 -m http.server -d tp-1 8123`: HTML/CSS/JS all serve correctly, `node --check app.js` passes, form markup present. Could not do a full rendered-browser check — chromium-cli and Playwright are not installed in this environment and were not installed (no network install performed without asking first).

**Files changed:**
- `tp-1/README.md` (new)
- `tp-1/CLAUDE.md` (new) — architecture notes for this TP
- `tp-1/index.html` (new) — complaint form markup
- `tp-1/style.css` (new) — styling
- `tp-1/app.js` (new) — validation + simulated submit handling

**Notes / caveats:**
- No backend exists or is planned for this TP; "submission" is simulated client-side with a generated ticket number. If persistence across reloads is wanted later, use `localStorage` rather than adding a server.
- The form is intentionally *not* annoying yet — that's a deliberate, separate future pass per the user's instruction ("make it correctly, we'll break it afterwards").
- Could not visually verify rendering in a real browser (no chromium-cli/Playwright available); verification was limited to static HTTP/JS checks. Flagged to the user rather than claimed as full UI verification.


## 2026-09-02 — Buenos Aires Subte branding for the line picker

**Prompt (verbatim):** "Let's do a bit of branding based on Buenos Aires Subte. Here's the signaletic system for it https://www.google.com/url?sa=t&source=web&rct=j&opi=89978449&url=https://shakespearweb.com/portfolio-item/subte-sistema-senalizacion-senaletica/&ved=2ahUKEwjY2uDpidGWAxUGKbkGHWQqDCQQFnoECCQQAQ&usg=AOvVaw3xpph1zX_sdSo5_fpeT6wj."

**Actions taken:**
1. Fetched the linked article (via WebFetch) on the real Subte signage/wayfinding system — it described line-colored "spheres" on porticos and a unifying "yellow BA" accent, but gave no hex codes or typeface specs.
2. Asked the user how branding should show up in the form (colored line-picker spheres vs. header/palette restyle vs. both); user chose the colored sphere picker only.
3. Replaced the plain `<select id="line">` in `tp-1/index.html` with a `role="radiogroup"` of 7 labeled radio inputs styled as colored circular "spheres" (A–H, Premetro), matching the real signage concept.
4. Added `--line-a` … `--line-premetro` CSS custom properties in `tp-1/style.css` with each line's real official color (A light blue, B red, C navy, D green, E violet, H yellow, Premetro orange), plus `.line-picker`/`.line-sphere`/`.line-option` styles (checked/focus-visible states, error state).
5. Reworked `tp-1/app.js` validation: `[...form.elements]` previously treated each same-named radio as its own field (would have broken with 7 duplicate "line" entries) — added a dedicated `validateLinePicker()` using `form.elements.line.value` (RadioNodeList aggregation), wired to `change` instead of `blur`, and excluded "line" from the generic per-field loop.
6. Verified via `node --check app.js` (passes) and serving the folder with `python3 -m http.server`: all 7 `.line-sphere` elements present in the served HTML, CSS loads. No rendered-browser check performed (same tooling gap as the prior session).

**Files changed:**
- `tp-1/index.html` (edited) — line `<select>` replaced with colored sphere radio group
- `tp-1/style.css` (edited) — added BA Subte line-color tokens and sphere-picker styles
- `tp-1/app.js` (edited) — added `validateLinePicker()`, adjusted field iteration and event wiring for the radio group
- `tp-1/CLAUDE.md` (edited) — added a "Branding" section documenting the line colors and sphere picker

**Notes / caveats:**
- The source article didn't publish exact hex codes; the colors used are the well-known official per-line colors from Buenos Aires Subte maps/signage, not values scraped from the page itself.
- User explicitly scoped this to the line picker only — no header/global palette restyle was done in this pass.


## 2026-09-02 — Station picker turned into a shuffled all-lines grid (first anti-pattern)

**Prompt (verbatim):** "Las estaciones en el formulario deberian ser un gran checker con todas las posibles opciones desordenadas segun la linea a la que correspondan (aleatorizadas)."

**Actions taken:**
1. Replaced the free-text `<input id="station">` in `tp-1/index.html` with an empty `<div id="station-grid" role="radiogroup">` container, populated at runtime.
2. In `tp-1/app.js`, added a `STATIONS_BY_LINE` object listing real Buenos Aires Subte stations per line (A: 18, B: 17, C: 9, D: 15, E: 12, H: 12 — 83 total, compiled from general knowledge, not scraped from an official source, so treat as best-effort rather than authoritative).
3. Added `shuffle()` (Fisher–Yates) and `renderStationGrid()`, which flattens all stations across every line into one array, shuffles it, and renders it as radio-tile options — deliberately not grouped or sorted by line, so the line already selected one field above gives the user no shortcut.
4. Added `validateStationPicker()` (same `RadioNodeList`-based pattern as the existing line picker) and wired it into the submit handler and a `change` listener on `#station-grid`; excluded "station" from the generic per-field validation loop.
5. Re-shuffle happens on every render call, including on "Cargar otro reclamo" (`newComplaintBtn` click), so the grid order is never stable across resets.
6. Added `.station-grid`/`.station-option`/`.station-tile` styles in `tp-1/style.css`: a scrollable auto-fill grid capped at `16rem` height, so the "gran checker" also forces scrolling to see all options.
7. Documented this as the first formal anti-pattern in `tp-1/CLAUDE.md` under a new "Anti-patterns" section (heuristic violated: #6 recognition-over-recall, #7 flexibility/efficiency — the line selection doesn't filter or sort the station list). Updated the "About this app" note to reflect that the annoying-UI pass has now started.
8. Verified via `node --check app.js` (passes), a Node one-off script counting stations (83 total, 81 unique — "Callao" and "Pueyrredón" legitimately appear twice, since they're real stations shared by two lines), and serving the folder with `python3 -m http.server` to confirm the HTML/CSS/JS still load. No rendered-browser check (same tooling gap as prior sessions — chromium-cli/Playwright not installed).

**Files changed:**
- `tp-1/index.html` (edited) — station `<input>` replaced with the `#station-grid` container
- `tp-1/app.js` (edited) — added `STATIONS_BY_LINE`, `shuffle()`, `renderStationGrid()`, `validateStationPicker()`; wired rendering/validation into load, submit, and reset flows
- `tp-1/style.css` (edited) — added scrollable station-grid/tile styles
- `tp-1/CLAUDE.md` (edited) — added "Anti-patterns" section documenting this change; updated "About this app" and the field list

**Notes / caveats:**
- Station list is a best-effort compilation, not verified against an official/current SBASE source — some station names may have changed (renamings happen) or be incomplete. Flagged rather than presented as authoritative.
- This is the first deliberate anti-pattern of the "make it annoying" phase; earlier fields (line picker, contact info, etc.) are still in their straightforward, non-annoying form and weren't touched.
- Did not add line-based grouping/sorting anywhere, per the explicit instruction that the shuffle should ignore line correspondence.


## 2026-09-02 — Station picker: grid → self-blocking toggle list

**Prompt (verbatim):** "en vez de grid hagamoslo una lista que sea una por fila y tenga un toggle switch en el final. El toggle-switch ademas solo permite picarse si no hay otro toggle seleccionado antes."

**Actions taken:**
1. In `tp-1/index.html`, changed `#station-grid`'s `role` from `radiogroup` to `group` (no longer semantically a radio group — it's checkboxes now).
2. In `tp-1/app.js`, renamed `renderStationGrid()` to `renderStationList()` and changed its markup: instead of one radio-styled tile per station, each station is now a `.station-row` (name on the left, a checkbox styled as a toggle switch on the right) — same shuffled 83-station list as before, one per row instead of a grid.
3. Added `handleStationToggle()`: on any station checkbox's `change` event, if it was just turned on, every *other* station checkbox gets `disabled = true`; if turned off, all are re-enabled. This means picking a different station requires switching the current one off first — the toggle enforces single-select but adds a mandatory extra step, unlike a plain radio button.
4. Rewrote `validateStationPicker()` to check for a checked box via `stationGrid.querySelector('input[name="station"]:checked')` instead of relying on `RadioNodeList.value` (that getter's single-checked-value semantics are specified for radio inputs, not checkboxes).
5. Wired `stationGrid`'s `change` listener to `handleStationToggle` (which itself calls `validateStationPicker()`) instead of calling `validateStationPicker` directly.
6. Rewrote `.station-grid`/`.station-option`/`.station-tile` CSS into `.station-grid` (now a scrollable vertical list, `max-height: 20rem`), `.station-row` (flex row, name + switch, bottom border, last-child border removed), and `.toggle-switch`/`.toggle-switch__track`/`.toggle-switch__thumb` (classic sliding-pill toggle switch, with a dimmed `not-allowed` state for `input:disabled`).
7. Updated `tp-1/CLAUDE.md`: reworded the station-picker anti-pattern entry for the list/toggle format, and added a second anti-pattern entry for the self-blocking toggle behavior (violates Nielsen #2 — a toggle should behave like a toggle, not a radio button with an extra step).
8. Verified via `node --check app.js` (passes) and serving the folder with `python3 -m http.server` (HTML/CSS still load; the station rows themselves are injected client-side by `app.js`, so they don't appear in the static-served HTML source, only after script execution).

**Files changed:**
- `tp-1/index.html` (edited) — `#station-grid` role changed to `group`
- `tp-1/app.js` (edited) — `renderStationGrid` → `renderStationList`; added `handleStationToggle()`; rewrote `validateStationPicker()`; rewired the `change` listener
- `tp-1/style.css` (edited) — grid/tile styles replaced with list-row + toggle-switch styles
- `tp-1/CLAUDE.md` (edited) — updated/added anti-pattern entries and the field list

**Notes / caveats:**
- No rendered-browser check performed (same tooling gap noted in prior sessions — chromium-cli/Playwright not installed here); verification was static (syntax check + serving), same limitation as before.
- The station data itself (`STATIONS_BY_LINE`) was not changed in this session — only how it's rendered and how selection is enforced.


## 2026-09-02 — Datetime picker replaced with a ±1-second stepper defaulting to 1810

**Prompt (verbatim):** "El selector de fecha y hora del incidente debe ser un componente que muestre fecha y hora y solo tenga dos flechas (arriba y abajo) que lo que hacen es subir el datetime seleccionado en un segundo. La fecha por default es 25 de mayo de 1810"

**Actions taken:**
1. In `tp-1/index.html`, replaced `<input type="datetime-local" id="datetime">` with a `.datetime-picker` component: a read-only text display (`#datetime-display`) plus two buttons (`#datetime-up` "▲", `#datetime-down` "▼"), and a `<input type="hidden" id="datetime" name="datetime" required>` that carries the actual value for form submission/validation.
2. In `tp-1/app.js`, added `DEFAULT_INCIDENT_DATETIME` (`new Date(1810, 4, 25, 0, 0, 0)` — 25 May 1810, 00:00:00, month index 4 = May) and mutable state `incidentDateTime` initialized from it.
3. Added `pad()`/`formatDateTime()` (manual `DD/MM/YYYY HH:MM:SS` formatting, no `Intl`/locale dependency) and `renderDateTime()`, which writes the formatted string to `#datetime-display` and the ISO string to the hidden input.
4. Added `adjustDateTime(deltaSeconds)`, wired to the two buttons with `deltaSeconds` of `+1`/`-1` — each click moves `incidentDateTime` by exactly one second, re-renders, and re-validates. No other way to change the value exists (no typing, no calendar, no jump-to-today).
5. Removed the now-dead `datetime-local` branch from the generic `validateField()` (no input of that type exists anymore) and added a dedicated `validateDateTimePicker()` (still checks "not in the future," now comparing the `incidentDateTime` Date object directly rather than parsing a form value).
6. Excluded `datetime` from the generic per-field validation loop and blur-listener setup (same pattern as `line`/`station`); wired `validateDateTimePicker()` into the submit handler and initial `renderDateTime()` call; reset `incidentDateTime` back to `DEFAULT_INCIDENT_DATETIME` on "Cargar otro reclamo."
7. Added `.datetime-picker`/`.datetime-picker__display`/`.datetime-picker__arrows`/`.datetime-picker__arrow` styles in `tp-1/style.css`: a bordered box with the display on the left and two stacked arrow buttons on the right.
8. Documented this as a third anti-pattern in `tp-1/CLAUDE.md` (Nielsen #7 — no way to jump to "now"; the one-second granularity from an 1810 default makes reaching a real incident date impractical — ~6.8 billion clicks). Updated the field list.
9. Verified via `node --check app.js` (passes), a Node one-off exercising `formatDateTime`/the +1s and +61s deltas (correct: `25/05/1810 00:00:00` → `00:00:01` → `00:01:01`), and serving the folder with `python3 -m http.server` to confirm HTML/CSS still load.

**Files changed:**
- `tp-1/index.html` (edited) — datetime `<input>` replaced with the `.datetime-picker` component + hidden input
- `tp-1/app.js` (edited) — added datetime state/formatting/stepper functions and `validateDateTimePicker()`; removed dead `datetime-local` validation branch; wired everything into submit/init/reset
- `tp-1/style.css` (edited) — added `.datetime-picker` styles
- `tp-1/CLAUDE.md` (edited) — added the datetime anti-pattern entry and updated the field list

**Notes / caveats:**
- No rendered-browser check performed (same tooling gap as prior sessions); verification was static (syntax check, a Node-side logic check of the formatting/increment math, and HTTP serving).
- The hidden input's value is an ISO string (`incidentDateTime.toISOString()`), kept only for form-submission completeness — the actual source of truth is the `incidentDateTime` JS variable, since a hidden input can't be interacted with directly.


## 2026-09-02 — Nombre/Apellido replaced with 500-entry random dropdowns

**Prompt (verbatim):** "Para nombre y apellido hace un dropdown de nombres y uno de apellidos con 500 datos cada uno (aleatorios)"

**Actions taken:**
1. In `tp-1/index.html`, replaced the single `<input id="name" name="name">` (label "Nombre y apellido") with two empty `<select>` elements: `#first-name` (`name="firstName"`) and `#last-name` (`name="lastName"`), each required, populated at runtime.
2. In `tp-1/app.js`, added `FIRST_NAME_PREFIXES`/`FIRST_NAME_SUFFIXES` (44×30 = 1,350 possible combos) and `LAST_NAME_PREFIXES`/`LAST_NAME_SUFFIXES` (30×20 = 600 possible combos) — pools of Spanish-sounding syllable fragments, not real name lists (there's no realistic way to hand-author 500+ real unique names, and the point is that they're fake).
3. Added `generateWords(prefixes, suffixes, count)`: builds `count` unique prefix+suffix combinations via a `Set` (rejection sampling on collision) — verified via a standalone Node script that both pools reliably produce 500 unique values in ~2ms.
4. Added `renderNameDropdown(selectEl, prefixes, suffixes, placeholder)`: generates 500 words, shuffles them with the existing `shuffle()` helper (reused, not duplicated), and renders them as `<option>`s with a disabled placeholder first.
5. Wired `renderNameDropdown()` calls for both selects into initial page load and into the "Cargar otro reclamo" reset handler (same reshuffle-on-reset pattern as the station list and datetime stepper).
6. No new validation function was needed — `firstName`/`lastName` are plain `<select required>` elements, so the existing generic `validateField()`/blur-listener loop already covers them (same as the pre-existing "type" select).
7. Documented this as a fourth anti-pattern in `tp-1/CLAUDE.md` (Nielsen #5 error prevention — the field structurally cannot capture the reporter's real name — and #6 recognition-over-recall). Updated the field list.
8. Verified via `node --check app.js` (passes), a standalone Node script confirming `generateWords()` returns exactly 500 unique values for both pools with real-looking samples (e.g., "Nuñez", "Ortizez" for surnames), and serving the folder with `python3 -m http.server` to confirm the page still serves.

**Files changed:**
- `tp-1/index.html` (edited) — `name` input replaced with `#first-name`/`#last-name` selects
- `tp-1/app.js` (edited) — added name-generation pools, `generateWords()`, `renderNameDropdown()`; wired into load and reset
- `tp-1/CLAUDE.md` (edited) — added the name-dropdown anti-pattern entry and updated the field list

**Notes / caveats:**
- No rendered-browser check performed (same tooling gap as prior sessions); verification was static (syntax check, a Node-side check of the generation logic, HTTP serving).
- Names are procedurally generated syllable combinations, not drawn from a real name corpus — this was a deliberate choice given there's no realistic way to source 500+ genuinely distinct real first/last names without an external dataset, and it keeps the anti-pattern self-contained with no new dependency.


## 2026-09-02 — GCBA-style header with the real Subte logo

**Prompt (verbatim):** "Mejoremos el branding. Deje el logo de subte en assets. Demosle una estética similar a la del GCBA y ubiquemos el logo en una cabecera."

**Actions taken:**
1. Found the logo the user had placed at `tp-1/assets/subte.png` (yellow circle, black "Subte" wordmark, "Buenos Aires Ciudad" lockup underneath — the real GCBA Subte mark) and viewed it directly.
2. Sampled the logo's yellow with a one-off `python3 -c "from PIL import Image..."` pixel read → `rgb(246, 205, 25)` / `#f6cd19`, added as `--color-brand-yellow` in `tp-1/style.css` (kept distinct from the pre-existing `--line-h` line-color token, even though visually similar, since they mean different things).
3. In `tp-1/index.html`, added a `<header class="site-header">` above `<main class="page">`: the logo image, a "BUENOS AIRES CIUDAD" eyebrow line, and the "Reclamos del Subte" title (moved out of the old `.page__header`, which is now just an intro paragraph). Added `<link rel="icon" href="assets/subte.png">` for the browser tab.
4. In `tp-1/style.css`: added `.site-header`/`.site-header__inner`/`.site-header__logo`/`.site-header__eyebrow`/`.site-header__title` (white background, thin yellow bottom border, bold black heading typography via a shared `h1, h2` rule); restyled `button[type="submit"]` to black background / yellow text (a common GCBA CTA pattern) instead of the generic blue.
5. Verified with a **real rendered screenshot** rather than static checks only: found `chromium-browser` already installed in this environment, served the folder with `python3 -m http.server`, and ran `chromium-browser --headless --disable-gpu --no-sandbox --screenshot=... --window-size=...` to capture the actual page. Confirmed visually: logo + eyebrow + title render correctly in the header, yellow accent bar shows under it, and the black/yellow submit button renders correctly — nothing from earlier sessions (line spheres, station toggles, datetime stepper, name dropdowns) broke.
6. Documented the finding that `chromium-browser --headless` works here in `tp-1/CLAUDE.md`, so future sessions don't repeat the "no browser tooling available" caveat from prior log entries.
7. Updated the "Branding" section in `tp-1/CLAUDE.md` with the logo location, the sampled brand tokens, and the header/CTA styling; deleted the temporary screenshots from the scratchpad afterward.

**Files changed:**
- `tp-1/index.html` (edited) — added `.site-header` with the logo, moved intro text to `.page__intro`, added favicon link
- `tp-1/style.css` (edited) — added `--color-brand-yellow`/`--color-brand-black` tokens, `.site-header*` styles, bold `h1, h2` rule, restyled the submit button
- `tp-1/CLAUDE.md` (edited) — expanded "Branding" section; added a note that `chromium-browser --headless` is available for real rendering checks

**Notes / caveats:**
- `assets/subte.png` was provided by the user, not generated or fetched by Claude — only read to sample its color and reference it in markup.
- This is the first session in this TP with an actual rendered-browser verification, not just static checks — worth keeping `chromium-browser --headless` in mind for future visual changes instead of falling back to "couldn't verify visually."


## 2026-09-02 — Fake "request a name" link under Nombre/Apellido

**Prompt (verbatim):** "en nombre y apellido pongamos un texto que diga ¿No está tu nombre o tu apellido? ¡llená este formulario para solicitar que lo agreguemos!. Que tenga un hipervinculo pero que no lleve a ningun lado"

**Actions taken:**
1. In `tp-1/index.html`, added a `<p class="dead-link-note">` between the "Apellido" field and "Email", with the exact requested copy and a `<a href="#" class="dead-link" data-dead-link>este formulario</a>` hyperlink.
2. In `tp-1/app.js`, added a listener over all `[data-dead-link]` elements that calls `event.preventDefault()` on click — the link is real-looking (normal blue underlined styling) but clicking it does nothing at all, not even a scroll-to-top `#` jump.
3. Added `.dead-link-note`/`.dead-link` styles in `tp-1/style.css` (muted small text, link colored like a normal link so it doesn't visually stand out as fake).
4. Verified with a real rendered screenshot (`chromium-browser --headless`, per the workflow noted in `tp-1/CLAUDE.md` from the last session): the note and link render correctly between the two name dropdowns and Email, styled as an ordinary link.
5. Documented this as a fifth anti-pattern in `tp-1/CLAUDE.md` — flagged as a dark pattern (fake affordance) rather than just a Nielsen heuristic violation, since it actively simulates a fix for the previous anti-pattern (the impossible-to-find name) and then has no fix behind it.

**Files changed:**
- `tp-1/index.html` (edited) — added the dead-link note between Apellido and Email
- `tp-1/app.js` (edited) — added the `preventDefault` click handler for `[data-dead-link]`
- `tp-1/style.css` (edited) — added `.dead-link-note`/`.dead-link` styles
- `tp-1/CLAUDE.md` (edited) — added the anti-pattern entry

**Notes / caveats:**
- The link's `href="#"` is inert in practice because of the `preventDefault()` handler; if JS ever failed to load, `href="#"` alone would still just jump to the top of the page rather than leave the site, so the "goes nowhere" requirement holds either way.


## 2026-09-02 — Description field darkens to illegibility as you type

**Prompt (verbatim):** "El campo de descripcion en la medida que se va tipeando se va oscureciendo el fondo por lo que en determinado momento no se permite ver mas las letras negras (calculemos para que sea aproximadamente al decimo caracter)."

**Actions taken:**
1. In `tp-1/app.js`, added `DESCRIPTION_MIN_LIGHTNESS` (5), `DESCRIPTION_START_LIGHTNESS` (96), `DESCRIPTION_DARKEN_PER_CHAR` (8.5), and `updateDescriptionDarkness(event)`: on every `input` event, sets `event.target.style.backgroundColor` to `hsl(0, 0%, ${lightness}%)` where `lightness = max(5, 96 - length * 8.5)`. Worked out the constant by hand so char 9 lands at ~19.5% and char 10 at ~11% lightness — close enough to the text's own near-black lightness (~14%) that contrast collapses right around the requested "decimo carácter."
2. Wired `descriptionField.addEventListener("input", updateDescriptionDarkness)` into the init block, and reset `descriptionField.style.backgroundColor = ""` in the "Cargar otro reclamo" handler so a fresh form starts light again.
3. Added `#description { transition: background-color 0.15s ease; }` in `tp-1/style.css` for a smoother (and more unsettling) darken-per-keystroke effect.
4. Verified with **interactive** browser automation, not just a static screenshot: launched `chromium-browser --headless=new --remote-debugging-port=9333`, wrote a one-off Node script (`cdp-type.mjs`, since deleted) using Node 22's built-in `WebSocket` to open a Chrome DevTools Protocol connection, `Runtime.evaluate` to set the textarea's value and dispatch a real `input` event, wait out the 150ms CSS transition, then `Page.captureScreenshot`. Confirmed visually: 0 chars is near-white, 4 chars ("Hola") is legible mid-grey (~62% lightness as predicted), 12 chars ("Hola que tal") is solid near-black with the typed text effectively invisible — matches the "~10th character" target. (First attempt screenshotted before the transition settled and showed misleadingly light colors — added the wait and re-ran.)
5. Documented this as a sixth anti-pattern in `tp-1/CLAUDE.md`, framed as a WCAG 1.4.3 contrast failure rather than a workflow-efficiency issue, and recorded the CDP-scripting technique in the "Verifying UI changes" note for future interactive-verification needs (static screenshots aren't enough for anything involving user interaction / CSS transitions).

**Files changed:**
- `tp-1/app.js` (edited) — added the darkening constants, `updateDescriptionDarkness()`, wired into init and reset
- `tp-1/style.css` (edited) — added the `#description` background-color transition
- `tp-1/CLAUDE.md` (edited) — added the anti-pattern entry, updated the field list, and expanded "Verifying UI changes" with the CDP/WebSocket interactive-testing technique

**Notes / caveats:**
- The darkening is reversible by deleting characters (recomputed from current length each keystroke), not a permanent one-way effect — this wasn't specified either way in the request, and reversibility seemed like the more natural reading of "en la medida que se va tipeando."
- The CDP test script and its screenshots were temporary (written to the scratchpad, not the repo) and deleted after verification — only the technique is preserved, in `tp-1/CLAUDE.md`.


## 2026-09-02 — Description darkening: max state now pixel-exact to text color

**Prompt (verbatim):** "el fondo al llegar al máximo debe ser del color exacto de la tipografia (ahora es negro y las letras ligeramente grises)."

**Actions taken:**
1. User correctly pointed out the previous implementation's floor was pure grayscale `hsl(0, 0%, 5%)` (near-black) while the text is `--color-text` = `#1f2328` (a slightly blue-grey near-black, `hsl(213, 13%, 14%)`) — close but not the same color, so at "max" darkness the text was still very faintly visible.
2. In `tp-1/app.js`, converted `#1f2328` to HSL by hand (`hsl(213, 13%, 14%)`) and reworked the constants: `DESCRIPTION_TEXT_HUE` (213) and `DESCRIPTION_TEXT_SATURATION` (13) now drive the whole ramp (not grayscale), `DESCRIPTION_MIN_LIGHTNESS` is now 14 (the text's own lightness, not an arbitrary 5), and `DESCRIPTION_DARKEN_PER_CHAR` is derived as `(96 - 14) / 10 = 8.2` so the floor is reached at exactly the 10th character (matching the original request's "aproximadamente al décimo carácter").
3. Once the computed lightness reaches the floor, `updateDescriptionDarkness()` now sets `backgroundColor` to the literal `"var(--color-text)"` string instead of a reconstructed `hsl(...)` value — this guarantees pixel-exact equality with the text color with zero rounding risk, rather than relying on the hand-converted HSL numbers being exactly right.
4. Verified this is truly exact, not just visually close: reused the CDP/WebSocket scripting technique documented in the previous session's log entry, but this time read `getComputedStyle(el).backgroundColor` and `.color` directly instead of only screenshotting — confirmed both report identically as `rgb(31, 35, 40)` at 10 characters (and beyond). Also re-confirmed visually via screenshot that typed text is completely invisible at that point.
5. Updated the description-darkening anti-pattern entry in `tp-1/CLAUDE.md` to reflect the corrected mechanism and the `getComputedStyle`-based verification method.

**Files changed:**
- `tp-1/app.js` (edited) — reworked the darkening constants and `updateDescriptionDarkness()` to target the exact text color instead of grayscale
- `tp-1/CLAUDE.md` (edited) — updated the anti-pattern entry with the corrected mechanism and verification detail

**Notes / caveats:**
- The hand-converted HSL value for `--color-text` was double-checked with a small Node script doing the RGB→HSL math, not eyeballed — worth re-deriving if `--color-text` in `style.css` ever changes, since the JS constants don't read it dynamically (mixing a hardcoded ramp with a literal `var()` snap at the floor was simpler than computing HSL from a live CSS custom property in JS, and the floor snap is the part that actually has to be exact).


## 2026-09-02 — Line picker spheres now bounce randomly inside a rectangle

**Prompt (verbatim):** "En tp-1, el selector de LInea (que son una serie de circulos ahora) me gustaría que sea una componente como con burbujas que rebotan dentro de un rectangulo aleatoriamente."

**Actions taken:**
1. In `tp-1/index.html`, added a `line-picker--bubbles` modifier class alongside the existing `.line-picker` on the line `role="radiogroup"` container; markup (radio inputs + `.line-sphere` labels) unchanged.
2. In `tp-1/style.css`, added `.line-picker--bubbles`: `position: relative`, fixed `height: 14rem`, `width: 100%`, `overflow: hidden`, bordered rectangle. Added `.line-picker--bubbles .line-option { position: absolute; top: 0; left: 0; }` so each sphere-label can be freely repositioned via `transform`.
3. In `tp-1/app.js`, added `initLineBubbles()`: reads the 7 `.line-option` elements, gives each a random starting `x`/`y` inside the rectangle and a random velocity vector (fixed speed magnitude, random angle), then runs a `requestAnimationFrame` loop that advances position by `velocity * dt`, reflects `vx`/`vy` off the rectangle's edges (classic screensaver-style wall bounce), and writes the result as `transform: translate(x, y)` on each label every frame. Called once at init alongside the other `render*()`/`init*()` calls.
4. Verified with rendered screenshots: served `tp-1/` via `python3 -m http.server`, took two `chromium-browser --headless` screenshots of the same URL back-to-back — confirmed the 7 line bubbles render inside the bounded rectangle at different random positions each load (bubbles fully inside the box, no clipping/overflow), consistent with random-start + bounce behavior.
5. Documented this as a new anti-pattern in `tp-1/CLAUDE.md` (Nielsen #7 — a moving target is harder to hit than a static one — and an accessibility/motion-sensitivity flag: no `prefers-reduced-motion` handling, and moving targets are a hard blocker for some motor-impaired/switch-input users, not just an inconvenience).

**Files changed:**
- `tp-1/index.html` (edited) — added `line-picker--bubbles` class to the line radiogroup container
- `tp-1/style.css` (edited) — added `.line-picker--bubbles` rectangle container and absolute positioning for `.line-option`
- `tp-1/app.js` (edited) — added `initLineBubbles()` (random start position/velocity + `requestAnimationFrame` wall-bounce loop), called at init
- `tp-1/CLAUDE.md` (edited) — added the bouncing-bubbles anti-pattern entry

**Notes / caveats:**
- Radio/label semantics are untouched — this is purely a positioning/animation change, so the field is still keyboard-focusable via Tab (focus doesn't chase the moving bubble, but a focused-and-Enter/Space flow still works even if the bubble isn't visually where a sighted mouse user expects).
- Framed this explicitly as an anti-pattern (per the TP's established pattern) rather than just a feature, since the effect straightforwardly makes the control harder to use — matches how prior sessions treated similar "make it annoying" requests. Not asked to add pause-on-hover or a reduced-motion fallback, so didn't add one, but flagged the omission in the anti-pattern write-up.


## 2026-09-02 — Email field replaced with a multi-tap phone keypad

**Prompt (verbatim):** "el Email que se llene con un teclado telefonico con letras, el método de tipeo de los teléfonos antes de los smartphone, con 1 siendo abc, 2 bcd, etc."

**Actions taken:**
1. Asked the user (via AskUserQuestion) to confirm the exact key→letters mapping, since "1 siendo abc, 2 bcd, etc." (overlapping-by-one groups) doesn't match how real feature phones were laid out. User picked the real standard: `2`=abc, `3`=def, `4`=ghi, `5`=jkl, `6`=mno, `7`=pqrs, `8`=tuv, `9`=wxyz, `1`=symbols (`. @ _ -`), `0`=space.
2. In `tp-1/index.html`, replaced `<input type="email" id="email">` with a `.phone-keypad` component: a display div (`#email-display`) showing the typed value, a 3-column grid of 12 buttons (digits 1–9/0 each showing the digit plus its letters, a delete key, and an inert spacer to keep the grid aligned), and a `<input type="hidden" id="email" name="email" required>` carrying the actual value, matching the pattern already used for the datetime stepper.
3. In `tp-1/app.js`, added `KEY_CHARS` (the mapping above) and `KEYPAD_TAP_TIMEOUT_MS` (800ms), plus `pressKeypadKey()`: tapping a key within the timeout of its own previous tap cycles through that key's `[...letters, digit]` sequence (replacing the last typed character); tapping any key after the timeout, or a different key, commits and starts a new character. `deleteKeypadChar()` removes the last character outright. `renderEmailKeypad()` syncs the visible display and the hidden input's value on every change.
4. Added `validateEmailKeypad()` (required + `EMAIL_PATTERN` check against the accumulated string, same pattern as `validateLinePicker()`/`validateStationPicker()`), wired into every keypad interaction (real-time feedback) and into the submit handler; excluded `name="email"` from the generic per-field validation loop and blur-listener wiring (same treatment as `line`/`station`/`datetime`), since it's now a hidden input with no blur interaction. Added `resetEmailKeypad()`, called from the "Cargar otro reclamo" handler.
5. Added `.phone-keypad`/`.phone-keypad__display`/`.phone-keypad__grid`/`.phone-keypad__key` styles in `tp-1/style.css` (bordered keypad box, 3×4 button grid, digit + small letter-group label per key, red delete key, error-state border reusing the existing `.field.has-error` pattern).
6. Verified interactively via CDP (`chromium-browser --headless=new --remote-debugging-port`, Node's built-in `WebSocket`, same technique as prior sessions): scripted clicks on `[data-key]`/`[data-action="delete"]` buttons with waits past the 800ms timeout between characters — pressing `3`, then `3` `3` (double-tap), then `6`, then `1` `1` (double-tap), then `6`, then `6` `6` `6` (triple-tap) produced exactly `dem@mo` in both the display and the hidden input; delete then correctly trimmed it to `dem@m`. Screenshot confirmed the keypad renders correctly with real letter groups per key and the red error border/message showing for the (intentionally) invalid partial email.
7. Documented this as a new anti-pattern in `tp-1/CLAUDE.md` (Nielsen #6 recognition-over-recall — the user must recall tap counts per letter — and #7 efficiency — far more physical taps than typing text directly, with mistimed taps silently misfiring). Updated the field list.

**Files changed:**
- `tp-1/index.html` (edited) — email `<input type="email">` replaced with the `.phone-keypad` component + hidden input
- `tp-1/app.js` (edited) — added `KEY_CHARS`, `pressKeypadKey()`, `deleteKeypadChar()`, `renderEmailKeypad()`, `resetEmailKeypad()`, `validateEmailKeypad()`; wired into submit, field-iteration exclusions, and reset
- `tp-1/style.css` (edited) — added `.phone-keypad` component styles
- `tp-1/CLAUDE.md` (edited) — added the multi-tap keypad anti-pattern entry and updated the field list

**Notes / caveats:**
- The user's literal wording ("1 siendo abc, 2 bcd") described overlapping 3-letter windows shifted by one per key, which isn't how any real phone keypad worked (real ones use fixed, non-overlapping groups) — flagged this via AskUserQuestion rather than guessing, and the user confirmed the real standard mapping was what they wanted, with `1` (traditionally unused/symbols on real phones) repurposed for `. @ _ -` since an email address needs those characters and this keypad has no other way to produce them.
- Digits themselves remain reachable (each key's tap cycle ends on the digit itself, e.g. tapping `2` four times types the literal character "2"), so numeric characters in an email/local-part are still possible, just at the end of that key's cycle.
- Real-time validation (`validateEmailKeypad()` on every tap) was a deliberate choice so the error message updates live as the user builds the string, consistent with how `validateLinePicker`/`validateStationPicker` give immediate feedback on their own interaction events rather than waiting for blur (which doesn't fire meaningfully on a button-driven hidden input anyway).


## 2026-09-02 — Migrated to a single self-contained HTML file

**Prompt (verbatim):** "tendría que ser un html single file. migremos a esto"

**Actions taken:**
1. Rewrote `tp-1/index.html` to inline the entire contents of `tp-1/style.css` into a `<style>` block in `<head>` and the entire contents of `tp-1/app.js` into a `<script>` block at the end of `<body>` — replacing the `<link rel="stylesheet" href="style.css">` and `<script src="app.js">` references. No markup, styling, or logic was changed in the process, only its location/packaging.
2. Deleted `tp-1/style.css` and `tp-1/app.js` (confirmed both were untracked in git, so nothing was lost from history).
3. Kept `tp-1/assets/subte.png` as the one remaining external file (still referenced via `<img src>`/`<link rel="icon">`) — true single-file inlining would mean base64-encoding it as a data URI, but the user's ask was framed around HTML/CSS/JS consolidation, not asset inlining, so left the logo external rather than assuming that scope.
4. Verified via `node --check` on the extracted `<script>` contents (syntax OK) and a rendered screenshot (`chromium-browser --headless` serving the folder with `python3 -m http.server`) confirming the page renders identically to before the migration (header, bouncing line bubbles, shuffled station list, datetime stepper all present and correctly styled).
5. Updated `tp-1/README.md` ("Stack"/"Structure" sections) and `tp-1/CLAUDE.md` ("Architecture" section, plus every anti-pattern entry's file references) to point at `index.html`'s inline `<style>`/`<script>` instead of the now-deleted `style.css`/`app.js`, and added a note in "Architecture" that this single-file structure is a deliberate user constraint to preserve in future sessions rather than re-split.

**Files changed:**
- `tp-1/index.html` (edited) — now a single self-contained file with inline `<style>` and `<script>`
- `tp-1/style.css` (deleted) — contents moved into `index.html`
- `tp-1/app.js` (deleted) — contents moved into `index.html`
- `tp-1/README.md` (edited) — updated Stack/Structure sections
- `tp-1/CLAUDE.md` (edited) — updated Architecture section and file references throughout Branding/Anti-patterns

**Notes / caveats:**
- Pure repackaging, not a rewrite — every constant, function, class name, and CSS rule is unchanged; only the file boundaries moved. Re-verified anti-pattern behaviors (bubbles, keypad, toggle list, datetime stepper) still worked post-migration rather than assuming a copy-paste was risk-free.
- Interpreted "single file" as covering markup/CSS/JS (the three files that existed) and deliberately left the PNG logo as an external asset rather than inlining it as base64 — flagged this scoping choice rather than silently deciding it either way.


## 2026-09-02 — Logo now loaded live from Wikimedia Commons instead of a local asset

**Prompt (verbatim):**
- "el asset intentemos capturarlo directo de aca https://www.google.com/url?...url=https%3A%2F%2Fes.wikipedia.org%2Fwiki%2FSubterr%25C3%25A1neos_de_Buenos_Aires... si no fuera posible pasemos a b64 y dejemos el single file"
- "No es mejor llamar la url de wikimedia desde el" (interrupted)
- "No es mejor llamar la url de wikimedia desde el html? https://upload.wikimedia.org/wikipedia/commons/b/bf/Subte-logo.svg?utm_source=es.wikipedia.org&utm_campaign=index&utm_content=original"

**Actions taken:**
1. Resolved the Google-redirect URL to the real target, `https://es.wikipedia.org/wiki/Subterráneos_de_Buenos_Aires`, and used WebFetch to find the logo it links to: the Wikimedia Commons file `Subte-logo.svg`, at `https://upload.wikimedia.org/wikipedia/commons/b/bf/Subte-logo.svg`.
2. Downloaded that SVG via `curl` to the scratchpad and rendered a PNG preview with `rsvg-convert` to confirm it's the same real SBASE "Subte / Buenos Aires Ciudad" mark already used in the header (visually identical to the previously-used local `assets/subte.png`) — so capturing it from the Wikipedia-linked source was possible, satisfying the first branch of the original ask.
3. First pass: base64-encoded the downloaded SVG and inlined it as a `data:image/svg+xml;base64,...` URI directly in both the `<link rel="icon">` and the header `<img src>` in `tp-1/index.html`, per the original instruction's fallback ("si no fuera posible pasemos a b64" — interpreted as also applying to "finish the single-file goal now that a real source was found").
4. User interrupted mid-message, then clarified: they'd rather reference the Wikimedia URL directly (`<img src="https://upload.wikimedia.org/...">`) instead of embedding base64. Since this reopens the single-file-vs-external-dependency tradeoff from the previous session, asked via AskUserQuestion to confirm — user explicitly chose "URL externa de Wikimedia" over the base64 inline option, accepting that the page now depends on Wikimedia being reachable.
5. Reverted the base64 data URIs back to the plain external URL (`https://upload.wikimedia.org/wikipedia/commons/b/bf/Subte-logo.svg`, without the tracking `utm_*` query params) in both the `<link rel="icon">` and the header `<img>` in `tp-1/index.html`.
6. Deleted the now-unused `tp-1/assets/subte.png` and the empty `tp-1/assets/` directory (confirmed untracked in git first).
7. Verified via `node --check` on the extracted inline `<script>` (still valid — this was a markup-only change) and a rendered screenshot (`chromium-browser --headless` serving the folder) confirming the yellow circular Subte logo renders correctly in the header, fetched live from Wikimedia.
8. Updated `tp-1/CLAUDE.md` ("Architecture" and "Branding" sections) and `tp-1/README.md` ("Stack"/"Structure") to describe the logo as loaded live from Wikimedia Commons rather than a local asset or a data URI, and to flag that this is the page's one network dependency (an internet connection is now needed for the header image to render, even though the rest of the app has no backend).

**Files changed:**
- `tp-1/index.html` (edited) — `<link rel="icon">` and header `<img src>` now point at the Wikimedia Commons SVG URL
- `tp-1/assets/subte.png` (deleted) — no longer referenced anywhere
- `tp-1/CLAUDE.md` (edited) — updated Architecture/Branding sections
- `tp-1/README.md` (edited) — updated Stack/Structure, noted the network dependency

**Notes / caveats:**
- The page is no longer 100% self-contained/offline-capable — it now makes exactly one external network request (the Wikimedia logo fetch) on load. This was a deliberate, explicit tradeoff the user made after being shown the alternative (base64 inline, fully offline-capable) side by side.
- If `Subte-logo.svg` is ever renamed/moved/deleted on Wikimedia Commons, or Commons is unreachable, the header logo (and favicon) will silently fail to load — no fallback `alt`-text styling or local backup copy was added, since none was requested.
- The brand-color tokens (`--color-brand-yellow`/`--color-brand-black`) were originally sampled from the now-deleted local PNG, not re-sampled from the SVG in this session — flagged in `tp-1/CLAUDE.md` as based on a "since-deleted local copy of this same logo" for traceability, but the values themselves weren't re-verified against the new SVG source since the mark is visually identical.


## 2026-09-02 — Complaint type replaced with a ball-toss basket mini-game

**Prompt (verbatim):** "El tipo de reclamo se debería llenar con una componente minijuego que consista en arrojar una pelota y embocar en una canasta que sean los tipos de reclamo posibles. Debe tener un boton de reiniciar para seleccionar otra."

**Actions taken:**
1. In `tp-1/index.html`, replaced the `<select id="type">` (6 complaint-type options) with a `<canvas id="claim-game-canvas" width="560" height="260">` inside a `.claim-game` wrapper, plus a hint text span (`#claim-game-hint`) and a `Reiniciar` button (`#claim-game-reset`), and kept a `<input type="hidden" id="type" name="type" required>` carrying the actual selected value — same pattern used for the datetime stepper/phone keypad.
2. Implemented a small 2D physics mini-game in the inline `<script>`: `CLAIM_TYPES` maps the same 6 values from the old `<select>` (demora/limpieza/seguridad/accesibilidad/personal/otro) to short basket labels; `claimBaskets` lays out 6 evenly-spaced "basket" zones along a floor line drawn on the canvas. A ball starts at a fixed launch point; the user drags it backward (slingshot metaphor — pointerdown near the ball, pointermove to aim, pointerup to release) and `launchClaimBall()` converts the drag vector into an opposite-direction velocity (clamped max pull distance, scaled down), then `updateClaimBallPhysics()` runs every frame via `requestAnimationFrame` applying gravity (`GRAVITY = 0.35`/frame) and horizontal-wall clamping.
3. Collision resolution: when the falling ball crosses the baskets' rim height (`BASKET_RIM_Y`), `findClaimBasketAt()` checks whether the ball's x falls inside a basket's horizontal range — a hit calls `resolveClaimCatch()` (snaps the ball into that basket, sets `typeHidden.value`, highlights the basket in brand yellow, updates the hint text); otherwise the ball keeps falling to the floor and `resolveClaimMiss()` fires (no value set, hint says "Fallaste").
4. Either outcome sets `claimBall.launched = true` permanently until reset, and the `pointerdown` handler on the canvas early-returns if `claimBall.launched` — so a new throw is impossible without pressing the button, per the explicit requirement ("Debe tener un botón de reiniciar para seleccionar otra"). `resetClaimGame()` (wired to `#claim-game-reset`) resets the ball to the launch point, clears `typeHidden.value` back to empty (forcing a fresh throw to get a valid selection again, consistent with this TP's other anti-patterns rather than preserving the last catch), clears the basket highlight, and resets the hint text and any error styling.
5. Added `validateTypeGame()` (required-check on `typeHidden.value`, same shape as `validateEmailKeypad()`/`validateLinePicker()`), called after every resolved throw (catch or miss) for live feedback and from the submit handler; excluded `name="type"` from the generic per-field `validateField()` loop and blur-listener wiring (same treatment as `line`/`station`/`datetime`/`email`, since it's now a hidden input driven by canvas interaction, not blur). Wired `resetClaimGame()` into the "Cargar otro reclamo" handler alongside the other field resets, and into initial page load (`resetClaimGame(); requestAnimationFrame(claimGameLoop);`).
6. Added `.claim-game`/`.claim-game__controls`/`.claim-game__hint`/`.claim-game__reset` styles in the inline `<style>` block (bordered card, responsive canvas via `aspect-ratio`, `touch-action: none` so dragging doesn't scroll the page on mobile, reused `.field.has-error` pattern for the error border).
7. Verified interactively via CDP (`chromium-browser --headless=new --remote-debugging-port`, same technique as prior sessions), since this needed real physics/interaction testing, not just a static screenshot: (a) set `claimBall.vx`/`vy` directly and enabled `launched` to simulate a throw — confirmed a well-aimed shot (`vx=4, vy=-8.5`) landed in and correctly identified the "Limpieza" basket, setting `typeHidden.value` and the hint text, with a screenshot showing the ball resting inside the highlighted basket; (b) clicking `#claim-game-reset` correctly cleared the value/hint and set `claimBall.launched = false`; (c) a deliberately weak throw (`vx=0.3, vy=-2`, falls short of the basket zone) correctly resolved as a miss with no value set; (d) dispatched a synthetic `pointerdown` near the ball while `claimBall.launched` was still `true` (before pressing reset) and confirmed `claimDragging` stayed `false` — new drags are genuinely blocked until reset, not just visually suggested.
8. Documented this as a new anti-pattern in `tp-1/CLAUDE.md` (Nielsen #7 — a physics-aiming task is far slower than clicking a dropdown option — and flagged as a harder accessibility failure than the other anti-patterns: the pointer-drag-only interaction has no keyboard-operable path at all, unlike the other custom pickers which remain keyboard-focusable). Updated the field list.

**Files changed:**
- `tp-1/index.html` (edited) — `<select id="type">` replaced with the `.claim-game` canvas component + hidden input; added the mini-game physics/rendering/input-handling JS and its CSS
- `tp-1/CLAUDE.md` (edited) — added the ball-toss mini-game anti-pattern entry and updated the field list

**Notes / caveats:**
- No keyboard-accessible fallback was added for this field (e.g. an alternate `<select>` behind a "no puedo jugar" link) — not requested, and every other custom picker in this TP remains at least nominally keyboard-operable (radios, hidden-input-plus-buttons), so this is a genuinely new, more severe accessibility regression worth flagging prominently rather than quietly matching the others.
- Physics constants (`GRAVITY`, `THROW_POWER_SCALE`, `MAX_DRAG_DISTANCE`) were hand-tuned by trial via the CDP test harness (direct `vx`/`vy` injection) rather than derived analytically — they produce a landable, not-impossibly-hard arc within the 560×260 canvas, but weren't tuned against real mouse/touch drag distances in a live browser session (only synthetic velocity injection and one synthetic `pointerdown`/`claimDragging` check were exercised), so real-user drag "feel" may need a follow-up tuning pass if it turns out too twitchy or too sluggish.
- On reset, the hidden value is cleared rather than preserved — a deliberate choice to keep this consistent with the rest of the TP's friction-by-design pattern (e.g. the station toggle requiring a full re-flip), not an oversight.


## 2026-09-02 — Phone field replaced with a binary (BCD) bit-entry component

**Prompt (verbatim):** "El teléfono que se tenga que ingresar en binario y se muestre el resultado."

**Actions taken:**
1. In `tp-1/index.html`, replaced `<input type="tel" id="phone">` with a `.binary-phone` component: a display area (`#binary-phone-bits` showing the raw bit string grouped in nibbles, `#binary-phone-result` showing the live-decoded decimal result) and a 3-button keypad (`0`, `1`, and a delete key) — no digit buttons or free-text entry exist. Kept `<input type="hidden" id="phone" name="phone">` (still optional, no `required`) carrying the actual decoded value.
2. In the inline `<script>`, added `phoneBits` (array of typed `"0"`/`"1"` characters), `decodeBcdNibble()` (interprets a 4-bit group as BCD: `parseInt(nibble, 2)`, valid only for `0000`–`1001` → digits `0`–`9`, anything else → `"?"`), and `renderBinaryPhone()`: groups the bit string into 4-bit chunks for display, decodes every *complete* nibble, and sets the hidden input's value to the decoded string — but only if no nibble decoded as `"?"`; a single invalid nibble anywhere blanks the entire hidden value back to empty, even though the display still shows the partial decode with `?` placeholders so the user can see what happened.
3. Added `pressPhoneBit()`/`deletePhoneBit()`/`resetBinaryPhone()` and a single delegated click listener on `.binary-phone__keys` (same delegation pattern as the email keypad and claim-game reset button). Wired `renderBinaryPhone()` into initial page load and `resetBinaryPhone()` into the "Cargar otro reclamo" handler.
4. Added `.binary-phone`/`.binary-phone__display`/`.binary-phone__bits`/`.binary-phone__result`/`.binary-phone__keys`/`.binary-phone__key` styles in the inline `<style>` block (monospace bit display, muted "Resultado" line with the decoded value in `<strong>`, three-button row matching the visual weight of the email keypad's buttons).
5. Verified interactively via CDP (`chromium-browser --headless=new --remote-debugging-port`, same technique as prior sessions in this TP): scripted clicks on `[data-bit]`/`[data-action="delete"]` to enter `00010101` (BCD for "15") — confirmed the hidden input became `"15"`, the bit display showed `"0001 0101"`, and the result line showed `"Resultado: 15"`. Then deleted the last nibble and typed `1010` (invalid BCD, decimal 10) — confirmed the display showed `"15?"` and, critically, the hidden input's value reverted to `""` (not `"15"` with the bad digit dropped) — the "one bad nibble voids everything" behavior works as designed, not just for the single bad digit. Screenshot confirmed the rendered component matches (bit groups, result line, 0/1/⌫ keys).
6. Documented this as a new anti-pattern in `tp-1/CLAUDE.md` (Nielsen #5 — no cheaper way to type a phone number than reciting it in binary — and #9 — the `?` signals an error but not which nibble, and the only recovery is retyping the whole number). Updated the field list.

**Files changed:**
- `tp-1/index.html` (edited) — phone `<input type="tel">` replaced with the `.binary-phone` component + hidden input; added the BCD encode/decode JS and its CSS
- `tp-1/CLAUDE.md` (edited) — added the binary-phone anti-pattern entry and updated the field list

**Notes / caveats:**
- Interpreted "se muestre el resultado" as showing the live-decoded decimal number as the user types (not just after some final "convert" action) — this seemed like the more literal, more immediately-legible reading of "show the result," and keeps the field's live-feedback pattern consistent with the email keypad and claim-type mini-game already in this form.
- The all-or-nothing invalidation on a bad nibble was a judgment call, not explicitly requested — chose it over silently dropping/ignoring invalid nibbles because it's more consistent with this TP's established pattern of one small mistake costing the whole input (mirrors the toggle-switch and description-darkening anti-patterns), and it's the more "annoying" reading, which fits the assignment's brief.
- Field stays optional (no `required` on the hidden input) since the original phone field was optional and nothing in the request asked to change that — an all-zero or empty bit string just means no phone was provided, same as before.


## 2026-09-02 — Confirmation screen now shows a summary of the submitted data

**Prompt (verbatim):** "En la pantalla de reclamo enviado que se muestren los datos ingresados a modo de resumen."

**Actions taken:**
1. In `tp-1/index.html`, added a `<dl class="confirmation__summary" id="confirmation-summary"></dl>` inside the `#confirmation` block, between the ticket-number paragraph and the "Cargar otro reclamo" button.
2. In the inline `<script>`, added `TYPE_LABELS` (maps the complaint-type mini-game's short basket labels/values back to the original fuller Spanish phrasing, e.g. `demora` → "Demora / frecuencia") and `buildConfirmationSummary()`: reads the current value of every field — line (`form.elements.line.value`), station (checked checkbox in `stationGrid`), incident datetime (`formatDateTime(incidentDateTime)`), complaint type (via `TYPE_LABELS`), description, first/last name, email (`emailValue`), phone (`phoneHidden.value`, falling back to an em dash if empty since it's optional) — and renders them as `<dt>`/`<dd>` pairs built with `createElement`/`textContent` (not string-concatenated `innerHTML`) so the free-text description can't inject markup.
3. Called `buildConfirmationSummary()` in the submit handler, right after `ticketNumberEl.textContent = ticketNumber` and before showing the confirmation panel, so the summary reflects the exact data that just passed validation.
4. Added `.confirmation__summary`/`dt`/`dd` styles in the inline `<style>` block: a bordered, left-aligned card (overriding the `.confirmation` parent's centered text) with muted uppercase-weight labels and normal-weight values.
5. Verified end-to-end via CDP (`chromium-browser --headless=new --remote-debugging-port`): scripted filling every field programmatically (clicking a line radio and a station checkbox directly — bypassing the moving bubbles/shuffled order rather than fighting them — injecting a valid ball throw for the complaint-type game, setting the description via a real `input` event, selecting name dropdown options, and setting the email keypad's internal state to a valid address), then clicked the real submit button. Confirmed zero validation errors remained, the confirmation panel became visible, and the rendered summary showed all 9 fields with correct human-readable values (e.g. "Tipo de reclamo: Limpieza", "Estación: Diagonal Norte"). Screenshot confirmed the visual layout reads cleanly.
6. Updated `tp-1/CLAUDE.md`'s "Submissions are simulated" note to describe the new summary and explicitly flagged it as a plain usability feature, not one of the catalogued anti-patterns (to avoid future confusion when scanning that file for friction points).

**Files changed:**
- `tp-1/index.html` (edited) — added the `#confirmation-summary` `<dl>`, `buildConfirmationSummary()`/`TYPE_LABELS`, and its call in the submit handler, plus the summary's CSS
- `tp-1/CLAUDE.md` (edited) — noted the new summary in the "Submissions are simulated" paragraph

**Notes / caveats:**
- This is a genuine usability improvement requested on top of an otherwise deliberately-degraded form — did not use it as an excuse to also surface or "fix" any of the existing anti-patterns; the summary just displays whatever ends up in each field's already-existing state (including a raw one-letter line code like "B" rather than a full line name, since that's the value the line picker itself stores — no new lookup was added there since it wasn't asked for).
- Testing programmatically clicked the underlying radio/checkbox inputs directly for the line and station pickers instead of simulating pointer drags on their bouncing/shuffled UI — this is a valid way to check the *data flow* (does the summary reflect what's selected) but doesn't re-verify the bubbles/shuffle interactions themselves, which were already covered in earlier sessions.


## 2026-09-02 — Bug fix: clicking a station toggle jumped the page to the bottom

**Prompt (verbatim):** "cuando se selecciona un toggle te manda al fondo de la página. Eso no es comportamiento esperado. Fix"

**Actions taken:**
1. Diagnosed the root cause: the station toggle's real `<input type="checkbox">` is visually hidden with the standard `position: absolute; width: 1px; height: 1px; clip: rect(0 0 0 0)` pattern (`.toggle-switch input` in the inline `<style>`), but its direct parent (`.toggle-switch`) had no `position` set. An absolutely-positioned element with no positioned ancestor falls back to being positioned against the page's initial containing block using a browser-computed "static position" — inside a `display:flex` row (`.station-row`) this fallback is unreliable across engines, and clicking the label focuses that off-place input; browsers auto-scroll a newly-focused element into view, which is what was dragging the page down.
2. Confirmed the same unpositioned-ancestor pattern existed on `.line-option` (the Línea sphere picker's hidden radio), currently masked only because `.line-picker--bubbles .line-option` happens to add `position: absolute` in the one context actually used on the page — so it was fixed defensively too, before it could cause the identical bug if that class combination ever changed.
3. Fix: added `position: relative;` to `.toggle-switch` (the real fix for the reported bug) and to the base `.line-option` rule (defensive, since the bubble-mode override already had positioning covering current usage) in `tp-1/index.html`'s inline `<style>`. This gives the visually-hidden inputs a correctly-scoped containing block, so their static position resolves to right where their visible sibling (`.toggle-switch__track` / `.line-sphere`) actually is, instead of an unpredictable page-level fallback.
4. Verified via CDP (`chromium-browser --headless=new --remote-debugging-port`, `Input.dispatchMouseEvent` for a real synthetic mouse click rather than `.click()`, to better match actual user interaction): confirmed `document.querySelector('.station-row input[name="station"]').getBoundingClientRect()` now reports coordinates matching its visible `.toggle-switch__track` sibling (previously not directly compared before/after due to a headless-vs-real-browser discrepancy noted below); confirmed clicking the visible track still correctly checks the underlying input and still triggers the existing "disable all other toggles" anti-pattern; confirmed `window.scrollY` was unchanged before/after the click; screenshot showed the toggled row highlighted correctly with no unexpected scroll.
5. Did not otherwise touch the station-toggle anti-pattern behavior (still self-blocking, still requires flipping back off before picking another) — this was purely a positioning bug fix, not a friction change.

**Files changed:**
- `tp-1/index.html` (edited) — added `position: relative;` to `.toggle-switch` and `.line-option` in the inline `<style>`

**Notes / caveats:**
- Could not get the exact "scrolls to the very bottom of the page" symptom to reproduce bit-for-bit inside headless Chromium via CDP-driven synthetic clicks — both `.click()` and a full synthetic mouse press/release sequence left `scrollY` unchanged even *before* the fix was applied, suggesting headless Chromium's focus-scroll heuristics don't trigger identically to whatever real browser/interaction the user hit this in. The underlying CSS defect (an absolutely-positioned focusable element with no positioned ancestor, inside a flex row) is nonetheless a well-known, real cause of exactly this class of jump-on-focus bug, and the fix is the standard, correct one for it — applied on the strength of the diagnosis rather than a pixel-perfect repro.
- If the user still sees a jump after this fix, worth checking their exact browser/OS and whether it happens on the very first toggle in the list or any of them, since that would help narrow whether it's this same root cause recurring elsewhere or a second, different bug.
