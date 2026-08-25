#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
GUARD=$ROOT/scripts/pmos-safe-upgrade
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/pmos-update-guard-test.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT HUP INT TERM

world=$TEST_DIR/world
printf '%s\n' 'advanced-snapshot><mock-r4' >"$world"

run_guard() {
	critical=$1
	marker=$2
	shift 2
	PMOS_UPDATE_APK=$ROOT/tests/fixtures/update-apk \
	PMOS_UPDATE_SUDO=$ROOT/tests/fixtures/update-sudo \
	PMOS_UPDATE_WORLD=$world \
	PMOS_UPDATE_EVIDENCE_DIR=$TEST_DIR/evidence \
	PMOS_MOCK_UPDATE_CRITICAL=$critical \
	PMOS_MOCK_UPDATE_APPLIED=$marker \
		"$GUARD" "$@"
}

# A normal upgrade that leaves the camera stack untouched is safe to apply.
run_guard no "$TEST_DIR/applied" --apply >"$TEST_DIR/safe.out"
grep -q '^critical=none$' "$TEST_DIR/safe.out"
grep -q '^result=applied$' "$TEST_DIR/safe.out"
[ -f "$TEST_DIR/applied" ]

# A critical package change is blocked before the apply phase.
if run_guard yes "$TEST_DIR/blocked" --apply \
	>"$TEST_DIR/blocked.out" 2>"$TEST_DIR/blocked.err"; then
	printf '%s\n' 'safe upgrade allowed a camera-critical transaction' >&2
	exit 1
fi
grep -q '^blocked-critical-packages=libcamera$' "$TEST_DIR/blocked.out"
grep -q 'refusing this upgrade' "$TEST_DIR/blocked.err"
[ ! -e "$TEST_DIR/blocked" ]

# Simulation remains the default and never applies the mock transaction.
run_guard no "$TEST_DIR/simulated" >"$TEST_DIR/simulate.out"
grep -q '^result=simulation-only$' "$TEST_DIR/simulate.out"
[ ! -e "$TEST_DIR/simulated" ]

printf '%s\n' 'postmarketOS update guard tests passed'
