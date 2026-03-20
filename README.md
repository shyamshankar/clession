# clession

Claude Session Manager with tmux. Isolated Claude Code sessions based off any branch — not just the default.

## Why?

Claude Code's `--worktree` only branches from the default remote branch. If your work lives on a different branch (e.g., `dev-ai-native`), that doesn't help.

clession gives you full repo clones checked out to any branch, each running Claude in its own tmux session — start, detach, resume, clean up.

## Install

### Homebrew

```bash
brew tap shyamshankar/clession
brew install clession
```

This automatically installs dependencies (`tmux`, `gh`). You still need [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed separately.

### Manual

```bash
curl -fsSL https://raw.githubusercontent.com/shyamshankar/clession/main/install.sh | bash
```

Or clone and link:

```bash
git clone https://github.com/shyamshankar/clession.git
ln -sf "$(pwd)/clession/bin/clession" ~/bin/clession
```

## Quick start

```bash
# Check your setup
clession doctor

# Save a repo alias (so you don't paste URLs every time)
clession config alias add app git@github.com:org/app.git

# Start a session off a specific branch
clession start feat-auth --repo app --base-branch dev-ai-native

# Detach from tmux (Ctrl-b d), then come back later
clession resume feat-auth

# Done? Clean up
clession stop feat-auth
```

## Commands

| Command | Description |
|---|---|
| `clession start <name> --repo <url-or-alias> --base-branch <branch>` | Clone repo at branch, launch Claude in tmux |
| `clession resume <name>` | Reattach to session (recreates tmux if needed) |
| `clession stop <name>` | Kill tmux session, remove clone |
| `clession list` | Show all sessions with status |
| `clession config alias add <alias> <url>` | Save a repo alias |
| `clession config alias get <alias>` | Show URL for alias |
| `clession config alias rm <alias>` | Remove alias |
| `clession config alias list` | List all aliases |
| `clession doctor` | Verify dependencies and credentials |

## Config

Aliases are stored in `~/.clession/config`:

```ini
[aliases]
app = git@github.com:org/app.git
infra = /Users/you/repos/infra
```

## Dependencies

| Dependency | Required | Installed by Homebrew |
|---|---|---|
| `git` | Yes | Yes (via Xcode CLT) |
| `tmux` | Yes | Yes |
| `claude` | Yes | No — [install separately](https://docs.anthropic.com/en/docs/claude-code) |
| `gh` | Recommended | Yes |

Run `clession doctor` to check everything is set up.

## How it works

1. **start** — `git clone --branch <base-branch> <repo>` into `~/.clession/sessions/<name>/repo`, creates a tmux session, runs `claude --name <name>`
2. **resume** — if tmux session exists, attach. If tmux died but clone is still there, recreate with `claude --continue --name <name>`
3. **stop** — kills tmux, removes the clone directory. Session name is freed for reuse.

## Testing

```bash
bash test/clession_test.sh
```

Runs 30 tests covering CLI args, config aliases, session lifecycle, and error handling. No tmux or Claude needed — tests mock the session layer.

## License

MIT
