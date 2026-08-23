---
title: Asset & Dependency Strategy
description: Why front-end dependencies are vendored and bundled rather than loaded from a CDN, and where the Node toolchain stands
status: living
updated: 2026-08-15
---

# Asset & dependency strategy

This exists because "Rails is going no-build" is easy to hear as "so load everything from a CDN," and for this product that would be the wrong conclusion. The two questions are separate and get separate answers:

1. **Who serves the bytes?** → **This server. Always.** Settled, not up for revisiting.
2. **What builds them?** → esbuild for now; importmap is a real option later, on its merits.

## 1. No CDN. Ever, in the runtime path.

### "No build" is a claim about the toolchain, not about hosting

`importmap-rails` removes the *bundler*. It does not require the *CDN* — `bin/importmap pin <package> --download` vendors the file into `vendor/javascript`, and the JSPM pin is a convenience default for getting started, not a deployment recommendation. 37signals does not serve Basecamp's JavaScript off jsDelivr. The no-build argument is "you shouldn't need Node to run a Rails app," and it is a good argument. It is not "your app's code should come from someone else's server."

So the CDN question has to be answered on its own, and for this app it answers itself six times over.

### Why a CDN is disqualified here specifically

1. **It contradicts the product in writing.** The README says self-hosted, your data never leaves your server. Today every page load tells jsDelivr and Google Fonts the IP address, user agent, and referring page of every user, on every visit. That is not a nuance — it makes a sentence in our own README false.
2. **It breaks one of the two named personas.** IT-ops / 情シス deployments routinely sit on networks with no general egress. Math and diagrams would silently stop rendering, with no error and nothing to debug. "Looks broken, don't know why" is worse than "feature absent."
3. **Supply chain: a third-party `<script src>` is an unrestricted code-execution channel into a page holding every note the user owns.** There is no SRI on the current tags. A hijacked or compromised CDN entry reads and exfiltrates the whole notebook. And SRI isn't the fix it looks like — pinning a hash means manually updating it on every upgrade, at which point you have vendoring with extra steps and a worse failure mode.
4. **Offline read-only (roadmap v1.0) is impossible while a third party serves part of the app.** A service worker can cache same-origin assets deterministically; opaque cross-origin responses it cannot.
5. **It blocks a real CSP.** `config/initializers/content_security_policy.rb` is currently commented out end to end, so `csp_meta_tag` in the layout emits nothing — this app renders user-supplied Markdown with no policy behind it. Once assets are same-origin, `default-src 'self'` becomes achievable, which is the single cheapest hardening available. Keep the CDNs and the policy has to allowlist them, which for XSS purposes is close to no policy at all.
6. **Self-hosted software gets installed once and run for years.** A pinned CDN path that 404s in 2029 breaks an instance whose owner never touched anything. Vendored bytes can't rot.

**Rule: nothing in the runtime path is fetched from a third party at request time — no JS, no CSS, no fonts, no icons.** Build-time downloads (yarn, bundler, `importmap pin --download`) are fine; those produce artifacts we commit or ship in the image.

### The current state is the worst of both

`layouts/application.html.erb` loads KaTeX 0.16.9 and Mermaid 10.6.1 from jsDelivr. `package.json` also depends on KaTeX 0.18.1 and Mermaid 11.16.1, and `lib/markdown_renderer.js` imports both directly. **So the browser downloads Mermaid twice, at two different major versions, on every page load** — roughly 3MB from the bundle plus another ~2.9MB from the CDN — and which copy wins depends on load order. This isn't a trade-off anyone chose; it's two solutions to the same problem left stacked on top of each other. Deleting the CDN tags is strictly a fix: smaller, faster, private, and it removes a version conflict.

## 2. The build: esbuild now, importmap as a deliberate later project

### What the numbers said (before the fixes in pre-beta-checklist.md § 1)

| Artifact | Before | Why |
|---|---|---|
| `application.js` | 10,493,077 bytes | no `--minify` in `package.json`'s build script, and every heavy library is imported eagerly |
| `application.js.map` | 17MB | `--sourcemap` runs in the production build too |
| `application.css` | 1,137,960 bytes | `sass` defaults to expanded output; no `--style=compressed` |
| bootstrap-icons | 2,078 icon classes + a webfont | the app uses **32**, but see below — not worth subsetting |

`assets:precompile` in the `Dockerfile` runs exactly the same script `bin/dev` does. So production ships all of it.

None of that was esbuild's fault, and none of it needed a different bundler to fix. It was four missing flags and one import pattern — now shipped: production `application.js` is 214,310 bytes (62,413 gzipped), `application.css` is 145,431 bytes gzipped. **Icon subsetting was deliberately skipped**: bootstrap-icons' own CSS is only ~13KB of that gzipped total, and the budget was already met without touching it — a hand-maintained subset's silent-failure mode (a forgotten icon just renders a missing glyph, no build error) isn't worth ~13KB against an already-met target.

