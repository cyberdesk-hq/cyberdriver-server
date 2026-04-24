# AGPL Compliance — cyberdriver-server (hbbs / hbbr fork)

This document explains how the Cyberdriver fork of `rustdesk-server`
satisfies its GNU Affero General Public License v3.0 (AGPLv3) obligations.
It mirrors the policy in
[cyberdriver-new/AGPL_COMPLIANCE.md](https://github.com/cyberdesk-hq/cyberdriver-new/blob/master/AGPL_COMPLIANCE.md).

## License inheritance

This repository is a fork of [rustdesk-server](https://github.com/rustdesk/rustdesk-server),
licensed under AGPL-3.0. All our modifications (the JWT validator
module, Fly deployment configs, branding) inherit AGPL-3.0. Full text in
[LICENSE](LICENSE).

## Section 13 obligation (network interaction)

Every Cyberdriver client that connects to our hbbs is a "user
interacting with the Program remotely through a computer network" under
AGPLv3 §13. We satisfy the source-offer obligation in two places:

1. **`Server:` HTTP header** on hbbs's web-client port (21118) and
   hbbr's WebSocket port (21119):
   ```
   Server: cyberdriver-hbbs (AGPL source: https://github.com/cyberdesk-hq/cyberdriver-server)
   ```
2. **`--source` / `--license` CLI flag** — `hbbs --source` and
   `hbbr --source` print the source URL and exit 0.

Both are populated from constants in `src/cyberdesk/source_links.rs`
(added in M10), so they stay in sync.

## Section 6 obligation (conveying object code)

We distribute hbbs/hbbr as Docker images on
`ghcr.io/cyberdesk-hq/cyberdriver-server`. The Corresponding Source is
this repository — public, no charge, satisfying §6.b.

## Operator note (self-host vs Cyberdesk-managed)

Anyone running our hbbs/hbbr Docker image is also bound by AGPL §13 and
must offer source. This is automatic for Cyberdesk's own deployment
because the binary already advertises the source link in its HTTP
responses. Self-hosters using our image are also covered transparently
for the same reason.

## Status

- AGPL compliance design: **drafted in this document**.
- Legal sign-off (Cyberdesk leadership / counsel): **Signed by Alan Duong, CTO of Cyberdesk**.
- In-binary source-link wiring: implemented as part of M10
  (`src/cyberdesk/source_links.rs`).
