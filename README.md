# loup-cmd-ls

GNU `ls` recreated in [Loup](https://code-craft.ai/references/loup): list
directory contents with `-a`, `-A`, `-1`, `-C`, `-R`, `-F`, `-r` and `-d`,
including GNU's exact column layout.

Part of the **loup-cmd** series of example applications: classic Linux and
Windows commands, and projects for each Loup execution mode, each in its own
repository under [myronccai](https://github.com/myronccai?tab=repositories&q=loup-cmd).
This one is `host.dual` Loup built as a native binary.

## Requirements

- [Loup Lite](https://github.com/code-craft-ai-company/loup-releases) 1.26.0
  or later; see [Installing Loup Lite](#installing-loup-lite).
- `make`, and `clang` 17 or later for the native build.

## Installing Loup Lite

This example is built and tested with **Loup Lite**, the free public build of
the Loup toolchain from [Code Craft AI](https://code-craft.ai), meant for
education and training. Code Craft AI publishes the official builds,
installers and signed checksums at
**<https://github.com/code-craft-ai-company/loup-releases>**, for Linux
(x86-64, arm64), macOS (Apple silicon, Intel) and Windows (x86-64).

Linux and macOS:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.sh | sh
```

Windows (PowerShell):

```powershell
irm https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.ps1 | iex
```

The installer picks the archive for your machine, checks it against the
release's `SHA256SUMS`, unpacks it into `~/.loup`
(`%LOCALAPPDATA%\Programs\Loup` on Windows) and puts its `bin` directory on
your `PATH`; it needs no administrator rights. You get `loup`, the Stage0
compiler `loup-bootstrap` and the Wasm runtime `loup-launcher`. Open a new
shell and check:

```sh
loup --version             # loup 1.26.0 or later
```

CI installs the exact version it tests with, 1.26.0. To do the same:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/download/v1.26.0/loup-install.sh | sh -s -- --version 1.26.0
```

To install by hand, download your platform's archive from the
[releases page](https://github.com/code-craft-ai-company/loup-releases/releases),
check it against `SHA256SUMS`, unpack it anywhere and add its `bin` directory to
`PATH`. The [loup-releases README](https://github.com/code-craft-ai-company/loup-releases#verify-a-download)
explains how to verify the Sigstore signature on `SHA256SUMS`.

Loup Lite leaves out Loup's cryptography library and the full set of Loup
packages; this example needs neither. The full release is at
<https://code-craft.ai/loup/download>, and commercial use of Loup needs a
license: <https://code-craft.ai/loup/license>.

## Usage

```sh
make build                    # native binary: build/ls
make ci                       # check, unit tests, build, end-to-end tests
make run ARGS="-F -R source"  # run from source with loup run
```

In a small project with a dot-file, a dangling symbolic link (`old-link`)
and a link back to its parent (`docs/up -> ..`):

```text
$ build/ls project
Makefile
README.md
docs
old-link
src
$ build/ls -A project
.gitignore
Makefile
README.md
docs
old-link
src
$ build/ls -F project
Makefile
README.md
docs/
old-link@
src/
$ build/ls -R project
project:
Makefile
README.md
docs
old-link
src

project/docs:
guide.md
up

project/src:
cli
main.loup

project/src/cli:
args.loup
$ build/ls -r project/src project/Makefile
project/Makefile

project/src:
main.loup
cli
$ build/ls nope project/Makefile
ls: cannot access 'nope': No such file or directory
project/Makefile
```

Columns, in this repository (the gaps are tabs and spaces, as GNU ls
prints them):

```text
$ build/ls -CF
AGENTS.md  README.md  package.lppkg  source/  tests/
Makefile   build/     skills/	     specs/
$ COLUMNS=40 build/ls -C source/commands tests
source/commands:
columns.loup  ls.loup
fsinfo.loup   quote.loup

tests:
app_test.loup	   e2e.sh
args_test.loup	   fixtures
columns_test.loup  ls_test.loup
```

Options:

| Option | Meaning |
|---|---|
| `-a`, `--all` | show entries starting with `.`, including `.` and `..` |
| `-A`, `--almost-all` | show entries starting with `.`, except `.` and `..` |
| `-1` | one name per line (the default) |
| `-C` | columns, filled top to bottom, sized to `COLUMNS` (default 80; 0 = no limit) |
| `-d`, `--directory` | list directories themselves, not their contents |
| `-F`, `--classify[=WHEN]` | append `/` to directories and `@` to recognised symbolic links; WHEN is `always`, `never` or `auto` |
| `-r`, `--reverse` | reverse the order |
| `-R`, `--recursive` | list subdirectories recursively, depth first |
| `--help`, `--version` | print help or the version and exit |

Options may appear anywhere, combine (`-aRF`), and long options may be
abbreviated (`--rec`). `--` ends the options.

Exit status: `0` if OK, `1` for minor problems (a subdirectory that cannot
be read; a bad `--classify` argument), `2` for serious trouble (an operand
that cannot be accessed; a usage error).

## Differences from GNU ls

Loup 1.26.0's `io.fs` has no `stat()` or `lstat()`: it can tell files from
directories but sees nothing else, and it follows symbolic links.

- No `-l`, `-t`, `-S`, `-h` or any other option that needs sizes, times,
  owners or permissions, and no `-i`, `-s`, `-m`, `-x`, `-Q`, `--color`,
  `-w` or `-T`.
- There is no way to ask whether standard output is a terminal, so the
  default is one name per line (what GNU ls does when its output is piped);
  pass `-C` for columns. `--classify=auto` acts like `never`.
- `-F` marks directories `/` and only the symbolic links it can recognise
  `@`: dangling links, and links to directories that are not siblings of the
  link (found by checking that `link/..` is not the link's own directory).
  Links to files get no `@`, executables no `*`, FIFOs and sockets no `|` or
  `=`. A link to a sibling directory (`same -> real`) is shown as a
  directory, and `-R` descends into it. Links to `.` or `..` are recognised,
  so `-R` cannot loop on them.
- Names are sorted by their bytes, as in the C locale (`LC_ALL=C ls`), and
  column widths count characters rather than display cells.
- In the native build an unreadable directory lists as empty instead of
  giving `cannot open directory` (its `listDir` returns no error).
- Names are printed as they are; GNU quotes unusual names on a terminal.
  Messages use ASCII quotes (`'name'`), as GNU does in the C locale.

## Layout

```text
source/main.loup               # entry point
source/appinfo.loup            # name, version, exit statuses
source/cli/args.loup           # GNU getopt_long-style option parsing
source/cli/usage.loup          # --help and --version text
source/cli/app.loup            # run(): parse, dispatch, exit status
source/commands/ls.loup        # operands, directories, -R, output
source/commands/columns.loup   # GNU's -C column layout
source/commands/fsinfo.loup    # file kinds without stat(): links, dangling links
source/commands/quote.loup     # GNU-style quoting of names in messages
tests/*_test.loup              # unit tests (make test)
tests/fixtures/tree/           # a small tree for the unit tests
tests/e2e.sh                   # end-to-end tests of build/ls (make e2e)
specs/ls/                      # requirements, design, tasks
```

[AGENTS.md](AGENTS.md) has every build and test command and the conventions
for changing the code.

## License

[MIT](LICENSE), copyright 2026 Code Craft AI LLC. The Loup skill in
[`skills/loup-programmer/`](skills/loup-programmer/) is copied from the Loup
project and is not covered by this license; it keeps the Loup project's terms.
