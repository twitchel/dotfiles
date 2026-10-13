# Claude setup overhaul: Matt Pocock skills, reader/writer agents, `aicli`

## Context

Current setup (all chezmoi-managed under `home/dot_claude/` + `home/.chezmoitemplates/claude/settings.managed.json.tmpl`):
- `mattpocock-skills@claude-plugins-official` is pinned by the official marketplace (sha `c55ee46`, v1.2.3). Upstream `mattpocock/skills` is v1.3.1 with new skills (`to-spec`, `to-tickets`, `implement`, `implement-spec`, `pr`, `retro`, `handoff`, `wait-what`, `wayfinder`, `ask-matt`, ...).
- `superpowers` plugin overlaps Matt's (tdd, debugging, code-review, brainstorming≈grilling) and injects a forced-skill SessionStart preamble.
- No custom agents. No deterministic tooling: history shows "commit this" ×19, "push it" ×10, "commit and push" ×7, "push it and open a PR" ×3 — all done by the model step by step.

Goal: Matt's skills as primary methodology (tracking upstream), a small kept subset of superpowers, six tiered reader/writer agents, and an `aicli` bash CLI that moves git/PR/context/health tasks out of the model.

## 1. Matt Pocock skills from upstream

Edit `home/.chezmoitemplates/claude/settings.managed.json.tmpl`:
- `extraKnownMarketplaces.mattpocock = {source: {source: "github", repo: "mattpocock/skills"}, autoUpdate: true}`
- `enabledPlugins`: add `"mattpocock-skills@mattpocock": true`; set `"mattpocock-skills@claude-plugins-official": false` and `"superpowers@claude-plugins-official": false` (explicit `false`, since `mergeOverwrite` never deletes keys from the live file).

`extraKnownMarketplaces` is an object → merges with the live caveman/litellm/ooh entries, no clobber.

Post-apply (one-off, documented in `aicli plugins sync`): `claude plugin marketplace add mattpocock/skills && claude plugin install mattpocock-skills@mattpocock`, then run `/setup-matt-pocock-skills` per repo.

## 2. Vendored superpowers subset

Copy from `obra/superpowers` tag `v7.0.0` into `home/dot_claude/skills/<name>/` (chezmoi manages only these dirs; `presenterm/`, `synced/` stay unmanaged):
- `verification-before-completion/`
- `subagent-driven-development/` (incl. `*-prompt.md` and `scripts/` → `executable_` prefix on scripts)
- `using-git-worktrees/`
- `finishing-a-development-branch/`

Rewrite cross-refs so they resolve without the plugin:
- `superpowers:using-git-worktrees` / `superpowers:finishing-a-development-branch` → bare name
- `superpowers:requesting-code-review` → `mattpocock-skills:code-review`
- `finishing-a-development-branch`: push/PR steps call `aicli ship --pr`
- `using-git-worktrees`: mention existing `wt` helpers (`home/dot_config/zsh/worktrees.functions.zshrc`) and `WT_DIR`

