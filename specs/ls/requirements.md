# Requirements: ls

## Introduction

`ls` lists directory contents. This repository recreates the GNU coreutils
`ls` in Loup for the options that need only names and file kinds: hidden
entries (`-a`, `-A`), one name per line (`-1`) or columns (`-C`), recursion
(`-R`), the `-F` indicator, reverse order (`-r`) and listing directories
themselves (`-d`). Loup 1.26.0's `io.fs` has no `stat()`, so long listings
and every option that needs sizes, times or permissions (`-l`, `-t`, `-S`,
`-h`) are out of scope.

## Requirements

### Requirement 1: Operands

**User Story:** As a shell user, I want to name files and directories so that
I can list exactly what I need.

#### Acceptance Criteria

1. WHEN ls is run without operands, THE program SHALL list the current
   directory.
2. WHEN operands are given, THE program SHALL list the operands that are not
   directories first (sorted by name), then the contents of each directory
   operand (sorted by name).
3. WHEN there is more than one operand, or a file operand is listed, or -R is
   given, THE program SHALL print each directory's name followed by `:`
   before its contents, and separate the blocks with an empty line.
4. WHEN an operand does not exist, THE program SHALL print
   `ls: cannot access 'NAME': No such file or directory` (or `Not a
   directory` when a component is a file), list the other operands, and exit
   with status 2.
5. WHEN an operand is a dangling symbolic link, THE program SHALL list its
   name.

### Requirement 2: Which entries are shown

**User Story:** As a shell user, I want to control hidden entries so that I
see dot-files only when I ask.

#### Acceptance Criteria

1. THE program SHALL omit entries whose names start with `.` by default.
2. WHEN -A is given, THE program SHALL show them, except `.` and `..`.
3. WHEN -a is given, THE program SHALL show them, including `.` and `..`.
4. WHEN both -a and -A are given, THE last one SHALL win.
5. WHEN -d is given, THE program SHALL list directory operands themselves
   instead of their contents (`.` when there are no operands).

### Requirement 3: Order and format

**User Story:** As a shell user, I want predictable sorting and a compact
column view.

#### Acceptance Criteria

1. THE program SHALL sort entries by the bytes of their names (the C
   locale's order); WHEN -r is given, in reverse.
2. THE program SHALL print one name per line by default and with -1.
3. WHEN -C is given, THE program SHALL arrange names in columns, filled top
   to bottom, using GNU ls's algorithm: as many columns as fit strictly
   within the line width, each as wide as its longest name plus two spaces,
   padded with tabs (stops every 8 columns) and spaces.
4. THE line width SHALL come from `COLUMNS` (80 when unset or empty; 0 means
   no limit). WHEN `COLUMNS` is not a number and -C is in effect, THE program
   SHALL warn `ls: ignoring invalid width in environment variable COLUMNS:
   'VALUE'` and use 80.
5. WHEN both -1 and -C are given, THE last one SHALL win.

### Requirement 4: Indicators and recursion

**User Story:** As a shell user, I want to see which entries are directories
and to list a whole tree.

#### Acceptance Criteria

1. WHEN -F (or `--classify`, `--classify=always`) is given, THE program SHALL
   append `/` to directories and `@` to symbolic links it can recognise
   (dangling links and links to directories elsewhere).
2. WHEN -F is given, THE program SHALL show a command-line operand that is a
   recognised link to a directory as the link itself; otherwise it SHALL list
   the target directory's contents.
3. WHEN -R is given, THE program SHALL list every subdirectory after its
   parent, depth first, with a header, and SHALL NOT descend into `.`, `..`
   or recognised links to directories.

### Requirement 5: Command line

**User Story:** As a shell user, I want GNU's option syntax and exit
statuses.

#### Acceptance Criteria

1. THE program SHALL accept options anywhere among the operands, combined
   short options (`-aRF`), `--` to end options, and the long options `--all`,
   `--almost-all`, `--directory`, `--classify[=WHEN]`, `--recursive`,
   `--reverse`, `--help` and `--version`, abbreviated to any unambiguous
   prefix.
2. WHEN an option is unknown, ambiguous or given an argument it does not
   take, THE program SHALL print GNU's message and `Try 'ls --help' for more
   information.` on standard error and exit with status 2.
3. WHEN `--classify` gets an invalid or ambiguous WHEN, THE program SHALL
   print the valid arguments and exit with status 1.
4. THE program SHALL exit with 0 on success, 1 for minor problems (a
   subdirectory that cannot be read) and 2 for serious trouble (an operand
   that cannot be accessed).
