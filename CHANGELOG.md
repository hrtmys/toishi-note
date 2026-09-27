# Changelog

All notable changes to this project are documented here. Format loosely follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this project doesn't yet follow Semantic Versioning strictly (pre-1.0 — see `docs/product/roadmap.md`'s versioning table for what each stage means).

## [0.2.1] — 2026-09-28

A new app icon, and the install button back in Chrome and Edge.

### Changed
- New app icon: an abstract mark of two stones with a bevelled blade between them, replacing the torii from the project's earlier name. Transparent background, with a padded maskable variant for Android. The favicon and touch icon use it too, and the 1.7MB original image is gone.

### Fixed
- Chrome and Edge now offer "Install app" again. The manifest pointed at a single 1536px icon, which Chrome rejects as unsuitable, so the only option left was "install page as app", which pins the current URL. The manifest now lists standard 192px and 512px icons.

## [0.2.0] — 2026-09-27

The editor batch, the TODO hub, and the first two pieces of faster movement around the app. Migrations are additive only (two boolean columns).

**If you installed Toishi Note as an app from Chrome or Edge, uninstall it and install it again once** — see the first Fixed entry.

### Added
- Editor shortcuts: Ctrl+B / Ctrl+I / Ctrl+K, paste a URL over a selection to make a link, automatic renumbering of ordered lists, and Ctrl+Shift+K to delete a line — all undo-preserving and IME-safe.
- A "Pinned" section at the top of the sidebar listing pinned notes from every notebook, so a favorite note is one click away wherever you are.
- TODO hub: `/todos` is now a mode of the main pane (the sidebar stays), with a project view grouped by notebook/folder/note and the due-first list.
- AI handoff, off by default in Settings: copy open TODOs as Markdown (or fetch `GET /todos.md`, session-authenticated), paste an AI's edited reply back, and apply it behind a preview that lists every add, check, due change and delete. A per-note flag keeps a note out of the handoff.
- The per-note bulk-add modal accepts `- [ ]` Markdown with due dates, not just JSON.
- Per-user memory of the last notebook and folder, so a reload lands where you left off.

### Changed
- Sidebar sections size to their content, capped as a share of the sidebar rather than of the window, and the file list always keeps a usable height on short windows.
- Pasting HTML keeps the undo stack (Shift+Ctrl+V pastes plain text), with a toast when it was converted to Markdown.
- Mobile/sidebar polish: the off-canvas sidebar no longer replays its animation on navigation, touch devices get a per-row ⋮ menu, and the note title uses the full header width.

### Fixed
- Installing the app from Chrome/Edge now always launches at the root and restores the last note, instead of reopening the page it was installed from. Existing installs need to be uninstalled and reinstalled once to pick this up.
- `*` + space + Enter continues the bullet instead of deleting it.
- Create/rename/delete actions give visible feedback, and silent autosave, settings, and scrap-source failures now show an error toast.
- Concurrent reorders and moves are serialized with row locks, and several N+1 queries are gone.
- Image uploads are size-capped and checked to be real images; bulk TODO import is count-capped.
- Preview scrolling stays put, and Mermaid/KaTeX no longer flicker or break under rapid typing.
- IME-safe auto-titling, and sturdier Word paste (unformatted pastes, copy failures, pasted images).

## [0.1.0] — 2026-08-24

The public beta — everything below shipped in the run-up to the first release strangers are invited to run.

### Added
- Ctrl/Cmd+P command palette: jump to any note by title, most-recently-viewed first, with the second-most-recent entry preselected so Ctrl+P → Enter alternates between the last two notes.
- Markdown list continuation: Enter continues `-`, `*`, `1.`, `- [ ]`, and `>` markers (or removes an empty one instead of continuing it); Tab/Shift+Tab indent. IME-safe, preserves the native undo stack.
- Settings → Account tab: email and sign-out relocated out of the sidebar; sign-out hidden (with an explanation) under trusted-header auth, where it previously signed the user out and immediately back in.
- Content Security Policy (`script-src 'self'`, no `unsafe-inline`) — the whole third-party-CDN removal effort (below) is what made this achievable.
- `bin/ci`: one-command local verification (tests, RuboCop, Brakeman, dependency audits) with compact, token-efficient output — see `docs/engineering/verification.md`.
- `bin/backup` / `bin/restore`: tested SQLite-safe backup and restore for `storage/` — see `docs/engineering/backup.md`.
- Optimistic locking on note saves (`lock_version`): concurrent edits from a second device show a conflict prompt (reload vs. keep mine) instead of silently last-write-wins. (Shipped in v0.1.0; recorded here 2026-09-09 — it was missing from these notes.)
- `.env.example`, a real self-hosting quickstart in `docs/engineering/deployment.md`, and `APP_HOST`/`APP_PROTOCOL` env vars so password-reset/invite emails link to the right domain instead of a placeholder.

### Fixed
- Scrap items rendered pasted Markdown without sanitization (self-XSS via pasted AI output) — now always sanitized, same as every other Markdown surface.
- Sidebar no longer relies on a remembered scroll offset that could silently go stale; scrolls the active row into view instead.
- `navigation_controller.js`'s `disconnect()` passed a freshly-bound function to `removeEventListener`, so the listener was never actually removed.
- i18n leak: default note titles and the "has this note been titled yet?" check were hardcoded to Japanese strings, so an English-locale user got Japanese titles and never got first-line auto-titling at all.
- A fresh clone couldn't boot in production: `config/credentials.yml.enc` was encrypted with a key only the original maintainer had. Regenerated with a fresh placeholder key meant for public distribution.
- `docker-compose.yml` depended on an external Docker network and published no port — unusable by anyone other than the original maintainer's own VPS. Now self-contained and reachable at `127.0.0.1:3000` out of the box.

### Removed
- All third-party CDN requests (KaTeX, Mermaid, Google Fonts) — everything is now bundled and self-hosted; the app works with the network blocked.
- Kamal scaffolding (`config/deploy.yml`, `.kamal/`) — half-configured and never matched the actual (Docker Compose) deployment.
- ~10.3MB of unminified JS/sourcemap payload and dead code (`_easymde.scss`, `NotesController#preview`, the `redcarpet` gem, unused globals, empty helper modules).

### Changed
- `db/seeds.rb` rewritten from Japanese demo business data into a locale-aware welcome/tutorial notebook.
- `docs/engineering/deployment.md` rewritten as a generic self-hosting guide; maintainer-specific VPS topology moved out of the public repo entirely.

[0.2.1]: https://github.com/hrtmys/toishi-note/releases/tag/v0.2.1
[0.2.0]: https://github.com/hrtmys/toishi-note/releases/tag/v0.2.0
[0.1.0]: https://github.com/hrtmys/toishi-note/releases/tag/v0.1.0
