#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CHECK=$ROOT/scripts/check-mobile-data
DISPATCH=$ROOT/tests/fixtures/mobile-check-command
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/mobile-check-test.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT HUP INT TERM

BIN=$TEST_DIR/bin
LOG=$TEST_DIR/commands.log
mkdir -p "$BIN"
: >"$LOG"
for command_name in nmcli mmcli ip ping curl resolvectl; do
	ln -s "$DISPATCH" "$BIN/$command_name"
done

output=$(PMOS_MOBILE_CHECK_FIXTURE_LOG=$LOG \
	PATH="$BIN:/usr/bin:/bin" sh "$CHECK")

printf '%s\n' "$output" | grep -q '^data_interface=qmapmux0.0$'
printf '%s\n' "$output" | grep -q '^ipv4_ping=ok$'
printf '%s\n' "$output" | grep -q '^dns=ok$'
printf '%s\n' "$output" | grep -q '^https=ok$'
grep -q '^ip|-4 route show table all default dev qmapmux0.0$' "$LOG"

deferred=$(PMOS_MOBILE_CHECK_FIXTURE_LOG=$LOG \
	PMOS_TEST_RESOLVECTL_FAIL=yes \
	PATH="$BIN:/usr/bin:/bin" sh "$CHECK")
printf '%s\n' "$deferred" | \
	grep -q '^dns=deferred (cellular is not system default)$'
printf '%s\n' "$deferred" | grep -q '^https=ok$'

printf '%s\n' 'mobile-data policy-route check tests passed'
