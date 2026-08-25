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
	"$REPORT" --output "$output"
grep -Fqx 'nfc_class=nfc0' "$output"
grep -Fqx 'rfkill_class=rfkill1' "$output"
grep -Fqx 'nfc-list=unavailable' "$output"
grep -Fqx 'poll=disabled (read-only inspection only)' "$output"
grep -q '^note=controller detection, rfkill state' "$output"

printf '%s\n' 'nfc report tests passed'
