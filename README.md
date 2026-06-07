# repoknife

```
  ╔═►   ____  _____ ____   ___  _  ___   _ ___ _____ _____
  ║    |  _ \| ____|  _ \ / _ \| |/ / \ | |_ _|  ___| ____|
  ╠══► | |_) |  _| | |_) | | | | ' /|  \| || || |_  |  _|
  ║    |  _ <| |___|  __/| |_| | . \| |\  || ||  _| | |___
  ╚═►  |_| \_\_____|_|    \___/|_|\_\_| \_|___|_|   |_____|
        a git-repos swiss-army-knife · gh · az · gitflow
```

A single-file bash TUI for managing a whole tree of local/remote git repos —
clone, pull, PRs, CI runs, health checks, branch hygiene, and gitflow-style
repo bootstrapping — built on `gum` + `fzf` + `gh`.

## What it does

| Module | |
|---|---|
| ✨ **Init** | turn plain folders into gitflow repos (`main` + `develop`, develop default) with optional GitHub remote creation |
| 🔁 **Sync** | fetch an org's remote repo list, multi-select, batch clone/pull with live git progress — dirty repos are skipped, never touched |
| 🔀 **PRs** | cross-org PR dashboard (authored / review-requested / assigned / mentioned) with checkout, diff, approve, merge — merge strategy follows gitflow (squash→develop, merge-commit→main) |
| 🤖 **Actions** | recent workflow runs across repos — watch live, re-run failed, failure logs |
| 💚 **Health** | every local repo, worst-first: dirty, diverged, behind/ahead, gone branches, missing develop — with one-keystroke fixes |
| 🧹 **Cleanup** | delete `[gone]`/`[merged]` branches (`main`/`develop`/current always protected), sync develop ← main |
| 🔧 **Config** | extra orgs, Azure DevOps org→project map, repo-create visibility, fork filter |

Run bare for the interactive menu, or script it: every module is a subcommand
(`repoknife health --plain`, `repoknife sync --org acme --dry-run`, …) with a
`--plain` mode that auto-activates when piped.

## Folder convention

```
~/Code/<provider>/<org>/<repo>              # github, gitlab
~/Code/azure-devops/<org>/<project>/<repo>  # ADO is 3-level
```

The script finds its Code root automatically (it can live inside a repo and be
symlinked from the root). Orgs are auto-discovered from folders plus config.

## Install

```bash
# dependencies
brew install bash gum fzf jq gh        # macOS (system bash 3.2 is too old)
gh auth login

# clone + symlink into your code root
git clone git@github.com:floriangrousset/repoknife.git ~/Code/github/floriangrousset/repoknife
ln -s github/floriangrousset/repoknife/repoknife ~/Code/repoknife

~/Code/repoknife            # launch the menu
~/Code/repoknife --help     # CLI reference
~/Code/repoknife _selftest  # 37-check self-diagnostic
```

Optional: `az` CLI for Azure DevOps · `lazygit` for the health-screen shortcut ·
`gh auth refresh -s workflow` to enable re-running failed Actions jobs.

## Notes

- Requires **bash ≥ 4.4** (a friendly guard tells you if not)
- Remote repo lists are cached for 1h in `~/.cache/repoknife` (`--refresh` bypasses)
- Config lives in `~/Code/.repoknife.conf` — parsed with a strict key allowlist, never sourced
- Exit codes: `0` ok · `1` usage/deps · `2` auth · `130` cancelled · `health --exit-code` gates CI

---
crafted by **Florian Grousset**
