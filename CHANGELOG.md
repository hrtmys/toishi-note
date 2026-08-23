# Changelog

All notable changes to this project are documented here. Format loosely follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this project doesn't yet follow Semantic Versioning strictly (pre-1.0 — see `docs/product/roadmap.md`'s versioning table for what each stage means).

## [0.1.0] — 2026-08-24

The public beta — everything below shipped in the run-up to the first release strangers are invited to run.

### Added
- Ctrl/Cmd+P command palette: jump to any note by title, most-recently-viewed first, with the second-most-recent entry preselected so Ctrl+P → Enter alternates between the last two notes.
- Markdown list continuation: Enter continues `-`, `*`, `1.`, `- [ ]`, and `>` markers (or removes an empty one instead of continuing it); Tab/Shift+Tab indent. IME-safe, preserves the native undo stack.
- Settings → Account tab: email and sign-out relocated out of the sidebar; sign-out hidden (with an explanation) under trusted-header auth, where it previously signed the user out and immediately back in.
- Content Security Policy (`script-src 'self'`, no `unsafe-inline`) — the whole third-party-CDN removal effort (below) is what made this achievable.
- `bin/ci`: one-command local verification (tests, RuboCop, Brakeman, dependency audits) with compact, token-efficient output — see `docs/engineering/verification.md`.
- `bin/backup` / `bin/restore`: tested SQLite-safe backup and restore for `storage/` — see `docs/engineering/backup.md`.
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

[0.1.0]: https://github.com/hrtmys/toishi-note/releases/tag/v0.1.0
