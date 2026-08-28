#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
REPORT=$ROOT/scripts/check-waydroid-vanilla
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/waydroid-vanilla-test.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT HUP INT TERM

FAKE_WAYDROID=$TEST_DIR/waydroid
cat > "$FAKE_WAYDROID" <<'EOF'
#!/bin/sh
set -eu

command_key=${1-}:${2-}:${3-}:${4-}:${5-}
case "$command_key" in
status::::)
	printf '%s\n' 'Session: RUNNING'
	;;
shell:--:getprop:ro.build.version.release:)
	printf '%s\n' '13'
	;;
shell:--:getprop:ro.build.version.incremental:)
	printf '%s\n' 'eng.example.20260403.000000'
	;;
shell:--:getprop:ro.build.version.security_patch:)
	printf '%s\n' '2026-02-01'
	;;
shell:--:getprop:ro.product.cpu.abilist:)
	printf '%s\n' 'arm64-v8a,armeabi-v7a,armeabi'
	;;
shell:--:getprop:ro.lineage.version:)
	printf '%s\n' '20.0-20260403-VANILLA-waydroid_arm64'
	;;
shell:--:getprop:ro.lineage.releasetype:)
	printf '%s\n' "${FAKE_RELEASE_TYPE:-VANILLA}"
	;;
shell:--:getprop:ro.com.google.gmsversion:)
	[ "${FAKE_WAYDROID_MODE:-vanilla}" != gms-property ] || printf '%s\n' '13_2026'
	;;
shell:--:pm:path:android)
	[ "${FAKE_WAYDROID_MODE:-vanilla}" != no-pm ] || exit 1
	printf '%s\n' 'package:/system/framework/framework-res.apk'
	;;
shell:--:pm:path:com.google.android.gms)
	[ "${FAKE_WAYDROID_MODE:-vanilla}" != gms-package ] ||
		printf '%s\n' 'package:/system/priv-app/GmsCore/GmsCore.apk'
	;;
shell:--:pm:path:com.google.android.gsf|shell:--:pm:path:com.android.vending)
	exit 1
	;;
*)
	printf 'unexpected fake waydroid command: %s\n' "$*" >&2
	exit 2
	;;
esac
EOF
chmod 0755 "$FAKE_WAYDROID"

verified=$TEST_DIR/verified.txt
PMOS_WAYDROID_VANILLA_WAYDROID="$FAKE_WAYDROID" \
	PMOS_WAYDROID_VANILLA_TIMEOUT=2 \
	"$REPORT" --output "$verified"
grep -Fqx 'status_exit=0' "$verified"
grep -Fqx 'lineage_release_type=VANILLA' "$verified"
grep -Fqx 'package_manager=ready' "$verified"
grep -Fqx 'gms=absent' "$verified"
grep -Fqx 'gsf=absent' "$verified"
grep -Fqx 'play_store=absent' "$verified"
grep -Fqx 'google_gms_property=absent' "$verified"
grep -Fqx 'vanilla=verified' "$verified"

for failure_mode in gms-package gms-property no-pm; do
	failed=$TEST_DIR/$failure_mode.txt
	if FAKE_WAYDROID_MODE=$failure_mode \
		PMOS_WAYDROID_VANILLA_WAYDROID="$FAKE_WAYDROID" \
		"$REPORT" --output "$failed"; then
		printf 'expected vanilla verification failure: %s\n' "$failure_mode" >&2
		exit 1
	fi
	grep -Fqx 'vanilla=not-verified' "$failed"
done

wrong_type=$TEST_DIR/wrong-type.txt
if FAKE_RELEASE_TYPE=GAPPS \
	PMOS_WAYDROID_VANILLA_WAYDROID="$FAKE_WAYDROID" \
	"$REPORT" --output "$wrong_type"; then
	printf '%s\n' 'expected non-VANILLA release-type failure' >&2
	exit 1
fi
grep -Fqx 'lineage_release_type=GAPPS' "$wrong_type"

printf '%s\n' 'waydroid VANILLA tests passed'
