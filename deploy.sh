#!/bin/bash
# deploy.sh — Encrypt and deploy proposals to prop.doceprojects.com
# Usage: ./deploy.sh <client-slug> <source-html> [password]
#
# Examples:
#   ./deploy.sh construhigienicas ../doceprojects/proposal-construhigienicas.html
#   ./deploy.sh casa-ardente /path/to/proposal.html doce-casa-ardente
#
# Password defaults to: doce-<client-slug>
# All proposals use shared salt from .staticrypt.json

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# --- Args ---
CLIENT="${1:-}"
SOURCE="${2:-}"
PASSWORD="${3:-}"

if [[ -z "$CLIENT" || -z "$SOURCE" ]]; then
  echo "Usage: ./deploy.sh <client-slug> <source-html> [password]"
  echo ""
  echo "  client-slug   Directory name (e.g. construhigienicas, casa-ardente, eqr)"
  echo "  source-html   Path to the unencrypted proposal HTML"
  echo "  password      Optional. Defaults to doce-<client-slug>"
  echo ""
  echo "Deployed proposals:"
  for dir in */; do
    [[ -f "${dir}index.html" ]] && echo "  - ${dir%/}"
  done
  exit 1
fi

if [[ ! -f "$SOURCE" ]]; then
  echo "Error: Source file not found: $SOURCE"
  exit 1
fi

# Default password pattern
if [[ -z "$PASSWORD" ]]; then
  PASSWORD="doce-${CLIENT}"
fi

# --- Check staticrypt ---
if ! command -v staticrypt &>/dev/null; then
  echo "Error: staticrypt not found. Install with: npm install -g staticrypt"
  exit 1
fi

# --- Encrypt ---
echo "Encrypting proposal for ${CLIENT}..."
mkdir -p "$CLIENT"
staticrypt "$SOURCE" \
  -p "$PASSWORD" \
  --remember 0 \
  -d "$CLIENT" \
  --config .staticrypt.json \
  --short

# Rename to index.html (staticrypt keeps original filename)
ENCRYPTED_FILE="$CLIENT/$(basename "$SOURCE")"
if [[ -f "$ENCRYPTED_FILE" && "$ENCRYPTED_FILE" != "$CLIENT/index.html" ]]; then
  mv "$ENCRYPTED_FILE" "$CLIENT/index.html"
fi

echo "Encrypted: $CLIENT/index.html"

# --- Git commit & push ---
git add "$CLIENT/index.html" .staticrypt.json
git commit -m "deploy: ${CLIENT} proposal (encrypted)"
git push origin main

echo ""
echo "Deployed: https://prop.doceprojects.com/${CLIENT}/"
echo "Password: ${PASSWORD}"