Add `home/dot_claude/skills/SOURCES.md` noting upstream repo + tag (in `.chezmoiignore` so it isn't installed).

## 3. Reader / writer agents

New `home/dot_claude/agents/*.md`, frontmatter `name`, `description`, `tools`, `model`, `effort`:

| Agent | model | effort | tools |
|---|---|---|---|
| `reader-quick` | haiku | low | Read, Grep, Glob, Bash |
| `reader` | sonnet | medium | Read, Grep, Glob, Bash |
| `reader-deep` | opus | high | Read, Grep, Glob, Bash, WebFetch |
| `writer-quick` | haiku | low | Read, Edit, Write, Grep, Glob |
| `writer` | sonnet | medium | Read, Edit, Write, Grep, Glob, Bash |
| `writer-deep` | opus | high | Read, Edit, Write, Grep, Glob, Bash |

Bodies (short):
- readers: read-only contract (never edit, Bash only for read-only commands), start with `aicli ctx`, return `path:line` evidence table + conclusion, no file dumps. Descriptions say when to pick each tier (lookup vs trace vs design/audit).
- writers: only touch files named in the brief; quick = mechanical edits (renames, typos, 1–2 files); default = scoped feature/fix with tests; deep = cross-file refactor. Must run the project's checks if given and report diff summary + what wasn't verified. Follow global comment rules.

Global `home/dot_claude/CLAUDE.md`: add short "Delegation" section (which tier for what) and "Deterministic tools" section (use `aicli` instead of hand-running git/gh sequences).

## 4. `aicli`

Layout (git-style dispatcher, bash 3.2-compatible for macOS `/bin/bash`, deps: git, gh, jq, curl, claude — all already in Brewfile or base OS):

```
home/dot_local/bin/executable_aicli          # dispatcher: aicli <cmd> [args]; help; unknown → usage, exit 2
home/dot_local/lib/aicli/lib.sh              # die, need <bin>, default_branch, is_default_branch, json/plain output helper
home/dot_local/lib/aicli/cmd/ctx.sh
home/dot_local/lib/aicli/cmd/ship.sh
home/dot_local/lib/aicli/cmd/pr.sh
home/dot_local/lib/aicli/cmd/doctor.sh
home/dot_local/lib/aicli/cmd/plugins.sh
```
Dispatcher resolves lib dir via `${AICLI_LIB:-$HOME/.local/lib/aicli}` (overridable for tests). Each cmd: `-h` usage, `--json` where useful, non-zero exit + one-line stderr on failure.

Subcommands:
- **`aicli ctx [--json]`** — one call replacing ~5: repo root, branch, default branch, upstream + ahead/behind, porcelain status counts + file list (capped), staged/unstaged diffstat, last 5 commits, open PR for branch (`gh pr view --json` if gh authed, else skipped), detected stack (go.mod, package.json+lockfile→pm, Makefile targets, pyproject, bats).
- **`aicli ship -m <msg> [-a] [-b <branch>] [--pr [--draft]]`** — commit (staged only, or `-a` all tracked+untracked) with message from `-m` or stdin (`-m -`); if on default branch requires `-b` (creates branch) else refuses; `git push -u origin HEAD`; with `--pr` delegates to `aicli pr create`. Nothing to commit + unpushed commits → just push. Prints final SHA, branch, PR URL.
- **`aicli pr create [--title t] [--body-file f|-] [--draft]`** — default title = first commit subject on branch, default body = commit list since merge-base; if PR exists prints URL. **`aicli pr status`** — state, review decision, checks summary (`gh pr view` + `gh pr checks`), compact.
- **`aicli doctor`** — deps present + versions, `gh auth status`, claude version, gateway reachability (`ANTHROPIC_BASE_URL` / settings `env` → `curl -sf -m5`), managed settings drift (`chezmoi diff ~/.claude/settings.json` empty?), enabled plugins missing from `installed_plugins.json`.
- **`aicli plugins [list|update|sync]`** — `list`: enabled vs installed version + marketplace sha (from `~/.claude/plugins/*.json` via jq); `update`: `claude plugin marketplace update` + `claude plugin update` each enabled; `sync`: install any enabled-but-missing (covers step 1 bootstrap).

Settings template: add `permissions.allow` for `Bash(aicli ctx:*)`, `Bash(aicli doctor:*)`, `Bash(aicli plugins list:*)`, `Bash(aicli pr status:*)` (read-only only; `ship` stays prompted). Live file has no `permissions` today, so no clobber; note in repo CLAUDE.md that this array is fully managed.

Optional later (not v1): `/ship` slash command wrapping `aicli ship`, SessionStart hook injecting `aicli ctx`.

## 5. Docs

- Repo `CLAUDE.md` "Claude Code config": add agents/, skills/ (vendored subset + source), aicli layout, permissions array is managed.
- `tests/README.md`: new suites.

## Verification

- `tests/bats/10_aicli.bats` (unit, `mock` helpers from `tests/helpers/common.bash`, run the real `home/dot_local/bin/executable_aicli` with `AICLI_LIB` pointed at repo lib): dispatcher help/unknown; `ctx` in a temp git repo (real git, mocked `gh`); `ship` refuses on main without `-b`, commits+pushes to a local bare remote, `--pr` calls mocked `gh pr create`; `pr create` defaults title/body; `plugins list` against fixture JSON.
- `tests/render/claude.bats`: settings renders mattpocock marketplace + plugin flags + permissions; six agents render with expected `model`/`effort`; vendored skills contain no `superpowers:` refs.
- `shellcheck` all aicli scripts (add `shellcheck` to brew base list if absent).
- `bash tests/run.sh`, then `chezmoi diff -S .` → `chezmoi apply -S .`; `aicli doctor`, `aicli plugins sync`; in a fresh Claude session: `/agents` lists six, `/skills` shows Matt 1.3.x skills + 4 vendored, superpowers preamble gone.
