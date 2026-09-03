# TP-1 — Subte Complaint Form

A plain HTML/CSS/JS front-end for filing a complaint about Buenos Aires's Subte (subway) service.

## About this assignment

This TP is a UI/UX exercise: build a working form first, then (in a later pass) deliberately make it hard to use in order to study usability heuristics and anti-patterns. Right now the form is meant to be **correct and straightforward** — no intentional friction yet.

## Stack

- A single self-contained HTML file (markup, CSS in `<style>`, and vanilla JS in `<script>`). No framework, no build step, no backend.
- Form submissions are simulated client-side (see `tp-1/CLAUDE.md` for details) since there is no server in this TP.
- The Subte logo in the header is loaded live from Wikimedia Commons — the only network dependency the page has.

## Running it

Open `index.html` directly in a browser (double-click it, or `file://` it), or serve the folder with any static file server, e.g.:

```
python3 -m http.server -d tp-1 8000
```

Then visit `http://localhost:8000`. An internet connection is needed for the header logo to load.

## Structure

- `index.html` — the complaint form: markup, styling, and behavior all in one file. No other project files.

See `tp-1/CLAUDE.md` for architecture notes and conventions specific to this TP.
