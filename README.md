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

Your **code root** defaults to `~/Code` (override with the `code_root` config key
or the `REPOKNIFE_CODE_ROOT` env var). Under it, repos are organized by provider:

```
<code-root>/github/<org>/<repo>
<code-root>/gitlab/<org>/<project>/<repo>        # project = subgroup · "No Project" if none
<code-root>/azure-devops/<org>/<project>/<repo>  # ADO is always 3-level
```

For example, with the default `~/Code`:

```
~/Code/
├── 🟦 github/
│   ├── 🟪 acme/
│   │   ├── 🟩 api-server/
│   │   └── 🟩 webapp/
│   └── 🟪 floriangrousset/
│       └── 🟩 repoknife/
├── 🟦 gitlab/
│   └── 🟪 widgets-inc/
│       ├── 🟨 firmware/
│       │   └── 🟩 bootloader/
│       └── 🟨 No Project/
│           └── 🟩 website/
└── 🟦 azure-devops/
    └── 🟪 contoso/
        ├── 🟨 platform/
        │   ├── 🟩 billing-service/
        │   └── 🟩 identity-service/
        └── 🟨 mobile/
            └── 🟩 ios-app/
```

- 🟦 **provider** — `github` · `gitlab` · `azure-devops`
- 🟪 **org** — GitHub org or user · GitLab group · Azure DevOps organization
- 🟨 **project** — the third level: Azure DevOps project · GitLab subgroup (repos without one go in a literal `No Project/` folder)
- 🟩 **repo** — the git clones themselves

Orgs are auto-discovered from these folders plus config. The code root needs no
special marker — it's just the folder that holds your `github/` · `gitlab/` ·
`azure-devops/` trees.

## Install

```bash
# dependencies
brew install bash gum fzf jq gh        # macOS (system bash 3.2 is too old)
gh auth login

# clone + symlink into your code root
git clone git@github.com:floriangrousset/repoknife.git ~/Code/github/floriangrousset/repoknife
ln -s github/floriangrousset/repoknife/repoknife ~/Code/repoknife
cp ~/Code/github/floriangrousset/repoknife/.repoknife.conf ~/Code/  # optional starter config

~/Code/repoknife            # launch the menu
~/Code/repoknife --help     # CLI reference
~/Code/repoknife _selftest  # 41-check self-diagnostic
```

Optional: `az` CLI for Azure DevOps · `lazygit` for the health-screen shortcut ·
`gh auth refresh -s workflow` to enable re-running failed Actions jobs.

## Notes

- Requires **bash ≥ 4.4** (a friendly guard tells you if not)
- Remote repo lists are cached for 1h in `~/.cache/repoknife` (`--refresh` bypasses)
- Code root: defaults to `~/Code`; set the `code_root` config key or export `REPOKNIFE_CODE_ROOT` to point elsewhere (env wins)
- Config location: the brew/installed binary reads `~/.repoknife.conf`; a dev run from the clone (`./repoknife`) reads the repo-adjacent `.repoknife.conf` (which doubles as the committed starter template). `REPOKNIFE_CFG_FILE` overrides. Parsed with a strict key allowlist, never sourced. Upgrading from a pre-1.6 layout? `mv ~/Code/.repoknife.conf ~/.repoknife.conf` (or let the first-run prompt move it)
- Failure UX: missing tools, an unauthenticated `gh`/`az`, and the workflow-scope gap are detected and **offered as a one-keypress fix** interactively (the exact command is shown verbatim before it runs); in `--plain` mode the copy-paste command is printed and the original exit code preserved
- Exit codes: `0` ok · `1` usage/deps · `2` auth · `130` cancelled · `health --exit-code` gates CI

---
crafted by **Florian Grousset**
