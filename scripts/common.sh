#!/usr/bin/env bash
# Shared paths and safeguards for the Ubuntu Asahi macOS 27 SMC battery fix.
set -Eeuo pipefail
# Shared globals are used by other scripts that source this file.
# shellcheck disable=SC2034

readonly SUPPORTED_KERNEL='7.1.0-1001-asahi-arm'
readonly SUPPORTED_UBUNTU='26.04'
readonly KERNEL="$(uname -r)"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
readonly WORK_DIR="$REPO_ROOT/work"
readonly MODULE_NAME='macsmc-power'
readonly MODULE_ORIGINAL="/lib/modules/$KERNEL/kernel/drivers/power/supply/macsmc-power.ko.zst"
readonly MODULE_OVERRIDE="/lib/modules/$KERNEL/updates/macsmc-power.ko"
readonly MODULE_BUILT="$WORK_DIR/stage/drivers/power/supply/macsmc-power.ko"
readonly INITRD="/boot/initrd.img-$KERNEL"
readonly INITRD_BACKUP="$INITRD.original-backup"
readonly INITRD_CANDIDATE="$INITRD.patched"
readonly SOURCE_ARCHIVE='linux-asahi-arm-7.1_7.1.0-1001.2~26.04.1.tar.gz'
readonly SOURCE_URL="https://ppa.launchpadcontent.net/ubuntu-asahi/ubuntu-asahi/ubuntu/pool/main/l/linux-asahi-arm-7.1/$SOURCE_ARCHIVE"
readonly PATCH_COMMIT='f7b253a6e217f71d754d70c525e9b4c1dcbd4414'
readonly PATCH_URL="https://github.com/torvalds/linux/commit/$PATCH_COMMIT.patch"

log() { printf '[asahi-battery-fix] %s\n' "$*"; }
fail() { printf '[asahi-battery-fix] ERROR: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || fail "Missing command '$1'. Install its Ubuntu package first."; }

check_target() {
    [[ "$KERNEL" == "$SUPPORTED_KERNEL" ]] || fail "Only kernel $SUPPORTED_KERNEL is tested. Running: $KERNEL. No changes made."
    [[ "$(uname -m)" == 'aarch64' ]] || fail 'This project targets ARM64 Apple Silicon.'
    [[ -f /etc/os-release ]] || fail 'Cannot determine operating system.'
    # shellcheck disable=SC1091
    . /etc/os-release
    [[ "${ID:-}" == 'ubuntu' && "${VERSION_ID:-}" == "$SUPPORTED_UBUNTU" ]] || \
        fail "Tested only on Ubuntu $SUPPORTED_UBUNTU (detected: ${PRETTY_NAME:-unknown})."
}

check_built_module() {
    need modinfo
    [[ -s "$MODULE_BUILT" ]] || fail "Missing compiled module: $MODULE_BUILT. Run scripts/build.sh first."
    local vermagic
    vermagic="$(modinfo -F vermagic "$MODULE_BUILT")"
    [[ "$vermagic" == "$KERNEL "* ]] || fail "Module vermagic doesn't match kernel: $vermagic"
}

check_initrd_dependency() {
    local image="$1" deps
    deps="$(sudo lsinitrd -f "usr/lib/modules/$KERNEL/modules.dep" "$image")" || fail "Cannot read modules.dep from $image"
    printf '%s\n' "$deps" | grep -E '^updates/macsmc-power\.ko:' >/dev/null || \
        fail "Initramfs module database does not select updates/macsmc-power.ko: $image"
    sudo lsinitrd "$image" | grep -E "usr/lib/modules/$KERNEL/updates/macsmc-power\.ko$" >/dev/null || \
        fail "Patched module missing from initramfs: $image"
}
