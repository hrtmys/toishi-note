# Toishi Note

A self-hosted, Markdown-first notebook app built on Rails 8 + Hotwire. Organize notes into notebooks and folders, and pick the note type that fits: freeform Markdown (split edit/preview, syntax highlighting, math), TODO lists, or a lightweight Scrap stream for quickly capturing fragments.

This project is pre-release and under active development. See [docs/product/roadmap.md](docs/product/roadmap.md) for where it's headed and the thinking behind it. [日本語 README](README.ja.md)

![The Markdown editor, split edit/preview, with syntax-highlighted code and rendered math](docs/images/editor.png)

## Who this is for

You're currently keeping study/work notes in Obsidian or Notion and would rather they lived on a server you control:

| | Obsidian | Notion | Toishi Note |
|---|---|---|---|
| Multi-device | Paid Sync, or you configure git/Syncthing yourself | Yes | **Yes, inherently — it's a server** |
| Your data on your box | Yes | No | **Yes** |
| Cost per teammate | Per seat | Per seat | **A few database rows** |
| Hackable | TypeScript plugin API | No | **It's a Rails app — send a PR** |

If you're not already self-hosting something and don't want to start, this probably isn't for you yet — there's no hosted version. If you are: `docker compose up` below gets you running in a few minutes.

![A TODO note, with a progress bar and checkable items](docs/images/todo.png)

## Self-hosting quickstart (Docker Compose)

```sh
git clone https://github.com/hrtmys/toishi-note.git
cd toishi-note
cp .env.example .env
bin/rails secret               # generates your own signing key — see docs/engineering/deployment.md
# edit .env: paste the generated value in as SECRET_KEY_BASE, set APP_HOST to your domain
docker compose up -d
```

Visit `http://127.0.0.1:3000` (or wherever you've put a reverse proxy in front — see below) and finish the one-time Setup screen. Full guide, including required env vars and the reverse-proxy pattern: [docs/engineering/deployment.md](docs/engineering/deployment.md). Backing up your data (tested, not just documented): [docs/engineering/backup.md](docs/engineering/backup.md).

## Authentication

The first visit to a fresh instance shows a one-time setup screen, asking **"Just me" or "My team"**:

- **Just me** creates a single note-taking account. That's the whole story — no team-management UI ever appears.
- **My team** creates an **admin account that doesn't take notes itself** — its only job is inviting the accounts that do, and removing ones that shouldn't have access anymore (a "Remove" button per teammate; an admin can't remove their own account this way). An admin invites a teammate with just a login (an email address, or — see below — a plain username); the response is a one-time link (never a password) to hand over however you'd normally share anything (chat, etc.), and the teammate sets their own password by visiting it. The same mechanism issues a fresh link to rescue a teammate locked out of their account. An admin never chooses, and never learns, anyone else's password. There's no invite email and no dependency on outbound mail working.
- **Every account's notebooks are private to them — there's no sharing or permission model at all.** "My team" is about running one deployment for several people, each with their own space, not a shared team workspace (the editor has no conflict handling for two people editing the same note at once, so nothing is ever shared between accounts by design). Removing a teammate deletes their notebooks with them; the confirmation says so first.
- Started solo and want a second account later? That's a one-line console promotion (see [SECURITY.md](SECURITY.md)), not an in-app toggle — deliberately, so solo users never see a button they'll never use.

Either way, once signed in:

- Sign in with a login (email address or username — one person often has exactly one corporate email address, already spoken for by their own note-taking account, so an admin login doesn't have to be one) + password. Passkey and OIDC are planned (see "Deferred, but not dropped" in [roadmap.md](docs/product/roadmap.md)) but not built yet. Forgotten a password? See [SECURITY.md](SECURITY.md) — the built-in "Forgot password?" email flow needs SMTP configured in production; a console-based reset works everywhere with no setup.
- **Behind a trusted reverse proxy** (Cloudflare Access, Tailscale Serve, oauth2-proxy, ...): set `TRUSTED_HEADER_AUTH_HEADER` to the header your proxy sets with the authenticated user's email (e.g. `Cf-Access-Authenticated-User-Email`), and the app auto-provisions and signs in from it — no login screen at all. Only enable this if the proxy is actually configured to strip that header from inbound requests and set it itself; otherwise a request could just claim to be anyone. Auto-provisioned accounts are always regular (non-admin) accounts — see [SECURITY.md](SECURITY.md) for what that means for team membership and admin accounts when you're using this instead of (or alongside) passwords.

In development, sent mail (password resets, etc.) doesn't go anywhere real — browse it at `/letter_opener` instead.

## Contributor quickstart (devcontainer)

The fastest way to get a working development environment is the included [devcontainer](.devcontainer/devcontainer.json) — it sets up Ruby, Node, and the system packages the app needs (see [docs/engineering/dev-environment.md](docs/engineering/dev-environment.md) for what's in it and why).

1. Open this repository in VS Code (or any [Dev Containers](https://containers.dev/)-compatible editor) and reopen in container.
2. `bin/setup` to install dependencies and prepare the database.
3. `bin/dev` to start the app, then visit `http://localhost:3000`.

### Manual setup

Requires Ruby (see [.ruby-version](.ruby-version)), Node.js, and the system libraries listed in [docs/engineering/dev-environment.md](docs/engineering/dev-environment.md) (`libvips`, and a Chromium-based browser if you want to run system tests).

```sh
bundle install
bin/rails db:prepare
bin/dev
```

## Running tests

```sh
bin/ci             # everything CI runs, in one command with compact output — see docs/engineering/verification.md
bin/ci quick       # skips system tests, for fast local iteration
```

Or individually: `bin/rails test`, `bin/rails test:system`, `bin/rubocop`, `bin/brakeman`, `bin/bundler-audit`, `yarn audit`. All of the above run in [CI](.github/workflows/ci.yml) on every pull request.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to get set up and the coding conventions this project follows ([docs/engineering/coding-style.md](docs/engineering/coding-style.md)), and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## Docs

[docs/README.md](docs/README.md) indexes the rest — product direction, UX decisions, and engineering notes.

## Security

See [SECURITY.md](SECURITY.md) for how to report a vulnerability.

## Acknowledgments

Toishi Note draws design inspiration from [citronote](https://citronote.korange.work/) ([source](https://github.com/citronote/citronote/)). citronote's Scrap feature (there, plain text) inspired this project's Markdown-rendered Scrap; its Markdown rendering inspired this project's KaTeX/Mermaid-extended version; and its simple TODO checklist inspired this project's more full-featured TODO. No code was reused — these ideas were reimplemented independently — but the credit is owed and gladly given.

## License

[MIT](LICENSE). Bundled third-party dependencies are under their own (all permissive) licenses — see [THIRD-PARTY-LICENSES.md](THIRD-PARTY-LICENSES.md).
