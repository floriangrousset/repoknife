# repoknife — development guide

Single-file bash TUI (`./repoknife`, ~2,400 lines) managing a `<code-root>/<provider>/<org>[/<project>]/<repo>` tree — code root defaults to `~/Code`, set via the `code_root` config key or `REPOKNIFE_CODE_ROOT` env (github=2-level · gitlab & azure-devops=3-level — GitLab repos without a subgroup live under a literal `No Project/` dir). Stack: gum (menus/confirm/spin/style) + fzf (all list pickers) + gh + jq. Shipped two ways: **brew** (`brew install floriangrousset/tap/repoknife`, the binary on PATH IS the script) and the legacy dev **symlink** `~/Code/repoknife → github/floriangrousset/repoknife/repoknife`.

## Verification loop — run after EVERY edit

```bash
./repoknife _selftest      # 70 checks, must be 0 failed (fixtures in mktemp under RK_TMP_ROOT, reaped on exit)
shellcheck repoknife       # must be clean (justified disables only, with comment)
/bin/bash ./repoknife --version   # must print the friendly "requires bash >= 4.4" guard, NOT a syntax error
```

Read-only smokes against the real tree: `./repoknife health --plain`, `sync --org cognific --dry-run --plain`, `init --dry-run --plain`, `pr mine --plain`. Mutating flows (clone/pull/init/merge/delete) only with the user watching.

## Hard constraints

- **bash ≥ 4.4** (assoc arrays, empty-array-safe `set -u`). The version guard at the top must stay **bash-3.2 parseable** (macOS system bash must reach the error message — no 4.x syntax above/inside it).
- `set -Eeuo pipefail` everywhere. Interactive cancels (gum/fzf ESC = rc 130) are captured by `ui::` wrappers — callers use `|| return`-style handling, never blanket `|| true` on user-facing logic.
- Single file, 12 banner-labeled sections (01 header → 12 CLI/main), `ns::fn` naming (`ui:: cfg:: path:: disco:: git:: provider:: cache:: worker:: mod:: cli::`), provider impls are `provider_<p>_<verb>` (underscores — name built by interpolation).
- Conventional commits + gitflow: work on `develop` or `feature/*`; `develop` is the default branch; never delete main/develop.

## Hard-won gotchas — violating these reintroduces fixed bugs

1. **BSD `xargs -I{}` mangles tabs/blanks** → batch items travel via numbered files (`$outdir/item.N`); only the index goes on the command line (`worker::write_items` / `worker::entry`).
2. **fzf auto-quotes `{n}` placeholders** → `{1}` must stand ALONE in `--preview` strings, never inside quotes; paths get `printf -v q '%q'`.
3. **Interactivity is frozen ONCE at startup** into `$INTERACTIVE` — live `[ -t 1 ]` checks are WRONG inside `$(...)` captures (stdout is a pipe there even on a real terminal).
4. **Pickers set `SEL` / `SEL_WAS_MENU` globals** and run in the main shell — never convert them to `$(...)`-echo style; the sync ESC navigation (NAV/STEP/`nav::pop`, dynamic scoping) depends on it.
5. **The banner is plain `printf`** — gum style/lipgloss mis-rendered the art on very wide terminals. Don't reintroduce a layout engine there.
6. **Menu icons must be Emoji_Presentation/EAW=Wide** (verify: `python3 -c "import unicodedata; print(unicodedata.east_asian_width('X'))"` → `W`). Wide emoji take 2 trailing spaces; narrow glyphs would need 3 and look ugly — use wide emoji only.
7. **Sanitize remote strings at ingestion**: every jq that pulls titles/descriptions/branch/workflow names applies `gsub("[[:cntrl:]]";" ")` (terminal-injection defense). Plain output goes through `ui::strip_ansi` (OSC + all CSI + control bytes, BSD-sed-safe).
8. **`--` separators** before branch-name args to git (`branch -D -- "$name"`); refs in previews as `refs/heads/{1}`.
9. **`gh repo list` defaults to `--limit 30`** and silently truncates — always `--limit 1000`. `gh search prs` JSON lacks reviewDecision/checks/branches — enrich per-PR via `gh pr view`. The repo-list cache key includes the fork filter.
10. **CODE_ROOT resolution order**: `REPOKNIFE_CODE_ROOT` env (pinned) > `code_root` config key (applied in `cfg::bootstrap`, after `cfg::load`) > walk UP from the resolved script path to the first ancestor with a provider dir > default **`~/Code`** (NOT `dirname(SELF)` — a brew binary at `/opt/homebrew/bin` must not anchor itself there). `cfg::bootstrap` exports the final `REPOKNIFE_CODE_ROOT` so workers/spinner children inherit it (they never re-discover); selftest sets `CODE_ROOT`/`REPOKNIFE_ROOT_PINNED` directly. **CFG_FILE** is independent of CODE_ROOT: `REPOKNIFE_CFG_FILE` env > script-adjacent `$(dirname SELF)/.repoknife.conf` if it exists (dev runs from the clone) > `~/.repoknife.conf` (installed). `_selftest` requires the source tree (the template-sync check reads `dirname(REPOKNIFE_SELF)/.repoknife.conf`) — a brew-installed `_selftest` would fail it, which is fine: it's a dev/CI command (the formula `test do` uses `--version`).
11. **PR merge never passes `--delete-branch`** when head is develop/main/master. Pull is always `--ff-only`; dirty repos are skipped, never autostashed.
12. **Clone progress**: `git clone --progress` stderr streams to the worker's `.err` file; `batch::render` tails the last CR-separated line. Don't redirect provider clone stderr to /dev/null.
13. **`fix::` offers prompt only from pre-check sites in the MAIN shell** — never inside `ui::spin`, `$(...)` captures, or worker/batch code (auth logins are interactive foreground programs needing the real TTY). Fix commands are fixed literal allowlists shown verbatim and run via `eval` (justified `SC2294` disable on the line). Rechecks are leaf predicates (`gh auth status`, `ado::auth_ok`, `auth::has_workflow_scope`), NEVER a `*::check` wrapper (recursion guard). Plain mode prints the command and returns the original rc (2 auth · 1 deps). `gum`-missing during `deps::check` uses `fix::offer_dep`'s plain `read -r` (never gum); `brew`-missing points at brew.sh and never installs brew.

