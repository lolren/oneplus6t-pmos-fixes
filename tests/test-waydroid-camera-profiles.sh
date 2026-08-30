#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SYNC=$ROOT/scripts/sync-waydroid-camera-profiles
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/waydroid-camera-profiles-test.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT HUP INT TERM

overlay=$TEST_DIR/overlay
proc_root=$TEST_DIR/proc
mountinfo=$TEST_DIR/mountinfo
backup_root=$TEST_DIR/backups
mkdir -p "$overlay/vendor/etc" "$proc_root/pressure"
printf '%s\n' old-profile >"$overlay/vendor/etc/media_profiles.xml"
printf '%s\n' old-profile-v1 >"$overlay/vendor/etc/media_profiles_V1_0.xml"
printf '%s\n' '1 2 0:1 / /var/lib/waydroid/rootfs rw - ext4 /dev/root rw' >"$mountinfo"
printf '%s\n' \
	'some avg10=0.00 avg60=0.00 avg300=0.00 total=0' \
	'full avg10=0.00 avg60=0.00 avg300=0.00 total=0' \
	>"$proc_root/pressure/io"

if WAYDROID_CAMERA_MOUNTINFO="$mountinfo" \
	WAYDROID_CAMERA_PROC_ROOT="$proc_root" \
	WAYDROID_CAMERA_PROFILES_BACKUP_ROOT="$backup_root" \
	"$SYNC" --dry-run "$overlay" >"$TEST_DIR/mounted.out" 2>"$TEST_DIR/mounted.err"; then
	printf '%s\n' 'profile sync did not refuse a mounted rootfs' >&2
	exit 1
fi
grep -q 'rootfs is mounted' "$TEST_DIR/mounted.err"

: >"$mountinfo"
WAYDROID_CAMERA_MOUNTINFO="$mountinfo" \
	WAYDROID_CAMERA_PROC_ROOT="$proc_root" \
	WAYDROID_CAMERA_PROFILES_BACKUP_ROOT="$backup_root" \
	"$SYNC" --dry-run "$overlay" >"$TEST_DIR/dry-run.out"
grep -q '^dry-run: would synchronize 2 profile files' "$TEST_DIR/dry-run.out"

WAYDROID_CAMERA_OVERLAY_DIR="$overlay" \
WAYDROID_CAMERA_MOUNTINFO="$mountinfo" \
	WAYDROID_CAMERA_PROC_ROOT="$proc_root" \
	WAYDROID_CAMERA_PROFILES_BACKUP_ROOT="$backup_root" \
	"$SYNC" --dry-run >"$TEST_DIR/default.out"
grep -q '^dry-run: would synchronize 2 profile files' "$TEST_DIR/default.out"

command_link=$TEST_DIR/pmos-sync-waydroid-camera-profiles
ln -s "$SYNC" "$command_link"
WAYDROID_CAMERA_MOUNTINFO="$mountinfo" \
	WAYDROID_CAMERA_PROC_ROOT="$proc_root" \
	WAYDROID_CAMERA_PROFILES_BACKUP_ROOT="$backup_root" \
	"$command_link" --dry-run "$overlay" >"$TEST_DIR/link.out"
grep -q '^dry-run: would synchronize 2 profile files' "$TEST_DIR/link.out"

fake_bin=$TEST_DIR/bin
mkdir -p "$fake_bin"
cat >"$fake_bin/id" <<'EOF'
#!/bin/sh
if [ "${1-}" = -u ]; then
	printf '%s\n' 0
	exit 0
fi
command -p id "$@"
EOF
chmod 0755 "$fake_bin/id"

PATH="$fake_bin:$PATH" \
	WAYDROID_CAMERA_MOUNTINFO="$mountinfo" \
	WAYDROID_CAMERA_PROC_ROOT="$proc_root" \
	WAYDROID_CAMERA_PROFILES_BACKUP_ROOT="$backup_root" \
	"$SYNC" "$overlay" >"$TEST_DIR/install.out"
backup_dir=$(sed -n 's/^backup: //p' "$TEST_DIR/install.out")
[ -n "$backup_dir" ] && [ -d "$backup_dir" ]
cmp "$ROOT/config/waydroid/media_profiles.xml" \
	"$overlay/vendor/etc/media_profiles.xml"
cmp "$ROOT/config/waydroid/media_profiles.xml" \
	"$overlay/vendor/etc/media_profiles_V1_0.xml"
grep -Fqx 'present	vendor/etc/media_profiles.xml' "$backup_dir/presence.tsv"
grep -Fqx 'present	vendor/etc/media_profiles_V1_0.xml' "$backup_dir/presence.tsv"
[ -f "$backup_dir/installed.sha256" ]

PATH="$fake_bin:$PATH" \
	WAYDROID_CAMERA_MOUNTINFO="$mountinfo" \
	WAYDROID_CAMERA_PROC_ROOT="$proc_root" \
	WAYDROID_CAMERA_PROFILES_BACKUP_ROOT="$backup_root" \
	"$SYNC" --rollback "$backup_dir" "$overlay" >"$TEST_DIR/rollback.out"
grep -Fqx 'old-profile' "$overlay/vendor/etc/media_profiles.xml"
grep -Fqx 'old-profile-v1' "$overlay/vendor/etc/media_profiles_V1_0.xml"
grep -q '^rolled back: ' "$TEST_DIR/rollback.out"

printf '%s\n' 'Waydroid camera-profile sync tests passed'