### The eager-import problem is the real one

`markdown_renderer.js` statically imports Mermaid, KaTeX, highlight.js, marked, and DOMPurify. `markdown_renderer.js` is imported by `editor_controller.js`, which is registered in `controllers/index.js`, which is imported by `application.js`. So **every page load pulls Mermaid** — including the sign-in page, the setup page, and the admin panel, none of which can render a diagram.

Mermaid is needed by the fraction of notes that contain a ```mermaid fence. KaTeX by the fraction with math. highlight.js by the fraction with code. All three belong behind a dynamic `import()` triggered by finding the corresponding thing in the rendered output. That change is worth more than any bundler choice on this list, and **it has to happen under either strategy** — which is exactly why it should happen first.

**Shipped** (see [pre-beta-checklist.md § 1](pre-beta-checklist.md) for the numbers and what this section originally got wrong about `--splitting`): `--chunk-names="chunks/[name]-[hash].digested"` is the actual fix — Propshaft's own documented escape hatch for a bundler's pre-fingerprinted output, not something to avoid `--splitting` over. Dynamic `import()` alone, without `--splitting`, does *not* produce a real separate fetch; esbuild inlines it straight back into the same file.

### Then: keep esbuild, or go importmap?

**The honest case for importmap + dartsass:** it deletes `node_modules`, `yarn.lock`, esbuild, and the entire npm dependency tree from the project. For an OSS project whose stated audience is Rubyists, "clone it, `bin/setup`, it runs — no Node" is a genuine selling point and a genuine reduction in contributor friction. It also removes a whole ecosystem from the security-monitoring burden, which matters more here than usual given that we are currently monitoring it not at all (see the checklist). `dartsass-rails` ships a standalone Dart Sass binary, so Bootstrap's SCSS still compiles with no Node — sourced from the `bootstrap` rubygem rather than `node_modules` (verify that gem tracks the 5.3 line before committing to it).

**The honest case against, right now:**

- **Mermaid is hostile to importmap.** Its ESM build splits into internal chunks; pinning it cleanly is fiddly, and the sane way to load it is a single vendored UMD file fetched on demand — which is a bundler-shaped solution living inside a no-bundler project.
- **highlight.js is 190 language modules.** Via importmap you either pin a prebuilt bundle or accept a request waterfall.
- The remaining dependencies — marked, DOMPurify, turndown (+gfm), diff, sortablejs, KaTeX, Bootstrap, Popper — are all single-file ESM and would pin without drama.
- Migration means rewriting every import specifier, reworking CI and the Dockerfile, and re-verifying the whole app through the system tests. That is days of work with a nonzero chance of subtle breakage, and it buys **zero** user-visible improvement — every byte it would save is saved by minify + lazy-loading anyway.

**Decision:**

- **v0.1.0 — keep esbuild.** Add `--minify`, drop the production sourcemap, add `--style=compressed` to the Sass build, move Mermaid/KaTeX/highlight.js behind dynamic `import()`, subset the icons, delete the CDN tags, self-host the font. Hours of work, no migration risk, and it addresses the entire measured problem.
- **Post-beta (v0.4-ish) — reassess importmap deliberately, not under release pressure.** The precondition is the lazy-loading work above: once Mermaid and highlight.js are no longer part of the eager payload, the eagerly-loaded set is Turbo, Stimulus, Bootstrap, marked, and DOMPurify — five well-behaved ESM packages that importmap handles comfortably. The awkward dependencies would already be isolated behind on-demand loading, where a vendored file works the same either way. **The dependency list has to get the right shape before the tool choice is even a fair question.** Do that first; decide after.
- If the answer then is still esbuild, that's fine. This is not a migration that has to happen — it's one that becomes cheap or expensive depending on work we're doing regardless.

### Targets to hold the result to

- Initial JS payload under 500KB gzipped, with no Mermaid in it
- CSS under 150KB gzipped
- Zero third-party requests on page load — verified in devtools on a cold load, not by reading the layout
- Everything still works with the machine's network egress blocked

## 3. If Node stays, it has to be treated as a real dependency

Keeping esbuild is defensible. Keeping it *unmonitored* was not, and now isn't — see [pre-beta-checklist.md § 10](pre-beta-checklist.md) for what shipped: an `npm` Dependabot entry, a real `scan_js` CI job running `yarn audit` (replacing the unused, never-invoked `config/ci.rb`/`bin/ci`, deleted rather than wired up), and `actions/setup-node` pinned to `.node-version` in the jobs that need it. That was the strongest practical argument in the whole importmap discussion above, independent of which bundler survives — DOMPurify, marked, and Turndown (everything that parses untrusted input in this app) are now actually monitored.
