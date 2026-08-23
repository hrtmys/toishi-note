---
title: Pre-Beta Checklist
description: What has to be true before the tree is pushed into the fresh toishi-note repository as v0.1.0
status: living
updated: 2026-08-15
---

# Pre-beta checklist

The v0.1.0 public beta is the moment the tree gets pushed into a brand-new repository as a single initial commit (mechanics: [release-process.md](release-process.md); the version label moved from v1.0 to v0.1.0 — see [roadmap.md § 2](../product/roadmap.md)). Whatever is in the tree that day becomes the entire visible history of the project. There is no "we'll clean that up later" commit to point at.

So this list is not "nice things to do before launch." It is: **what would embarrass the project, or lose someone's data, if a stranger cloned it on day one.**

Three tiers: **Blockers** hold the release. **Should-fix** are things a reviewer will notice and think less of the project for. **Housekeeping** is mechanical and can be batched into one commit.

---

## Blockers

### 1. ~~Assets: 11.6MB of unminified payload, part of it from a CDN~~ — done

The reasoning lives in [asset-strategy.md](asset-strategy.md); this records what shipped and corrects two things this section originally got wrong.

| Artifact | Before | After |
|---|---|---|
| `application.js` (production) | 10,493,077 bytes | **214,310 bytes (62,413 gzipped)**, no Mermaid/KaTeX/highlight.js in it |
| `application.js.map` (production) | 17MB | none |
| `application.css` | 1,137,960 bytes | **911,464 bytes (145,431 gzipped)** |

Both under the "JS < 500KB gzipped, CSS < 150KB gzipped" targets. `--minify`/no-sourcemap in production is driven by `RAILS_ENV` inside `package.json`'s own `build` script (a real Docker `ENV` var by the time `assets:precompile` shells out to `yarn`), so `bin/dev` and `db:test:prepare` are untouched. `--style=compressed` was added to the Sass build unconditionally.

**Correction: `--splitting` turned out to be required, not something to avoid.** This section originally claimed dynamic `import()` alone emits separate chunks without it — false. Without `--splitting`, esbuild inlines a dynamically-imported module straight back into the same output file (confirmed by inspecting the compiled output), so nothing was actually being lazy-loaded. `--splitting`'s default `chunk-XXXXXXXX.js` naming does collide with Propshaft's digest-detection regex, exactly as the Organize-view comments said — but the fix is `--chunk-names="chunks/[name]-[hash].digested"`, using Propshaft's own documented escape hatch for externally-fingerprinted files (its README, "Bypassing the digest step"), not avoiding `--splitting` altogether. Verified against both a real dev server and a real `assets:precompile` + static-file-served `public/assets` (the actual Docker path): every chunk resolves at the exact filename baked into the importing file, in both modes.

One consequence: `organize_controller.js`'s existing "separate top-level entry point" workaround for SortableJS (specifically built to avoid `--splitting`) turned out to not actually be lazy either — the same inlining-without-`--splitting` issue — and was now broken outright by turning `--splitting` on (its plain, undigested output filename would 404 the same way a direct request for `application.js` does). Deleted the workaround; `organize_controller.js` now does a plain `import("sortablejs")`, split like everything else.

**Icon subsetting was dropped, not done.** Measured before touching it: `application.css` at 145,431 bytes gzipped is already under the 150KB target *with the full 2,078-icon set still in it* — bootstrap-icons' own CSS is only ~13KB of that gzipped. A hand-maintained subset (32 rules copied out of the full file) has a real ongoing cost: forgetting to add a newly-used icon's rule doesn't error, it silently renders a missing glyph, which is exactly the kind of contributor trap this project is trying to avoid elsewhere. An automated subset (a build step that greps for `bi-*` usage) removes that trap but adds real complexity to save ~13KB against a budget that's already met. Neither side of that trade earns its cost here — left as the full, unmodified `@import 'bootstrap-icons/font/bootstrap-icons'`.

### 2. ~~Third-party CDNs in the runtime path — including a library loaded twice~~ — done

