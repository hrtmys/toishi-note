---
title: Backup and restore
description: How to back up storage/ and actually get your data back — tested, not just documented
status: living
updated: 2026-08-16
---

# Backup and restore

Everything this app can't recreate lives under `storage/`: the primary SQLite database (notebooks, folders, notes, users, sessions), three more SQLite databases for Solid Cache/Queue/Cable, and every uploaded image (Active Storage's local disk service is also rooted there — see `config/storage.yml`). `docker-compose.yml` bind-mounts this one directory into the container for exactly this reason — back it up, and you have everything.

## Why not just `cp`

A plain `cp` of a live SQLite file can copy it mid-write, or miss data still sitting in the write-ahead log that hasn't been checkpointed back into the main file yet — silent, and you won't find out until the day you actually need the backup. `sqlite3 <file> ".backup '<dest>'"` is SQLite's own online-backup API, built specifically to produce a consistent snapshot safely even while the source is being written to concurrently.

## `bin/backup` / `bin/restore`

```sh
bin/backup [DEST_DIR]        # default: ./backups
bin/restore BACKUP_DIR       # BACKUP_DIR is one timestamped snapshot bin/backup made
```

`bin/backup` takes a `.backup` snapshot of all four SQLite databases (verifying each with `PRAGMA integrity_check` before considering it done — it fails loudly rather than silently shipping a corrupt backup), then copies every uploaded file alongside them. Safe to run against a live, currently-serving instance.

`bin/restore` verifies the snapshot's integrity again before touching anything, asks for confirmation, then copies everything back into `storage/` — clearing any stale write-ahead-log files left over from before the restore, so an old, possibly-conflicting WAL can't replay itself back on top of the restored data. **Stop the app first** (`docker compose stop`) — restoring into a `storage/` directory Puma/Solid Queue still hold open defeats the same consistency guarantee `.backup` exists to provide on the way in.

Both scripts run inside the container or on the host — anywhere `storage/` and `sqlite3`/`rsync` are reachable:

```sh
docker exec toishi-note_app bin/backup /rails/backups
# or, from the host, against the bind-mounted directory directly:
./bin/backup ./backups
```

## Automating it

A daily cron entry plus offsite sync (rclone to Backblaze B2, S3, a second machine, anywhere not on the same disk as `storage/`) is the standard shape:

```cron
0 3 * * * cd /path/to/toishi-note && ./bin/backup ./backups && rclone sync ./backups remote:toishi-note-backups --min-age 1h
```

`--min-age 1h` skips syncing a backup that's still being written by a concurrently-running `bin/backup` — harmless belt-and-suspenders given `bin/backup` already writes into a fresh timestamped directory per run. A 7-day rolling window (`find ./backups -maxdepth 1 -mtime +7 -exec rm -rf {} +` after a successful sync) keeps local disk use bounded; keep more than 7 days offsite if you want deeper history.

## This procedure is tested, not just written down

Every claim above was verified directly against a real instance before being documented, not assumed from reading the SQLite docs:

1. Booted a fresh production-mode instance (`db:prepare` against an empty `storage/`).
2. Created a real user, notebook, folder, and note — including an actual attached image (a real file on disk under `storage/`, not just a database row).
3. Ran `bin/backup` against the live data; it verified all four databases' integrity and copied the image file.
4. Simulated total data loss: deleted `storage/` entirely.
5. Ran `bin/restore` against the backup.
6. Verified — via a real query against the restored database, and a real download of the restored image blob — that the user, the note, its exact content, and the attached image all came back byte-for-byte.

If you change how `storage/` is laid out (a new Solid-* database, switching Active Storage off local disk, etc.), re-run this same drill before trusting the result — a backup procedure that was correct once isn't guaranteed to still be correct after the thing it backs up changes shape.
