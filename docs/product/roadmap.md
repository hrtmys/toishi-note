---
title: Product Roadmap (v0.1 → v2.0)
description: What ships when, from the public beta through v2.0, and why each requested feature was accepted, rescoped, or dropped
status: living
updated: 2026-09-26
---

# Roadmap — v0.1 to v2.0

This supersedes [`ux-roadmap.md.old`](ux-roadmap.md.old), which is kept as an archive because it holds the *reasoning* behind decisions that are still in force (persona pivot, auth design, Word/Excel paste split, Compare's three failed designs). Nothing in this document contradicts the persona or the design principles there — it re-plans **what ships when**, now that Phases 0–4 are actually built and the app has been used daily. (One flagged exception: publish links in §7, explicitly weighed against design principle 2.)

This document fixes direction only. Implementation belongs in issues and PRs.

---

## 1. Where we are

**v0.1.0 shipped 2026-08-24** (see `CHANGELOG.md`): the fresh public `hrtmys/toishi-note` repository, command palette, editor list behaviors, Account tab, self-hosted assets + CSP, backup runbook, and docs. Two items this document had scheduled for v0.2 were already in that cut — optimistic locking + conflict prompt, and the seeded welcome notebook — so §8 below has been corrected to show them under v0.1.0.

Since then (2026-08-24 → 2026-09-11) the work has been a **post-beta hardening wave**, then the first v0.2 slice: CRUD feedback toasts, TODO/Scrap form fixes, N+1 fixes, concurrent-reorder locking, upload/bulk-import caps, silent-save error toasts, preview/diagram rendering stability, IME-safe auto-title, Word-paste robustness, per-user last-notebook/folder memory, and a dev-environment refresh (`bin/d`) — followed by the v0.2 editor batch (Ctrl+B / Ctrl+I / Ctrl+K, paste-URL-over-selection, auto-renumbering, `Ctrl+Shift+K` delete line) plus the mobile/sidebar bug insertions B1–B5 (instant offcanvas restore, undo-preserving paste with Shift opt-out, touch ellipsis menus, unreserved title width, `*` + space + Enter continuation). Then a **TODO-hub wave** (2026-09-21, issue #47, PRs #49–#51): `/todos` folded into the main pane with a project view, a Settings-gated Markdown handoff at `GET /todos.md`, and bulk apply of an AI's edited reply behind a confirm-gated preview. Still open from the post-v0.1 plan: global pins, resizable panes, body search, import, scratch pad, trash, PNG capture, URL title fetch.

**Re-plan, 2026-09-26.** Three changes, each explained where it lands: a PWA install bug found in daily use is pulled into v0.2 (§5 #17); `[[links]]` and import swap places, so the graph ships as v0.3 and import as v0.5 (§8); and the PNG-capture approach is decided against the browser-native alternatives (§5 #6). §8 now also carries a size and a delegation label per item. v2.0 was re-checked against the code the same day and nothing in it has started — no encryption code, no citation fields, no `tags` table; the only trace is a comment in `settings/_modal.html.erb` reserving the "Integrations" tab.

What has *still* not shipped is anything beyond the palette that makes the app fast to **move around in** — global pins, body search, `[[links]]` — and that remains the most keenly felt gap in daily use.

## 2. Version numbering — and one correction to release-process.md

| Version | Meaning |
|---|---|
| **v0.1.0** | **Public beta.** The fresh `toishi-note` repository was created here, not at v1.0. First release strangers are invited to run. |
| v0.2 – v0.5 | Beta iterations. Breaking changes allowed, but every release must migrate cleanly. |
| **v1.0.0** | "I would tell a stranger to trust their notes to this." Data safety and polish, not new surface. |
| v1.x | Presentation, local distribution — things that widen *where* the app runs. |
| **v2.0.0** | Encrypted notebooks and the researcher tier. The first release that changes the data model in a way v1.x can't. |

[`release-process.md`](../engineering/release-process.md) said the repo move happens at v1.0. **That was corrected: the move happened at v0.1.0** (public repo `hrtmys/toishi-note`, old repo kept private), because the whole point of a public beta is having somewhere for strangers to file issues. The mechanics in that document (fresh initial commit, `.gitignore` check, decide the old repo's fate, update the remote) are unchanged and still authoritative — only the version label moved, and the move itself is now done.

v0.1.0 was cut against [`pre-beta-checklist.md`](../engineering/pre-beta-checklist.md) — all exit criteria checked, tag `v0.1.0` on 2026-08-24.

## 3. The organizing thesis for v0.1 – v0.5: the movement layer

The stated daily pain is not writing and not organizing. It is **travel**: going from `OSS開発 → Toishi Note → 今後の追加機能` over to `学習 → Ruby → Rails` costs a notebook click, a folder click, and a note click, twice. Three-level hierarchies are good for *filing* and bad for *returning*.

Obsidian solved this with a quick switcher and links. Notion solved it with search and a sidebar tree. Neither is magic — both just made "jump straight there" cheaper than "walk there." So do that, in this order, cheapest first:

1. **Command palette (Ctrl/Cmd+P)** — most-recently-viewed notes first, then match over every note title. Two keystrokes to anywhere. *(v0.1)*
2. **Alternate (Ctrl/Cmd+Tab or Ctrl+P twice)** — bounce between the last two notes without reading a list. This is literally the "行き来する" case; it deserves its own zero-thought gesture. *(v0.1)*
3. **Global pinned section** — `notes.is_pinned` already exists and is currently used only to sort within one folder. Surfacing pinned notes cross-notebook at the top of the sidebar is a few lines and turns an existing column into a favorites bar. *(v0.2)*
4. **Search, folded into the same palette** — not a separate screen. *(v0.3)*
5. **`[[Internal links]]` + backlinks** — structural jumps, and the thing that makes the graph of notes navigable rather than the tree. *(v0.3 — moved up from v0.5 on 2026-09-26; see §8)*

Everything in that list shares one UI. Do not build five entry points.

*Status 2026-09-11:* items 1–2 shipped in v0.1.0 (palette: recent-first + title `LIKE` match + alternate via preselected second entry; ranking since moved into `Note.search_ranked`, with empty-state/keyboard polish). Unplanned but shipped alongside: per-user last-notebook/folder memory, which removes one re-navigation step on reload. The v0.2 editor batch from §5 #4 has since shipped too (Ctrl+B / Ctrl+I / Ctrl+K, paste-URL-over-selection, auto-renumbering, `Ctrl+Shift+K`). Items 3–5 have not started — the palette still searches titles only, no `note_links` table exists, no daily note.

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
| 7 | Internal links (TODO→note, scrap→note) | **Adopt, promoted to a flagship epic** — `[[wikilinks]]` + backlinks | v0.3 (was v0.5) |
| 8 | Proportional (P) font hurts full/half-width reading | **Adopt** — non-proportional UD font, self-hosted | v0.1 |
| 9 | Ctrl+P to recently opened notes | **Adopt — highest priority item on this list** | v0.1 |
| 10 | Search | **Adopt** — `LIKE` first, FTS5 when it's actually slow | v0.3 |
| 11 | Selectable notebook/folder list height | **Adopt, rescoped** — resizable panes, not a number setting | v0.2 |
| 12 | Sidebar forgets scroll position | **Adopt as a bug fix** — replace scroll memory with "scroll the active row into view" | v0.1 |
| 13 | Secret memo that vanishes on close | **Adopt** — `sessionStorage` only, never touches the server | v0.4 |
| 14 | Local version (Ruby, not Electron) | **Adopt as two answers** — documented localhost Docker now, a `toishi-note` CLI gem at v1.5, encrypted notebooks at v2.0 | v0.1 / v1.5 / v2.0 |
| 15 | Presentation mode (Rabbit compatible?) | **Adopt, redefined** — built-in slide mode, plus *export* to Rabbit rather than embedding it | v1.5 |
| 16 | Paste a URL, fetch the title | **Split** — paste-over-selection client-side; title fetch opt-in and SSRF-guarded | v0.2 / v0.4 |
| 17 | Installed app opens a stale note instead of the last one (bug, 2026-09-26) | **Adopt as a bug fix** — link the manifest so the install uses `start_url: "/"` | v0.2 |

### Status as of 2026-09-21

Shipped in v0.1.0: #1 (README quickstart, `README.ja.md`, `CHANGELOG.md`), #2 (public repo cut), #3 (Account tab; trusted-header sign-out hidden), #4 core (list continuation + Tab indent), #8 (BIZ UDGothic self-hosted), #9 (palette), #12 (scroll-active-into-view). #14's localhost answer shipped as docs (self-contained `docker-compose.yml` on `127.0.0.1:3000`); the CLI gem and encrypted notebooks remain v1.5 / v2.0. Shipped in the v0.2 slice: #4's v0.2 half (Ctrl+B / Ctrl+I / Ctrl+K, paste-URL-over-selection, auto-renumbering, `Ctrl+Shift+K` delete line, all undo-preserving and IME-safe) and #16's client-side half (paste-URL-over-selection). #11 is partial — the sidebar now shows more than two rows, no longer snaps on click, restores the offcanvas without a replayed animation, has touch ellipsis menus, and the title input fills the freed header width, but panes are still fixed-height, not flexible or resizable. **#5 shipped 2026-09-21**, inside the TODO-hub wave rather than on its own: the per-note bulk-add modal now takes `- [ ]` Markdown as well as JSON, and carries due dates through, which is what "bullets → TODO" was asking for. Not started: #6, #7, #10 (palette searches titles only — no body search yet), #13, #15, #16's server-side title fetch, and global pins.

### Notes on the non-obvious calls

**#3 — hide the email and sign-out.** The right fix is not a solo-only conditional. The sidebar header is prime real estate spent on information you already know (your own email) and an action you take once a month. Move both into the Settings modal's "Account" tab — a tab the old roadmap had designed but that shipped only with v0.1.0. Then, separately: when `TRUSTED_HEADER_AUTH_HEADER` is active, hide sign-out entirely, because it currently signs you out and the very next request signs you straight back in. That is a real bug hiding inside a cosmetic request.

**#4 — do not adopt CodeMirror or EasyMDE.** Three reasons. The bundle is already far too large (see the checklist). Every paste handler in the app — Word, Excel, images — is written against a real `<textarea>` and would need rewriting. And CodeMirror 5, which EasyMDE wraps, has a long history of Japanese IME composition bugs, which is disqualifying for this audience. Write the behaviors directly.

Scope, in two batches:

- *v0.1:* Enter continues `-`, `*`, `1.`, `- [ ]`, `>`; Enter on an empty marker removes it; Tab/Shift+Tab indent and outdent inside a list.
- *v0.2:* Ctrl+B / Ctrl+I / Ctrl+K, paste-a-URL-over-a-selection → `[selection](url)`, auto-renumbering, `Ctrl+Shift+K` delete line.

Two implementation constraints that must be honored or the feature is worse than nothing: **use `document.execCommand("insertText")` (or an equivalent that preserves the native undo stack)** — assigning `textarea.value` destroys Ctrl+Z, which is a far bigger regression than the feature is a win; and **suppress every handler while `isComposing` is true**, or Japanese input breaks on the first Enter that confirms a conversion.

Good extraction candidate: `@toishi/markdown-textarea`.

**#6 — screenshot.** "The whole note screen" would include the sidebar and toolbar, which nobody wants in a LINE message. Capture the rendered preview pane only, as PNG, from the same FAB that already hosts "Copy for Word," with a "download PNG" fallback in the same action.

*How to rasterize — decided 2026-09-26: a lazy-loaded SVG-`foreignObject` library (`modern-screenshot`), with a browser-native path added behind feature detection once one exists in stable.* The native routes were checked first, since zero bytes beats any library:

| Route | Bundle cost (gzip) | KaTeX / Mermaid | Verdict |
|---|---|---|---|
| HTML-in-Canvas (`drawElementImage`) | 0 | exact (native paint) | Origin trial in Chrome 148–150 only. Trial tokens are per origin, so every self-hosted instance would need its own registration — unusable here until it ships in stable. Chromium-only (Edge follows). **Preferred path later**, behind feature detection. |
| `getDisplayMedia` + Element/Region Capture | 0 | exact, visible area only | A screen-share picker on every capture, and only the visible part of the pane, so a long note is cut off. Rejected. |
| Print → PDF (`@media print`) | 0 | exact | Not a PNG and can't reach the clipboard. A print stylesheet for the preview is still cheap and answers "send this as a file" — worth doing on its own. |
| html2canvas / html2canvas-pro | 45.6 / 67.6 KB | broken | Re-implements CSS layout: KaTeX's positioned spans misalign fractions and roots, and Mermaid's `foreignObject` HTML labels aren't drawn. Rejected. |
| html-to-image 1.11 | 6.6 KB | good | Same approach as the pick, but last released 2025-04. |
| **modern-screenshot 4.7** | **13.9 KB** | **good** | Maintained fork of html-to-image (released 2026-04). **Chosen.** |
| @zumer/snapdom 3.1 | 84.3 KB | good | Fastest, at 6× the bytes for speed this use doesn't need. |

Sizes are the minified ESM builds gzipped at `-9`, measured 2026-09-26.

*Why the `foreignObject` route handles math and diagrams:* it serializes a clone of the pane into an SVG `<foreignObject>` and lets the browser's own layout engine paint it, so KaTeX's positioned spans and Mermaid's inline SVG (labels included) come out as they look on screen. Two things to verify at implementation with a real note holding Japanese text, math, and a diagram. KaTeX's fonts get embedded as data URLs: they're same-origin woff2 (20 files, ≈520 KB, ≈700 KB as base64), so embed only the families the pane actually uses. Body text uses OS-installed Japanese fonts rather than a webfont, so nothing heavy is embedded for CJK; a machine without BIZ UDPGothic renders its fallback in the PNG, same as on screen.

*Bundle and memory:* loaded by dynamic `import()` on click, the same pattern as Mermaid and KaTeX, so the initial payload and its budget are untouched. Peak runtime memory is the cloned DOM, plus the serialized SVG string (low single-digit MB with fonts), plus the canvas bitmap at width × height × DPR² × 4 bytes. For an 800 × 3,000 CSS-px note that is ≈15 MB at DPR 1.25 (a typical 125% Windows laptop) and ≈38 MB at DPR 2, plus a short-lived PNG encode buffer, all freed after the copy. Canvas has hard limits (Chromium: ≈32,767 px per side, ≈268 M px of area), so scale down past a height cap and toast when a note is too long rather than fail silently.

*Persona fit:* engineers and IT-ops staff on Chrome or Edge, pasting into LINE, Teams, or Slack — the `ClipboardItem` image path works on both. Two catches specific to this audience. `navigator.clipboard.write` needs a secure context, and an intranet install served over plain `http://192.168.x.x` isn't one, so for some IT-ops deployments the download fallback is the main path, not a Firefox nicety. A no-egress network is fine, because the library is bundled like everything else. The CSP already allows `img-src data:`, which this route needs, so no policy change.

Consider also that the underlying want here is *sharing*, and a read-only public link is the other answer to it — see §7.

**#7 — internal links, and why it's the flagship.** Use `[[Note title]]` and `[[Note title|alias]]`. Obsidian-compatible syntax means an imported vault keeps working and a departing user's export keeps working — cheap goodwill in both directions. Design points:

- A `note_links` table (`source_note_id`, `target_note_id`, plus the raw text for unresolved links), rebuilt when a note saves.
- That table gives **backlinks** — a "Linked mentions" panel under the note — for free. Backlinks, not forward links, are what make people call a note app "a second brain."
- Rendering happens in the shared markdown renderer, so TODO items and Scrap items get links with no extra work. That satisfies "TODO→ノート" and "scrap→ノート" in one change.
- `[[` opens title autocomplete, backed by the same title index the Ctrl+P palette already needs.
- An unresolved link renders differently and offers "create this note."
- *To settle in the implementation plan:* titles are not unique across notebooks, so `[[Title]]` can match several notes. Recommended: prefer a match in the linking note's own notebook, then the most recently viewed; accept `[[Notebook/Title]]` to pin one explicitly; and have autocomplete insert the qualified form only when the bare title is ambiguous. Whatever is chosen has to be the same rule the v0.5 import uses.

**#10 — search, decided rather than deferred.** Start with `LIKE '%q%'` over `notes.content` and `notes.title`, scoped through `Current.user`. On a personal notebook of a few thousand notes on SQLite this is fast enough, needs no migration, no gem, and no index to keep in sync. Ship that in v0.3 inside the palette.

Upgrade to SQLite **FTS5** only when a real corpus is actually slow, and when you do, use **`tokenize='trigram'`**. The default `unicode61` tokenizer does not segment Japanese — it treats a whole run of kanji/kana as one token, so Japanese search silently returns nothing useful. Trigram indexing handles CJK substring matching correctly and costs index size; verify at implementation time that the minimum query length (trigram needs 3 characters) is acceptable, and fall back to `LIKE` for 1–2 character queries. This is exactly the kind of thing that is invisible in English-only testing, so write the test with Japanese content.

**#11 — pane heights.** A settings field ("show N notebooks") is configuration where the user actually wants control. The panes are currently pinned at `max-height: 110px` and `145px` in inline styles. Make them flex-sized with sensible minimums so an empty folder list stops reserving space (v0.2), then add drag handles between the three sections with sizes remembered per browser (v0.4). No settings entry either way.

**#12 — sidebar scroll memory.** Two mechanisms fight here, which explains "sometimes it remembers." `scroll_controller.js` restores `scrollTop` from localStorage on connect and again on `turbo:load`; `navigation_controller.js` separately does a `Turbo.visit()` on a bare `/`, causing a second render — and on narrow viewports the sidebar is an off-canvas element, where assigning `scrollTop` to a `display: none` element is silently dropped.

Do not fix the restore timing. Delete the guessing: **scroll the currently-active row into view** (`scrollIntoView({ block: "nearest" })`) on connect. The correct scroll position is always "where the thing you selected is," it needs no storage, and it cannot go stale. Keep `scroll_controller` only if some list genuinely has no active row.

**#13 — the vanishing scratch pad.** Content lives in `sessionStorage` and nowhere else: never POSTed, never in the database, never in a backup, gone when the tab closes. That makes it the rare feature that adds real value while *shrinking* the attack surface, which fits design principle 2. A single local pad — no auto-save, no auto-send, no expiry mode on the pad itself. Add "Send to Scrap" and "Copy" so anything worth keeping can graduate by explicit user action only. Reuse the existing `lib/markdown_renderer.js` pipeline for preview; no new rendering library. Place it as a global section at the bottom of the sidebar (global state needs a global home; the files pane must not be taxed). Label it honestly in the UI — it is a *durability* guarantee, not a *security* one; browser memory and extensions can still see it, and the copy should say so.

Offline behavior (same feature): when offline is detected (`navigator.onLine` + `online`/`offline` events), show that the app is offline and only cached notes are viewable; editing/saving is disabled with notice, but the vanishing pad keeps working locally (it needs no network by construction). Each offline save records its time; on reconnect, if sessionStorage content remains, offer once: "content saved offline at HH:MM exists — send it to the server?" with Send / Keep local / Discard. (Archive-with-expiry is a separate feature on normal notes — see §7 — not a pad mode.)

**#14 — the local version.** Three separate answers, because "local" is being asked to mean three things:

- *Runs on my laptop:* already true. `docker compose up` bound to `127.0.0.1` is a local version. Before v0.1.0 this was a documentation task because the then-current `docker-compose.yml` could not serve it — it joined an external network that only existed on the production VPS. Shipped in v0.1.0 as a self-contained file reachable at `127.0.0.1:3000` out of the box.
- *Installs like a Ruby tool:* a `toishi-note` gem with a CLI that boots Puma on localhost against a SQLite file in `~/.toishi-note` and opens a browser — `jekyll serve` for notes. Pure Ruby, no Electron, small memory. **v1.5.** Honest cost: a local-only instance gives up the multi-device story that is currently the strongest reason to use this at all.
- *I don't want secrets on the VPS:* the actually-interesting answer is **client-side encrypted notebooks** — mark a notebook end-to-end encrypted, encrypt content in the browser under a passphrase, the server stores ciphertext it cannot read. This keeps multi-device sync, which the local build sacrifices. It costs server-side search, server-side export, and preview for those notes, and losing the passphrase means losing the data with no reset path. That is a v2.0-sized commitment, and it is the right shape for the problem.

**#15 — presentation.** Do not target Rabbit compatibility as an *input* format. Rabbit is a desktop GTK application with its own theming and Ruby DSL; matching it means chasing a moving target for a feature used a few times a year. Instead:

- **Slide mode** — split the open note on `---` (or on `##`), render full-screen using the marked + KaTeX + Mermaid + highlight.js pipeline that is *already bundled*, arrow keys to advance. Small, and it makes the existing dependencies earn their weight.
- **Export to Rabbit** — emit the Markdown layout Rabbit expects (`#` title slide, `##` per slide) as one more export format. Near-zero cost, and it means a Matsue.rb talk can be written in Toishi Note and presented in Rabbit. *That* is the interop story worth telling, and it makes a much better conference demo than an embedded viewer.

**#16 — URL titles.** Paste-a-URL-over-a-selection is pure client-side string work and belongs with the editor batch (v0.2). Fetching a page title is a server making an outbound request to a user-supplied URL, i.e. **SSRF**, on a box that in the target deployment sits inside a company network. Ship it opt-in and off by default, guarded: reject private, loopback, and link-local address ranges *after* DNS resolution, re-check on every redirect hop, cap at ~512KB and ~5 seconds, and use `Net::HTTP` rather than adding a gem. If that guard can't be written confidently, ship only the client-side half — it covers most of the actual want.

**#17 — the installed app opens the wrong note.** Chrome and Edge's "install as app" uses the page's web app manifest if one is linked, and the current URL if not. `app/views/pwa/manifest.json.erb` exists with `start_url: "/"`, but `config/routes.rb` has no route for it and the layout has no `<link rel="manifest">`, so the install captured whatever was open — e.g. `/?folder_id=8&note_id=67&notebook_id=7&organize=true`. Every launch then reopens that note in Organize mode, and `navigation_controller.js` never restores the last-opened note, because it only does that on a bare `/`. Fix scope, v0.2:

- Enable the Rails PWA manifest route and link it in the layout. Add `"id": "/"`, so a future `start_url` change doesn't fork installs into a second app, and replace the scaffold's `theme_color`/`background_color: "red"`.
- Link the manifest with `crossorigin="use-credentials"`. Browsers fetch manifests without cookies by default, and a deployment behind Cloudflare Access (the maintainer's own) would get the Access login page instead of the JSON. Check the icon fetch the same way.
- Stop `navigation_controller.js` from remembering mode params (`organize`, `todos`, `view`) in `lastPath`: a restore should bring back the note, not the mode you were in when you clicked it.
- Don't register the service worker yet. Chromium no longer needs one to install, and caching belongs to v1.0's offline read-only work, not here.
- Existing installs keep their captured URL: the release notes must say to uninstall and reinstall once.

This is the "installable" half of v1.0's "PWA installable + offline read-only", pulled forward because the bug is live. Offline stays in v1.0.

---

## 6. Reversed decisions

**Import is no longer out of scope.** The old roadmap says "Export only, one direction." The stated goal is winning over people currently in Obsidian and Notion, and nobody abandons three years of notes to retype them. Import a zip or folder of Markdown: directories become notebooks and folders, `.md` files become notes, front matter is preserved into the body, and `[[wikilinks]]` resolve once §5 #7 lands. Export already does the reverse mapping, so most of the thinking is done. **v0.5** (was v0.3 — moved behind `[[links]]` on 2026-09-26 so an imported vault's links resolve on arrival instead of needing a re-import), and it should be the headline of that release's post rather than an afterthought.

**Settings grows an "Account" tab now,** ahead of the old "don't build tab chrome before a feature needs it" rule — the sign-out relocation (#3) is that feature.

**PWA offline read-only moves from "someday" to v1.0.** It is listed in the old roadmap with no phase. It belongs with the v1.0 trust story, and it is blocked on removing CDN dependencies (a service worker cannot cache what a third party serves), which the pre-beta checklist does anyway.

### Deferred, but not dropped

These carry over from the archived roadmap with no scheduled release. They are still wanted; nothing here is blocking anyone today, and each would displace something that is.

- **Passkey / WebAuthn and OIDC login.** Deprioritized deliberately: the maintainer's own deployment sits behind Cloudflare Access, which already solves this, and Rails ships no WebAuthn support, so it is not the small job it sounds like. Revisit when someone running a standalone instance actually asks.
- **TOTP / 2FA.** Answers a different question ("is this really you?") than the one the auth design solves ("you forgot your password and email doesn't reach you"). Revisit only if this ever opens up beyond a trusted team.
- **Bulk operations on the admin team list** (export, multi-remove) — revisit alongside import/export work in v0.3.
- **Tags** — see §7.
- **A custom prompt template for the AI handoff** — deferred in #47 rather than dropped. It backs straight into Settings bloat, and the preamble is editable in the AI chat itself. Revisit on repeated demand, not on the first request.
- **A dedicated multi-note import screen** — covered for now by the paste box and preview on `/todos`.

---

## 7. Additional proposals from reading the code

Ordered by how much they matter, not by size.

### Data safety (these are the v1.0 story)

- **~~Multi-device overwrite is currently silent data loss.~~ — shipped in v0.1.0.** `notes.lock_version` (Rails optimistic locking): the autosave sends/stores the version, and on conflict a banner offers reload vs. keep-mine instead of last-write-wins. Polished post-beta (conflict dialog keep/cancel UX).
- **Deleting a notebook is irreversible and cascades to every folder and note under it,** behind one `confirm()`. A notes app needs a trash: soft-delete with a retention window (default 30 days, tunable via a constant/env from the console — never a hardcoded value) and an undo toast. Trash and Archive are separate lists, never mixed. **v0.4.** Still open. Trash introduces the `notes.status` column the archive below also uses (`active`/`trashed` now, `archived` added in v0.5). Designing the column once here avoids a second migration of the same field one release later. Notebooks and folders get their own soft-delete, since today they cascade with `dependent: :destroy`.
- **Archive with expiry.** Normal Markdown notes and scrap-type notes can carry an optional archive expiry, set from a button left-aligned in the preview/edit toggle lane (toast popup: 1 hour / 1 day / 1 month / custom datetime; scrap editors get the same button next to Copy-all). Expiry is computed from the last-edited time (`updated_at`): each content update recomputes `expires_at`, reads never extend it. Past expiry the note moves from its folder into a **global Archive section** (one cross-notebook list with origin breadcrumbs — per-notebook nesting is rejected because a note whose folder is gone must still be findable) and becomes read-only: editable no more, deletable yes. Restore reparents to the original folder when it still exists, otherwise falls back to a picker (default: first folder, or create "Restored"). Data model: `notes.status` (`active`/`archived`/`trashed`) + `expires_at` + `original_folder_id`/`original_notebook_id`, swept by an hourly job. **v0.5.** Still open.
- **Note revision history.** Autosave overwrites blindly, so one bad paste plus a reload is unrecoverable. Snapshot into a `note_versions` table on a coarse interval. Then wire it to the **Compare** view that already exists: "compare this note to how it looked yesterday" reuses a shipped feature and makes it the reason people trust the editor. **v1.0.** Still open.
- **~~Backups are promised and don't exist.~~ — runbook shipped in v0.1.0** (`bin/backup` / `bin/restore`, SQLite-safe, verified round-trip with a real image blob; see [backup.md](../engineering/backup.md)). What remains is the Account-tab status line — still a **v1.0** item.

### Product

- **~~A seeded welcome notebook on first run.~~ — shipped in v0.1.0.** `db/seeds.rb` creates a locale-aware welcome notebook whose first note *is* the tutorial (three note types, editor rendering, Ctrl+P).
- **Daily note.** Obsidian's most-used feature, and it fits "self-learning notes" exactly: one keystroke opens today's note, created if absent. **v0.3** (with `[[links]]`, since a daily note is mostly a place to link out from). Recommended home, to confirm in the implementation plan: an auto-created "Daily" notebook with one folder per month, titled `YYYY-MM-DD` so `[[2026-09-26]]` links resolve without a qualifier; no settings entry until someone asks to move it.
- **Publish a note as a read-only link.** This is the other answer to the screenshot request, and a better one for anything longer than a paragraph. It does add an unauthenticated public endpoint, against design principle 2 — so: off by default, per-note, unguessable token, revocable, and never for a whole notebook. **v1.x**, deliberately after the PNG route, which needs no new attack surface.
- **A `?` keyboard-shortcut cheatsheet,** once there are enough shortcuts to forget. **v0.4.**
- **Tags (`#tag`) are deferred, not planned.** They add a whole second navigation dimension parallel to folders. Search plus backlinks may well cover the need; revisit at v1.x only if real use says otherwise.

### Extraction (supports the star-count goal as much as the code)

Each of these is a separate README, a separate Zenn post, and a separate surface to be found through:

- `@toishi/markdown-textarea` — the editor behaviors from #4, IME-safe and undo-preserving. The most broadly useful thing in this repo.
- `@toishi/office-clipboard` — Word/Excel clipboard HTML → Markdown, already isolated in `word_clipboard.js` / `html_to_markdown.js`, merged-cell handling and all.
- `turndown-plugin-katex` — the sup/sub → KaTeX plugin already planned in the archived roadmap.

### Refactoring — all done (2026-09-09)

Every item in this subsection shipped during the pre-beta cleanup or the post-beta hardening wave, so it is recorded here as done rather than re-planned:

- **`home/index.html.erb` extraction** — done pre-beta (353 → 87 lines; sidebar/editors extracted, inline CSS moved to SCSS).
- **Dead code deletion** — done pre-beta (EasyMDE CSS, `NotesController#preview` + `redcarpet`, unused globals, empty helpers).
- **`Note::DEFAULT_TITLES` hardcoded Japanese** — done pre-beta (explicit titled-state, translated display values).
- **`Note#todo_completion_percentage` three COUNT queries** — done post-beta (single grouped query, memoized per render).
- **`navigation_controller.js#disconnect` leaked listener** — done pre-beta (stored bound handler).

---

## 8. Release plan

### v0.1.0 — Public beta ✅ shipped 2026-08-24

*Theme: a stranger can install it, and moving around it feels fast.*

- Everything in [`pre-beta-checklist.md`](../engineering/pre-beta-checklist.md) — bundle size, CDN removal, self-hosted fonts, sanitization, dead code, docs, backup runbook (`bin/backup` / `bin/restore`)
- Ctrl/Cmd+P palette: recent notes + title match, plus alternate-between-last-two
- Markdown list continuation and Tab indent (IME-safe, undo-preserving)
- Non-proportional UD font on content surfaces
- Sidebar scrolls the active row into view
- Email and sign-out move to a Settings "Account" tab; sign-out hidden under trusted-header auth
- Optimistic locking (`lock_version`) + conflict prompt — built during pre-beta, so it rode the v0.1.0 cut rather than waiting for v0.2
- Seeded locale-aware welcome notebook (`db/seeds.rb` rewrite) — likewise, shipped here rather than v0.2
- README rewritten for self-hosters, `README.ja.md` added, `CHANGELOG.md` started
- **Repository refresh happened here** (public `hrtmys/toishi-note`; old repo kept private).

### v0.1.x — Post-beta hardening ✅ shipped 2026-08-24 → 2026-09-09

No new roadmap features; stability and correctness for the beta audience:

- Per-user last-notebook/folder memory (one fewer re-navigation on reload)
- CRUD operations give visible feedback (flash toasts); flash/toast Stimulus connect-order race fixed
- Three N+1 queries fixed; palette ranking relocated into `Note.search_ranked`
- Row-level locks + unique indexes around concurrent position/reparent/promote writes
- Image upload size cap + real image validation; bulk TODO import count cap
- Silent autosave/settings/scrap-source failures now surface an error toast
- Preview scroll stability and Mermaid/KaTeX hardening under rapid typing
- IME-safe auto-title; Word-paste robustness (unformatted pastes, copy failures, pasted images)
- Dev environment refresh (`.devcontainer` → `Dockerfile.dev` + `bin/d`); palette empty-state/keyboard and sidebar empty-state polish

### Size and delegation labels (added 2026-09-26)

Each open item from here to v0.5 carries two labels. **Size:** S = under half a day, M = about one focused session, L = several sessions (plan → tests first → implementation → review). **Delegation:** *delegable* means this document already pins the behavior, so a contributor or a less careful model can implement it from a short brief, with review after; *design* means it needs judgment this document doesn't settle (security, data model, state machines) and should go through a written plan first.

### v0.2.0 — The editor earns its keep (partially shipped 2026-09-11)

- ✅ Remaining editor shortcuts; paste-URL-over-selection
- ✅ Mobile/sidebar bug insertions: FILES-only offcanvas close with no re-show animation on notebook/folder navigation (B1); paste keeps its broad HTML detector but preserves the undo stack via `execCommand("insertText")`, with Shift+Enter passthrough and an extended "converted to Markdown" toast (B2); per-row tap-to-open vertical ellipsis on touch, hover reveal kept on desktop (B3); title input no longer reserves button space (B4); `*` + space + Enter continues the bullet instead of deleting it (B5)
- ✅ **Installable PWA fix** (merged 2026-09-27, #53) — linked manifest with `start_url`/`id` `"/"`, credentialed manifest fetch, mode params out of `lastPath` (§5 #17). *S–M, design* (small diff, but it has to be checked behind Cloudflare Access and on a real Chrome/Edge install). Do this first.
- ✅ Global pinned section, cross-notebook (#54)
- ✅ Flexible sidebar pane heights: content-sized panes capped relative to the sidebar, Files keeps at least 10rem (#57). Drag handles stay in v0.4.
- Cut: v0.2.0 also carries the TODO-hub wave below. The release notes must tell existing PWA installs to reinstall once.

### v0.2.x — Test suite reset (between v0.2.0 and v0.3)

*Theme: a two-minute CI, so the plan → test → implement loop stops waiting on it.* No user-facing change. It goes here because v0.3's `[[links]]` will add many tests, and those should be written to the new rules from the start.

- `docs/engineering/testing.md`: system tests are a named smoke set of about 10–15 cases covering what only a real browser can check (IME composition, paste and the undo stack, keyboard focus flows, viewport layout). Everything else is a controller/integration test, or a `node:test` unit test of a pure function in `app/javascript/lib/`.
- Classify the ~130 current system tests against that rule, then convert them in batches. *L, design* for the rule and the classification; the conversions are *delegable*.
- CI: cache the apt packages; shard the remaining system tests only if still needed. (The push trigger fix and cancelling superseded runs ship with v0.2.0.)
- Target: CI wall time about 2 minutes, down from about 4.

### TODO hub and the AI handoff loop ✅ merged 2026-09-21, awaiting a cut

*Theme: TODOs scatter across notebooks by design; managing them shouldn't mean walking the tree, and handing them to an AI shouldn't mean retyping them.*

Issue #47, shipped as three PRs (#49, #50, #51). Not a release of its own — it rides whichever cut comes next.

- `/todos` stops being a standalone page and becomes a mode of the main pane, so the sidebar survives. Two stateless views: grouped by `Notebook / Folder / Note`, or the existing global due-first list. Fixes a real bug on the way — the old view dropped the folder name entirely.
- A Settings-gated AI handoff, off by default per design principle 1: a per-note `ai_excluded` flag, copy buttons, and `GET /todos.md` — session-authenticated Markdown, scoped by notebook/folder/note, with a preamble, a `## Structure` tree, and a collapsed recently-done block. No public API, no server-side LLM key, no egress requirement; the loop is copy-paste, which is what an IT-ops network can actually do.
- Bulk apply of the AI's reply, behind a preview that lists every add, check, due change and delete before anything runs, and a digest that makes the apply refuse any state the preview didn't describe.

**Two rules did most of the design work, and are worth keeping in mind for anything else that mutates from pasted text.** Removal is never inferred — an item missing from the paste is untouched, and a missing `(due:)` never clears a date, because a chat reply gets truncated and a partial paste must not wipe what it omitted. And removal therefore has to be sayable out loud: `(id: <base36>;delete!)` deletes, `(due: none)` clears. The delete marker lives *inside* the id tag rather than standing alone as `(delete)`, because a task can genuinely read "Clean up old backup files (delete)" — and because embedding it makes an unbound delete syntactically impossible rather than a rule the parser has to remember. The cost is that an AI may garble the marker; every way it can do so ends in no deletion, which is the right direction to fail.

Rejected along the way, and still rejected: a PAT-authenticated task API (grows the attack surface, design principle 2), a server-side LLM key (cost, secrets, and dead on a no-egress network), and a separate `Task` model (the Notion-database direction this project is deliberately not taking).

### v0.3.0 — The graph, and finding things again

*Moved up from v0.5 on 2026-09-26.* `[[links]]` are the most keenly felt gap (§3), and import needs them anyway — an Obsidian vault is mostly wikilinks, and importing before they resolve would mean a second pass or a re-import.

- `[[Internal links]]`: `note_links` table, shared-renderer support, `[[` autocomplete, unresolved-link creation (§5 #7, including the ambiguous-title rule). *L, design.*
- Backlinks panel. *S, delegable* once `note_links` exists.
- Search (`LIKE`) inside the palette, tested with Japanese content (§5 #10). *M, delegable* with a plan — it extends `Note.search_ranked`.
- Daily note (§7). *S, delegable* once its home is confirmed.
- ✅ Bullets → TODO — shipped 2026-09-21 inside the TODO-hub wave

### v0.4.0 — Comfort

- Trash and undo: soft-delete for notebooks, folders, and notes, configurable retention defaulting to 30 days, introducing `notes.status` (§7). *L, design.*
- Vanishing scratch pad (sessionStorage-only single pad). *S, delegable.*
- Offline detection with the reconnect prompt (§5 #13). *M, design.*
- Copy preview as PNG via lazy-loaded `modern-screenshot` (§5 #6). *M, delegable* with a plan — the verification list in §5 #6 is the brief.
- URL title fetch (opt-in, SSRF-guarded). *M, design* — security-sensitive.
- Resizable sidebar panes; `?` cheatsheet. *S + S, delegable.*

### v0.5.0 — Getting your notes in, and letting them go

- **Import** from an Obsidian vault or folder of Markdown, resolving `[[links]]` with v0.3's rule (§6). Has to cap zip size and entry count and reject path traversal in entry names. `rubyzip` is already a dependency. *L, design.*
- Archive with expiry: global section, read-only, restore flow, hourly sweep on Solid Queue's `recurring.yml` (§7). *L, design.*

### Effort to v0.5, estimated 2026-09-26

Four L items (links, trash, import, archive) and three design-labelled S/M items (PWA fix, offline, URL fetch) need a written plan each: roughly 12–15 focused sessions. The nine delegable items can run in parallel with those, but still get reviewed before merge.

### v1.0.0 — Trust

- Revision history, wired into Compare
- Backup status in Account settings
- PWA offline read-only (the installable half moved to v0.2 — §5 #17)
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

*Status 2026-09-26:* not started. Checked against the code rather than assumed: no encryption code, no citation/DOI fields, no Zotero or BibTeX code, and no `tags` table. The only trace is the reserved "Integrations" tab mentioned in a comment in `settings/_modal.html.erb`.

---

## 9. Non-goals (unchanged, restated)

- A public JSON API
- A plugin system — core PRs instead
- Offline *editing* or sync; offline is read-only, the server is always right
- Shared or permissioned notebooks
- Paid literature databases
- CodeMirror, EasyMDE, or any editor framework in the Markdown pane
- Rabbit as an embedded runtime (export only)
