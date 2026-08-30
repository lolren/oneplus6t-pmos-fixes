#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
REPORT=$ROOT/scripts/check-nfc
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/nfc-report-test.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT HUP INT TERM

mkdir -p "$TEST_DIR/sys/class/nfc/nfc0" "$TEST_DIR/sys/class/rfkill/rfkill1"
mkdir -p "$TEST_DIR/dev"
output=$TEST_DIR/report.txt
PMOS_NFC_SYSFS_ROOT="$TEST_DIR/sys" \
	PMOS_NFC_DEV_ROOT="$TEST_DIR/dev" \
PMOS_NFC_RFKILL="$ROOT/tests/fixtures/nfc-rfkill" \
	PMOS_NFC_SYSTEMCTL=/missing/systemctl \
	PMOS_NFC_LIST=/missing/nfc-list \
	PMOS_NFC_POLL=/missing/nfc-poll \
	PMOS_NFC_TOOL=/missing/nfctool \
	"$REPORT" --output "$output"
grep -Fqx 'nfc_class=nfc0' "$output"
grep -Fqx 'rfkill_class=rfkill1' "$output"
grep -Fqx 'nfc-list=unavailable' "$output"
grep -Fqx 'nfctool=unavailable' "$output"
grep -Fqx 'poll=disabled (read-only inspection only)' "$output"
grep -q '^note=controller detection, rfkill state' "$output"

poll_output=$TEST_DIR/poll.txt
PMOS_NFC_SYSFS_ROOT="$TEST_DIR/sys" \
	PMOS_NFC_DEV_ROOT="$TEST_DIR/dev" \
	PMOS_NFC_RFKILL="$ROOT/tests/fixtures/nfc-rfkill" \
	PMOS_NFC_SYSTEMCTL=/missing/systemctl \
	PMOS_NFC_LIST=/missing/nfc-list \
	PMOS_NFC_POLL=/missing/nfc-poll \
	PMOS_NFC_TOOL="$ROOT/tests/fixtures/nfctool" \
	PMOS_NFC_POLL_PRIVILEGED=yes \
	"$REPORT" --poll >"$poll_output"
grep -Fqx 'nfctool=available' "$poll_output"
grep -Fqx 'nfctool_device=nfc0' "$poll_output"
grep -Fqx 'poll_backend=nfctool' "$poll_output"
grep -Fqx 'poll_device=nfc0' "$poll_output"
grep -Fqx 'target: UID 04:11:22:33:44:55:66' "$poll_output"

unprivileged_output=$TEST_DIR/unprivileged.txt
PMOS_NFC_SYSFS_ROOT="$TEST_DIR/sys" \
	PMOS_NFC_DEV_ROOT="$TEST_DIR/dev" \
	PMOS_NFC_RFKILL="$ROOT/tests/fixtures/nfc-rfkill" \
	PMOS_NFC_SYSTEMCTL=/missing/systemctl \
	PMOS_NFC_LIST=/missing/nfc-list \
	PMOS_NFC_POLL=/missing/nfc-poll \
	PMOS_NFC_TOOL="$ROOT/tests/fixtures/nfctool" \
	PMOS_NFC_POLL_PRIVILEGED=no \
	"$REPORT" --poll >"$unprivileged_output"
grep -Fqx 'poll=requires-root' "$unprivileged_output"
grep -Fqx 'poll_note=run this check with sudo to change NFC adapter state' "$unprivileged_output"

printf '%s\n' 'nfc report tests passed'
