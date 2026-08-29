#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PATCH_DIR=$ROOT/patches/snapshot/50.0
MONOLITH=$ROOT/packaging/pmaports/0001-oneplus6t-camera-stack.patch

fail() {
	printf '%s\n' "snapshot patch test: $1" >&2
	exit 1
}

for patch_name in \
	0004-snapshot-serialize-viewfinder-stream-lifecycle.patch \
	0005-snapshot-await-camerabin-teardown.patch
do
	patch=$PATCH_DIR/$patch_name
	[ -f "$patch" ] || fail "missing $patch_name"

	case "$patch_name" in
	0004-*)
		grep -q 'Subject: \[PATCH\] fix(camera): serialize viewfinder stream lifecycle' "$patch"
		grep -q '^diff --git a/aperture/src/viewfinder.rs b/aperture/src/viewfinder.rs$' "$patch"
		blob_hash=d085cbd09bda9ae0f46fea399c755d8866e9d589
		sha512=3fb02943a52332bd125012e9c9f7b3aca12056430ca27c45f9e82ae220d16635eedc274a7dfc6fce87d60eea061feb3192728a9f1494d224d1b834dac4624060
		;;
	0005-*)
		grep -q 'Subject: \[PATCH\] fix(camera): await stream teardown before reconfiguration' "$patch"
		grep -q '^diff --git a/aperture/src/viewfinder.rs b/aperture/src/viewfinder.rs$' "$patch"
		test "$(grep -c '^diff --git ' "$patch")" -eq 1
		blob_hash=e388bcdd2c576634b651c8a6dff80e48e08f49e5
		sha512=de159a880fdd2efe13dfc7ef25e1ff6c5360be144ff7bbb4035292f37311e4436acf8207eb4ab7d3b4052499909374c4dc5f964032d29e3dd784a3d4191af127
		;;
	0006-*)
		grep -q 'Subject: \[PATCH\] fix(camera): handle current GStreamer state result' "$patch"
		grep -q '^diff --git a/aperture/src/viewfinder.rs b/aperture/src/viewfinder.rs$' "$patch"
		test "$(grep -c '^diff --git ' "$patch")" -eq 1
		blob_hash=3bdc4cfbc1c2d60981238f6c4c16c68f35b86d38
		sha512=4b7dc2880efb74707906a1fb74b624d56b431bb26365e06b5d8065ffbbb6167314c52784402972d94b30b0801c0387df6af1c2af7f0df0f21bf146aa6cfb2240
		;;
	esac

	test "$(git hash-object "$patch")" = "$blob_hash" ||
		fail "$patch_name blob hash is not the embedded hash"
	test "$(sha512sum "$patch" | awk '{print $1}')" = "$sha512" ||
		fail "$patch_name SHA-512 changed without updating the recipe"
	grep -q "^index 0000000..$blob_hash$" "$MONOLITH" ||
		fail "$patch_name is not embedded as the expected blob"
	grep -q "^+$sha512  $patch_name$" "$MONOLITH" ||
		fail "$patch_name checksum is not embedded in pmaports"
done

grep -q '^+pkgrel=6$' "$MONOLITH" || fail 'Snapshot recipe is not r6'
grep -q '0004-snapshot-serialize-viewfinder-stream-lifecycle.patch' "$MONOLITH" ||
	fail 'Snapshot r4 patch is not in the integration patch'
grep -q '0005-snapshot-await-camerabin-teardown.patch' "$MONOLITH" ||
	fail 'Snapshot r5 patch is not in the integration patch'
grep -q '0006-snapshot-gstreamer-state-tuple.patch' "$MONOLITH" ||
	fail 'Snapshot r6 patch is not in the integration patch'

printf '%s\n' 'Snapshot patch series and pmaports embedding tests passed'
