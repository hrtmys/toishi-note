---
title: Deployment
description: Self-hosting Toishi Note with Docker Compose
status: living
updated: 2026-08-16
---

# Deployment

Docker Compose is the only supported deployment path. Kamal scaffolding (`config/deploy.yml`, `.kamal/`) was removed rather than left half-configured — it never matched this architecture, and a broken deploy config invites issues from people who try to use it.

## Quickstart

```sh
git clone https://github.com/hrtmys/toishi-note.git
cd toishi-note
cp .env.example .env
bin/rails secret    # generates SECRET_KEY_BASE — see below
# edit .env: paste the generated value in as SECRET_KEY_BASE, set APP_HOST
docker compose up -d
```

Visit the container's published address (`http://127.0.0.1:3000` by default — see `docker-compose.yml`) and finish the one-time Setup screen.

### Required configuration

Everything below is documented in `.env.example` too — this is the reasoning behind it.

- **`APP_HOST`.** Without it, password-reset and teammate-invite emails link to `https://example.com/...` instead of your actual domain — nothing else surfaces that, and it fails silently rather than refusing to boot (an operator who hasn't wired up SMTP yet, and only uses the console-based reset in [SECURITY.md](../../SECURITY.md), shouldn't have their whole app refuse to boot over a mailer setting they aren't using — but the app logs a warning on every boot until this is set, so the gap can't stay quiet indefinitely).
- **Credentials — see the dedicated section below.** Not optional; every deployment needs a `secret_key_base` from somewhere.

### Credentials

`secret_key_base` (the base secret behind every signed cookie/session) has to come from somewhere, and Rails gives a few ways to supply it. Which one to use depends on how you redeploy:

