# Contributing

Thanks for considering a contribution.

## Getting set up

The [devcontainer](.devcontainer/devcontainer.json) is the easiest path — see the [README](README.md#quickstart-devcontainer) for the quickstart, and [docs/engineering/dev-environment.md](docs/engineering/dev-environment.md) if you want to know why it's configured the way it is.

## Before opening a PR

```sh
bin/rails test
bin/rails test:system
bin/rubocop -A
bin/brakeman
```

All of these run in CI ([.github/workflows/ci.yml](.github/workflows/ci.yml)); running them locally first saves a round trip.

## Coding conventions

[docs/engineering/coding-style.md](docs/engineering/coding-style.md) covers the Ruby/Rails conventions this project follows — Rubocop settles formatting automatically, so that doc only covers what a linter can't decide (things like: prefer POROs over a `Service` layer, don't lean on `created_at` for domain ordering, no changelog-style comments).

## Docs

If a change affects why something is built the way it is — not just what changed — update the relevant file under `docs/` in the same PR. [docs/README.md](docs/README.md) explains the structure. Docs are written in English so anyone can read them regardless of what language discussion around the change happened in.

## Adding a font to the CJK/monospace stack

`$cjk-monospace-stack` in [`app/assets/stylesheets/_typography.scss`](app/assets/stylesheets/_typography.scss) is a fallback chain, not a bundled asset — the app never ships a font file (see [`docs/engineering/asset-strategy.md`](docs/engineering/asset-strategy.md)). Whichever named font a viewer happens to have installed locally is the one that renders; that's the whole mechanism, and it's deliberately simple rather than a settings-UI font picker.

Currently listed are three yuru7 fonts (Bizin Gothic, UDEV Gothic, HackGen) tuned for Japanese, but the same reasoning applies to any language whose script needs a specific programming font — this isn't meant to stay Japanese-only. If you want to add one:

1. **Check its license first.** It has to be redistributable-by-name at minimum (SIL OFL and MIT both qualify); if you're unsure, say so in the issue/PR rather than guessing.
2. Add the exact font-family name to `$cjk-monospace-stack` (or a new stack, if it's for a script this one doesn't serve).
3. If it's free to fetch from an upstream release, add it to `install_yuru7_font` (or an equivalent block) in [`.devcontainer/post-create.sh`](.devcontainer/post-create.sh) so contributors' screenshots and system tests actually render it, and mention it in [`docs/engineering/dev-environment.md`](docs/engineering/dev-environment.md).
4. Open an issue or PR — either is fine for something this small.

## Product direction

[docs/product/roadmap.md](docs/product/roadmap.md) records what's planned and what was deliberately turned down; [docs/product/ux-roadmap.md.old](docs/product/ux-roadmap.md.old) is the archive behind it, holding the persona and design principles those decisions come from. If you're proposing a new feature, it's worth checking whether it fits there first — this project deliberately keeps a narrow, opinionated scope (see the "Non-goals" section) rather than trying to be a general-purpose everything-app.
