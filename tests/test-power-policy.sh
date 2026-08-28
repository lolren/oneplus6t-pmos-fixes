#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
POLICY=$ROOT/scripts/configure-power
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/power-policy-test.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT HUP INT TERM

FAKE_GSETTINGS=$TEST_DIR/gsettings
STORE=$TEST_DIR/settings.tsv
cat > "$STORE" <<'EOF'
idle-dim	false
power-saver-profile-on-low-battery	false
sleep-inactive-battery-timeout	900
sleep-inactive-battery-type	'nothing'
sleep-inactive-ac-timeout	uint32 1200
sleep-inactive-ac-type	'nothing'
EOF

cat > "$FAKE_GSETTINGS" <<'EOF'
#!/bin/sh
set -eu

operation=$1
schema=$2
key=$3
[ "$schema" = org.gnome.settings-daemon.plugins.power ]
case "$operation" in
get)
	awk -F '\t' -v key="$key" '$1 == key { print $2; found = 1; exit }
		END { exit found ? 0 : 1 }' "$PMOS_POWER_POLICY_TEST_STORE"
	;;
set)
	value=$4
	tmp=$PMOS_POWER_POLICY_TEST_STORE.tmp
	awk -F '\t' -v key="$key" -v value="$value" 'BEGIN { OFS = "\t" }
		$1 == key { print key, value; found = 1; next }
		{ print }
		END { if (!found) print key, value }' \
		"$PMOS_POWER_POLICY_TEST_STORE" > "$tmp"
	mv "$tmp" "$PMOS_POWER_POLICY_TEST_STORE"
	;;
*) exit 2 ;;
esac
EOF
chmod 0755 "$FAKE_GSETTINGS"
tab=$(printf '\t')

run_policy() {
	PMOS_POWER_POLICY_GSETTINGS=$FAKE_GSETTINGS \
	PMOS_POWER_POLICY_TEST_STORE=$STORE \
	PMOS_POWER_POLICY_STATE_ROOT=$TEST_DIR/state \
		"$POLICY" "$@"
}

dry_output=$(run_policy --dry-run --timeout 240)
printf '%s\n' "$dry_output" | grep -Fqx 'mode=dry-run'
printf '%s\n' "$dry_output" | grep -Fqx \
	'current_sleep-inactive-battery-timeout=900'
printf '%s\n' "$dry_output" | grep -Fqx \
	'desired_sleep-inactive-battery-timeout=240'
grep -Fqx "sleep-inactive-battery-type${tab}'nothing'" "$STORE"

apply_output=$(run_policy --apply --timeout 240)
printf '%s\n' "$apply_output" | grep -Fqx 'result=applied'
grep -Fqx 'idle-dim	true' "$STORE"
grep -Fqx 'power-saver-profile-on-low-battery	true' "$STORE"
grep -Fqx 'sleep-inactive-battery-timeout	240' "$STORE"
grep -Fqx "sleep-inactive-battery-type${tab}'suspend'" "$STORE"
grep -Fqx 'sleep-inactive-ac-timeout	uint32 1200' "$STORE"
grep -Fqx "sleep-inactive-ac-type${tab}'nothing'" "$STORE"
[ "$(stat -c %a "$TEST_DIR/state")" = 700 ]
[ "$(stat -c %a "$TEST_DIR/state/power-policy.tsv")" = 600 ]

if run_policy --apply --timeout 240 >/dev/null 2>&1; then
	printf '%s\n' 'second apply unexpectedly replaced rollback state' >&2
	exit 1
fi

rollback_output=$(run_policy --rollback)
printf '%s\n' "$rollback_output" | grep -Fqx 'result=rolled-back'
grep -Fqx 'idle-dim	false' "$STORE"
grep -Fqx 'power-saver-profile-on-low-battery	false' "$STORE"
grep -Fqx 'sleep-inactive-battery-timeout	900' "$STORE"
grep -Fqx "sleep-inactive-battery-type${tab}'nothing'" "$STORE"
[ ! -e "$TEST_DIR/state/power-policy.tsv" ]

for invalid in 0 59 3601 nope; do
	if run_policy --dry-run --timeout "$invalid" >/dev/null 2>&1; then
		printf 'invalid timeout unexpectedly accepted: %s\n' "$invalid" >&2
		exit 1
	fi
done

printf '%s\n' 'power policy tests passed'
