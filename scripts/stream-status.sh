#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# stream-status.sh — Query and display the status of a salary stream
#
# Displays a formatted table of stream details including status, claimable amount,
# and time-to-exhaustion for quick operator monitoring.
#
# Usage:
#   export STREAM_CONTRACT_ID=<deployed stream contract id>
#   export STREAM_ID=<numeric stream id>
#   export NETWORK=testnet  # or mainnet; defaults to testnet
#   ./scripts/stream-status.sh
#
# Alternatively, pass as arguments:
#   ./scripts/stream-status.sh <STREAM_CONTRACT_ID> <STREAM_ID> [NETWORK]
#
# Exits with 0 on success, non-zero if stream not found or query fails.

set -euo pipefail

# Parse arguments or fall back to environment variables
STREAM="${1:-${STREAM_CONTRACT_ID:-}}"
STREAM_ID="${2:-${STREAM_ID:-}}"
NETWORK="${3:-${NETWORK:-testnet}}"

[[ -n "$STREAM" ]] || { echo "Error: STREAM_CONTRACT_ID must be set or passed as first argument" >&2; exit 1; }
[[ -n "$STREAM_ID" ]] || { echo "Error: STREAM_ID must be set or passed as second argument" >&2; exit 1; }

log() { echo "[stream-status] $*"; }
fail() { echo "[stream-status] FAIL: $*" >&2; exit 1; }
strip() { tr -d '"'; }

log "Querying stream $STREAM_ID on contract $STREAM ($NETWORK)..."

# Query the full stream object
STREAM_DATA=$(stellar contract invoke --id "$STREAM" --network "$NETWORK" \
  -- get_stream --stream_id "$STREAM_ID" 2>/dev/null) || fail "Stream not found (ID: $STREAM_ID)"

# Parse JSON fields from the returned stream object
# Output format varies by Soroban SDK, but typically includes structured data
# For now, we'll attempt to extract via standard JSON tools if available
if command -v jq &>/dev/null; then
  ID=$(echo "$STREAM_DATA" | jq -r '.id // empty')
  EMPLOYER=$(echo "$STREAM_DATA" | jq -r '.employer // empty')
  EMPLOYEE=$(echo "$STREAM_DATA" | jq -r '.employee // empty')
  TOKEN=$(echo "$STREAM_DATA" | jq -r '.token // empty')
  DEPOSIT=$(echo "$STREAM_DATA" | jq -r '.deposit // empty')
  WITHDRAWN=$(echo "$STREAM_DATA" | jq -r '.withdrawn // empty')
  RATE=$(echo "$STREAM_DATA" | jq -r '.rate_per_second // empty')
  STATUS=$(echo "$STREAM_DATA" | jq -r '.status // empty')
  STOP_TIME=$(echo "$STREAM_DATA" | jq -r '.stop_time // empty')
else
  # Fallback: manual parsing for common Soroban contract output
  # If the contract returns a formatted string, extract fields manually
  ID=$(echo "$STREAM_DATA" | grep -o '"id"[^,]*' | cut -d':' -f2 | tr -d ' "' | head -1)
  STATUS=$(echo "$STREAM_DATA" | grep -o '"status"[^,]*' | cut -d':' -f2 | tr -d ' "' | head -1)
  DEPOSIT=$(echo "$STREAM_DATA" | grep -o '"deposit"[^,]*' | cut -d':' -f2 | tr -d ' "' | head -1)
  WITHDRAWN=$(echo "$STREAM_DATA" | grep -o '"withdrawn"[^,]*' | cut -d':' -f2 | tr -d ' "' | head -1)
  RATE=$(echo "$STREAM_DATA" | grep -o '"rate_per_second"[^,]*' | cut -d':' -f2 | tr -d ' "' | head -1)
  STOP_TIME=$(echo "$STREAM_DATA" | grep -o '"stop_time"[^,]*' | cut -d':' -f2 | tr -d ' "' | head -1)
  EMPLOYER=$(echo "$STREAM_DATA" | grep -o '"employer"[^,]*' | cut -d':' -f2 | tr -d ' "' | head -1)
  EMPLOYEE=$(echo "$STREAM_DATA" | grep -o '"employee"[^,]*' | cut -d':' -f2 | tr -d ' "' | head -1)
  TOKEN=$(echo "$STREAM_DATA" | grep -o '"token"[^,]*' | cut -d':' -f2 | tr -d ' "' | head -1)
fi

# Query claimable amount
CLAIMABLE=$(stellar contract invoke --id "$STREAM" --network "$NETWORK" \
  -- claimable --stream_id "$STREAM_ID" 2>/dev/null | strip) || CLAIMABLE="error"

# Calculate remaining deposit
REMAINING=0
if [[ -n "$DEPOSIT" && -n "$WITHDRAWN" && "$DEPOSIT" =~ ^[0-9]+$ && "$WITHDRAWN" =~ ^[0-9]+$ ]]; then
  REMAINING=$((DEPOSIT - WITHDRAWN))
fi

# Calculate time to exhaustion (in seconds)
NOW=$(date +%s)
TIME_TO_EXHAUSTION="N/A"
if [[ -n "$RATE" && "$RATE" =~ ^[0-9]+$ && "$RATE" -gt 0 && "$REMAINING" -ge 0 ]]; then
  SECONDS_LEFT=$((REMAINING / RATE))
  if [[ "$SECONDS_LEFT" -lt 60 ]]; then
    TIME_TO_EXHAUSTION="${SECONDS_LEFT}s"
  elif [[ "$SECONDS_LEFT" -lt 3600 ]]; then
    MINS=$((SECONDS_LEFT / 60))
    TIME_TO_EXHAUSTION="${MINS}m"
  elif [[ "$SECONDS_LEFT" -lt 86400 ]]; then
    HOURS=$((SECONDS_LEFT / 3600))
    TIME_TO_EXHAUSTION="${HOURS}h"
  else
    DAYS=$((SECONDS_LEFT / 86400))
    TIME_TO_EXHAUSTION="${DAYS}d"
  fi
fi

# Display results in a formatted table
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log "Stream Status Report"
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log "Stream ID:           $ID"
log "Status:              ${STATUS:-unknown}"
log "Employer:            ${EMPLOYER:0:16}..."
log "Employee:            ${EMPLOYEE:0:16}..."
log "Token Contract:      ${TOKEN:0:16}..."
log ""
log "Deposit:             $DEPOSIT"
log "Withdrawn:           $WITHDRAWN"
log "Remaining:           $REMAINING"
log "Claimable Now:       $CLAIMABLE"
log "Rate (tokens/sec):   $RATE"
log ""
log "Stop Time:           ${STOP_TIME:-indefinite}"
log "Time to Exhaustion:  $TIME_TO_EXHAUSTION"
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log "SUCCESS"
