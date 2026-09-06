# Tests

BATS tests that validate the chezmoi templates and generated dotfiles, plus a
local reproduction of the GitHub Actions build. Everything is driven from the
repo-root `Makefile`.

## Layout

Three tiers, in increasing cost:

| Tier | Path | What it checks | Runs by default |
|---|---|---|---|
| unit | `tests/bats/` | script bash logic, against mocked binaries | yes |
| render | `tests/render/` | what chezmoi actually renders (Brewfile, scripts, zshrc) | yes |
| apply | `tests/apply/` | a real `chezmoi apply` into an isolated HOME | no — `make test-apply` |

`tests/run.sh` runs the unit and render tiers; that is what CI invokes. The
suites assert in plain bash rather than bats-assert, so the only dependency is
bats itself.

## Quick start

```bash
make vendor        # download pinned bats-core into tests/vendor/
make test          # unit + render tiers in fedora:44 and ubuntu:26.04 containers (fast)
make test-fedora   # just Fedora
make ci            # reproduce the GitHub CI build locally (chezmoi init/data/apply)
make test-apply    # apply-tier suite: real `chezmoi apply` (slower, opt-in)
```

Requires docker. On a podman host, pass `CONTAINER_RUNTIME=podman`, e.g.
`make CONTAINER_RUNTIME=podman test`.

## How the tests render templates

`home/.chezmoi.yaml.tmpl` prompts for `customHostname`/`email` via
`promptStringOnce`, which reads `/dev/tty` and can't be driven by a flag. The
helper in `helpers/common.bash` therefore pre-seeds an isolated chezmoi config
with those answers, runs a normal `chezmoi init` (no prompt), then renders with:

- `chezmoi cat <target>` — for managed target files (Brewfile, zshrc). Needed
  because `Brewfile.tmpl` pulls in `.chezmoitemplates` partials that only
  resolve with full source context.
- `chezmoi execute-template < <script>` — for `.chezmoiscripts` (not target
  files), which still resolve `.hostData`, includes, and the sha256 cachebust
  after init.

`CI` is unset during rendering so GitHub's `CI=true` doesn't pin the hostname to
`ci` and defeat the per-host cases.

## Tiers

- **Render** (`make test` → `render.bats`, `scripts.bats`, `zsh.bats`): fast,
  no Homebrew, runs on every PR. Asserts the *content* of generated files per
  host.
- **Apply** (`make test-apply` → `apply.bats`): runs chezmoi's real apply
  engine to a temp HOME and checks the tree is materialised. Excludes scripts
  (Homebrew/casks/flatpaks/rpm-ostree can't run in a headless container) and
  externals (network). Opt-in; not run in CI by default.

## Known coverage limitation

`.chezmoi.os` / `.chezmoi.osRelease` can't be faked, so the macOS-only branches
(`OS == darwin` flatpak-skip, casks as the only GUI path) are not exercised from
the Linux test containers. macOS behaviour stays validated by the
`macos-latest` job in GitHub Actions.

## Layout

```
test/
  Dockerfile          # ARG BASE_IMAGE; chezmoi + tooling + non-root `tester`
  helpers/common.bash # chez_init / chez_cat / chez_template helpers
  render.bats         # Brewfile / package-merge content
  scripts.bats        # generated .chezmoiscripts content
  zsh.bats            # bootstrap.zshrc content
  apply.bats          # real-apply smoke tests
  vendor/             # git-ignored; populated by `make vendor`
```
