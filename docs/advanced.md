# Advanced Features

## Directives

Directives are paste-safe Q comments that control test behavior:

```q
/@fn:label              Link following tests to label
/@fn:                   Reset (no label)
/@ci:required           Tests must pass (default)
/@ci:optional           Failures are warnings
/@ci:skip               Skip tests
```

## Labels

Labels group tests and can be any text - function names, namespaces, or descriptions:

```q
/@fn:add
/// add[1;2] -> 3

/@fn:.utils.parse
/// parse["123"] -> 123

/@fn:edge cases
/// 0%0 -> 0n
```

### Implicit Labels

In `.q` files, function definitions set implicit context:

```q
add:{x+y}
/// add[1;2] -> 3      / linked to 'add' implicitly

mul:{x*y}
/// mul[2;3] -> 6      / linked to 'mul' implicitly
```

### Filtering by Label

Run only tests with a specific label:

```bash
q qdust.q --fn add test file.q
q qdust.q --fn ".utils.parse" test file.q
q qdust.q --fn "edge cases" test file.q
```

## CI Tags

Control test behavior in CI environments:

```q
/@ci:required          / must pass (default)
/@ci:optional          / warning only
/@ci:skip              / don't run
```

### JUnit Output

For CI integration, use JUnit XML output:

```bash
q qdust.q --junit test file.q > results.xml
```

This format is recognized by:
- GitHub Actions
- GitLab CI
- Gitea Actions
- Jenkins
- Most CI systems

### Exit Codes

- `0` - all tests passed
- `1` - one or more tests failed

## Command-Line Flags

| Flag | Purpose |
|------|---------|
| `-cwd <dir>` | Change working directory before running |
| `-noipc` | Disable IPC worker mode, use subprocess instead |
| `-timeout <N>` | Per-expression timeout in seconds (default 5, IPC mode) |
| `-debug` | Debug mode: single file drops to `q))` on error |
| `-filter <pattern>` | Filter test files by name (substring or glob) |
| `-integration` | Run only `@integration` tagged tests |
| `-all` | Run all tests (preflight + integration) |
| `-errors-only` | Show only errors, not full output |
| `-json` | Output in JSON format |
| `-junit` | Output in JUnit XML format |
| `-listci` | CI-clickable error format |

Both `-flag` and `--flag` forms are accepted.

### Working Directory

Use `-cwd` to run tests from a different directory:

```bash
q qdust.q -cwd /path/to/project test tests/
```

This changes the Q process working directory before any test discovery or execution. Useful when invoking qdust from a different location than the project root.

### Diff Modes

Control how diffs are displayed (positional args, no hyphen):

```bash
q qdust.q test file.q diff:term    # terminal diff (default)
q qdust.q test file.q diff:ide     # external diff tool
q qdust.q test file.q diff:none    # suppress diff output
```

Also configurable via `QDUST_DIFF` env var (`term`, `ide`, `none`) or `QDUST_DIFF_TOOL` for the IDE command.

## Environment Variables

### Q Installation

Configure these in `env.sh` (sourced automatically by the wrapper) or export them directly:

| Variable | Purpose |
|----------|---------|
| `QDUST_Q_HOME_BASE` | Base directory of Q installation (e.g. `~/q`). Derives `QHOME` and `QDUST_Q`. |
| `QVER` | Q version subdirectory (e.g. `4.1`). Only used with `QDUST_Q_HOME_BASE`. |
| `QDUST_Q` | Explicit path to Q executable. Overrides all auto-detection. |
| `QHOME` | Q home directory. Derived automatically if `QDUST_Q_HOME_BASE` is set. |
| `QLIC` | Q license directory. |

If none of these are set, the wrapper looks for `q` on PATH.

### Runtime

| Variable | Purpose |
|----------|---------|
| `QDUST_DEBUG` | Set to `1` to enable debug mode (equivalent to `-debug` flag) |
| `QDUST_TIMEOUT` | Per-expression timeout in seconds (default 5) |
| `QDUST_PORTS` | IPC port range (default `65000-65500`) |
| `QDUST_DIFF` | Diff mode: `term`, `ide`, or `none` |
| `QDUST_DIFF_TOOL` | External diff tool command (e.g. `opendiff`, `code --diff`) |
| `QDUST_RLWRAP` | Path to rlwrap binary (auto-detected) |
| `QDUST_RLWRAP_OPTS` | rlwrap flags (default: `-A -pYELLOW -c -r -H ~/.q_history`) |

### IPC Hooks

For corporate environments with custom authentication or port restrictions, override these in Q before loading qdust:

```q
.qd.ipcHopen:{[target] hopen target}   / pluggable connect
.qd.ipcPc:{[handle] exit 0}            / pluggable disconnect handler
```

## Custom Loader

Override the default file loader for custom dependency management:

```q
/ qdust-init.q
.qd.customloader:{[file]
  / Your custom loading logic
  .myloader.load file}
```

Set via environment or command line:

```bash
export QDUST_INIT=qdust-init.q
q qdust.q test file.t

# or
q qdust.q --init qdust-init.q test file.t
```
