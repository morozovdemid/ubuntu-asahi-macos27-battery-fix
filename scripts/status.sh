#!/usr/bin/env bash
# Read-only status; modinfo shows the on-disk selection, not proof of loaded bytes.
set -Eeuo pipefail
# shellcheck source=scripts/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"

printf 'OS kernel: %s\n' "$KERNEL"
printf 'Architecture: %s\n' "$(uname -m)"
if command -v modinfo >/dev/null 2>&1; then
    printf 'Selected battery module (on disk): %s\n' "$(modinfo -n macsmc_power 2>/dev/null || printf 'not found')"
fi
if grep -q '^macsmc_power ' /proc/modules; then
    printf 'macsmc_power: loaded (source path of loaded copy not directly verified)\n'
else
    printf 'macsmc_power: not listed in /proc/modules\n'
fi

battery='/sys/class/power_supply/macsmc-battery/uevent'
if [[ -r "$battery" ]]; then
    echo 'Battery readings:'
    grep -E '^POWER_SUPPLY_(STATUS|ENERGY_NOW|ENERGY_FULL|CAPACITY|CAPACITY_LEVEL|CHARGE_NOW|CHARGE_FULL)=' "$battery" || true
else
    echo "Battery sysfs not found: $battery"
fi

echo 'Reminder: correct-looking readings at one instant do NOT prove discharge stability.'
echo 'Test for 15–20 minutes unplugged and verify no jumps or unexplained shutdowns.'
