# Hecate status reporting for Claude Code

`hecate-report.sh` reports Claude Code session status to a Hecate dashboard via
global hooks, so every project/session reports automatically.

## What it does

The script reads the hook JSON from stdin, derives a stable per-session
`agent_id` from `session_id`, uses the current project folder name as the
`label`, derives the repository/branch/worktree/terminal context from `cwd`
and the tmux pane, and POSTs (non-blocking) to Hecate:

```json
{
  "agent_id": "claude-<session_id>",
  "source": "claude",
  "status": "working | needs_input | finished",
  "label": "<project folder name>",
  "message": "<event>: <status> (<cwd>)",
  "repository": "<project>",
  "branch": "<git branch>",
  "worktree": "<cwd>",
  "terminal": "tmux <session>:<window>.<pane>"
}
```

`repository`, `branch`, `worktree`, and `terminal` are derived, not configured:

- **repository** — the project name. Following the `wt` convention, the script
  walks up from `cwd` to the directory containing `.bare` and uses its basename;
  outside a `.bare` layout it falls back to the git toplevel's basename.
- **branch** — `git rev-parse --abbrev-ref HEAD` in `cwd`.
- **worktree** — the `cwd` itself (the checkout this session runs in).
- **terminal** — the tmux pane this session runs in, read from `$TMUX_PANE`
  (inherited from the pane's shell through Claude Code into the hook child).
  Omitted when not running under tmux.

Each field is sent only when non-empty, so the four stay optional.

It backgrounds the `curl` with a 2s timeout and always exits 0, so a slow or
unreachable Hecate never blocks or fails a turn.

The endpoint is hardcoded near the top of the script:

```sh
endpoint="http://ygors-mac-mini.local:3000/api/v1/reports"
```

Change that line if Hecate moves.

## Install

1. Make the script executable (already committed as such):

   ```sh
   chmod +x ~/PersonalProjects/wt/hecate-report.sh
   ```

2. Add the hook block to `~/.claude/settings.json` (global, all projects).
   Merge into the existing `hooks` object — do not replace other settings:

   ```json
   {
     "hooks": {
       "UserPromptSubmit": [
         {
           "hooks": [
             { "type": "command", "command": "$HOME/PersonalProjects/wt/hecate-report.sh working" }
           ]
         }
       ],
       "PreToolUse": [
         {
           "matcher": "Agent|Task",
           "hooks": [
             { "type": "command", "command": "$HOME/PersonalProjects/wt/hecate-report.sh subagent_start" }
           ]
         }
       ],
       "SubagentStop": [
         {
           "hooks": [
             { "type": "command", "command": "$HOME/PersonalProjects/wt/hecate-report.sh subagent_stop" }
           ]
         }
       ],
       "Notification": [
         {
           "hooks": [
             { "type": "command", "command": "$HOME/PersonalProjects/wt/hecate-report.sh notification" }
           ]
         }
       ],
       "Stop": [
         {
           "hooks": [
             { "type": "command", "command": "$HOME/PersonalProjects/wt/hecate-report.sh idle" }
           ]
         }
       ],
       "SessionEnd": [
         {
           "hooks": [
             { "type": "command", "command": "$HOME/PersonalProjects/wt/hecate-report.sh shutdown" }
           ]
         }
       ]
     }
   }
   ```

3. Open the `/hooks` menu in Claude Code once (or restart). Claude Code does not
   activate hooks edited mid-session until they are reviewed there.

## Status mapping

| Hook event         | Argument         | Status sent                            | Meaning                                              |
| ------------------ | ---------------- | -------------------------------------- | ---------------------------------------------------- |
| `UserPromptSubmit` | `working`        | `working`                              | You handed off a task; the agent is busy             |
| `PreToolUse` (`Agent`/`Task`) | `subagent_start` | `working`                   | Agent delegated to a subagent; still processing      |
| `SubagentStop`     | `subagent_stop`  | `working`                              | A subagent finished; main agent resumes              |
| `Notification`     | `notification`   | depends on `notification_type`         | Permission/elicitation → `needs_input`; idle → see below; auth/etc. → not reported |
| `Stop`             | `idle`           | `working` if a subagent is in flight, else `needs_input` | Turn ended; ball is in your court only if nothing is still running |
| `SessionEnd`       | `shutdown`       | `shutdown`                             | Session closed; agent is gone                        |

`Stop` does **not** unconditionally mean "waiting for you." With background
subagents, the main agent's turn ends (firing `Stop`) while a subagent keeps
running. The script tracks in-flight subagents per session in a marker directory
(`$TMPDIR/hecate-inflight/<session_id>`): `subagent_start` adds a marker,
`subagent_stop` removes one, and `idle` reports `needs_input` only when no marker
remains — otherwise it reports `working` so the card shows "processing", not
"waiting on you." A new `UserPromptSubmit` clears the directory, so any marker
leaked by a crashed subagent self-heals on your next prompt (and a genuinely
stuck `working` agent still trips the dashboard's freshness/stale window).

`Stop` maps to `needs_input` rather than `finished` because the end of a turn
means the agent is waiting for you, not that the whole task is complete —
`finished` can't be reliably auto-detected. The script still accepts `finished`
as an argument, so it can be sent manually when a task genuinely completes.

For `status = shutdown` the script POSTs **synchronously** (foreground curl)
instead of backgrounding it, because a backgrounded child can be killed before
it sends when the process is tearing down on `SessionEnd`.

## Verify

```sh
echo '{"session_id":"test","cwd":"'"$PWD"'","hook_event_name":"Stop"}' \
  | ~/PersonalProjects/wt/hecate-report.sh needs_input
```

The agent should appear on the Hecate dashboard with `agent_id` `claude-test`,
showing `repository`, `branch`, and `worktree` derived from `cwd`. Run it from
inside a tmux pane to confirm `terminal` populates (`tmux <session>:<window>.<pane>`);
outside tmux that field is simply omitted.

## Requirements

- `jq` (used to parse hook input and build the payload)
- `curl`
- Reachable Hecate endpoint (see above)