`layouts/application.html.erb` pulls KaTeX 0.16.9 and Mermaid 10.6.1 from `cdn.jsdelivr.net` on **every page load**, while `package.json` depends on KaTeX 0.18.1 and Mermaid 11.16.1 and `lib/markdown_renderer.js` imports them directly. **Mermaid is downloaded twice, at two different major versions**, and which one wins depends on load order.

Deleting the CDN tags is strictly a fix — smaller, faster, private, and it resolves a version conflict. The full argument for why no CDN is ever acceptable in this product's runtime path (README accuracy, egress-free 情シス networks, supply chain, offline mode, CSP) is in [asset-strategy.md § 1](asset-strategy.md); it is settled policy, not a preference.

Delete the CDN `<script>`/`<link>` tags and the inline `mermaid.initialize` block. Self-host `katex.min.css` through Propshaft.

### 3. ~~Fonts come from Google, and the wrong one is applied~~ — done

Two problems in one place. `layouts/application.html.erb` preconnects to `fonts.googleapis.com` and loads **BIZ UDPGothic** — the *proportional* variant. That is the reported "全角半角が分かりづらい" symptom: proportional CJK metrics make half-width and full-width characters hard to tell apart, which matters constantly in an editor holding mixed Japanese and code.

- Switch content-bearing surfaces (editor, preview, note lists, titles) to **BIZ UDGothic** — same family, fixed width. Keep the proportional face for chrome if desired.
- Give the editor `<textarea>` a CJK-capable monospace stack rather than the bare `monospace` it has now.
- **Self-host the font** for the same reasons as item 2, and because DOM-to-PNG capture (roadmap v0.4) can only embed fonts it is allowed to read. BIZ UDGothic is distributed under the SIL Open Font License 1.1 — confirm that at the source before vendoring, and ship the license file alongside it.

### 4. ~~Scrap items render Markdown without sanitization~~ — done

`editor_controller.js` calls `renderMarkdownIntoElement(..., { sanitize: true })`. `markdown_controller.js` — which renders every Scrap item — does not, and `marked` does not strip HTML on its own. Scrap is the note type explicitly designed to receive pasted AI output, i.e. text from somewhere else.

The blast radius is limited (each account only ever renders its own content), so this is self-XSS rather than a cross-account hole. It is still a one-word fix in a project that ships a [SECURITY.md](../../SECURITY.md), and "we render untrusted paste through an unsanitized Markdown pipeline" is not a sentence to have in the initial commit.

### 5. ~~Japanese leaks through the i18n layer~~ — done

`Note::DEFAULT_TITLES` hardcodes `無題のノート` / `無題のTODO` / `無題のスクラップ`. An English-locale user creating a note gets a Japanese title. Worse, `auto_set_title` decides "is this still an untitled note?" by regex-matching those Japanese strings — so a note created under an English locale never picks up its first line as a title, which is a real behavioral difference between locales, not just a cosmetic one.

Both come from encoding a state ("the user hasn't titled this") as a magic string. Model it explicitly and translate the display value.

Also in this pass, since the launch audience will read the source: the Japanese comments in `layouts/application.html.erb` (`領域のアニメーション`, `テーブル崩れ防止など`) contradict [coding-style.md](coding-style.md)'s English-comments rule.

### 6. ~~The README has no answer to "how do I run this on my server"~~ — done

`docker-compose.yml` no longer depends on the maintainer's own external network or private container names — it's self-contained, binds `127.0.0.1:3000` by default, and works against a plain `.env` (`.env.example` added). README gained a self-hosting quickstart above the fold, a "who this is for" comparison table, real screenshots (captured via the existing Capybara/Selenium system-test infrastructure, not mocked up), `README.ja.md`, and `CHANGELOG.md`. Issue/PR templates and `CODE_OF_CONDUCT.md` landed too — see item 12 below for the rest of what this same audit pass found and fixed.

### 7. ~~There is no documented backup path~~ — done

