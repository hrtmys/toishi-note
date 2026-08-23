# Third-party licenses

Toishi Note itself is [MIT-licensed](LICENSE). Everything it bundles or links against is too, with the exceptions below — all permissive, all compatible with shipping inside an MIT project, but worth naming explicitly rather than leaving a stranger to work it out from `Gemfile.lock`/`yarn.lock`.

## Bundled in the browser

| Package | License |
|---|---|
| [highlight.js](https://github.com/highlightjs/highlight.js) | BSD-3-Clause |
| [diff](https://github.com/kpdecker/jsdiff) | BSD-3-Clause |
| [DOMPurify](https://github.com/cure53/DOMPurify) | MPL-2.0 OR Apache-2.0 (this project uses it under Apache-2.0) |
| [KaTeX](https://github.com/KaTeX/KaTeX) | MIT |

KaTeX's own font files (vendored under `app/assets/stylesheets/katex/fonts/` — see [docs/engineering/asset-strategy.md](docs/engineering/asset-strategy.md) for why they're vendored rather than CDN-loaded) are covered by the same KaTeX MIT license, not a separate font license.

Everything else in `package.json` (Bootstrap, Bootstrap Icons, Stimulus, Turbo, marked, SortableJS, Turndown, `@popperjs/core`) is MIT.

## Ruby gems

| Gem | License |
|---|---|
| [sqlite3](https://github.com/sparklemotion/sqlite3-ruby) | BSD-3-Clause |
| [rubyzip](https://github.com/rubyzip/rubyzip) | BSD-2-Clause |
| [puma](https://github.com/puma/puma) | BSD-3-Clause |

Everything else in `Gemfile.lock` outside the `development`/`test` groups (Rails itself and its component gems, Propshaft, jsbundling-rails, cssbundling-rails, bcrypt, image_processing, ruby-vips, kamal's absence notwithstanding, etc.) is MIT.

`brakeman` (Brakeman Public Use License, not OSI-approved) and `bundler-audit` (GPL-3.0-or-later) are both `development`/`test`-only tooling, never shipped in the production image — `Dockerfile`'s `BUNDLE_WITHOUT="development:test"` excludes both, along with `debug`, `capybara`, and `selenium-webdriver`.

## A linked system library, not a bundled one

[libvips](https://github.com/libvips/libvips) — the image-processing library `ruby-vips` binds to via FFI, used for the WebP conversion described in `docs/product/roadmap.md`'s image-attachments notes — is **LGPL-2.1-or-later**. It's installed as a system package (`libvips42t64` in the devcontainer, `libvips` in `Dockerfile`) and linked dynamically at runtime, not statically compiled into this application or redistributed as source — the standard arrangement under which LGPL software may be used by a differently-licensed (including MIT) application without that application itself becoming LGPL.
