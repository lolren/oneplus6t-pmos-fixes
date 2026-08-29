#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
INSTALLER=$ROOT/scripts/install-waydroid-camera
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/waydroid-installer-test.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT HUP INT TERM

stage=$TEST_DIR/stage
overlay=$TEST_DIR/overlay
mountinfo=$TEST_DIR/mountinfo
proc_root=$TEST_DIR/proc
base_prop=$TEST_DIR/waydroid_base.prop
runtime_prop=$TEST_DIR/waydroid.prop
mkdir -p "$stage" "$overlay/vendor" "$overlay/system/etc/init" "$proc_root/pressure"
printf '%s\n' 'ro.hardware.camera=v4l2' 'other.base=value' > "$base_prop"
printf '%s\n' 'ro.hardware.camera=v4l2' 'other.runtime=value' > "$runtime_prop"

while IFS= read -r target; do
	[ -n "$target" ] || continue
	mkdir -p "$stage/$(dirname "$target")"
	: > "$stage/$target"
done <<'EOF'
vendor/bin/hw/android.hardware.camera.provider@2.4-service
vendor/lib/hw/android.hardware.camera.provider@2.4-impl.so
vendor/lib/hw/android.hardware.camera.provider@2.4-legacy.so
vendor/lib/hw/camera.device@1.0-impl.so
vendor/lib/hw/camera.libcamera.so
vendor/lib/libcamera.so
vendor/lib/libcamera-base.so
vendor/lib/libc++_shared.so
vendor/lib/libcamera/ipa/ipa_soft_simple.so
vendor/lib/libcamera/ipa/ipa_soft_simple.so.sign
vendor/libexec/libcamera/soft_ipa_proxy
vendor/etc/libcamera/camera_hal.yaml
vendor/etc/libcamera/configuration.yaml
vendor/etc/media_profiles.xml
vendor/etc/media_profiles_V1_0.xml
vendor/etc/vintf/manifest/legacy-libcamera.xml
vendor_extra/etc/seccomp_policy/mediaswcodec.policy
vendor/share/libcamera/ipa/simple/imx371.yaml
vendor/share/libcamera/ipa/simple/imx376.yaml
vendor/share/libcamera/ipa/simple/imx519.yaml
vendor/share/libcamera/ipa/simple/uncalibrated.yaml
EOF

printf '%s\n' '1 2 0:1 / /var/lib/waydroid/rootfs rw - ext4 /dev/root rw' > "$mountinfo"
printf '%s\n' \
	'some avg10=0.00 avg60=0.00 avg300=0.00 total=0' \
	'full avg10=0.00 avg60=0.00 avg300=0.00 total=0' \
	> "$proc_root/pressure/io"
if VIDEO_GID=27 WAYDROID_CAMERA_MOUNTINFO="$mountinfo" \
	WAYDROID_CAMERA_PROC_ROOT="$proc_root" \
	WAYDROID_CAMERA_BASE_PROP="$base_prop" \
	WAYDROID_CAMERA_RUNTIME_PROP="$runtime_prop" \
	"$INSTALLER" --dry-run "$stage" "$overlay" > "$TEST_DIR/mounted.out" 2> "$TEST_DIR/mounted.err"; then
	printf '%s\n' 'installer did not refuse a mounted Waydroid rootfs' >&2
	exit 1
fi
grep -q 'rootfs is mounted' "$TEST_DIR/mounted.err"

: > "$mountinfo"
printf '%s\n' \
	'some avg10=0.00 avg60=0.00 avg300=0.00 total=0' \
	'full avg10=0.00 avg60=0.00 avg300=0.00 total=0' \
	> "$proc_root/pressure/io"
VIDEO_GID=27 WAYDROID_CAMERA_MOUNTINFO="$mountinfo" \
	WAYDROID_CAMERA_PROC_ROOT="$proc_root" \
	WAYDROID_CAMERA_BASE_PROP="$base_prop" \
	WAYDROID_CAMERA_RUNTIME_PROP="$runtime_prop" \
	"$INSTALLER" --dry-run "$stage" "$overlay" > "$TEST_DIR/clear.out"