The archived roadmap describes a backup status line; nothing exists. Inviting strangers to keep their study notes in a SQLite file on a VPS, with no documented way to get them back, is the fastest way to earn the project's first angry issue.

`docs/engineering/backup.md`: `sqlite3 .backup` (not `cp` — never copy a live SQLite file), on cron, into rclone, with a 7-day rolling window, plus the restore procedure. Documentation only; the Account-tab status line is a v1.0 item.

### 8. ~~Dead code, deleted before it becomes history~~ — done

The point of a fresh repository is a clean first read. Each of these is currently a thing a curious contributor has to rule out:

- `app/assets/stylesheets/_easymde.scss` — ~15KB of vendored CodeMirror/EasyMDE CSS for a dependency that is not in `package.json`, plus the `.EasyMDEContainer` rules in `application.bootstrap.scss`
- `NotesController#preview` and the `redcarpet` gem — Markdown is rendered client-side by `marked`; the only caller left is a controller test
- `window.hljs` and `window.marked` in `application.js` — every real use goes through ES imports
- Five empty helper modules
- The 66-line inline `<style>` block in `home/index.html.erb` and the 28-line one in the layout — move to SCSS partials

Also done in the same sweep: roughly thirty comments across `app/`, `config/`, `db/migrate/`, and `test/` cited `ux-roadmap.md` by filename — repointed at [ux-roadmap.md.old](../product/ux-roadmap.md.old), which is where the reasoning they cite actually still lives (none of them turned out to reference anything that migrated into [roadmap.md](../product/roadmap.md), which is forward-looking rather than a restatement of shipped-feature rationale).

### 9. ~~`home/index.html.erb` is 353 lines~~ — done (86 lines, sidebar/editors extracted)

Sidebar, all three note-type editors, and inline CSS in one file. It is the file anyone evaluating the codebase opens first. Extract `home/_sidebar`, `notes/_todo_editor`, `notes/_scrap_editor` — mechanical, no behavior change, and it is the difference between "clean Rails app" and "someone's weekend project" at first glance.

### 10. ~~The JavaScript dependency tree has no vulnerability monitoring, and CI is defined twice~~ — done

Four separate gaps, all closed in one pass:

- `.github/dependabot.yml` gained an `npm` entry alongside `bundler` and `github-actions`.
- `config/ci.rb` and `bin/ci` (the unused, undocumented, never-called-by-anything second CI definition) were deleted rather than wired up — a single real definition, `.github/workflows/ci.yml`, is what actually gates PRs, and keeping a second one around invited exactly the divergence this item was about. Its two steps this workflow was missing — `yarn audit` (now its own `scan_js` job) and `db:seed:replant` (now a step in `test`, verifying the welcome-notebook seed from item 11 below stays runnable) — both migrated over.
- `test` and `system-test` now pin Node via `actions/setup-node` with `node-version-file: .node-version` (the same file the devcontainer already honors) plus a yarn cache, closing the gap `dev-environment.md`'s "the container matches CI" claim didn't actually cover.
- Net effect: DOMPurify, marked, and Turndown — everything that parses untrusted input in this app — are now covered by both Dependabot and a real CI audit step, not just the Ruby half.

### 11. ~~Japanese comments and Japanese demo data in the source~~ — done

The three comments this item originally flagged (`layouts/application.html.erb`, `scrap_items/_item.html.erb`) turned out already fixed — moved into SCSS and translated while removing the inline `<style>` blocks they lived in. `db/seeds.rb` — 387 lines, entirely Japanese, still describing the product under its old name (`"01. Citron Note v2 構想"`, `"- **Citron**: 超軽量・スピード重視"`) — was rewritten as a locale-aware welcome notebook that's the tutorial itself, not unrelated demo data: one Markdown note covering the three note types and the editor's own rendering (code/math/mermaid), one TODO note, one Scrap note, chosen by the owner's locale preference rather than fixed to one language.

