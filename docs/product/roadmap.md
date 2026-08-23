---
title: Product Roadmap (v0.1 → v2.0)
description: What ships when, from the public beta through v2.0, and why each requested feature was accepted, rescoped, or dropped
status: living
updated: 2026-08-15
---

# Roadmap — v0.1 to v2.0

This supersedes [`ux-roadmap.md.old`](ux-roadmap.md.old), which is kept as an archive because it holds the *reasoning* behind decisions that are still in force (persona pivot, auth design, Word/Excel paste split, Compare's three failed designs). Nothing in this document contradicts the persona or the design principles there — it re-plans **what ships when**, now that Phases 0–4 are actually built and the app has been used daily.

This document fixes direction only. Implementation belongs in issues and PRs.

---

## 1. Where we are

Everything the old roadmap called Phase 0 through Phase 4 has shipped: auth (password + trusted header), the three note types, Settings, Compare, i18n, Organize, export, image attachments, Word/Excel paste. What has *not* shipped is anything that makes the app fast to **move around in**, and that is now the single most-felt gap in daily use.

## 2. Version numbering — and one correction to release-process.md

| Version | Meaning |
|---|---|
| **v0.1.0** | **Public beta.** The fresh `toishi-note` repository is created here, not at v1.0. First release strangers are invited to run. |
| v0.2 – v0.5 | Beta iterations. Breaking changes allowed, but every release must migrate cleanly. |
| **v1.0.0** | "I would tell a stranger to trust their notes to this." Data safety and polish, not new surface. |
| v1.x | Presentation, local distribution — things that widen *where* the app runs. |
| **v2.0.0** | Encrypted notebooks and the researcher tier. The first release that changes the data model in a way v1.x can't. |

[`release-process.md`](../engineering/release-process.md) says the repo move happens at v1.0. **That is now wrong: the move happens at v0.1.0**, because the whole point of a public beta is having somewhere for strangers to file issues. The mechanics in that document (fresh initial commit, `.gitignore` check, decide the old repo's fate, update the remote) are unchanged and still authoritative — only the version label moves.

Gate for cutting v0.1.0: [`docs/engineering/pre-beta-checklist.md`](../engineering/pre-beta-checklist.md).

## 3. The organizing thesis for v0.1 – v0.5: the movement layer

The stated daily pain is not writing and not organizing. It is **travel**: going from `OSS開発 → Toishi Note → 今後の追加機能` over to `学習 → Ruby → Rails` costs a notebook click, a folder click, and a note click, twice. Three-level hierarchies are good for *filing* and bad for *returning*.

Obsidian solved this with a quick switcher and links. Notion solved it with search and a sidebar tree. Neither is magic — both just made "jump straight there" cheaper than "walk there." So do that, in this order, cheapest first:

1. **Command palette (Ctrl/Cmd+P)** — most-recently-viewed notes first, then fuzzy match over every note title. Two keystrokes to anywhere. *(v0.1)*
2. **Alternate (Ctrl/Cmd+Tab or Ctrl+P twice)** — bounce between the last two notes without reading a list. This is literally the "行き来する" case; it deserves its own zero-thought gesture. *(v0.1)*
3. **Global pinned section** — `notes.is_pinned` already exists and is currently used only to sort within one folder. Surfacing pinned notes cross-notebook at the top of the sidebar is a few lines and turns an existing column into a favorites bar. *(v0.2)*
4. **Search, folded into the same palette** — not a separate screen. *(v0.3)*
5. **`[[Internal links]]` + backlinks** — structural jumps, and the thing that makes the graph of notes navigable rather than the tree. *(v0.5)*

Everything in that list shares one UI. Do not build five entry points.

## 4. Differentiation, stated plainly

The audience is Rubyists currently using Obsidian or Notion for study notes. "Self-hosted Markdown notes" is not a reason to switch. These are:

| | Obsidian | Notion | Toishi Note |
|---|---|---|---|
| Multi-device | Paid Sync, or you configure git/Syncthing yourself | Yes | **Yes, inherently — it's a server** |
| Your data on your box | Yes | No | **Yes** |
| AI-output workflow | Plugins | Manual | **Scrap → polish → Note → TODO is the built-in path** |
| Structured TODOs from AI text | No | Databases (heavy) | **Bulk JSON import; bullets → TODO** |
| Cost per teammate | Per seat | Per seat | **A few database rows** |
| Hackable by a Rubyist | TypeScript plugin API | No | **It's a Rails app; send a PR** |

The last row is the one to lead with on Zenn/Qiita. The others are table stakes for whoever already decided to self-host.

**The honest gap:** Obsidian users will not migrate without an import path, and the old roadmap declared import out of scope. That decision is reversed — see §6.

---

## 5. Triage of the requested items

| # | Request | Decision | Ships |
|---|---|---|---|
| 1 | Documentation cleanup | **Adopt** — plus a Japanese README and a real self-host quickstart | v0.1 |
| 2 | Repository refresh | **Adopt** — it *is* the v0.1.0 release event | v0.1 |
| 3 | Hide email + sign-out when solo | **Adopt, rescoped** — move both into a Settings "Account" tab for everyone | v0.1 |
| 4 | Markdown editor: continuous bullets | **Adopt** — plain-textarea behaviors, no CodeMirror | v0.1 (core) / v0.2 (rest) |
| 5 | Bullets → TODO | **Adopt** — reuses the existing bulk-import endpoint | v0.3 |
| 6 | Screenshot note → clipboard | **Adopt, rescoped** — preview pane → PNG, not the whole window | v0.4 |
| 7 | Internal links (TODO→note, scrap→note) | **Adopt, promoted to a flagship epic** — `[[wikilinks]]` + backlinks | v0.5 |
| 8 | Proportional (P) font hurts full/half-width reading | **Adopt** — non-proportional UD font, self-hosted | v0.1 |
| 9 | Ctrl+P to recently opened notes | **Adopt — highest priority item on this list** | v0.1 |
| 10 | Search | **Adopt** — `LIKE` first, FTS5 when it's actually slow | v0.3 |
| 11 | Selectable notebook/folder list height | **Adopt, rescoped** — resizable panes, not a number setting | v0.2 |
| 12 | Sidebar forgets scroll position | **Adopt as a bug fix** — replace scroll memory with "scroll the active row into view" | v0.1 |
| 13 | Secret memo that vanishes on close | **Adopt** — `sessionStorage` only, never touches the server | v0.4 |
| 14 | Local version (Ruby, not Electron) | **Adopt as two answers** — documented localhost Docker now, a `toishi-note` CLI gem at v1.5, encrypted notebooks at v2.0 | v0.1 / v1.5 / v2.0 |
| 15 | Presentation mode (Rabbit compatible?) | **Adopt, redefined** — built-in slide mode, plus *export* to Rabbit rather than embedding it | v1.5 |
| 16 | Paste a URL, fetch the title | **Split** — paste-over-selection client-side; title fetch opt-in and SSRF-guarded | v0.2 / v0.4 |

### Notes on the non-obvious calls

**#3 — hide the email and sign-out.** The right fix is not a solo-only conditional. The sidebar header is prime real estate spent on information you already know (your own email) and an action you take once a month. Move both into the Settings modal's "Account" tab — a tab the old roadmap already designed and never built. Then, separately: when `TRUSTED_HEADER_AUTH_HEADER` is active, hide sign-out entirely, because it currently signs you out and the very next request signs you straight back in. That is a real bug hiding inside a cosmetic request.

**#4 — do not adopt CodeMirror or EasyMDE.** Three reasons. The bundle is already far too large (see the checklist). Every paste handler in the app — Word, Excel, images — is written against a real `<textarea>` and would need rewriting. And CodeMirror 5, which EasyMDE wraps, has a long history of Japanese IME composition bugs, which is disqualifying for this audience. Write the behaviors directly.

Scope, in two batches:

- *v0.1:* Enter continues `-`, `*`, `1.`, `- [ ]`, `>`; Enter on an empty marker removes it; Tab/Shift+Tab indent and outdent inside a list.
- *v0.2:* Ctrl+B / Ctrl+I / Ctrl+K, paste-a-URL-over-a-selection → `[selection](url)`, auto-renumbering, `Ctrl+Shift+K` delete line.

Two implementation constraints that must be honored or the feature is worse than nothing: **use `document.execCommand("insertText")` (or an equivalent that preserves the native undo stack)** — assigning `textarea.value` destroys Ctrl+Z, which is a far bigger regression than the feature is a win; and **suppress every handler while `isComposing` is true**, or Japanese input breaks on the first Enter that confirms a conversion.

Good extraction candidate: `@toishi/markdown-textarea`.

**#6 — screenshot.** "The whole note screen" would include the sidebar and toolbar, which nobody wants in a LINE message. Capture the rendered preview pane only, as PNG, from the same FAB that already hosts "Copy for Word." Two constraints to plan around: `ClipboardItem` image writes need a secure context and are not universally available (Firefox in particular), so ship a "download PNG" fallback in the same action; and DOM-to-image rasterization only embeds fonts it can read, which is a second reason to self-host the font (§ pre-beta item 3) rather than pull it from Google.

Consider also that the underlying want here is *sharing*, and a read-only public link is the other answer to it — see §7.

**#7 — internal links, and why it's the flagship.** Use `[[Note title]]` and `[[Note title|alias]]`. Obsidian-compatible syntax means an imported vault keeps working and a departing user's export keeps working — cheap goodwill in both directions. Design points:

- A `note_links` table (`source_note_id`, `target_note_id`, plus the raw text for unresolved links), rebuilt when a note saves.
- That table gives **backlinks** — a "Linked mentions" panel under the note — for free. Backlinks, not forward links, are what make people call a note app "a second brain."
- Rendering happens in the shared markdown renderer, so TODO items and Scrap items get links with no extra work. That satisfies "TODO→ノート" and "scrap→ノート" in one change.
- `[[` opens title autocomplete, backed by the same title index the Ctrl+P palette already needs.
- An unresolved link renders differently and offers "create this note."

**#10 — search, decided rather than deferred.** Start with `LIKE '%q%'` over `notes.content` and `notes.title`, scoped through `Current.user`. On a personal notebook of a few thousand notes on SQLite this is fast enough, needs no migration, no gem, and no index to keep in sync. Ship that in v0.3 inside the palette.

Upgrade to SQLite **FTS5** only when a real corpus is actually slow, and when you do, use **`tokenize='trigram'`**. The default `unicode61` tokenizer does not segment Japanese — it treats a whole run of kanji/kana as one token, so Japanese search silently returns nothing useful. Trigram indexing handles CJK substring matching correctly and costs index size; verify at implementation time that the minimum query length (trigram needs 3 characters) is acceptable, and fall back to `LIKE` for 1–2 character queries. This is exactly the kind of thing that is invisible in English-only testing, so write the test with Japanese content.

**#11 — pane heights.** A settings field ("show N notebooks") is configuration where the user actually wants control. The panes are currently pinned at `max-height: 110px` and `145px` in inline styles. Make them flex-sized with sensible minimums so an empty folder list stops reserving space (v0.2), then add drag handles between the three sections with sizes remembered per browser (v0.4). No settings entry either way.

**#12 — sidebar scroll memory.** Two mechanisms fight here, which explains "sometimes it remembers." `scroll_controller.js` restores `scrollTop` from localStorage on connect and again on `turbo:load`; `navigation_controller.js` separately does a `Turbo.visit()` on a bare `/`, causing a second render — and on narrow viewports the sidebar is an off-canvas element, where assigning `scrollTop` to a `display: none` element is silently dropped.

Do not fix the restore timing. Delete the guessing: **scroll the currently-active row into view** (`scrollIntoView({ block: "nearest" })`) on connect. The correct scroll position is always "where the thing you selected is," it needs no storage, and it cannot go stale. Keep `scroll_controller` only if some list genuinely has no active row.

**#13 — the vanishing scratch pad.** Content lives in `sessionStorage` and nowhere else: never POSTed, never in the database, never in a backup, gone when the tab closes. That makes it the rare feature that adds real value while *shrinking* the attack surface, which fits design principle 2. Add "Send to Scrap" and "Copy" so anything worth keeping can graduate. Label it honestly in the UI — it is a *durability* guarantee, not a *security* one; browser memory and extensions can still see it, and the copy should say so.

**#14 — the local version.** Three separate answers, because "local" is being asked to mean three things:

- *Runs on my laptop:* already true. `docker compose up` bound to `127.0.0.1` is a local version. This is a documentation task (v0.1), not a code one — and the current `docker-compose.yml` cannot serve it, since it joins an external network that only exists on the production VPS.
- *Installs like a Ruby tool:* a `toishi-note` gem with a CLI that boots Puma on localhost against a SQLite file in `~/.toishi-note` and opens a browser — `jekyll serve` for notes. Pure Ruby, no Electron, small memory. **v1.5.** Honest cost: a local-only instance gives up the multi-device story that is currently the strongest reason to use this at all.
- *I don't want secrets on the VPS:* the actually-interesting answer is **client-side encrypted notebooks** — mark a notebook end-to-end encrypted, encrypt content in the browser under a passphrase, the server stores ciphertext it cannot read. This keeps multi-device sync, which the local build sacrifices. It costs server-side search, server-side export, and preview for those notes, and losing the passphrase means losing the data with no reset path. That is a v2.0-sized commitment, and it is the right shape for the problem.

**#15 — presentation.** Do not target Rabbit compatibility as an *input* format. Rabbit is a desktop GTK application with its own theming and Ruby DSL; matching it means chasing a moving target for a feature used a few times a year. Instead:

- **Slide mode** — split the open note on `---` (or on `##`), render full-screen using the marked + KaTeX + Mermaid + highlight.js pipeline that is *already bundled*, arrow keys to advance. Small, and it makes the existing dependencies earn their weight.
- **Export to Rabbit** — emit the Markdown layout Rabbit expects (`#` title slide, `##` per slide) as one more export format. Near-zero cost, and it means a Matsue.rb talk can be written in Toishi Note and presented in Rabbit. *That* is the interop story worth telling, and it makes a much better conference demo than an embedded viewer.

**#16 — URL titles.** Paste-a-URL-over-a-selection is pure client-side string work and belongs with the editor batch (v0.2). Fetching a page title is a server making an outbound request to a user-supplied URL, i.e. **SSRF**, on a box that in the target deployment sits inside a company network. Ship it opt-in and off by default, guarded: reject private, loopback, and link-local address ranges *after* DNS resolution, re-check on every redirect hop, cap at ~512KB and ~5 seconds, and use `Net::HTTP` rather than adding a gem. If that guard can't be written confidently, ship only the client-side half — it covers most of the actual want.

---

## 6. Reversed decisions

**Import is no longer out of scope.** The old roadmap says "Export only, one direction." The stated goal is winning over people currently in Obsidian and Notion, and nobody abandons three years of notes to retype them. Import a zip or folder of Markdown: directories become notebooks and folders, `.md` files become notes, front matter is preserved into the body, and `[[wikilinks]]` resolve once §5 #7 lands. Export already does the reverse mapping, so most of the thinking is done. **v0.3**, and it should be the headline of the launch post rather than an afterthought.

**Settings grows an "Account" tab now,** ahead of the old "don't build tab chrome before a feature needs it" rule — the sign-out relocation (#3) is that feature.

**PWA offline read-only moves from "someday" to v1.0.** It is listed in the old roadmap with no phase. It belongs with the v1.0 trust story, and it is blocked on removing CDN dependencies (a service worker cannot cache what a third party serves), which the pre-beta checklist does anyway.

### Deferred, but not dropped

These carry over from the archived roadmap with no scheduled release. They are still wanted; nothing here is blocking anyone today, and each would displace something that is.

- **Passkey / WebAuthn and OIDC login.** Deprioritized deliberately: the maintainer's own deployment sits behind Cloudflare Access, which already solves this, and Rails ships no WebAuthn support, so it is not the small job it sounds like. Revisit when someone running a standalone instance actually asks.
- **TOTP / 2FA.** Answers a different question ("is this really you?") than the one the auth design solves ("you forgot your password and email doesn't reach you"). Revisit only if this ever opens up beyond a trusted team.
- **Bulk operations on the admin team list** (export, multi-remove) — revisit alongside import/export work in v0.3.
- **Tags** — see § 7.

---

## 7. Additional proposals from reading the code

Ordered by how much they matter, not by size.

### Data safety (these are the v1.0 story)

- **Multi-device overwrite is currently silent data loss.** `autosave_controller.js` PUTs the entire note body 500ms after typing stops, with no version check, and `NotesController#update` accepts it. The stated primary persona has a work PC, a home PC, and a phone. Two devices with the same note open, and the last save wins with no warning. Add `lock_version` (Rails optimistic locking) and, on conflict, tell the user rather than picking for them. **v0.2** — this is a correctness bug against the persona, not an enhancement.
- **Deleting a notebook is irreversible and cascades to every folder and note under it,** behind one `confirm()`. A notes app needs a trash: soft-delete with a 30-day window and an undo toast. **v0.4.**
- **Note revision history.** Autosave overwrites blindly, so one bad paste plus a reload is unrecoverable. Snapshot into a `note_versions` table on a coarse interval. Then wire it to the **Compare** view that already exists: "compare this note to how it looked yesterday" reuses a shipped feature and makes it the reason people trust the editor. **v1.0.**
- **Backups are promised and don't exist.** The old roadmap describes a "Last backup: 3 hours ago ✅" line. Shipping a public beta that holds someone's notes with no documented backup path is a trust problem. The runbook (`sqlite3 .backup` + rclone on cron) is a **v0.1** documentation task; the status line in the Account tab is **v1.0**.

### Product

- **A seeded welcome notebook on first run.** The empty state is currently a shrug. Seed a notebook whose first note *is* the tutorial — Ctrl+P, `[[links]]`, the three note types, the FAB — written in Markdown so reading it demonstrates the editor. Highest-leverage onboarding change available, and it makes screenshots easy. **v0.2.**
- **Daily note.** Obsidian's most-used feature, and it fits "self-learning notes" exactly: one keystroke opens today's note, created if absent. **v0.5.**
- **Publish a note as a read-only link.** This is the other answer to the screenshot request, and a better one for anything longer than a paragraph. It does add an unauthenticated public endpoint, against design principle 2 — so: off by default, per-note, unguessable token, revocable, and never for a whole notebook. **v1.x**, deliberately after the PNG route, which needs no new attack surface.
- **A `?` keyboard-shortcut cheatsheet,** once there are enough shortcuts to forget. **v0.4.**
- **Tags (`#tag`) are deferred, not planned.** They add a whole second navigation dimension parallel to folders. Search plus backlinks may well cover the need; revisit at v1.x only if real use says otherwise.

### Extraction (supports the star-count goal as much as the code)

Each of these is a separate README, a separate Zenn post, and a separate surface to be found through:

- `@toishi/markdown-textarea` — the editor behaviors from #4, IME-safe and undo-preserving. The most broadly useful thing in this repo.
- `@toishi/office-clipboard` — Word/Excel clipboard HTML → Markdown, already isolated in `word_clipboard.js` / `html_to_markdown.js`, merged-cell handling and all.
- `turndown-plugin-katex` — the sup/sub → KaTeX plugin already planned in the archived roadmap.

### Refactoring

- **`app/views/home/index.html.erb` is 353 lines** and contains the sidebar, all three note-type editors, and 66 lines of inline CSS. It is the first file a curious contributor opens. Extract `home/_sidebar`, `notes/_todo_editor`, `notes/_scrap_editor`; move the CSS to SCSS partials. **Do this before the fresh repo** — first impressions of the code are part of a launch.
- **Dead code to delete before the fresh repo, not after:** the vendored EasyMDE/CodeMirror stylesheet (~15KB for a dependency that isn't installed), `NotesController#preview` plus the `redcarpet` gem (rendering is client-side; the only caller is a test), the `window.hljs` / `window.marked` globals, five empty helper modules. A clean repo is the entire point of the exercise.
- **`Note::DEFAULT_TITLES` is hardcoded Japanese** (`無題のノート`), so an English-locale user gets Japanese titles — and `auto_set_title` only pattern-matches the Japanese placeholders, so an English-created note never auto-retitles from its first line. Both symptoms of deriving "has the user titled this?" from string comparison. Model it as a boolean instead.
- **`Note#todo_completion_percentage` issues three COUNT queries per render.** Minor, but it's in a partial that renders on every TODO interaction.
- **`navigation_controller.js#disconnect` passes a freshly-bound function to `removeEventListener`,** so the listener is never removed. Compare `scroll_controller.js`, which stores the bound handler correctly.

---

## 8. Release plan

### v0.1.0 — Public beta 🚀

*Theme: a stranger can install it, and moving around it feels fast.*

- Everything in [`pre-beta-checklist.md`](../engineering/pre-beta-checklist.md) — bundle size, CDN removal, self-hosted fonts, sanitization, dead code, docs, backup runbook
- Ctrl/Cmd+P palette: recent notes + fuzzy title match, plus alternate-between-last-two
- Markdown list continuation and Tab indent (IME-safe, undo-preserving)
- Non-proportional UD font on content surfaces
- Sidebar scrolls the active row into view
- Email and sign-out move to a Settings "Account" tab; sign-out hidden under trusted-header auth
- README rewritten for self-hosters, `README.ja.md` added, `CHANGELOG.md` started
- **Repository refresh happens here.**

### v0.2.0 — The editor earns its keep

- Remaining editor shortcuts; paste-URL-over-selection
- Optimistic locking + conflict prompt
- Global pinned section, cross-notebook
- Flexible sidebar pane heights
- Seeded welcome notebook

### v0.3.0 — Getting your notes in and finding them again

- Search (`LIKE`), inside the palette
- **Import** from an Obsidian vault or folder of Markdown
- Bullets → TODO

### v0.4.0 — Comfort

- Vanishing scratch pad
- Trash and undo
- Copy preview as PNG
- URL title fetch (opt-in, SSRF-guarded)
- Resizable sidebar panes; `?` cheatsheet

### v0.5.0 — The graph

- `[[Internal links]]`, autocomplete, unresolved-link creation
- Backlinks panel
- Daily note

### v1.0.0 — Trust

- Revision history, wired into Compare
- Backup status in Account settings
- PWA installable + offline read-only
- Full i18n pass, docs site, demo GIF
- Extracted npm packages published
- Performance pass with a realistic corpus (FTS5 if `LIKE` is no longer enough)

### v1.5 — Reach

- Slide mode; Rabbit-compatible export
- `toishi-note` CLI gem for local use
- Read-only publish links

### v2.0 — The hard things

- Client-side encrypted notebooks
- Researcher tier from the archived roadmap: DOI/citation metadata, Zotero, BibTeX export
- Reassess tags and a graph view on real usage, not speculation

---

## 9. Non-goals (unchanged, restated)

- A public JSON API
- A plugin system — core PRs instead
- Offline *editing* or sync; offline is read-only, the server is always right
- Shared or permissioned notebooks
- Paid literature databases
- CodeMirror, EasyMDE, or any editor framework in the Markdown pane
- Rabbit as an embedded runtime (export only)
