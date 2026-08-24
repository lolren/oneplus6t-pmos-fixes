#!/bin/sh
set -eu

probe_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
sdk_root=${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}
platform=${ANDROID_PLATFORM:-android-34}
build_tools_version=${ANDROID_BUILD_TOOLS_VERSION:-36.0.0}
output_dir=${1:-"$probe_dir/build"}

if [ -z "$sdk_root" ]; then
	printf '%s\n' 'Set ANDROID_SDK_ROOT (or ANDROID_HOME) to an Android SDK.' >&2
	exit 1
fi

android_jar="$sdk_root/platforms/$platform/android.jar"
build_tools="$sdk_root/build-tools/$build_tools_version"
for required in \
	"$android_jar" \
	"$build_tools/aapt2" \
	"$build_tools/apksigner" \
	"$build_tools/d8" \
	"$build_tools/zipalign"
do
	if [ ! -e "$required" ]; then
		printf 'Missing required Android SDK file: %s\n' "$required" >&2
		exit 1
	fi
done

for command in jar javac keytool zip; do
	if ! command -v "$command" >/dev/null 2>&1; then
		printf 'Missing required build command: %s\n' "$command" >&2
		exit 1
	fi
done

mkdir -p "$output_dir"
probe_tmp=$(mktemp -d "${TMPDIR:-/tmp}/waydroid-camera-probe.XXXXXX")
trap 'rm -rf -- "$probe_tmp"' EXIT HUP INT TERM
mkdir -p "$probe_tmp/classes" "$probe_tmp/dex"

keystore="$output_dir/debug.keystore"
if [ ! -f "$keystore" ]; then
	keytool -genkeypair -noprompt \
		-keystore "$keystore" \
		-storepass android \
		-keypass android \
		-alias androiddebugkey \
		-dname 'CN=Android Debug,O=Android,C=US' \
		-keyalg RSA \
		-keysize 2048 \
		-validity 10000
fi

javac --release 8 \
	-cp "$android_jar" \
	-d "$probe_tmp/classes" \
	"$probe_dir/src/dev/lolren/waydroidcameraprobe/CameraProbeActivity.java"
jar --create --file "$probe_tmp/classes.jar" -C "$probe_tmp/classes" .
"$build_tools/d8" \
	--lib "$android_jar" \
	--min-api 23 \
	--output "$probe_tmp/dex" \
	"$probe_tmp/classes.jar"
"$build_tools/aapt2" link \
	--manifest "$probe_dir/AndroidManifest.xml" \
	-I "$android_jar" \
	--min-sdk-version 23 \
	--target-sdk-version 33 \
	-o "$probe_tmp/probe-unsigned.apk"

(
	cd "$probe_tmp"
	zip -q -j probe-unsigned.apk dex/classes.dex
)
"$build_tools/zipalign" -f 4 \
	"$probe_tmp/probe-unsigned.apk" \
	"$probe_tmp/probe-aligned.apk"
"$build_tools/apksigner" sign \
	--ks "$keystore" \
	--ks-key-alias androiddebugkey \
	--ks-pass pass:android \
	--key-pass pass:android \
	--out "$probe_tmp/waydroid-camera-probe.apk" \
	"$probe_tmp/probe-aligned.apk"
"$build_tools/apksigner" verify --verbose \
	"$probe_tmp/waydroid-camera-probe.apk"

install -m 0644 "$probe_tmp/waydroid-camera-probe.apk" \
	"$output_dir/waydroid-camera-probe.apk"
sha256sum "$output_dir/waydroid-camera-probe.apk"
