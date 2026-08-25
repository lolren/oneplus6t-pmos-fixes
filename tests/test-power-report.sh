#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
REPORT=$ROOT/scripts/check-power
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/power-report-test.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT HUP INT TERM

mkdir -p "$TEST_DIR/sys/class/power_supply/BAT0"
mkdir -p "$TEST_DIR/sys/devices/system/cpu/cpufreq/policy0"
mkdir -p "$TEST_DIR/sys/power"
printf '%s\n' Battery >"$TEST_DIR/sys/class/power_supply/BAT0/type"
printf '%s\n' Discharging >"$TEST_DIR/sys/class/power_supply/BAT0/status"
printf '%s\n' 73 >"$TEST_DIR/sys/class/power_supply/BAT0/capacity"
printf '%s\n' Good >"$TEST_DIR/sys/class/power_supply/BAT0/health"
printf '%s\n' 4200000 >"$TEST_DIR/sys/class/power_supply/BAT0/charge_full_design"
printf '%s\n' schedutil >"$TEST_DIR/sys/devices/system/cpu/cpufreq/policy0/scaling_governor"
printf '%s\n' 'performance powersave schedutil' >"$TEST_DIR/sys/devices/system/cpu/cpufreq/policy0/scaling_available_governors"
printf '%s\n' 's2idle [deep]' >"$TEST_DIR/sys/power/mem_sleep"
printf '%s\n' 'mem cpu' >"$TEST_DIR/sys/power/state"

output=$TEST_DIR/report.txt
PMOS_POWER_SYSFS_ROOT="$TEST_DIR/sys" \
	PMOS_POWER_PROC_ROOT="$TEST_DIR/proc" \
	"$REPORT" --output "$output"
grep -Fqx 'capacity_percent=73 ' "$output"
grep -Fqx 'health=Good ' "$output"
grep -Fqx 'governor=schedutil ' "$output"
grep -Fqx 'memory_sleep_modes=s2idle [deep] ' "$output"
grep -q '^note=report is observational;' "$output"

printf '%s\n' 'power report tests passed'
