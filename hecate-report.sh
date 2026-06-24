#!/usr/bin/env bash
# Reports Claude Code session status to Hecate. Invoked by global hooks.
# Usage: hecate-report.sh <working|needs_input|finished>
# Reads hook JSON from stdin (session_id, cwd, hook_event_name).

status="${1:-working}"
endpoint="http://ygors-mac-mini.local:3000/api/v1/reports"

input="$(cat)"
session_id="$(printf '%s' "$input" | jq -r '.session_id // "unknown"' 2>/dev/null)"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)"
event="$(printf '%s' "$input" | jq -r '.hook_event_name // empty' 2>/dev/null)"

label="${cwd##*/}"
[ -z "$label" ] && label="claude"

payload="$(jq -nc \
  --arg agent_id "claude-${session_id}" \
  --arg source "claude" \
  --arg status "$status" \
  --arg label "$label" \
  --arg message "${event:-hook}: ${status} (${cwd:-unknown})" \
  '{agent_id: $agent_id, source: $source, status: $status, label: $label, message: $message}')"

curl -sS -m 2 -X POST "$endpoint" \
  -H "Content-Type: application/json" \
  -d "$payload" >/dev/null 2>&1 &

exit 0
