# wt

A collection of small Bash tools for Pi-based workflows.

## Tools

- **wt** — manages Git worktrees (create, rebase, merge, remove)
- **pi-plan-next** — drives `pi` through blueprint steps automatically

## Install

Keep the source in this repository and expose the tools on your PATH with symlinks:

```bash
ln -sfn "$PWD/wt" ~/.local/bin/wt
ln -sfn "$PWD/pi-plan-next" ~/.local/bin/pi-plan-next
```

Make sure `~/.local/bin` is on your PATH.
