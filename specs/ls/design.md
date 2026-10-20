# Design: ls

## Overview

`main()` passes `runtime.args()` to `cli.app.run`, which parses the
arguments into `Options`, handles `--help` and `--version`, and calls
`commands.ls.run_ls`. `run_ls` asks `list_operands` for a `Listing` (the
lines for standard output, the error messages and the exit status) and only
then prints. Everything that does not touch the file system is a pure
function with unit tests; the file-system parts are covered by the unit test
on `tests/fixtures/tree` and by `tests/e2e.sh`.

## Modules

| Module | Contents |
|---|---|
| `source/cli/args.loup` | `Options`, `parse_args` (getopt_long rules: permutation, clusters, `--`, unambiguous prefixes), `match_long`, `parse_when` |
| `source/cli/usage.loup` | `usage()`, `version_line()` |
| `source/cli/app.loup` | `run()`, `usage_status()` (1 for a bad `--classify` argument, 2 otherwise) |
| `source/commands/ls.loup` | `parse_width`, `is_shown`, `sort_entries`, `indicator`, `format_entries`, `directory_entries`, `list_directory` (recursive), `list_operands`, `run_ls` |
| `source/commands/columns.loup` | `indent`, `fit_columns`, `layout_columns`: GNU's `-C` layout |
| `source/commands/fsinfo.loup` | `Kind`, `read_names`, `operand_kind`, `entry_kind`, `is_symlinked_dir`, `entry_present`, `missing_reason` |
| `source/commands/quote.loup` | `quote()`: GNU's quoting of names in messages |

### Listing

`list_operands` sorts the operands into files (including everything with
-d) and directories, formats the files, then calls `list_directory` for each
directory. `list_directory` reads the names, filters them (`is_shown`), adds
`.` and `..` for -a, sorts, formats, and with -R calls itself for each entry
of kind `Dir` in display order, which gives GNU's depth-first order. The
header rule is GNU's: no header only when there is exactly one operand (or
none), it is a directory, no file was listed, and -R is off.

### Columns

`fit_columns` is GNU's `calculate_columns`: for every candidate column count
it tracks each column's width (name length plus a two-space gap, except in
the last column, minimum 3) and the line length, and keeps the largest count
whose line stays strictly shorter than the width. `layout_columns` walks the
rows and pads with `indent`, which emits a tab whenever the next tab stop
does not pass the target column. The widths of all candidates live in one
flat list (candidate i at offset i(i+1)/2).

### File kinds without stat()

`io.fs` follows symbolic links and has no `lstat`, so `fsinfo` derives kinds:

- `isDir` / `isFile` / `exists` give directory, file, or "something else".
- A name that `listDir` shows but `exists` denies is a dangling link.
- A directory reached through a link is detected by listing `path/..`: the
  kernel resolves it to the parent of the link's target, so it lists
  different names from the directory holding `path` unless the link points
  to a sibling. -F marks detected links `@`, and -R does not descend into
  them, which also stops loops such as `up -> ..`.

## Differences from GNU ls

- No `-l`, `-t`, `-S`, `-h` or any other option that needs file metadata
  (T1), and no `-i`, `-s`, `-m`, `-x`, `-Q`, `--color`, `-w`, `-T`.
- Without a terminal check, the default format is one name per line (GNU's
  behaviour when the output is not a terminal); use -C for columns, and
  `--classify=auto` acts like `never`.
- `-F` cannot see links to files, executables, FIFOs or sockets: it marks
  only directories (`/`), dangling links and links to directories that are
  not siblings (`@`). A link to a sibling directory looks like a directory,
  gets `/`, and -R descends into it.
- Names are sorted by bytes (the C locale), and column widths count
  characters, not display cells.
- An unreadable directory lists as empty in the native build (its `listDir`
  cannot report the error).
- Names are printed as they are (GNU quotes unusual names on a terminal), and
  messages use ASCII quotes.

## Error handling

Missing operands are reported in command-line order with status 2. A
directory whose listing throws (only under the Stage0 interpreter) is
reported as `cannot open directory` with status 2 for an operand and 1 for a
subdirectory. Usage errors exit 2, a bad `--classify` argument 1. An
unexpected exception is reported by `run()` with status 1.

## Testing

- `tests/args_test.loup`: clusters, last-wins pairs, permutation, `--`, long
  prefixes, ambiguity, `--classify=WHEN`.
- `tests/columns_test.loup`: `indent`, `fit_columns`, the GNU layout for a
  known set of names, no-limit and narrow widths.
- `tests/ls_test.loup`: `COLUMNS` parsing, hidden names, sorting, indicators,
  quoting, and listings of `tests/fixtures/tree`.
- `tests/app_test.loup`: exit statuses through `run()`.
- `tests/e2e.sh`: builds trees under `$TMP` (dangling link, link to `..`,
  links elsewhere and to a sibling) and checks the native binary's output,
  messages and statuses, including byte-exact `-C` layouts.
