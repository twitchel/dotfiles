# Writing style: ASD-STE100

Write all prose in ASD-STE100 Simplified Technical English. This includes replies, code comments, commit messages, PR bodies, docs and briefs to subagents. It does not apply to code, identifiers, commands, file paths, quoted output, or text the user gives you to keep as is.

- Use one word for one meaning. Use the simple, common sense of a word. Use technical names and technical verbs as necessary.
- Keep procedural sentences to 20 words or fewer, and descriptive sentences to 25 words or fewer.
- Write one instruction in each sentence. Put steps in a numbered list.
- Use the active voice. Use the imperative for instructions.
- Use only the simple present, simple past and simple future tenses. Do not use "-ing" forms as verbs.
- Do not make noun clusters of more than three words. Use articles ("the", "a") where possible.
- Keep a paragraph to six sentences or fewer, about one topic.
- Put a warning or a caution before the step it applies to.

# Code comments

Keep them concise: **what**, and a short optional **why**. Usually one line, rarely more than two.

Never include historical context. A comment describes the code as it stands, not how it got there. Git has the history.

Do not write:

- what a value used to be, or that it was changed, raised, lowered, renamed or moved
- the bug, incident, outage or review that prompted the code
- dates, issue numbers, PR numbers, or "as of <version>"
- narration of what was tried first, or what the alternative was
- restating the diff in prose

```yaml
# Bad
# Raised from 250 once the pool ran out of schedulable room. What bounds Longhorn is not
# free space but the ceiling: storageMaximum minus a fixed 74 GiB storageReserved. At 250
# that was 173 GiB per node with 167 GiB already scheduled, and a new 20Gi claim could not
# be placed.
vm_disk_gb = 500

# Good
# Longhorn's pool. Schedulable space is this minus storageReserved, not free space.
vm_disk_gb = 500
```

```python
# Bad
# We used to use a dict here but it broke on duplicate keys (see #412), so after trying
# a set first, this is now a list of tuples.
pairs = [(k, v) for k, v in items]

# Good
# Tuples, not a dict: keys repeat.
pairs = [(k, v) for k, v in items]
```

The test: if a sentence only makes sense to someone who watched the change happen, cut it.

This applies to comments in every language, and to config and infrastructure files.

# Deterministic tools

`aicli` (in `~/.local/bin`) does fixed git/GitHub/Claude chores in one call. Prefer it to running the steps by hand:

- `aicli ctx` — repo snapshot (branch, upstream, status, diffstat, recent commits, PR, stack). Run it first instead of separate `git status`/`git log`/`git diff --stat` calls.
- `aicli ship -m "<msg>" [-a [<path>[:<start>-<end>]...]] [-b <branch>] [--pr]` — commit, push, optionally open the PR. `-a` alone stages everything; `-a <paths>` stages only those; `<path>:<start>-<end>` stages only the changed hunks touching those working-copy lines. Write the message yourself; the script does the rest. It refuses the default branch without `-b`.
- `aicli pr create|status` — open or inspect the branch's PR.
- `aicli doctor`, `aicli plugins list|update|sync` — setup health.

`aicli <cmd> -h` shows options.

# Delegation

The main session plans, briefs, verifies and commits. It does not do the legwork itself:

- **Edits go to a writer.** A hook blocks main-session Edit/Write on project files. Do not route edits through Bash (`sed`, heredocs, scripts) to get around it.
- **Investigation goes to a reader** when it spans more than one file or needs more than a couple of searches: tracing a flow, reviewing a diff, auditing a design.
- **Stay inline** only for single-fact lookups in a file you already know, running tests, and `aicli`/git chores.

User-level agents pair a model with an effort level. Pick the cheapest that fits:

| Need | Agent |
|---|---|
| single-fact lookup: where is X, what calls Y | `reader-quick` |
| trace a flow, explain a feature, review a diff | `reader` |
| architecture audit, subtle bug, whole-branch review | `reader-deep` |
| mechanical 1–2 file edit with a full spec | `writer-quick` |
| scoped feature or fix with tests | `writer` |
| cross-file refactor, design judgment, a stuck writer | `writer-deep` |

Brief writers with the exact files, the change, and the checks to run. Commit their work yourself, with `aicli ship`.

One agent per task, not per item: give a reader the whole file list rather than one reader per file. A hook caps spawns at 8 per prompt, 2 of them `reader-deep`/`writer-deep`. Run independent agents in parallel. Verify a writer's report (re-run its checks, read the diff) before claiming the work is done.