**`SECRET_KEY_BASE` (recommended if you redeploy by pulling this repo directly** — a plain random value, generated once and kept only in your untracked `.env`:

```sh
bin/rails secret   # prints a value; put it in .env as SECRET_KEY_BASE
```

This is the actual fix for a real incident: an earlier commit to this project regenerated `config/credentials.yml.enc` for public-template purposes and broke the maintainer's own running production deployment, because at the time `secret_key_base` had nowhere to live except that one shared, git-tracked file. With `SECRET_KEY_BASE` set, a future `git pull` bringing in an updated/regenerated `config/credentials.yml.enc` can't touch a deployment that no longer depends on it for this value.

**One gotcha that isn't obvious:** `SECRET_KEY_BASE` only replaces *one* of two things Rails reads credentials for. Active Record Encryption's own configuration is read from `Rails.application.credentials` independently, at boot, regardless of whether `SECRET_KEY_BASE` is set — and a **present but mismatched** `config/master.key` (or `RAILS_MASTER_KEY` env var) still crashes boot right there, even though this app doesn't use Active Record Encryption at all. A **missing** key is fine (Rails skips the check silently) — it's specifically a *stale, wrong* key file left over from before that's the problem. So: if you're using `SECRET_KEY_BASE`, don't also leave a `config/master.key` file around unless you're sure it's currently correct — simplest is to just not have one.

**`RAILS_MASTER_KEY` / per-environment credentials (alternative, if you want other secrets — SMTP credentials, etc. — managed the traditional Rails way):**

- The simple version decrypts the repo's shared `config/credentials.yml.enc` — fine for a one-off deployment, but this is the same shared file the public template itself uses, so it's not independent of a future `git pull` the way `SECRET_KEY_BASE` is.
- **For a deployment that needs to stay independent of the shared default (a redeploy-via-`git pull` setup, same as this maintainer's own VPS), use Rails' own per-environment credentials instead:**
  ```sh
  RAILS_ENV=production bin/rails credentials:edit --environment production
  ```
  This creates `config/credentials/production.yml.enc` + `config/credentials/production.key` — both gitignored (the whole `config/credentials/` directory is), so neither is ever touched by `git pull`, and Rails automatically prefers this pair over the shared default whenever it exists. **Don't also set a `RAILS_MASTER_KEY` env var if you go this route** — it overrides file-based key resolution unconditionally, for whichever encrypted file Rails loads, and a value meant for the shared default file will silently fail to decrypt the per-environment one.

### Infrastructure-specific overrides

`docker-compose.yml` is the generic public template — self-contained, no assumptions about your infrastructure beyond a filled-in `.env`. If you're running this behind an existing reverse-proxy setup that needs a fixed container name, an existing Docker network, or anything else specific to your environment, **don't edit `docker-compose.yml` for it** — a future `git pull` would silently drop your changes the same way the `SECRET_KEY_BASE` incident above happened to the credentials file.

Instead:

```sh
cp docker-compose.override.yml.example docker-compose.override.yml
# edit docker-compose.override.yml with your actual values
docker compose up -d    # merges docker-compose.override.yml in automatically — no -f flags needed
```

`docker-compose.override.yml` is gitignored — `git pull` never touches it, so `docker-compose.yml` stays free to evolve for OSS-template purposes without risk to a deployment that depends on infrastructure specifics living in the override file instead.

### A reverse proxy is expected, not optional

The container has no TLS of its own and, by default, binds only to `127.0.0.1` on the host — not reachable from outside that machine until something fronts it. Put a reverse proxy in front for real use: nginx, Caddy, Traefik, or a tunnel-based option (Cloudflare Tunnel, Tailscale Serve) that needs no inbound port at all. The general shape, regardless of which you pick:

1. The proxy terminates TLS and forwards to the container's published port (`127.0.0.1:3000` by default).
2. Set `APP_PROTOCOL=https` (already the default) so generated links match.
3. If your proxy already authenticates requests (Cloudflare Access, an `nginx auth_request` setup, ...), it can hand the authenticated identity straight to the app instead of showing a password form — see `TRUSTED_HEADER_AUTH_HEADER` in `.env.example` and the warning comment on `app/models/trusted_header_login.rb` before enabling it: this is only safe if the proxy is configured to strip that header from inbound requests and set it itself, or a request could just claim to be anyone.

This repo doesn't ship a specific proxy config — every self-hoster's setup (bare-metal nginx, a Docker Compose stack with its own proxy service, a managed tunnel) is different enough that a single example would be more misleading than helpful.

## Redeploying

```sh
docker compose build
docker compose down && docker compose up -d
```

`bin/docker-entrypoint` runs `./bin/rails db:prepare` on boot: creates the database if missing, runs pending migrations, and — **only when the database was just created** — loads `db/seeds.rb` (a locale-aware welcome/tutorial notebook, not demo business data). A normal redeploy against an existing `storage/production.sqlite3` just migrates; it doesn't reseed.

## Backups

See [backup.md](backup.md) — `bin/backup`/`bin/restore`, tested end to end against real data including uploaded images, not just documented from reading the SQLite docs.

## Trusted-header auth notes

A few behaviors worth knowing if you enable `TRUSTED_HEADER_AUTH_HEADER` (Cloudflare Access or similar):

- **Solo vs. team is a Setup-time choice, not just an env var.** Choosing "Just me" pins every future request to the one account created at Setup (`users.trusted_header_owner`), regardless of which verified identity the header reports later — see `TrustedHeaderLogin#call`. Choosing "My team" instead auto-provisions one account per distinct verified identity, with no identity-linking across two logins for the same person.
- **A team deployment gated by Cloudflare Access (or similar) has no in-app admin UI**, by design — the proxy is already the access-control layer. Removing someone who's left is a console command (`User.find_by(email_address: "...").destroy`), the same escape-hatch pattern used for solo→team upgrades and password resets elsewhere in this app (see [SECURITY.md](../../SECURITY.md)).
- **This app's own session cookie keeps working on its own once issued**, independent of what your proxy's access policy says right now — removing someone from Cloudflare Access (or equivalent) blocks any *new* session at the edge, but doesn't retroactively invalidate one already issued unless the origin is genuinely unreachable except through the proxy (a tunnel, or an IP allowlist restricted to it). To invalidate an existing session explicitly: `User.find_by(email_address: "...").sessions.destroy_all`.
