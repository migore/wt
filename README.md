# wt

A collection of small Bash tools for Pi-based workflows.

## Tools

- **wt** — manages Git worktrees (create, rebase, merge, remove)
- **pi-plan-next** — drives `pi` through blueprint steps automatically, then runs a read-only code review with `omlx/Qwen3.6-27B-8bit` and prints any issues found when the blueprint is done
- **tmux-pane-label** — prints `project - worktree` for the tmux pane footer (uses `.bare` to detect worktree projects)

## Install

Keep the source in this repository and expose the tools on your PATH with symlinks:

```bash
ln -sfn "$PWD/wt" ~/.local/bin/wt
ln -sfn "$PWD/pi-plan-next" ~/.local/bin/pi-plan-next
ln -sfn "$PWD/tmux-pane-label" ~/.local/bin/tmux-pane-label
```

Make sure `~/.local/bin` is on your PATH.
