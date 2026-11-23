#!/usr/bin/env bash
# Runs tests/run_tests.gd as several Godot processes in parallel and merges the results.
#
#   tests/run_fast.sh                 whole suite, 4 shards
#   JOBS=8 tests/run_fast.sh          8 shards
#   tests/run_fast.sh --skip-slow     any runner filter is passed through
#   tests/run_fast.sh --only=95,133   (--only, --match, --skip-slow)
#
# Environment: JOBS (default 4), SHARD_TIMEOUT in seconds per shard (default 600),
# GODOT (default: godot4 on PATH, else ~/.local/bin/godot4), LOG_DIR (default: a new
# temp directory; its path is printed). Each shard gets its own XDG_DATA_HOME, so
# shards never share user:// with each other or with a game that is running.
#
# Exit code 0 only if every shard passed, none timed out, no SCRIPT ERROR was
# printed, and the sections the shards ran add up to what --list says the filters select.
set -u

JOBS="${JOBS:-4}"
SHARD_TIMEOUT="${SHARD_TIMEOUT:-600}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-}"
if [ -z "$GODOT" ]; then
	if command -v godot4 >/dev/null 2>&1; then
		GODOT="godot4"
	else
		GODOT="$HOME/.local/bin/godot4"
	fi
fi
for arg in "$@"; do
	case "$arg" in
		--shard=*|--list)
			echo "run_fast.sh: $arg is set by the wrapper itself; pass it to run_tests.gd directly" >&2
			exit 2
			;;
	esac
done
case "$JOBS" in
	''|*[!0-9]*|0)
		echo "run_fast.sh: JOBS must be a positive number, got '$JOBS'" >&2
		exit 2
		;;
esac

LOG_DIR="${LOG_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/founders-tests.XXXXXX")}"
mkdir -p "$LOG_DIR"
started=$(date +%s)

run_godot() {
	# $1 = XDG_DATA_HOME, rest = runner arguments
	local data_home="$1"
	shift
	XDG_DATA_HOME="$data_home" timeout "$SHARD_TIMEOUT" "$GODOT" --headless --path "$REPO" --script tests/run_tests.gd -- "$@"
}

mkdir -p "$LOG_DIR/xdg-list"
run_godot "$LOG_DIR/xdg-list" --list "$@" > "$LOG_DIR/list.log" 2>&1
list_status=$?
expected=$(sed -n 's/^Sections listed: \([0-9]*\) of \([0-9]*\)$/\1/p' "$LOG_DIR/list.log")
all_sections=$(sed -n 's/^Sections listed: \([0-9]*\) of \([0-9]*\)$/\2/p' "$LOG_DIR/list.log")
if [ "$list_status" -ne 0 ] || [ -z "$expected" ]; then
	echo "run_fast.sh: could not list the sections (exit $list_status), see $LOG_DIR/list.log" >&2
	tail -n 5 "$LOG_DIR/list.log" >&2
	exit 2
fi

echo "Running $expected of $all_sections sections in $JOBS shards (logs in $LOG_DIR)"
pids=()
for ((k = 0; k < JOBS; k++)); do
	mkdir -p "$LOG_DIR/xdg-$k"
	run_godot "$LOG_DIR/xdg-$k" "--shard=$k/$JOBS" "$@" > "$LOG_DIR/shard-$k.log" 2>&1 &
	pids+=($!)
done

bad=0
passed_total=0
failed_total=0
sections_total=0
for ((k = 0; k < JOBS; k++)); do
	wait "${pids[$k]}"
	status=$?
	log="$LOG_DIR/shard-$k.log"
	passed=$(sed -n 's/^Tests Passed: \([0-9]*\) | Tests Failed: \([0-9]*\)$/\1/p' "$log")
	failed=$(sed -n 's/^Tests Passed: \([0-9]*\) | Tests Failed: \([0-9]*\)$/\2/p' "$log")
	sections=$(sed -n 's/^Sections run: \([0-9]*\) of .*$/\1/p' "$log")
	seconds=$(sed -n 's/^Sections run: .* Total time: \([0-9.]*\) s$/\1/p' "$log")
	data_dir=$(sed -n 's/^user data dir: //p' "$log")
	note="ok"
	if [ "$status" -eq 124 ]; then
		note="TIMED OUT after ${SHARD_TIMEOUT}s"
		bad=1
	elif [ "$status" -ne 0 ]; then
		note="FAILED (exit $status)"
		bad=1
	elif [ -z "$passed" ] || [ -z "$sections" ]; then
		note="NO RESULT LINE"
		bad=1
	fi
	case "$data_dir" in
		"$LOG_DIR/xdg-$k"/*) ;;
		*)
			note="$note; user data dir is not the shard's own: '$data_dir'"
			bad=1
			;;
	esac
	echo "  shard $k: ${sections:-?} sections, ${passed:-?} passed, ${failed:-?} failed, ${seconds:-?} s - $note"
	echo "           user data dir: $data_dir"
	passed_total=$((passed_total + ${passed:-0}))
	failed_total=$((failed_total + ${failed:-0}))
	sections_total=$((sections_total + ${sections:-0}))
done

fail_lines=$(grep -h '^\[FAIL\]' "$LOG_DIR"/shard-*.log)
error_lines=$(grep -h -A1 '^SCRIPT ERROR' "$LOG_DIR"/shard-*.log | grep -v '^--$')
if [ -n "$fail_lines" ]; then
	echo "Failed checks:"
	echo "$fail_lines" | sed 's/^/  /'
	bad=1
fi
if [ -n "$error_lines" ]; then
	echo "Script errors:"
	echo "$error_lines" | sed 's/^/  /'
	bad=1
fi
skipped=$(grep -h '^\[SKIP-SLOW\]' "$LOG_DIR"/shard-*.log)
if [ -n "$skipped" ]; then
	echo "Skipped as slow:"
	echo "$skipped" | sed 's/^/  /'
fi
echo "Slowest sections:"
grep -h '^  \[SLOW\]' "$LOG_DIR"/shard-*.log | sort -k2 -n -r | head -n 10

if [ "$sections_total" -ne "$expected" ]; then
	echo "SECTION COUNT MISMATCH: the shards ran $sections_total sections, --list selects $expected"
	bad=1
fi
if [ "$failed_total" -ne 0 ]; then
	bad=1
fi

filter_note=""
if [ "$expected" -ne "$all_sections" ]; then
	filter_note=" (filtered: $expected of $all_sections sections)"
fi
echo "======================================================"
echo "Sections run: $sections_total of $all_sections | Wall time: $(( $(date +%s) - started )) s | Shards: $JOBS"
echo "Tests Passed: $passed_total | Tests Failed: $failed_total"
if [ "$bad" -ne 0 ]; then
	echo "RESULT: FAILED$filter_note"
	exit 1
fi
echo "RESULT: ALL TESTS PASSED$filter_note"
exit 0
