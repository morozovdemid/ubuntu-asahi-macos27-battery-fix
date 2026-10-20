#!/usr/bin/env bash
# Install module override and a validated initramfs, preserving originals.
# Does not reload modules or reboot.
set -Eeuo pipefail
# shellcheck source=scripts/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"

check_target
check_built_module
for cmd in sudo depmod dracut lsinitrd install cp mv; do need "$cmd"; done
[[ -f "$MODULE_ORIGINAL" ]] || fail "Original packaged module missing: $MODULE_ORIGINAL"
[[ -f "$INITRD" ]] || fail "Boot image missing: $INITRD"

log 'WARNING: modifies /lib/modules and replaces the current kernel initramfs.'
log 'Keep the charger connected. The kernel version is pinned; updates require a new build.'
read -r -p 'Type INSTALL to continue: ' confirmation
[[ "$confirmation" == 'INSTALL' ]] || fail 'Cancelled by user.'
sudo -v
[[ -f /boot/grub/grub.cfg ]] || fail 'Expected GRUB configuration missing: /boot/grub/grub.cfg'
sudo grep -Fq "initrd.img-$KERNEL" /boot/grub/grub.cfg || \
    fail "GRUB does not reference initrd.img-$KERNEL; refusing to alter boot image."

log 'Saving original module in the work directory...'
mkdir -p "$WORK_DIR/backup"
if [[ ! -f "$WORK_DIR/backup/macsmc-power-original.ko.zst" ]]; then
    cp -- "$MODULE_ORIGINAL" "$WORK_DIR/backup/macsmc-power-original.ko.zst"
fi

log 'Backing up original initramfs without overwriting any existing backup...'
if sudo test ! -e "$INITRD_BACKUP"; then
    sudo cp -a -- "$INITRD" "$INITRD_BACKUP"
fi
sudo test -s "$INITRD_BACKUP" || fail "Initramfs backup missing or empty: $INITRD_BACKUP"

log 'Installing the override module (original package file is untouched)...'
sudo install -D -m 644 -- "$MODULE_BUILT" "$MODULE_OVERRIDE"
sudo depmod -a "$KERNEL"
selected="$(modinfo -n macsmc_power)"
[[ "$selected" == "$MODULE_OVERRIDE" ]] || fail "depmod didn't select override: $selected"

log 'Creating separate patched initramfs...'
sudo dracut --force --add-drivers macsmc_power "$INITRD_CANDIDATE" "$KERNEL"
check_initrd_dependency "$INITRD_CANDIDATE"

log 'Installing validated initramfs atomically...'
new_image="$INITRD.new"
sudo install -m 600 -- "$INITRD_CANDIDATE" "$new_image"
sudo mv -f -- "$new_image" "$INITRD"
check_initrd_dependency "$INITRD"
sync

log 'Installation successful. NO automatic reboot was performed.'
log "Rollback image: $INITRD_BACKUP"
log 'Reboot manually after saving work: sudo reboot'
log 'After reboot: ./scripts/status.sh ; then test gradual discharge for 15–20 minutes.'
