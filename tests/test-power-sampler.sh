#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SAMPLER=$ROOT/scripts/measure-power
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/power-sampler-test.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT HUP INT TERM

mkdir -p "$TEST_DIR/sys/class/power_supply/BAT0"
printf '%s\n' Battery >"$TEST_DIR/sys/class/power_supply/BAT0/type"
printf '%s\n' Discharging >"$TEST_DIR/sys/class/power_supply/BAT0/status"
printf '%s\n' 73 >"$TEST_DIR/sys/class/power_supply/BAT0/capacity"
printf '%s\n' -450000 >"$TEST_DIR/sys/class/power_supply/BAT0/current_now"
printf '%s\n' 3800000 >"$TEST_DIR/sys/class/power_supply/BAT0/voltage_now"
printf '%s\n' 300 >"$TEST_DIR/sys/class/power_supply/BAT0/temp"

output=$TEST_DIR/samples.txt
PMOS_POWER_SYSFS_ROOT="$TEST_DIR/sys" \
	"$SAMPLER" --duration 0 --interval 1 --output "$output"
grep -Fqx 'supply=BAT0' "$output"
grep -q '^sample=0 elapsed_seconds=0 ' "$output"
grep -Fqx 'capacity_start_percent=73' "$output"
grep -Fqx 'capacity_end_percent=73' "$output"
grep -Fqx 'capacity_delta_percent=0' "$output"
grep -Fqx 'current_mean_ua=-450000' "$output"
grep -Fqx 'temperature_max_tenths_c=300' "$output"
grep -Fqx 'note=read-only sampling; no power or suspend setting is changed' "$output"

printf '%s\n' 'power sampler tests passed'
