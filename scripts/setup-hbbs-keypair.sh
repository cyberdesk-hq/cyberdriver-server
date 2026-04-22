#!/usr/bin/env bash
# setup-hbbs-keypair.sh — generate an Ed25519 keypair for hbbs and store
# it as Fly secrets so volume loss can never permanently break clients
# that trust the existing public key.
#
# Usage:
#   scripts/setup-hbbs-keypair.sh prod
#   scripts/setup-hbbs-keypair.sh dev
#
# What this does:
#   1. Builds rustdesk-utils locally (requires Rust toolchain).
#   2. Runs `rustdesk-utils genkeypair`, captures Public Key + Secret Key.
#   3. Sets HBBS_KEY_PRIV and HBBS_KEY_PUB Fly secrets on the matching
#      hbbs app (cyberdriver-server-hbbs-iad-{prod,dev}).
#   4. Prints the public key so you can paste it into
#      cyberdriver-new/branding/hbbs_pubkey.txt and
#      cyberdriver-new/src/cyberdesk_branding.rs::HBBS_PUBKEY.
#
# Why this lives in the cyberdriver-server repo:
#   The keypair is tied to the hbbs app — it lives in the server's
#   `id_ed25519` file at runtime. Generating it here keeps the
#   blast-radius of "where does this secret come from" obvious.
set -euo pipefail

ENV="${1:-}"
case "$ENV" in
  prod)
    APP="cyberdriver-server-hbbs-iad-prod"
    ;;
  dev)
    APP="cyberdriver-server-hbbs-iad-dev"
    ;;
  *)
    echo "Usage: $0 prod|dev" >&2
    exit 1
    ;;
esac

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

if ! command -v cargo >/dev/null; then
  if [ -x "$HOME/.cargo/bin/cargo" ]; then
    export PATH="$HOME/.cargo/bin:$PATH"
  else
    echo "ERROR: cargo not found. Install Rust toolchain (https://rustup.rs)." >&2
    exit 1
  fi
fi

if ! command -v flyctl >/dev/null; then
  echo "ERROR: flyctl not found. Install: https://fly.io/docs/flyctl/install/" >&2
  exit 1
fi

# --- 1. Build rustdesk-utils ---
echo "[setup-hbbs-keypair] Building rustdesk-utils (target/release/rustdesk-utils)..."
cargo build --release --bin rustdesk-utils >/dev/null

# --- 2. Generate keypair ---
echo "[setup-hbbs-keypair] Generating Ed25519 keypair for $ENV..."
KEYPAIR_OUTPUT=$(./target/release/rustdesk-utils genkeypair)
PUBLIC_KEY=$(echo "$KEYPAIR_OUTPUT" | grep '^Public Key:' | sed 's/^Public Key:[[:space:]]*//')
SECRET_KEY=$(echo "$KEYPAIR_OUTPUT" | grep '^Secret Key:' | sed 's/^Secret Key:[[:space:]]*//')

if [ -z "$PUBLIC_KEY" ] || [ -z "$SECRET_KEY" ]; then
  echo "ERROR: failed to parse rustdesk-utils genkeypair output:" >&2
  echo "$KEYPAIR_OUTPUT" >&2
  exit 1
fi

# --- 3. Set Fly secrets ---
echo "[setup-hbbs-keypair] Setting Fly secrets on $APP..."
flyctl secrets set --app "$APP" \
  HBBS_KEY_PRIV="$SECRET_KEY" \
  HBBS_KEY_PUB="$PUBLIC_KEY"

# --- 4. Print public key for client BUILTIN_SETTINGS ---
echo
echo "==============================================================="
echo "  $ENV hbbs keypair created and stored as Fly secrets on $APP"
echo "==============================================================="
echo
echo "Public Key (paste into cyberdriver-new/src/cyberdesk_branding.rs"
echo "                   pub const HBBS_PUBKEY: &str = ...):"
echo
echo "    $PUBLIC_KEY"
echo
echo "Also update cyberdriver-new/branding/hbbs_pubkey.txt for $ENV"
echo "(replace the PLACEHOLDER line)."
echo
echo "The matching SECRET KEY is now stored as the HBBS_KEY_PRIV Fly"
echo "secret on $APP and is never logged or written to disk locally."
echo "Re-run this script if you need to rotate the keypair."