grep -q '^dry-run: would back up to ' "$TEST_DIR/clear.out"
grep -q '^dry-run: would install 21 runtime files' "$TEST_DIR/clear.out"
grep -q '^dry-run: would set ro.hardware.camera=libcamera' "$TEST_DIR/clear.out"

# Exercise a real fixture install and exact rollback, including the two host
# property files that a clean VANILLA image does not preconfigure for libcamera.
mkdir -p "$overlay/vendor/bin/hw"
printf '%s\n' 'old-provider' > \
	"$overlay/vendor/bin/hw/android.hardware.camera.provider@2.4-service"
printf '%s\n' 'old-init' > \
	"$overlay/system/etc/init/init.zz-oneplus6t-camera.rc"
printf '%s\n' \
	'ro.hardware.camera=v4l2' \
	'other.base=value' \
	'ro.hardware.camera=external' > "$base_prop"
printf '%s\n' \
	'other.runtime=value' \
	'ro.hardware.camera=v4l2' > "$runtime_prop"
cp "$base_prop" "$TEST_DIR/base.original"
cp "$runtime_prop" "$TEST_DIR/runtime.original"

fake_bin=$TEST_DIR/bin
mkdir -p "$fake_bin"
cat > "$fake_bin/id" <<'EOF'
#!/bin/sh
if [ "${1-}" = -u ]; then
	printf '%s\n' 0
	exit 0
fi
command -p id "$@"
EOF
chmod 0755 "$fake_bin/id"

backup_root=$TEST_DIR/backups
PATH="$fake_bin:$PATH" VIDEO_GID=27 \
	WAYDROID_CAMERA_MOUNTINFO="$mountinfo" \
	WAYDROID_CAMERA_PROC_ROOT="$proc_root" \
	WAYDROID_CAMERA_BACKUP_ROOT="$backup_root" \
	WAYDROID_CAMERA_BASE_PROP="$base_prop" \
	WAYDROID_CAMERA_RUNTIME_PROP="$runtime_prop" \
	"$INSTALLER" "$stage" "$overlay" > "$TEST_DIR/install.out"
backup_dir=$(sed -n 's/^backup: //p' "$TEST_DIR/install.out")
[ -n "$backup_dir" ] && [ -d "$backup_dir" ]
[ "$(grep -c '^ro.hardware.camera=libcamera$' "$base_prop")" -eq 1 ]
[ "$(grep -c '^ro.hardware.camera=libcamera$' "$runtime_prop")" -eq 1 ]
! grep -q '^ro.hardware.camera=v4l2$' "$base_prop"
! grep -q '^ro.hardware.camera=external$' "$base_prop"
grep -Fqx 'other.base=value' "$base_prop"
grep -Fqx 'other.runtime=value' "$runtime_prop"
[ ! -s "$overlay/vendor/bin/hw/android.hardware.camera.provider@2.4-service" ]
grep -q 'group audio camera input drmrpc 27' \
	"$overlay/system/etc/init/init.zz-oneplus6t-camera.rc"
[ -f "$backup_dir/host-props/waydroid_base.prop" ]
[ -f "$backup_dir/host-props/waydroid.prop" ]
[ -f "$backup_dir/host-props.sha256" ]

PATH="$fake_bin:$PATH" VIDEO_GID=27 \
	WAYDROID_CAMERA_MOUNTINFO="$mountinfo" \
	WAYDROID_CAMERA_PROC_ROOT="$proc_root" \
	WAYDROID_CAMERA_BACKUP_ROOT="$backup_root" \
	WAYDROID_CAMERA_BASE_PROP="$base_prop" \
	WAYDROID_CAMERA_RUNTIME_PROP="$runtime_prop" \
	"$INSTALLER" --rollback "$backup_dir" "$overlay" \
	> "$TEST_DIR/rollback.out"
grep -Fqx 'old-provider' \
	"$overlay/vendor/bin/hw/android.hardware.camera.provider@2.4-service"
grep -Fqx 'old-init' \
	"$overlay/system/etc/init/init.zz-oneplus6t-camera.rc"