## Testing notes

- Add selftest checks for any new pure logic (path parsing, config, TSV schemas) — `t::check name expected actual`.
- TSV schemas are load-bearing: repo list = 8 cols, health status = 10 cols, runs = 7 cols. Producer/consumer drift is the classic regression — selftest checks field counts.
- Interactive flows can't be CI-tested; pty driving via `script(1)` is flaky — prefer extracting logic into testable functions and verify fzf matching with `fzf --filter`.

## Release pipeline (brew)

Distribution: a dedicated tap repo `floriangrousset/homebrew-tap` → `brew install floriangrousset/tap/repoknife`. The release artifact is the **plain single-file script** (+ `repoknife.sha256`) — no shc/compilation (it would break the `$SELF` re-exec used by workers and fzf previews). Homebrew installs the script verbatim and `inreplace`s the shebang to the brewed bash (`Formula["bash"].opt_bin`).

- `.github/workflows/ci.yml` — on PRs to develop/main + push to develop: `shellcheck` (pinned release binary, `shellcheck repoknife`), `actionlint` (pinned, lints the workflow YAML + their embedded `run:` shell), `_selftest` on ubuntu (native bash 5) and macos (brew bash — system 3.2 can't run it), and a `guard-macos` job asserting `/bin/bash ./repoknife --version` exits 1 with `requires bash >= 4.4`.
- `.github/workflows/release.yml` — on push to **main** (the develop→main merge commit): extracts `VERSION` (repoknife:23), skips if tag `vX.Y.Z` already exists (idempotent re-merge), re-runs the checks, tags + publishes a GitHub Release with `repoknife` + `repoknife.sha256`, then `bump-tap` (decoupled job) bumps the formula with a **plain script** (computes the tag-tarball sha256, `sed`-rewrites the formula `url`+`sha256`, pushes) using the `HOMEBREW_TAP_TOKEN` secret (classic PAT, `repo`+`workflow`) — replaced the `mislav/bump-homebrew-formula-action` which hit an HTTP 303 fetching the tarball.
- `Makefile` — `make check` (selftest+shellcheck+guard) · `build` (dist/) · `install-dev` (the ~/Code symlink) · `install-brew-local` · `release-dry-run`. `dist/` and `dist-tap/` are gitignored.

**Routine release**: bump `VERSION="X.Y.Z"` (repoknife:23) on a feature branch → squash-merge to develop → PR develop→main (**merge commit**) → release.yml fires. The version bump is the release trigger; the human owns it.

**One-time setup** (outward-facing): create the tap repo (`gh repo create floriangrousset/homebrew-tap --public`), mint a classic PAT (browser; `repo`+`workflow`), `gh secret set HOMEBREW_TAP_TOKEN`, and bootstrap the first formula (the staged formula + tap README live in the gitignored `dist-tap/` — copy them into the tap repo, fill the sha256 of the tag tarball). `_selftest` requires the source tree (the template-sync check reads `dirname(REPOKNIFE_SELF)/.repoknife.conf`), so the formula's `test do` only runs `--version`.

## User environment

macOS arm64 (brew bash 5.x, gum 0.17, fzf, gh authed as floriangrousset w/o the `workflow` scope, az present/unauthed), iTerm2 + MesloLGS NF, often ultra-wide terminals — test layout at both 80 and 190 cols. Config: dev runs read the repo-adjacent `.repoknife.conf`; installed/brew copies read `~/.repoknife.conf` (`REPOKNIFE_CFG_FILE` overrides). Cache: `~/.cache/repoknife/`. The committed `.repoknife.conf` doubles as the starter template AND the dev config — keep its keys in sync with `cfg::is_allowed_key` (selftest-enforced). `code_root` defaults to `~/Code`.
