#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
REPORT=$ROOT/scripts/check-waydroid-gapps
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/waydroid-gapps-test.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT HUP INT TERM

FAKE_WAYDROID=$TEST_DIR/waydroid
cat >"$FAKE_WAYDROID" <<'EOF'
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
shell:--:getprop:ro.product.cpu.abilist:)
	printf '%s\n' 'armeabi-v7a,armeabi'
	;;
shell:--:pm:path:com.google.android.gms)
	printf '%s\n' 'package:/system/priv-app/GmsCore/GmsCore.apk'
	;;
shell:--:pm:path:com.google.android.gsf)
	printf '%s\n' 'package:/system/priv-app/GoogleServicesFramework/GoogleServicesFramework.apk'
	;;
shell:--:pm:path:com.android.vending)
	if [ "${FAKE_WAYDROID_MODE:-all}" = missing-store ]; then
		exit 1
	fi
	printf '%s\n' 'package:/system/priv-app/Phonesky/Phonesky.apk'
	;;
*)
	printf 'unexpected fake waydroid command: %s\n' "$*" >&2
	exit 2
	;;
esac
EOF
chmod 0755 "$FAKE_WAYDROID"

verified=$TEST_DIR/verified.txt
PMOS_WAYDROID_GAPPS_WAYDROID="$FAKE_WAYDROID" \
	PMOS_WAYDROID_GAPPS_TIMEOUT=2 \
	"$REPORT" --output "$verified"
grep -Fqx 'status_exit=0' "$verified"
grep -Fqx 'android_release=13' "$verified"
grep -Fqx 'android_abis=armeabi-v7a,armeabi' "$verified"
grep -Fqx 'gms=present' "$verified"
grep -Fqx 'gsf=present' "$verified"
grep -Fqx 'play_store=present' "$verified"
grep -Fqx 'gapps=verified' "$verified"

if PMOS_WAYDROID_GAPPS_WAYDROID="$FAKE_WAYDROID" \
	"$REPORT" --output "$verified" >/dev/null 2>&1; then
	printf '%s\n' 'expected output overwrite refusal' >&2
	exit 1
fi

missing=$TEST_DIR/missing.txt
if FAKE_WAYDROID_MODE=missing-store \
	PMOS_WAYDROID_GAPPS_WAYDROID="$FAKE_WAYDROID" \
	"$REPORT" --output "$missing"; then
	printf '%s\n' 'expected missing Play Store failure' >&2
	exit 1
fi
grep -Fqx 'play_store=missing' "$missing"
grep -Fqx 'gapps=not-verified' "$missing"

printf '%s\n' 'waydroid GAPPS tests passed'
