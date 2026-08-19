# wt

Git worktree methodology, and the small Bash tools built on it.

## Tools

- **wt** — manages Git worktrees (create, rebase, merge, remove)
- **pi-plan-next** — drives `pi` through blueprint steps automatically, then runs a read-only code review with `omlx/Qwen3.6-27B-8bit` and prints any issues found when the blueprint is done

## Install

Keep the source in this repository and expose the tools on your PATH with symlinks:

```bash
ln -sfn "$PWD/wt" ~/.local/bin/wt
ln -sfn "$PWD/pi-plan-next" ~/.local/bin/pi-plan-next
```

Make sure `~/.local/bin` is on your PATH.

## Hecate

`hecate-report.sh` and `tmux-pane-label` used to live here. They moved to Hecate's
own `cli/` directory, where they are now subcommands of one installed `hecate`
command — `hecate report` and `hecate pane-label`. Everything that talks to
Hecate belongs to Hecate; wt stays the worktree methodology that Hecate reads.

Install them from a Hecate checkout:

```bash
cli/hecate install
```

They still follow the `.bare` layout this repository defines, so a `wt` project
keeps reporting its project and worktree names to the dashboard.
