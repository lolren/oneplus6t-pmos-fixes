#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT=$ROOT/scripts/configure-daily-use
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/daily-use-test.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT HUP INT TERM

make_mock() {
	name=$1
	path=$TEST_DIR/$name
	cat >"$path" <<'EOF'
#!/bin/sh
printf '%s %s\n' "$(basename "$0")" "$*" >>"$PMOS_DAILY_TEST_LOG"
exit 0
EOF
	chmod 0755 "$path"
}

make_mock mobile
make_mock time
make_mock systemctl

dry_log=$TEST_DIR/dry.log
dry_output=$(PMOS_DAILY_MOBILE_COMMAND=$TEST_DIR/mobile \
	PMOS_DAILY_TIME_COMMAND=$TEST_DIR/time \
	PMOS_DAILY_SYSTEMCTL=$TEST_DIR/systemctl \
	PMOS_DAILY_TEST_LOG=$dry_log \
	"$SCRIPT" --operator-code 23420 --gid1 0309 --timezone Europe/London)
printf '%s\n' "$dry_output" | grep -q '^mode=dry-run$'
printf '%s\n' "$dry_output" | grep -q 'would-run=configure-mobile-data --dry-run'
printf '%s\n' "$dry_output" | grep -q 'would-run=configure-time-sync --timezone Europe/London'
printf '%s\n' "$dry_output" | grep -q 'would-run=systemctl --user enable --now oneplus6t-audio-route.service'
grep -q '^mobile --dry-run --operator-code 23420 --gid1 0309$' "$dry_log"
[ "$(wc -l <"$dry_log" | tr -d ' ')" -eq 1 ]

apply_log=$TEST_DIR/apply.log
apply_output=$(PMOS_DAILY_MOBILE_COMMAND=$TEST_DIR/mobile \
	PMOS_DAILY_TIME_COMMAND=$TEST_DIR/time \
	PMOS_DAILY_SYSTEMCTL=$TEST_DIR/systemctl \
	PMOS_DAILY_SUDO=env \
	PMOS_DAILY_TEST_LOG=$apply_log \
	"$SCRIPT" --apply --operator-code 23420 --gid1 0309 --timezone Europe/London)
printf '%s\n' "$apply_output" | grep -q '^mode=apply$'
grep -q '^mobile --operator-code 23420 --gid1 0309$' "$apply_log"
grep -q '^time --timezone Europe/London$' "$apply_log"
grep -q '^systemctl --user daemon-reload$' "$apply_log"
grep -q '^systemctl --user enable --now oneplus6t-audio-route.service$' "$apply_log"

if PMOS_DAILY_MOBILE_COMMAND=$TEST_DIR/mobile \
	PMOS_DAILY_TIME_COMMAND=$TEST_DIR/time \
	PMOS_DAILY_SYSTEMCTL=$TEST_DIR/systemctl \
	PMOS_DAILY_SUDO=env \
	PMOS_DAILY_TEST_LOG=$TEST_DIR/invalid.log \
	"$SCRIPT" --apply --skip-mobile-data --skip-time-sync --skip-audio \
	>/dev/null 2>&1; then
	printf '%s\n' 'all-skipped invocation unexpectedly succeeded' >&2
	exit 1
fi

printf '%s\n' 'daily-use setup tests passed'
