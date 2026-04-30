#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${GRABKIT_URL:-http://localhost:9777}"
TOKEN="${GRABKIT_TOKEN:-}"
CMD="${1:-health}"
shift || true

curl_headers=()
if [[ -n "$TOKEN" ]]; then
  curl_headers=(-H "Authorization: Bearer $TOKEN")
fi

case "$CMD" in
  health)
    curl -s "$BASE_URL/grab/health" | jq .
    ;;
  tree)
    curl -s "${curl_headers[@]}" "$BASE_URL/grab/tree" | jq .
    ;;
  mode)
    ENABLED="${1:-true}"
    curl -s -X POST "${curl_headers[@]}" "$BASE_URL/grab/mode" \
      -H 'Content-Type: application/json' \
      -d "{\"enabled\":$ENABLED}" | jq .
    ;;
  select-id)
    ID="${1:?usage: grabctl.sh select-id <id>}"
    curl -s -X POST "${curl_headers[@]}" "$BASE_URL/grab/select-id" \
      -H 'Content-Type: application/json' \
      -d "{\"id\":\"$ID\"}" | jq .
    ;;
  select-point)
    X="${1:?usage: grabctl.sh select-point <x> <y>}"
    Y="${2:?usage: grabctl.sh select-point <x> <y>}"
    curl -s -X POST "${curl_headers[@]}" "$BASE_URL/grab/select-point" \
      -H 'Content-Type: application/json' \
      -d "{\"x\":$X,\"y\":$Y}" | jq .
    ;;
  stop)
    curl -s -X POST "${curl_headers[@]}" "$BASE_URL/grab/stop" | jq .
    ;;
  *)
    echo "usage: grabctl.sh [health|tree|mode true|false|select-id <id>|select-point <x> <y>|stop]" >&2
    exit 2
    ;;
esac
