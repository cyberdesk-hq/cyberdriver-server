# Discoveries — cyberdriver-server

Things found mid-execution that aren't part of the current milestone.
Revisit after each acceptance gate. Do **not** sneak fixes into the
current PR.

| Date (UTC) | Milestone | Discovery | Owner | Action |
|---|---|---|---|---|
| 2026-04-21 | m1-upstream | Submodule and upstream wiring went clean. No surprises so far. | — | None. |
| 2026-04-23 | m2-stress | hbbs crash-loops on Fly with `Main child exited normally with code: 1` ~30s after boot. Cause: upstream `test_hbbs` self-check (src/rendezvous_server.rs:1303) sends UDP to localhost:21116 every 1s expecting hbbs's UDP listener to respond, but our fly-global-services UDP bind isn't reachable on localhost. After 12s `bail!("Timeout of test_hbbs")` triggers `process::exit(1)`. Fix: set `TEST_HBBS=no` env var on both hbbs Fly apps (gate at line 169 skips the test). | — | Fixed in fly.hbbs-{dev,prod}.toml. Worth checking on every upstream rebase that the env-var gate stays in place. |
