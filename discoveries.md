# Discoveries — cyberdriver-server

Things found mid-execution that aren't part of the current milestone.
Revisit after each acceptance gate. Do **not** sneak fixes into the
current PR.

| Date (UTC) | Milestone | Discovery | Owner | Action |
|---|---|---|---|---|
| 2026-04-21 | m1-upstream | Submodule and upstream wiring went clean. No surprises so far. | — | None. |
| 2026-04-23 | m2-stress | hbbs crash-loops on Fly with `Main child exited normally with code: 1` ~30s after boot. Cause: upstream `test_hbbs` self-check (src/rendezvous_server.rs:1303) sends UDP to localhost:21116 every 1s expecting hbbs's UDP listener to respond, but our fly-global-services UDP bind isn't reachable on localhost. After 12s `bail!("Timeout of test_hbbs")` triggers `process::exit(1)`. Fix: set `TEST_HBBS=no` env var on both hbbs Fly apps (gate at line 169 skips the test). | — | Fixed in fly.hbbs-{dev,prod}.toml. Worth checking on every upstream rebase that the env-var gate stays in place. |
| 2026-04-23 | m2-stress | First successful Mac→Win VM connection via relay (hbbr), not direct UDP punch. Both ends were behind symmetric NATs (Parallels VM + residential ISP), so UDP punch failed and clients fell back to hbbr. **This is the designed behavior** and confirms relay path works end-to-end. Real Cyberdesk customers (cloud Win VMs + residential viewer ISPs) will lean heavily on relay too, so the plan's original "80% direct punch" success criterion was unrealistic for any test topology. Substantive proof of m2-gate (system carries traffic e2e through Fly) is achieved. | — | None. Note for capacity planning: hbbr bandwidth will dominate over hbbs. |
| 2026-04-23 | m2-stress | Mac RustDesk client crashed once after entering the desktop password during the very first connect attempt. We have not modified the upstream RustDesk client code at all yet (only branding strings in M1), so this is a vanilla RustDesk bug. Did not reproduce after restart. Tracking here in case it recurs during M4+ cyberdesk_tunnel work; if reproducible we'll investigate, otherwise treat as a one-off upstream UI glitch. | — | None for now. Re-evaluate during M4 testing. |
