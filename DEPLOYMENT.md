# Deployment runbook — cyberdriver-server on Fly.io

Status of M2 setup. Done items don't need re-running unless something
breaks.

## Apps (DONE)

Created in the `cyberdesk` Fly org, region `iad`:

| App | IPv4 | Volume |
|---|---|---|
| `cyberdriver-server-hbbs-iad-prod` | `213.188.205.7` | `hbbs_data_prod` (1 GB, scheduled snapshots) |
| `cyberdriver-server-hbbr-iad-prod` | `213.188.205.65` | (none — relay is stateless) |
| `cyberdriver-server-hbbs-iad-dev` | `213.188.205.73` | `hbbs_data_dev` (1 GB, scheduled snapshots) |
| `cyberdriver-server-hbbr-iad-dev` | `213.188.205.44` | (none) |

Cost: 4 × $2/mo = $8/mo for dedicated IPv4. Machines start at ~$2-4/mo
each on `shared-cpu-1x / 512mb` (the size in the fly.toml files);
total ops cost roughly $20/mo for both envs.

## hbbs Ed25519 keypairs (DONE)

Generated locally via `scripts/setup-hbbs-keypair.sh`, set as Fly
secrets `HBBS_KEY_PRIV` and `HBBS_KEY_PUB` on each hbbs app. The
`fly-entrypoint.sh` materializes them to `/root/id_ed25519` on
container start if the volume comes up empty (catastrophic loss
recovery). Public keys baked into
`cyberdriver-new/src/cyberdesk_branding.rs::HBBS_PUBKEY`:

| Env | hbbs public key (base64) |
|---|---|
| prod | `zhJ/30tgM6fCP+cJro8DjPN2WnswhMiowPkehilsMYc=` |
| dev  | `EHHHwBfzjJasItIOwAJAI60Jj64uJu4rpI1cdE4ulhI=` |

To rotate: re-run `./scripts/setup-hbbs-keypair.sh {prod,dev}`. You'll
need to push a new cyberdriver-new build with the new public key
afterwards (existing clients will reject the new hbbs until they
upgrade).

## What's left for you to do before the M2 acceptance gate

### 1. Cloudflare DNS records (4 A records)

Add these in your `cyberdesk.io` zone, all with **proxy mode OFF (gray
cloud)** — Cloudflare's proxy doesn't pass through the custom UDP/TCP
ports we need.

| Subdomain | Type | Value |
|---|---|---|
| `hbbs` | A | `213.188.205.7` |
| `hbbr` | A | `213.188.205.65` |
| `hbbs-dev` | A | `213.188.205.73` |
| `hbbr-dev` | A | `213.188.205.44` |

Optional but nice: also add AAAA records for IPv6 — run `flyctl ips
allocate-v6 --app <each app>` (free; allocates a shared IPv6) and add
the AAAA records pointing at the `2a09:8280:1::...` addresses Fly
prints.

### 2. GitHub Action secret

In `cyberdesk-hq/cyberdriver-server` → Settings → Secrets and variables
→ Actions, add:

- `FLY_API_TOKEN` = output of `flyctl tokens create deploy --org cyberdesk`

This lets the workflow `flyctl deploy` against the org's apps.

### 3. First deploy (dev)

Trigger by pushing to the `dev` branch:

```bash
cd /Users/alanduong/Documents/Code/Projects/cyberdriver-server
git checkout -b dev
git add -A
git commit -m "M2: dev/prod fly setup, dockerfile, deploy workflow"
git push -u origin dev
```

The workflow `.github/workflows/release.yml` will:

1. Build `Dockerfile.fly` on GitHub-hosted Ubuntu (~3 min cold).
2. Push image to `ghcr.io/cyberdesk-hq/cyberdriver-server:dev-<sha>`.
3. `flyctl deploy --config fly.hbbs-dev.toml --image <tag>`.
4. `flyctl deploy --config fly.hbbr-dev.toml --image <tag>`.

Watch progress at <https://github.com/cyberdesk-hq/cyberdriver-server/actions>.

After deploy succeeds (~5 min total):

```bash
flyctl status --app cyberdriver-server-hbbs-iad-dev
flyctl status --app cyberdriver-server-hbbr-iad-dev

flyctl logs --app cyberdriver-server-hbbs-iad-dev | head -50
# Expect to see:
#   [entrypoint] /root/id_ed25519 missing; restoring from HBBS_KEY_PRIV secret
#   listen on udp ... (fly-global-services)
#   ID server listening on ...
```

Sanity check from your Mac (TCP signaling responds):

```bash
nc -zv hbbs-dev.cyberdesk.io 21115   # should connect immediately
nc -zv hbbs-dev.cyberdesk.io 21116
nc -zv hbbr-dev.cyberdesk.io 21117
```

### 4. Promote to prod

If dev looks healthy:

```bash
git checkout -b main
git merge dev
git push -u origin main
```

Same workflow re-runs, this time deploying to the prod apps. Same
sanity checks against `hbbs.cyberdesk.io` and `hbbr.cyberdesk.io`.

### 5. M2 acceptance gate (`m2-stress`)

With both envs deployed and DNS resolving, do the connect-and-control
test through Fly:

1. On a Win11 VM: install vanilla RustDesk MSI (or your existing one
   from M0).
2. In RustDesk → Network settings:
   - ID Server: `hbbs-dev.cyberdesk.io`
   - Relay Server: `hbbr-dev.cyberdesk.io`
   - Key: `EHHHwBfzjJasItIOwAJAI60Jj64uJu4rpI1cdE4ulhI=`
3. On your Mac: same RustDesk + same Network settings.
4. Connect Mac → VM. Verify desktop visible + controllable.
5. Disconnect, reconnect 10 times. Note any UDP punch failures (they
   manifest as "connecting via relay" badges or 5s+ first-frame
   latency).
6. Repeat steps 2-5 against prod (`hbbs.cyberdesk.io` /
   `hbbr.cyberdesk.io` / `zhJ/30tgM6fCP+cJro8DjPN2WnswhMiowPkehilsMYc=`).

If both envs work and UDP punch reliability is acceptable (>80%
success on first try), M2 closes. We discuss `ALWAYS_USE_RELAY` mode
or pivot conversation if not.

## Known caveats

- **First deploy will pull a fresh image (~5 min)**; subsequent deploys
  layer-cache via GHCR + GitHub Actions cache (~1-2 min).
- **Cloudflare proxy must be OFF** for these subdomains. The proxy
  terminates custom-port traffic and breaks UDP entirely.
- **UDP behavior on Fly is region-pinned**; we're in `iad` only. If
  Cyberdriver agents are mostly in EU or APAC, `m2-stress` may show
  high punch-failure rates and we should add an `lhr` or `nrt` region.
- **Volume snapshot retention is 5 by default** (Fly's auto-snapshot).
  That's fine; the keypair restore from Fly secrets is the real
  durability story for the only critical data.