(Two Japanese literals are still *correct* and stay: the `日本語` label in the settings language picker, and the kana/kanji character ranges in `text_format_controller.js`'s regexes — plus, now, `db/seeds.rb`'s own `:ja` content branch and the schema migration's `PLACEHOLDER_TITLES`, which names the old hardcoded strings it backfills away.)

---

## Should-fix

Not release-blocking, but each is something a reviewer will notice.

All done except the last one:

- ~~There is no Content Security Policy.~~ — done (`script-src 'self'`, no `unsafe-inline`; see `config/initializers/content_security_policy.rb`).
- ~~Kamal is half-configured scaffolding that isn't used.~~ — done (removed entirely).
- ~~`Note#set_defaults` assigns `note_type ||= "txt"`~~ — done (`note_type` is now a real enum, NOT NULL).
- ~~Nullable booleans with no database default~~ — done (`notes.is_pinned`, `todo_items.is_checked` are both `null: false, default: false`).
- ~~`notebooks.name` and `folders.name` are nullable`~~ — done (both `null: false` in the schema now).
- ~~`navigation_controller.js#disconnect` passes a freshly-bound function to `removeEventListener`~~ — done, fixed alongside the sidebar-scroll rework (see `scroll_controller.js`'s pattern, now copied there too).
- **`Note#todo_completion_percentage` issues three COUNT queries per render** (`todo_items_total_count` twice, `todo_items_completed_count` once), in a partial that re-renders on every TODO interaction. Still open — low severity, not a correctness issue.

## 12. Found during the pre-open-source audit (2026-08-16), not on the original list

Four more genuine blockers, none of which the list above anticipated — found by inspecting the actual current tree rather than trusting this document's own (by-then-stale) status, and fixed the same pass:

- **A fresh clone couldn't boot in production.** `config/credentials.yml.enc` was encrypted with a key only the original maintainer had — `config/master.key` is correctly gitignored, so nobody else could ever decrypt the committed file (reproduced the exact crash: `AEAD authentication tag verification failed`). Regenerated with a fresh key meant only for public distribution.
- **Password-reset/invite emails linked to `https://example.com`.** `config.action_mailer.default_url_options` was left at the Rails-generated placeholder, silently, with nothing surfacing it. Now `APP_HOST`-driven (`.env.example`), with a boot-time log warning if it's still unset.
- **`docker-compose.yml` was unusable by anyone but the original maintainer's own VPS** — it joined an external Docker network that only exists there, and published no port at all. Rewritten to be self-contained, bound to `127.0.0.1:3000` by default.
- **`docs/engineering/deployment.md` was a private ops runbook, not a public doc** — named the maintainer's actual VPS container topology and host paths. Rewritten as a generic self-hosting guide.

Each was verified from the perspective of a genuinely fresh clone, not just the existing devcontainer: a real production-mode boot against an empty database (confirmed it reaches the Setup screen), a real `bin/backup` → simulated total data loss → `bin/restore` → verified-intact-data round trip (including an actual uploaded image blob, not just the database), and `docker-compose.yml`/`.env.example` reviewed for what an operator with none of this repo's history would actually need.

**Real incident, found immediately after: the credentials regeneration above broke the maintainer's actual running production deployment.** This repo is both the public template *and* the maintainer's own live deployment source (redeployed via `git pull`) — regenerating `config/credentials.yml.enc` changed the one committed file production's `RAILS_MASTER_KEY` env var was decrypting, with no way for both to stay valid at once. A first attempt at a private-notes file to preserve the VPS-specific detail removed from `deployment.md` was also a mistake — gitignored is not the same as safe, and the maintainer didn't need a copy of their own infrastructure notes sitting in the repo tree at all; it was deleted rather than kept.

The actual fix: `docker-compose.override.yml` (gitignored, auto-merged by `docker compose up` with no flags) for anything infrastructure-specific, and `SECRET_KEY_BASE` as the recommended env var for `secret_key_base` specifically. That alone turned out to be incomplete on first pass, worth recording: `SECRET_KEY_BASE` stops Rails from reading `credentials.secret_key_base`, but Active Record Encryption's own config is read from `Rails.application.credentials` independently at boot regardless — a *present but mismatched* `config/master.key` still crashes there even with `SECRET_KEY_BASE` set (a *missing* key file is fine; it's specifically a stale, wrong one that's dangerous). Full fix needs both: `SECRET_KEY_BASE`, and no stray mismatched `config/master.key` file lying around. Rails' own per-environment credentials (`config/credentials/production.yml.enc`, gitignored) are documented as the alternative for anyone who wants other secrets managed the traditional way while staying fully independent of the shared default file. See `docker-compose.yml`'s own header comment and `docs/engineering/deployment.md`'s "Credentials" / "Infrastructure-specific overrides" sections.

## Housekeeping

Batch these into one commit — mechanical, no judgment required.

- Stale product names outside `docs/`: `docker-compose.yml`'s `container_name: oyashironote_app`, the `Dockerfile` header comments (`docker build -t oyashiro_note .`), `config/deploy.yml` throughout. `LICENSE` says `Copyright (c) 2026 oyashiro` — fine if that's the intended attribution, worth a deliberate decision rather than a default.
- Commented-out Valkey/Redis service blocks and `REDIS_URL` env stanzas in `.github/workflows/ci.yml` — generator leftovers for a service this app doesn't use.
- `package.json`'s `"name": "app"`.
- Add `CODE_OF_CONDUCT.md` and `.github/ISSUE_TEMPLATE/` + a PR template — expected furniture on a repo asking for contributors.

---

## Also in v0.1.0, from the feature list

These are release content rather than hygiene, but they ship in the same cut — see [roadmap.md § 8](../product/roadmap.md):

- Ctrl/Cmd+P palette (recent notes, fuzzy title match, alternate between last two)
- Markdown list continuation and Tab indent — IME-safe, undo-stack-preserving
- Sidebar scrolls the active row into view instead of restoring a remembered offset
- Email and sign-out relocated to a Settings "Account" tab; sign-out hidden entirely under trusted-header auth, where it currently signs the user out and straight back in

---

## Exit criteria

- [x] `bin/ci` (runs `bin/rails test`, `bin/rails test:system`, `bin/rubocop`, `bin/brakeman`, `bin/bundler-audit`, `yarn audit`) green locally — see `docs/engineering/verification.md`
- [x] Production `application.js` under 500KB gzipped, no Mermaid in the initial payload
- [x] Zero third-party requests on page load (verified with devtools on a fresh load, not by reading the layout)
- [x] The app works with the machine's outbound network blocked — no third-party requests remain on page load (see "Removed" in `CHANGELOG.md`)
- [x] `grep -P '[\p{Hiragana}\p{Katakana}\p{Han}]'` over `app/ config/ db/ lib/ test/ bin/` returns only `config/locales/`, the `日本語` picker label, `PLACEHOLDER_TITLES`/`db/seeds.rb`'s `:ja` branch, the character-range regexes in `text_format_controller.js`, and Japanese-text fixtures in tests that specifically exercise Japanese rendering/formatting (i18n, Word/Excel paste, text formatting) — verified 2026-08-24
- [x] A person who has never seen the repo gets from `git clone` to a running instance using only the README — verified against a genuinely fresh production boot (empty database, fresh credentials, real HTTP request reaching Setup)
- [x] Backup and restore performed once, for real, against a copy of production data — `bin/backup`/`bin/restore`, including an actual uploaded image, see `docs/engineering/backup.md`
- [x] `.gitignore` verified to cover `vendor/bundle` and `app/assets/builds` — confirmed neither is tracked in `hrtmys/toishi-note`
- [x] Old repository's fate decided — kept private (`hrtmys/oyashiro_note`); the public move is `hrtmys/toishi-note`
- [x] `git remote set-url origin` updated — `origin` points at `hrtmys/toishi-note.git`, no stale `oyashiro_note`/`citron_web` reference remains

**v0.1.0 tagged 2026-08-24.**
