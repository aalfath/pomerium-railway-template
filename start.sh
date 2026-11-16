#!/bin/bash
# Renders Pomerium's config.yaml from environment variables, then starts Pomerium.
# Railway's edge terminates TLS, so Pomerium serves plain HTTP on $PORT.
set -euo pipefail

DATA_DIR="${POMERIUM_DATA_DIR:-/data}"
CONFIG=/tmp/pomerium-config.yaml
mkdir -p "$DATA_DIR/databroker"
chmod 700 "$DATA_DIR"

fail() { echo "railway-start: $*" >&2; exit 1; }

# Secrets: use the variable if set, else generate once and keep it on the volume.
persist_secret() {
  local f="$DATA_DIR/.$1"
  if [ ! -s "$f" ]; then
    head -c 32 /dev/urandom | base64 -w0 > "$f"
    chmod 600 "$f"
  fi
  cat "$f"
}
export SHARED_SECRET="${SHARED_SECRET:-$(persist_secret shared_secret)}"
export COOKIE_SECRET="${COOKIE_SECRET:-$(persist_secret cookie_secret)}"
if [ -z "${SIGNING_KEY:-}" ]; then
  key="$DATA_DIR/.signing_key.pem"
  if [ ! -s "$key" ]; then
    openssl ecparam -genkey -name prime256v1 -noout -out "$key" 2>/dev/null
    chmod 600 "$key"
  fi
  export SIGNING_KEY="$(base64 -w0 "$key")"
fi

export ADDRESS=":${PORT:-8080}"
export INSECURE_SERVER=true
export AUTOCERT=false
export DATABROKER_STORAGE_TYPE="${DATABROKER_STORAGE_TYPE:-file}"
if [ "$DATABROKER_STORAGE_TYPE" = "file" ]; then
  export DATABROKER_STORAGE_CONNECTION_STRING="${DATABROKER_STORAGE_CONNECTION_STRING:-file://$DATA_DIR/databroker}"
fi

HOST="${POMERIUM_HOST:-${RAILWAY_PUBLIC_DOMAIN:-}}"
HOST="${HOST#https://}"; HOST="${HOST#http://}"; HOST="${HOST%%/*}"
[ -n "$HOST" ] || fail "no public hostname: add a domain to this service or set POMERIUM_HOST"

valid='^[A-Za-z0-9._%+@-]+$'
policy_lines=""
add_rule() { # $1 = email|domain, $2 = comma-separated list
  local item
  IFS=',' read -ra items <<< "$2"
  for item in "${items[@]}"; do
    item="$(echo "$item" | tr -d '[:space:]')"
    [ -z "$item" ] && continue
    [[ "$item" =~ $valid ]] || fail "invalid value in ALLOWED_${1^^}S: $item"
    policy_lines+="            - $1:"$'\n'"                is: \"$item\""$'\n'
  done
}
add_rule email "${ALLOWED_EMAILS:-}"
add_rule domain "${ALLOWED_DOMAINS:-}"
[ -n "$policy_lines" ] || fail "set ALLOWED_EMAILS (or ALLOWED_DOMAINS): with no allow list Pomerium would deny everyone"

if [ -n "${UPSTREAM_URL:-}" ]; then
  [[ "$UPSTREAM_URL" =~ ^https?://[^[:space:]\"]+$ ]] || fail "UPSTREAM_URL must start with http:// or https://"
  target="    to: \"$UPSTREAM_URL\""
else
  target="    response:
      status: 200
      body: \"Pomerium is running and you are signed in. Set UPSTREAM_URL on the Pomerium service to put your app behind it. Your session details: /.pomerium/\""
fi

{
  echo "log_level: ${LOG_LEVEL:-info}"
  echo "routes:"
  echo "  - from: \"https://$HOST\""
  echo "$target"
  echo "    pass_identity_headers: true"
  echo "    allow_websockets: true"
  echo "    preserve_host_header: ${PRESERVE_HOST_HEADER:-false}"
  echo "    policy:"
  echo "      - allow:"
  echo "          or:"
  printf '%s' "$policy_lines"
  if [ -n "${EXTRA_ROUTES:-}" ]; then
    printf '%s\n' "$EXTRA_ROUTES"
  fi
} > "$CONFIG"

echo "railway-start: route https://$HOST -> ${UPSTREAM_URL:-built-in welcome page}; databroker: $DATABROKER_STORAGE_TYPE"
exec /bin/pomerium --config "$CONFIG"
