#!/bin/sh
# Cyberdriver-server entrypoint — picks hbbs vs hbbr based on the
# CYBERDRIVER_ROLE env var, restores the hbbs Ed25519 keypair from
# Fly secrets if not present on the volume.
#
# Env vars consumed:
#   CYBERDRIVER_ROLE   "hbbs" | "hbbr"  (required)
#   HBBR_ADDR          "<host>:<port>"  (hbbs only, builds hbbs's -r flag)
#   HBBS_KEY_PRIV      base64-encoded id_ed25519 private key (hbbs only)
#   HBBS_KEY_PUB       base64-encoded id_ed25519 public key  (hbbs only)
#
# Any extra args passed to the container are forwarded to the binary.
set -e

ROLE="${CYBERDRIVER_ROLE:-}"

if [ -z "$ROLE" ]; then
  echo "[entrypoint] ERROR: CYBERDRIVER_ROLE env var must be set to 'hbbs' or 'hbbr'." >&2
  exit 1
fi

case "$ROLE" in
  hbbs)
    # Restore Ed25519 keypair from Fly secrets if the volume came up empty.
    # See cyberdriver-new/AGPL_COMPLIANCE.md and the M2 plan for the
    # rationale (volume loss must NOT invalidate every deployed
    # Cyberdriver client trusting our hbbs).
    #
    # File format: hbbs (src/common.rs:gen_sk) writes the keypair as
    # base64-encoded TEXT into id_ed25519 / id_ed25519.pub. The
    # `rustdesk-utils genkeypair` output (Public Key / Secret Key
    # base64 strings) is exactly the string to drop in. The Fly secret
    # value contains that base64 text directly; we write it verbatim.
    # Same pattern as upstream's docker/rootfs/etc/s6-overlay key-secret
    # script (`echo -n "$KEY_PRIV" > /data/id_ed25519`).
    if [ ! -f /root/id_ed25519 ] && [ -n "$HBBS_KEY_PRIV" ]; then
      echo "[entrypoint] /root/id_ed25519 missing; restoring from HBBS_KEY_PRIV secret"
      umask 077
      printf '%s' "$HBBS_KEY_PRIV" > /root/id_ed25519
      if [ -n "$HBBS_KEY_PUB" ]; then
        printf '%s' "$HBBS_KEY_PUB" > /root/id_ed25519.pub
      fi
      umask 022
    elif [ -f /root/id_ed25519 ]; then
      echo "[entrypoint] /root/id_ed25519 present on volume; not touching."
    else
      echo "[entrypoint] WARNING: /root/id_ed25519 missing AND no HBBS_KEY_PRIV secret. hbbs will generate a fresh keypair on first start." >&2
    fi

    # Build hbbs args from env.
    set -- "$@"
    if [ -n "$HBBR_ADDR" ]; then
      set -- -r "$HBBR_ADDR" "$@"
    fi
    echo "[entrypoint] starting hbbs $*"
    exec /usr/local/bin/hbbs "$@"
    ;;

  hbbr)
    echo "[entrypoint] starting hbbr $*"
    exec /usr/local/bin/hbbr "$@"
    ;;

  *)
    echo "[entrypoint] ERROR: CYBERDRIVER_ROLE must be 'hbbs' or 'hbbr', got: $ROLE" >&2
    exit 1
    ;;
esac
