#!/usr/bin/env bash
# Restore the original boot image and remove this kernel's module override.
# Does not reboot automatically.
set -Eeuo pipefail
# shellcheck source=scripts/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"

check_target
for cmd in sudo depmod install mv; do need "$cmd"; done
[[ -f "$INITRD_BACKUP" ]] || fail "Missing original initramfs backup: $INITRD_BACKUP"
[[ -f "$MODULE_ORIGINAL" ]] || fail "Missing original packaged module: $MODULE_ORIGINAL"
log 'This restores the original Ubuntu battery driver (which may have broken battery reporting).'
read -r -p 'Type ROLLBACK to continue: ' confirmation
[[ "$confirmation" == 'ROLLBACK' ]] || fail 'Cancelled by user.'
sudo -v

log 'Restoring original initramfs from backup...'
sudo install -m 600 -- "$INITRD_BACKUP" "$INITRD.new"
sudo mv -f -- "$INITRD.new" "$INITRD"

if sudo test -f "$MODULE_OVERRIDE"; then
    log 'Removing ONLY the custom macsmc-power override for this kernel...'
    sudo rm -- "$MODULE_OVERRIDE"
fi
sudo depmod -a "$KERNEL"
selected="$(modinfo -n macsmc_power)"
[[ "$selected" == "$MODULE_ORIGINAL" ]] || fail "Expected packaged module not selected: $selected"
sync
log 'Rollback is staged on disk. The running driver remains unchanged until reboot.'
log 'Save work, then reboot manually: sudo reboot'
