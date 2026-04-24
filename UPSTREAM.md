# Upstream tracking — cyberdriver-server

This fork tracks [rustdesk/rustdesk-server](https://github.com/rustdesk/rustdesk-server).
The upstream remote is wired as `upstream`:

```
origin    https://github.com/cyberdesk-hq/cyberdriver-server.git
upstream  https://github.com/rustdesk/rustdesk-server.git
```

## Cadence

Rebase `master` onto `upstream/master` monthly (lower cadence than
cyberdriver-new because rustdesk-server moves slower). Owner: TBD.

## Conflict zones

- `Cargo.toml` — only if we add new dependencies (`lru`, `governor` in
  M10).
- `src/lib.rs` — only the `pub mod cyberdesk;` declaration (added in
  M10).
- `src/main.rs` — only the `tokio::spawn(cyberdesk::refresh_jwks_loop(...))`
  call (added in M10).
- `src/rendezvous_server.rs` — only the `cyberdesk::authorize_punch(&ph).await?`
  calls in the two `PunchHoleRequest` arms (TCP and UDP, both added in
  M10). Upstream changes to surrounding match arms may cause merge
  conflicts; the resolution is mechanical (re-apply `authorize_punch`
  call at the start of each arm).
- `Dockerfile` and `docker-classic/Dockerfile` — adapted in M2 for Fly.

## Rebase procedure

```bash
git fetch upstream
git checkout master
git rebase upstream/master
# Resolve in conflict zones above.
git push --force-with-lease origin master
```

## CI gate

`.github/workflows/upstream-rebase.yml` (added in M12) runs the same
dry-run check as cyberdriver-new.
