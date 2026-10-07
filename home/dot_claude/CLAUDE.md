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
