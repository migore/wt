#!/usr/bin/env bash
# Reports Claude Code session status to Hecate. Invoked by global hooks.
# Usage: hecate-report.sh <event>
#   Explicit status : working | needs_input | finished | shutdown
#   Computed status : subagent_start | subagent_stop | idle | notification
# Reads hook JSON from stdin (session_id, cwd, hook_event_name, notification_type).

event="${1:-working}"
endpoint="http://ygors-mac-mini.local:3000/api/v1/reports"

input="$(cat)"
session_id="$(printf '%s' "$input" | jq -r '.session_id // "unknown"' 2>/dev/null)"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)"
hook_event="$(printf '%s' "$input" | jq -r '.hook_event_name // empty' 2>/dev/null)"
notif_type="$(printf '%s' "$input" | jq -r '.notification_type // empty' 2>/dev/null)"

# Track in-flight subagents per session. The main agent's turn ends (Stop fires)
# while a backgrounded subagent keeps running, so without this the card would
# read "needs_input" when it is really still processing. One marker file per
# launched subagent; "idle" only means needs_input when the dir is empty.
inflight_dir="${TMPDIR:-/tmp}/hecate-inflight/${session_id}"
inflight_count() { ls "$inflight_dir" 2>/dev/null | wc -l | tr -d ' '; }

# Capitalize the first letter (bash 3.2-safe; no ${var^}).
cap_first() {
  printf '%s%s' "$(printf '%s' "${1:0:1}" | tr '[:lower:]' '[:upper:]')" "${1:1}"
}

case "$event" in
  working)
    # New user turn: clear any markers leaked by a prior turn, then report working.
    rm -rf "$inflight_dir"
    status="working" ;;
  subagent_start)
    mkdir -p "$inflight_dir"; : > "$inflight_dir/$$.$RANDOM"
    status="working" ;;
  subagent_stop)
    f="$(ls "$inflight_dir" 2>/dev/null | head -1)"
    [ -n "$f" ] && rm -f "$inflight_dir/$f"
    status="working" ;;
  idle)
    # Stop hook: genuinely idle only if no subagent is still running.
    [ "$(inflight_count)" -gt 0 ] && status="working" || status="needs_input" ;;
  notification)
    case "$notif_type" in
      permission_prompt|elicitation_dialog) status="needs_input" ;;
      idle_prompt) [ "$(inflight_count)" -gt 0 ] && status="working" || status="needs_input" ;;
      *) exit 0 ;;  # auth_success, elicitation_complete, etc. — nothing to report
    esac ;;
  shutdown)
    rm -rf "$inflight_dir"; status="shutdown" ;;
  needs_input|finished)
    status="$event" ;;
  *)
    status="$event" ;;
esac

[ -z "$status" ] && exit 0

label="${cwd##*/}"
[ -z "$label" ] && label="claude"

# Derive project context from cwd (wt convention: <root with .bare>/<worktree>/...).
repository=""; branch=""; terminal=""
if [ -n "$cwd" ]; then
  root="$cwd"
  while [ "$root" != "/" ] && [ ! -d "$root/.bare" ]; do root="$(dirname "$root")"; done
  if [ -d "$root/.bare" ]; then
    repository="$(basename "$root")"
  else
    repository="$(basename "$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)")"
  fi
  branch="$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)"
fi

# Terminal: a human-friendly "<Project> - <Worktree>" label for the pane this
# session runs in, derived from the wt layout (mirrors tmux-pane-label) instead
# of raw tmux coordinates like "tmux 0:1.1".
if [ -n "$repository" ]; then
  terminal="$(cap_first "$repository")"
  if [ -d "$root/.bare" ]; then
    rel="${cwd#"$root"/}"
    worktree="${rel%%/*}"
    if [ -n "$worktree" ] && [ "$worktree" != "$cwd" ]; then
      terminal="$terminal - $(cap_first "$worktree")"
    fi
  fi
fi

payload="$(jq -nc \
  --arg agent_id "claude-${session_id}" \
  --arg source "claude" \
  --arg status "$status" \
  --arg label "$label" \
  --arg message "${hook_event:-$event}: ${status} (${cwd:-unknown})" \
  --arg repository "$repository" \
  --arg branch "$branch" \
  --arg worktree "$cwd" \
  --arg terminal "$terminal" \
  '{agent_id: $agent_id, source: $source, status: $status, label: $label, message: $message}
   + (if $repository != "" then {repository: $repository} else {} end)
   + (if $branch     != "" then {branch: $branch}         else {} end)
   + (if $worktree   != "" then {worktree: $worktree}     else {} end)
   + (if $terminal   != "" then {terminal: $terminal}     else {} end)')"

if [ "$status" = "shutdown" ]; then
  # Synchronous: a backgrounded child can be killed before it POSTs on teardown.
  curl -sS -m 2 -X POST "$endpoint" \
    -H "Content-Type: application/json" \
    -d "$payload" >/dev/null 2>&1
else
  curl -sS -m 2 -X POST "$endpoint" \
    -H "Content-Type: application/json" \
    -d "$payload" >/dev/null 2>&1 &
fi

exit 0
