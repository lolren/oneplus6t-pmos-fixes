#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
REPORT=$ROOT/scripts/check-device-session
BIN=$ROOT/tests/fixtures/transport-bin
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/device-session-test.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT HUP INT TERM

[ -x "$REPORT" ]
sh -n "$REPORT"
output=$TEST_DIR/pass.txt
env \
	PMOS_SESSION_SSH="$BIN/ssh" \
	PMOS_SESSION_TIMEOUT_COMMAND=/bin/timeout \
	PMOS_SESSION_USER=user \
	"$REPORT" --ip 172.16.42.1 --timeout 2 --output "$output"
grep -Fqx 'ssh_status=0' "$output"
grep -Fqx 'ssh_session=pass' "$output"
grep -Fqx 'assessment=command-channel-usable' "$output"

if env \
	PMOS_SESSION_SSH="$BIN/ssh" \
	PMOS_SESSION_TIMEOUT_COMMAND=/bin/timeout \
	PMOS_SESSION_USER=user \
	"$REPORT" --output "$output" >/dev/null 2>&1; then
	printf '%s\n' 'session probe unexpectedly overwrote an existing output' >&2
	exit 1
fi

timeout_output=$TEST_DIR/timeout.txt
if env \
	PMOS_TRANSPORT_FIXTURE_SSH=timeout \
	PMOS_SESSION_SSH="$BIN/ssh" \
	PMOS_SESSION_TIMEOUT_COMMAND=/bin/timeout \
	PMOS_SESSION_USER=user \
	"$REPORT" --timeout 1 --output "$timeout_output"; then
	printf '%s\n' 'stalled session unexpectedly passed' >&2
	exit 1
fi
grep -Fqx 'ssh_status=124' "$timeout_output"
grep -Fqx 'ssh_session=timeout' "$timeout_output"
grep -Fqx 'assessment=authenticated-channel-stalled' "$timeout_output"

fail_output=$TEST_DIR/fail.txt
if env \
	PMOS_TRANSPORT_FIXTURE_SSH=fail \
	PMOS_SESSION_SSH="$BIN/ssh" \
	PMOS_SESSION_TIMEOUT_COMMAND=/bin/timeout \
	PMOS_SESSION_USER=user \
	"$REPORT" --output "$fail_output"; then
	printf '%s\n' 'failed session unexpectedly passed' >&2
	exit 1
fi
grep -Fqx 'ssh_session=auth-or-client-failure' "$fail_output"

printf '%s\n' 'device authenticated-session tests passed'
