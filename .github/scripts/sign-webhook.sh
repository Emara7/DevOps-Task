#!/usr/bin/env bash
set -euo pipefail

# Computes GitHub webhook X-Hub-Signature (sha1) header value for a payload.
# Usage: echo -n "$payload" | ./sign-webhook.sh "$secret"

secret="${1?secret required}"
payload=$(cat)

sig=$(printf '%s' "$payload" | openssl dgst -sha1 -hmac "$secret" | awk '{print $2}')
echo "sha1=${sig}"
