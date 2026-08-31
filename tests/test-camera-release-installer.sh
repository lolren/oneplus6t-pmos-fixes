#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
INSTALLER=$ROOT/scripts/install-camera-generation

[ -x "$INSTALLER" ] || {
	printf '%s\n' 'camera release installer is not executable' >&2
	exit 1
}

sh -n "$INSTALLER"
help=$("$INSTALLER" --help)
printf '%s\n' "$help" | grep -q -- '--apply'
printf '%s\n' "$help" | grep -q -- '--work-dir'
printf '%s\n' "$help" | grep -q 'simulation-only'

grep -Fq 'RELEASE_TAG=runtime-r44-camera-r35' \
	"$INSTALLER" || {
	printf '%s\n' 'camera release installer tag is not pinned' >&2
	exit 1
}
grep -Fq 'base_url=https://github.com/' "$INSTALLER" || {
	printf '%s\n' 'camera release installer is not HTTPS-only' >&2
	exit 1
}
grep -Fq 'sha256sum -c "$CHECKSUMS"' "$INSTALLER" || {
	printf '%s\n' 'camera release installer does not verify checksums' >&2
	exit 1
}
grep -Fq 'download "$STACK_PATCH"' "$INSTALLER" || {
	printf '%s\n' 'camera release installer omits the integration patch asset' >&2
	exit 1
}
grep -Fq 'download "$RELEASE_NOTES"' "$INSTALLER" || {
	printf '%s\n' 'camera release installer omits the release-notes asset' >&2
	exit 1
}
grep -Fq 'sudo apk add --allow-untrusted' "$INSTALLER" || {
	printf '%s\n' 'camera release installer has no guarded runtime install' >&2
	exit 1
}
if grep -Eq '(^|[[:space:]])rm[[:space:]]+-rf([[:space:]]|$)' "$INSTALLER"; then
	printf '%s\n' 'camera release installer contains broad recursive deletion' >&2
	exit 1
fi

printf '%s\n' 'Camera release installer invariants passed'
