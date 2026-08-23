# Security Policy

## Reporting a vulnerability

Please **do not** open a public issue for a security vulnerability.

Instead, use GitHub's [private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing/privately-reporting-a-security-vulnerability) for this repository (the "Security" tab → "Report a vulnerability"). This opens a private advisory visible only to the maintainer until a fix is ready.

## Supported versions

This project is pre-1.0 and evolving quickly. Until a first stable release, only the latest commit on `main` is supported — please make sure you can reproduce the issue there before reporting.

## Authentication

The app requires a login (email or username + password, or auto-provisioning from a trusted reverse-proxy header — see the README) before any note content is reachable. Passkey and OIDC login are planned but not built yet (tracked in [docs/product/roadmap.md](docs/product/roadmap.md) under "Deferred, but not dropped").

There's no email-sending configured by default. In development, sent mail (including password-reset links) is browsable at `/letter_opener` instead of actually going anywhere. In production, the reset-by-email flow needs real SMTP settings supplied via ENV (see `config/environments/production.rb`) — until that's configured, clicking "Forgot password?" silently goes nowhere.

**For a self-hosted, operator-is-the-only-user (or small-team) deployment, resetting a password from the console is simpler and doesn't depend on email deliverability at all** — you already have shell access to the server:

```sh
bin/rails runner 'User.find_by(email_address: "you@example.com").update!(password: "new-password")'
```

This is also the escape hatch if you're locked out of the *only* admin account in a "My team" deployment (see below) and there's no other admin around to issue you a fresh link. It's a console command rather than an in-app "reset anyone's password" button on purpose — that button would be a bigger attack surface than the rare situation it'd rescue you from.

If you do want the email flow working, note that routing it through a personal Gmail account's SMTP tends to be unreliable for this kind of automated/transactional send (app-password requirements, rate limits, spam flagging) — a transactional provider (Postmark, Resend, Amazon SES, Mailgun, ...) is a better fit than `smtp.gmail.com`.

## Admin accounts and invites

A "My team" deployment (see README) has one or more admin accounts (`User#role`) whose only job is inviting/rescuing other accounts and removing ones that shouldn't have access anymore — they hold no notes themselves, so compromising one exposes logins, not note content. An admin login doesn't have to be a real email address (a username works — see README); no format beyond presence/uniqueness is enforced on it.

Invite and rescue links are signed and time-limited (`has_secure_password`'s built-in `password_reset_token`, not a custom scheme — 24 hours here rather than the 15-minute default, since a link handed over in chat may sit unread a while). They're single-use *in effect*, not by explicit revocation: setting a password changes `password_salt`, which invalidates every outstanding token for that account, but a token that was issued and never used stays valid until it expires or that happens — generating a newer link doesn't retroactively kill an older one. **If a link leaks before it's used**, the fix is the same console command as any other lockout: setting a fresh random password invalidates every token issued so far for that account.

```sh
bin/rails runner 'User.find_by(email_address: "someone@example.com").update!(password: SecureRandom.base58(32))'
```

An admin never sees or chooses another account's password at any point in this flow — including the rescue path.

A solo ("Just me") deployment has no admin account and no invite/reset-link UI anywhere in the app. Promoting that account to admin later — to start adding teammates — is a deliberate console action, not an in-app toggle:

```sh
bin/rails runner 'User.find_by(email_address: "you@example.com").update!(role: :admin)'
```

There's no TOTP/2FA yet (tracked in [docs/product/roadmap.md](docs/product/roadmap.md) under "Deferred, but not dropped") — it wasn't skipped by oversight, it answers a different question (a second factor on top of a password you already know) than what this phase solves. Revisit if this ever opens up SaaS-style to people outside a trusted team.

## Trusted-header auth (Cloudflare Access, etc.) and admin accounts

**Accounts auto-provisioned from `TRUSTED_HEADER_AUTH_HEADER` are always `member`, never `admin`** — the proxy vouches for identity, not for a role in this app. This has a real consequence worth planning around, not just a detail:

- If the header is already active on the very first request this instance ever receives, that first visitor gets auto-provisioned as a member and Setup (the only path to creating an admin) becomes unreachable from then on — `request_authentication` only offers Setup when no session could be resumed at all, and a request carrying the trusted header always resumes one. There is then no admin account, ever, unless you deliberately create one from the console (`user.update!(role: :admin)`, per above).
- **That's not a bug to route around — for most trusted-header deployments it's correct.** If Cloudflare Access is gating the whole app for one person, no admin is needed. If it's gating the whole app for a team, membership is Cloudflare Access's own policy to manage (add/remove people in its dashboard) — this app's password/invite/admin system exists for the *standalone, no-reverse-proxy* case, and mostly sits unused once trusted-header auth is the actual gate.
- Want an in-app admin (e.g., the "Remove" button as a second lever, independent of Cloudflare) **on top of** trusted-header auth? Run Setup's "My team" path once, with `TRUSTED_HEADER_AUTH_HEADER` still unset, *before* turning the header on. Doing it in the other order locks you out of ever creating one through the UI.
- **"Remove" a teammate via Cloudflare Access's own dashboard, not this app's, if that's your source of truth for membership.** That fully works only if the origin server is unreachable except through Cloudflare (a Cloudflare Tunnel or an IP allowlist restricted to Cloudflare's network is the standard way to guarantee this) — this app doesn't and can't verify that for you, it's a deployment-level requirement.
- One consequence of that: this app's own session cookie (`.permanent`, checked *before* the trusted header on every request — see `Authentication#resume_session`) keeps working on its own once issued, independent of what Cloudflare Access's policy says *right now*. Removing someone from Cloudflare Access stops any *new* session from being created for them and blocks the request at the edge entirely (as long as the origin truly isn't reachable directly) — but if you want that person's *existing* session invalidated immediately rather than relying on that, do it explicitly:

  ```sh
  bin/rails runner 'User.find_by(email_address: "someone@example.com").sessions.destroy_all'
  ```

## Self-hosting note

This app is designed to be self-hosted. Since you control your own deployment, you're also responsible for its operational security: keeping the container/host updated, keeping backups, and the access control described above. Vulnerability reports about the application code itself are welcome; reports about a specific self-hosted deployment's configuration are best directed at whoever operates that deployment.