[ ! -e "$overlay/vendor/lib/hw/camera.libcamera.so" ]
cmp "$TEST_DIR/base.original" "$base_prop"
cmp "$TEST_DIR/runtime.original" "$runtime_prop"
grep -q '^rolled back: ' "$TEST_DIR/rollback.out"

grep -q 'setprop media.settings.xml /vendor/etc/media_profiles_V1_0.xml' \
	"$ROOT/config/waydroid/init.zz-oneplus6t-camera.rc.in"
grep -q 'setprop debug.stagefright.ccodec 2' \
	"$ROOT/config/waydroid/init.zz-oneplus6t-camera.rc.in"
grep -q 'setprop waydroid.pulse_runtime_path /run/xdg/pulse' \
	"$ROOT/config/waydroid/init.zz-oneplus6t-camera.rc.in"
grep -q '^sched_setscheduler: 1$' \
	"$ROOT/config/waydroid/mediaswcodec.policy"
for camera_id in 0 1; do
	grep -q "<CamcorderProfiles cameraId=\"$camera_id\">" \
		"$ROOT/config/waydroid/media_profiles.xml"
done
if grep -q '<CamcorderProfiles cameraId="2">' \
	"$ROOT/config/waydroid/media_profiles.xml"; then
	printf '%s\n' 'unsafe auxiliary Venus recording profile is still advertised' >&2
	exit 1
fi
grep -q 'ID 2 is intentionally omitted' \
	"$ROOT/config/waydroid/media_profiles.xml"
for frame_rate in 24 19; do
	grep -q "frameRate=\"$frame_rate\"" \
		"$ROOT/config/waydroid/media_profiles.xml"
done
grep -q 'Requesting linear RGB multi-stream private buffer' \
	"$ROOT/patches/libcamera/waydroid/v0.7.2/0014-android-keep-RGB-preview-and-coalesce-NV12-streams.patch"
grep -Fq '<< "Mapped " << mappedNv12Streams' \
	"$ROOT/patches/libcamera/waydroid/v0.7.2/0014-android-keep-RGB-preview-and-coalesce-NV12-streams.patch"
grep -Fq '<< " NV12 Android stream(s) to source "' \
	"$ROOT/patches/libcamera/waydroid/v0.7.2/0014-android-keep-RGB-preview-and-coalesce-NV12-streams.patch"
grep -q 'sourceCrop_' \
	"$ROOT/patches/libcamera/waydroid/v0.7.2/0014-android-keep-RGB-preview-and-coalesce-NV12-streams.patch"
grep -q 'maxPrivateStreamResolution{ 1280, 960 }' \
	"$ROOT/patches/libcamera/waydroid/v0.7.2/0015-android-cap-software-ISP-private-previews.patch"

install_stage=$TEST_DIR/install-stage
make -s -C "$ROOT" install DESTDIR="$install_stage" PREFIX=/usr >/dev/null
for installed_config in media_profiles.xml mediaswcodec.policy; do
	[ -f "$install_stage/usr/libexec/oneplus6t-pmos-fixes/config/waydroid/$installed_config" ]
done

printf '%s\n' \
	'some avg10=0.00 avg60=0.00 avg300=0.00 total=0' \
	'full avg10=100.00 avg60=100.00 avg300=100.00 total=1' \
	> "$proc_root/pressure/io"
if VIDEO_GID=27 WAYDROID_CAMERA_MOUNTINFO="$mountinfo" \
	WAYDROID_CAMERA_PROC_ROOT="$proc_root" \
	WAYDROID_CAMERA_BASE_PROP="$base_prop" \
	WAYDROID_CAMERA_RUNTIME_PROP="$runtime_prop" \
	"$INSTALLER" --dry-run "$stage" "$overlay" > "$TEST_DIR/pressure.out" 2> "$TEST_DIR/pressure.err"; then
	printf '%s\n' 'installer did not refuse active full I/O pressure' >&2
	exit 1
fi
grep -q 'I/O pressure is active' "$TEST_DIR/pressure.err"

printf '%s\n' 'Waydroid installer guard/install/rollback tests passed'
