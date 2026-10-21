#!/usr/bin/env bash
# End-to-end tests: run the built binary and compare its standard output
# (byte for byte), standard error and exit status with the expected ones.
# Every case runs inside a fixture tree built under $TMP.
#
# usage: tests/e2e.sh BINARY

set -u
BIN=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
unset COLUMNS
pass=0
fail=0

# check_file NAME STATUS EXPECTED_FILE [ARGS...]
# Runs BINARY ARGS... with standard input from the file named by $IN
# (default: /dev/null) and compares standard output with EXPECTED_FILE.
check_file() {
    local name=$1 want_status=$2 want_file=$3
    shift 3
    "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
    local status=$?
    if [ "$status" -eq "$want_status" ] && cmp -s "$want_file" "$TMP/out"; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff <(od -c "$want_file") <(od -c "$TMP/out") | sed 's/^/    /' | head -20
        sed 's/^/    stderr: /' "$TMP/err" | head -5
    fi
}

# check NAME STATUS EXPECTED_STDOUT [ARGS...]
# As check_file, with the expected output given as a string.
check() {
    local name=$1 want_status=$2
    printf '%s' "$3" > "$TMP/want"
    shift 3
    check_file "$name" "$want_status" "$TMP/want" "$@"
}

# check_err NAME STATUS EXPECTED_STDERR [ARGS...]
# Runs BINARY ARGS... and compares standard error (without its final
# newline) and the exit status.
check_err() {
    local name=$1 want_status=$2 want_err=$3
    shift 3
    "$BIN" "$@" < /dev/null > "$TMP/out" 2> "$TMP/err"
    local status=$?
    if [ "$status" -eq "$want_status" ] && [ "$(cat "$TMP/err")" = "$want_err" ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        echo "    expected stderr: $want_err"
        sed 's/^/    actual stderr:   /' "$TMP/err" | head -5
    fi
}

# The fixture tree:
#   tree/  alpha beta .hidden  dangling -> nowhere
#          dir/  one two .dot  up -> ..  sub/deep
#          empty/
#   cols/  sixteen files for the column layout
#   links/ real/file  same -> real  far -> ../tree/dir
mkdir -p "$TMP/tree/dir/sub" "$TMP/tree/empty" "$TMP/cols" "$TMP/links/real"
touch "$TMP/tree/alpha" "$TMP/tree/beta" "$TMP/tree/.hidden" \
      "$TMP/tree/dir/one" "$TMP/tree/dir/two" "$TMP/tree/dir/.dot" \
      "$TMP/tree/dir/sub/deep" "$TMP/links/real/file"
ln -s nowhere "$TMP/tree/dangling"
ln -s .. "$TMP/tree/dir/up"
ln -s real "$TMP/links/same"
ln -s ../tree/dir "$TMP/links/far"
for n in eight eleven five four longername_here nine one self seven six sub \
         ten three twelve two x; do
    touch "$TMP/cols/$n"
done
cd "$TMP/tree" || exit 1

# Listing a directory
check "default"            0 $'alpha\nbeta\ndangling\ndir\nempty\n'
check "-1"                 0 $'alpha\nbeta\ndangling\ndir\nempty\n' -1
check "-a"                 0 $'.\n..\n.hidden\nalpha\nbeta\ndangling\ndir\nempty\n' -a
check "-A"                 0 $'.hidden\nalpha\nbeta\ndangling\ndir\nempty\n' -A
check "-a then -A"         0 $'.hidden\nalpha\nbeta\ndangling\ndir\nempty\n' -aA
check "-r"                 0 $'empty\ndir\ndangling\nbeta\nalpha\n' -r
check "-F"                 0 $'alpha\nbeta\ndangling@\ndir/\nempty/\n' -F
check "-aF"                0 $'./\n../\n.hidden\nalpha\nbeta\ndangling@\ndir/\nempty/\n' -aF
check "--classify=never"   0 $'alpha\nbeta\ndangling\ndir\nempty\n' --classify=never
check "one directory"      0 $'one\nsub\ntwo\nup\n' dir
check "empty directory"    0 '' empty
check "-a empty"           0 $'.\n..\n' -a empty
check "options after operand" 0 $'one\nsub/\ntwo\nup@\n' dir -F

# Several operands: files first, then each directory with a header
check "files then dirs"    0 $'alpha\nbeta\n\ndir:\none\nsub\ntwo\nup\n\nempty:\n' beta dir alpha empty
check "-r operands"        0 $'beta\nalpha\n\nempty:\n\ndir:\nup\ntwo\nsub\none\n' -r beta dir alpha empty
check "file operand"       0 $'dir/sub/deep\n' dir/sub/deep
check "dangling operand"   0 $'dangling\n' dangling
check "-F dangling"        0 $'dangling@\n' -F dangling

# -d
check "-d"                 0 $'.\n' -d
check "-dF"                0 $'alpha\ndir/\n' -dF dir alpha
check "-d -R"              0 $'dir\n' -dR dir

# -R: depth first; dir/up (a link to ..) is not followed
check "-R" 0 $'.:\nalpha\nbeta\ndangling\ndir\nempty\n\n./dir:\none\nsub\ntwo\nup\n\n./dir/sub:\ndeep\n\n./empty:\n' -R
check "-RF dir" 0 $'dir:\none\nsub/\ntwo\nup@\n\ndir/sub:\ndeep\n' -RF dir
check "-R trailing slash" 0 $'dir/:\none\nsub\ntwo\nup\n\ndir/sub:\ndeep\n' -R dir/
check "-Rr" 0 $'dir:\nup\ntwo\nsub\none\n\ndir/sub:\ndeep\n' -Rr dir
check "-aR empty" 0 $'empty:\n.\n..\n' -aR empty

# Symbolic links to directories (far, and same, a link to its sibling real)
# are told apart by `test -h`: -F marks them `@` and -R does not enter
# them, as GNU ls does; a link named on the command line is still followed.
check "-F links" 0 $'far@\nreal/\nsame@\n' -F ../links
check "link operand followed" 0 $'deep\n' ../links/far/sub
check "sibling link operand" 0 $'file\n' ../links/same
check "-F link operand"    0 $'../links/same@\n' -F ../links/same
check "-R links" 0 $'../links:\nfar\nreal\nsame\n\n../links/real:\nfile\n' -R ../links
check "-RF links" 0 $'../links:\nfar@\nreal/\nsame@\n\n../links/real:\nfile\n' -RF ../links

# -C: GNU's column layout, with tabs, sized from COLUMNS
COLUMNS=40 check "-C 40" 0 $'eight\tlongername_here  seven\tthree\neleven\tnine\t\t six\ttwelve\nfive\tone\t\t sub\ttwo\nfour\tself\t\t ten\tx\n' -C ../cols
COLUMNS=30 check "-C 30" 0 $'eight\t\t seven\neleven\t\t six\nfive\t\t sub\nfour\t\t ten\nlongername_here  three\nnine\t\t twelve\none\t\t two\nself\t\t x\n' -C ../cols
COLUMNS=20 check "-C 20" 0 $'eight\neleven\nfive\nfour\nlongername_here\nnine\none\nself\nseven\nsix\nsub\nten\nthree\ntwelve\ntwo\nx\n' -C ../cols
COLUMNS=0 check "-C no limit" 0 $'alpha  beta  dangling  dir  empty\n' -C
check "-C default 80" 0 $'eight\tfive  longername_here  one   seven  sub  three\t two\neleven\tfour  nine\t       self  six    ten  twelve  x\n' -C ../cols
check "-C then -1" 0 $'alpha\nbeta\ndangling\ndir\nempty\n' -C -1
check "-CF" 0 $'alpha  beta  dangling@\tdir/  empty/\n' -CF
COLUMNS=abc check "-C bad COLUMNS" 0 $'alpha  beta  dangling  dir  empty\n' -C
COLUMNS=abc check "-1 ignores COLUMNS" 0 $'alpha\n' alpha

# Errors and exit statuses
check "missing operand"    2 $'alpha\n' nope alpha
check_err "missing message" 2 "ls: cannot access 'nope': No such file or directory" nope
check_err "quoted name"    2 "ls: cannot access \"it's\": No such file or directory" "it's"
check_err "not a directory" 2 "ls: cannot access 'alpha/': Not a directory" alpha/
check_err "file in path"   2 "ls: cannot access 'alpha/x/y': Not a directory" alpha/x/y
COLUMNS=abc check_err "COLUMNS warning" 0 "ls: ignoring invalid width in environment variable COLUMNS: 'abc'" -C
check_err "invalid option" 2 $'ls: invalid option -- \'l\'\nTry \'ls --help\' for more information.' -l
check_err "unknown long"   2 $'ls: unrecognized option \'--bogus\'\nTry \'ls --help\' for more information.' --bogus
check_err "ambiguous"      2 $'ls: option \'--re\' is ambiguous; possibilities: \'--reverse\' \'--recursive\'\nTry \'ls --help\' for more information.' --re
check_err "no argument"    2 $'ls: option \'--all\' doesn\'t allow an argument\nTry \'ls --help\' for more information.' --all=1
check_err "bad WHEN"       1 $'ls: invalid argument \'x\' for \'--classify\'\nValid arguments are:\n  - \'always\', \'yes\', \'force\'\n  - \'never\', \'no\', \'none\'\n  - \'auto\', \'tty\', \'if-tty\'\nTry \'ls --help\' for more information.' --classify=x
check_err "-- ends options" 2 "ls: cannot access '-a': No such file or directory" -- -a

check "version"            0 $'ls (loup-cmd-ls) 0.1.0\n' --version
"$BIN" --help | head -1 > "$TMP/help"
if [ "$(cat "$TMP/help")" = "Usage: ls [OPTION]... [FILE]..." ]; then
    pass=$((pass + 1))
else
    fail=$((fail + 1))
    echo "FAIL: --help first line: $(cat "$TMP/help")"
fi

echo "e2e: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
