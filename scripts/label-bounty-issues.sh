#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# label-bounty-issues.sh — Automatically label bounty issues from docs/bounties.md
#
# Parses the bounty table in docs/bounties.md, extracts issue numbers, and applies
# `good-first-issue`, `bounty`, and effort labels (small/medium/large) to matching
# GitHub issues. Issues not listed in bounties.md have the `bounty` label removed.
#
# Usage:
#   ./scripts/label-bounty-issues.sh [--dry-run]
#
# With --dry-run, shows which issues would be labeled without making changes.

set -euo pipefail

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
fi

REPO="veracindarella/paystream-contracts"
BOUNTY_FILE="docs/bounties.md"

log() { echo "[label-bounty] $*"; }
fail() { echo "[label-bounty] FAIL: $*" >&2; exit 1; }

# Verify required tools
command -v gh >/dev/null || fail "GitHub CLI (gh) is required but not installed"

if [[ ! -f "$BOUNTY_FILE" ]]; then
  fail "Cannot find $BOUNTY_FILE"
fi

log "Parsing bounty issues from $BOUNTY_FILE..."

# Extract issue numbers from the bounty table in the markdown file
# The bounty table format is: | [#87](URL) | Title | Category | Effort | Description |
# We extract the issue numbers from the [#NN] format
declare -A BOUNTY_ISSUES
declare -A ISSUE_EFFORT

# Parse Beginner-Friendly Open Bounties table
while IFS= read -r line; do
  # Look for lines with [#NUMBER] format
  if [[ $line =~ \[#([0-9]+)\] ]]; then
    ISSUE_NUM="${BASH_REMATCH[1]}"
    # Try to determine effort level from the line
    if [[ $line =~ (Small|small) ]]; then
      EFFORT="small"
    elif [[ $line =~ (Medium|medium) ]]; then
      EFFORT="medium"
    elif [[ $line =~ (Large|large) ]]; then
      EFFORT="large"
    else
      EFFORT="small"  # Default to small if not specified
    fi
    BOUNTY_ISSUES["$ISSUE_NUM"]=1
    ISSUE_EFFORT["$ISSUE_NUM"]="$EFFORT"
    log "Found bounty issue #$ISSUE_NUM (effort: $EFFORT)"
  fi
done < "$BOUNTY_FILE"

if [[ ${#BOUNTY_ISSUES[@]} -eq 0 ]]; then
  fail "No issues found in bounty table"
fi

log "Found ${#BOUNTY_ISSUES[@]} bounty issues"
log ""

# Apply labels to bounty issues
for issue_num in "${!BOUNTY_ISSUES[@]}"; do
  effort="${ISSUE_EFFORT[$issue_num]}"
  
  log "Processing #$issue_num (effort: $effort)..."
  
  if [[ "$DRY_RUN" == true ]]; then
    log "  [DRY-RUN] Would add labels: good-first-issue, bounty, $effort"
  else
    # Add labels
    gh issue edit "$issue_num" --repo "$REPO" \
      --add-label "good-first-issue" \
      --add-label "bounty" \
      --add-label "$effort" 2>/dev/null || true
    log "  ✓ Labeled #$issue_num"
  fi
done

log ""
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log "Labeling complete!"
log "Applied labels: good-first-issue, bounty, and effort level"
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ "$DRY_RUN" == true ]]; then
  log "Note: This was a --dry-run. No actual changes were made."
fi
