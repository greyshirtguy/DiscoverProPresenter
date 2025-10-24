#!/usr/bin/env bash
# discover_pros.sh
# Intended to work on Raspbian/Ubuntu (Bash)
# Requires avahi-browse comment that is a part of avahi-utils
set -Eeuo pipefail

# ===== Config =====
SERVICES=("_pro7proremote._tcp" "_proapiv1ws._tcp")
COMPANION_HOST="${COMPANION_HOST:-192.168.1.7}"
COMPANION_PORT="${COMPANION_PORT:-8888}"
START_INDEX="${START_INDEX:-1}"
VAR_PREFIX="${VAR_PREFIX:-DiscoveredPro}"
TIMEOUT_SEC="${TIMEOUT_SEC:-5}"
DEBUG="${DEBUG:-0}"
DRY_RUN="${DRY_RUN:-0}"

command -v avahi-browse >/dev/null || { echo "avahi-browse not found. sudo apt install avahi-utils"; exit 1; }
command -v curl >/dev/null || { echo "curl not found. sudo apt install curl"; exit 1; }

RAW_OUT=""
for svc in "${SERVICES[@]}"; do
  [[ "$DEBUG" == "1" ]] && echo "DEBUG: avahi-browse -rtp \"$svc\" (timeout ~${TIMEOUT_SEC}s)"
  out="$(timeout "${TIMEOUT_SEC}" avahi-browse -rtp "$svc" || true)"
  RAW_OUT+=$'\n'"$out"
done

if [[ "$DEBUG" == "1" ]]; then
  echo "DEBUG: -------- RAW avahi-browse OUTPUT --------"
  printf '%s\n' "$RAW_OUT"
  echo "DEBUG: -------------- END RAW ------------------"
fi

# event;ifindex;protocol;name;type;domain;host;address;port;txt
declare -A seen_key      # dedupe on ip:port
declare -A best_for_host # store best key for each hostname
declare -A host_for_key  # map ip:port back to hostname
declare -a results

while IFS=';' read -r event ifidx proto name type domain host addr port txt || [[ -n "${event:-}" ]]; do
  [[ -z "${event:-}" ]] && continue
  [[ "$event" != "=" ]] && continue
  [[ "$proto" != "IPv4" ]] && continue
  [[ -n "${addr:-}" && -n "${port:-}" ]] || continue

  key="${addr}:${port}"

  if [[ -n "${seen_key[$key]:-}" ]]; then
    continue
  fi

  if [[ -n "${best_for_host[$host]:-}" ]]; then
    continue
  fi

  seen_key["$key"]=1
  best_for_host["$host"]="$key"
  host_for_key["$key"]="$host"
  results+=("$key")

  [[ "$DEBUG" == "1" ]] && {
    echo "DEBUG: ACCEPT host=$host addr=$addr port=$port type=$type"
  }
done <<< "$RAW_OUT"

if [[ ${#results[@]} -eq 0 ]]; then
  echo "No ProPresenter services found on IPv4."
  exit 0
fi

echo "Discovered ${#results[@]} unique machine(s):"
for key in "${results[@]}"; do
  echo "  - ${host_for_key[$key]} ($key)"
done

# ===== Post to Companion =====
idx=$START_INDEX
for key in "${results[@]}"; do
  addr="${key%%:*}"
  port="${key##*:}"
  host="${host_for_key[$key]}"
  var="${VAR_PREFIX}${idx}"

  url="http://${COMPANION_HOST}:${COMPANION_PORT}/api/custom-variable/${var}/value"
  # include hostname + IP + port
  value="${host}:${addr}:${port}"

  echo "Setting ${var} = ${value} via ${url}"
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "DRY_RUN=1 → skipping curl"
  else
    curl -fsS --connect-timeout 2 --max-time 4 -X POST "${url}?value=${value}" || {
      echo "WARN: Failed to set ${var} on ${COMPANION_HOST}:${COMPANION_PORT}" >&2
    }
  fi

  ((idx++))
done

echo "Done."
