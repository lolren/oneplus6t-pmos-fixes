#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
REPORT=$ROOT/scripts/check-device-transport
BIN=$ROOT/tests/fixtures/transport-bin
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/device-transport-test.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT HUP INT TERM

mkdir -p "$TEST_DIR/sys/class/net/enxfixture"
output=$TEST_DIR/report.txt
env \
	PMOS_TRANSPORT_SYSFS_ROOT="$TEST_DIR/sys" \
	PMOS_TRANSPORT_UDEVADM="$BIN/udevadm" \
	PMOS_TRANSPORT_IP_COMMAND="$BIN/ip" \
	PMOS_TRANSPORT_PING="$BIN/ping" \
	PMOS_TRANSPORT_NC="$BIN/nc" \
	PMOS_TRANSPORT_ADB="$BIN/adb" \
	PMOS_TRANSPORT_FASTBOOT="$BIN/fastboot" \
	"$REPORT" --ip 172.16.42.1 --output "$output"
grep -Fqx 'oneplus_usb=pass' "$output"
grep -Fqx 'oneplus_usb_interface=enxfixture' "$output"
grep -Fqx 'oneplus_usb_driver=cdc_ncm' "$output"
grep -Fqx 'transport_mode=postmarketos-usb-network' "$output"
grep -Fqx 'network_link=pass' "$output"
grep -Fqx 'network_address=pass' "$output"
grep -Fqx 'ping=pass' "$output"
grep -Fqx 'ssh_tcp=pass' "$output"
grep -Fqx 'ssh_probe=accepted' "$output"
grep -Fqx 'ssh_banner=pass' "$output"
grep -Fqx 'adb_devices=1' "$output"
grep -Fqx 'adb_oneplus=present' "$output"
grep -Fqx 'fastboot_devices=0' "$output"
grep -Fqx 'assessment=ssh-transport-usable' "$output"

if env \
	PMOS_TRANSPORT_SYSFS_ROOT="$TEST_DIR/sys" \
	PMOS_TRANSPORT_UDEVADM="$BIN/udevadm" \
	PMOS_TRANSPORT_IP_COMMAND="$BIN/ip" \
	PMOS_TRANSPORT_PING="$BIN/ping" \
	PMOS_TRANSPORT_NC="$BIN/nc" \
	PMOS_TRANSPORT_ADB="$BIN/adb" \
	PMOS_TRANSPORT_FASTBOOT="$BIN/fastboot" \
	"$REPORT" --output "$output" >/dev/null 2>&1; then
	printf '%s\n' 'transport report unexpectedly overwrote an existing output' >&2
	exit 1
fi

missing=$TEST_DIR/missing-banner.txt
env \
	PMOS_TRANSPORT_FIXTURE_NC=missing \
	PMOS_TRANSPORT_SYSFS_ROOT="$TEST_DIR/sys" \
	PMOS_TRANSPORT_UDEVADM="$BIN/udevadm" \
	PMOS_TRANSPORT_IP_COMMAND="$BIN/ip" \
	PMOS_TRANSPORT_PING="$BIN/ping" \
	PMOS_TRANSPORT_NC="$BIN/nc" \
	PMOS_TRANSPORT_ADB="$BIN/adb" \
	PMOS_TRANSPORT_FASTBOOT="$BIN/fastboot" \
	"$REPORT" --output "$missing"
grep -Fqx 'ssh_tcp=pass' "$missing"
grep -Fqx 'ssh_probe=accepted' "$missing"
grep -Fqx 'ssh_banner=missing' "$missing"
grep -Fqx 'assessment=network-up-ssh-not-speaking' "$missing"

printf '%s\n' 'device transport tests passed'
