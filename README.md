# Ubuntu Asahi macOS 27 battery fix

A pinned backport and deployment workflow for the Linux `macsmc-power` driver on Ubuntu Asahi 26.04. It applies the [upstream macOS 27 SMC compatibility patch](https://github.com/torvalds/linux/commit/f7b253a6e217f71d754d70c525e9b4c1dcbd4414) to the corresponding Ubuntu kernel source, builds a replacement module, and stages an initramfs with a reversible module override.

**Scope:** MacBook Air M1 (2020), Ubuntu Asahi 26.04 (`resolute`), kernel `7.1.0-1001-asahi-arm`, macOS 27 firmware. The scripts reject other kernel versions. This is an independent workaround, not an Ubuntu Asahi package.

## Problem

After a firmware update through macOS 27, the tested system intermittently reported invalid battery charge data. One sysfs reading showed `POWER_SUPPLY_ENERGY_NOW=-174967200` µWh (−174.97 Wh); the reported battery percentage also jumped between implausible values. macOS reported the battery normally.

The upstream `macsmc-power` fix addresses two firmware-interface changes:

- `B0RM`: remaining-charge data no longer requires the byte swap used with older firmware.
- `BCF0`: the battery-critical indication uses a one-byte key rather than the earlier four-byte representation.

The upstream patch detects the firmware behavior and handles both cases. **The kernel fix itself is not original to this repository.**

## Implementation

The tools in `scripts/` operate on one explicitly pinned kernel build:

1. Obtain the matching Ubuntu Asahi source archive and upstream Linux patch.
2. Apply the patch to a local copy of `drivers/power/supply/macsmc-power.c` with zero fuzz.
3. Build an external module against the running kernel headers.
4. Place the module in `/lib/modules/<kernel>/updates/` without replacing Ubuntu's packaged `.ko.zst`.
5. Back up the existing initramfs, generate a Dracut image and verify `modules.dep` selects the override before replacing the boot image.

`build.sh` does not alter installed kernel files. `install.sh` modifies the module tree and initramfs only after confirmation, and does not reboot automatically. `rollback.sh` restores the saved boot image and removes the override.

## Prerequisites

- The exact configuration listed above, including a working GRUB/Dracut boot setup.
- Matching `linux-headers-7.1.0-1001-asahi-arm` and the original packaged module.
- A working Linux recovery path and backups before modifying `/boot`.

Install the build prerequisites:

```bash
sudo apt update
sudo apt install git build-essential patch wget dracut-core linux-headers-$(uname -r)
```

## Build and install

```bash
git clone https://github.com/morozovdemid/ubuntu-asahi-macos27-battery-fix.git
cd ubuntu-asahi-macos27-battery-fix
uname -r                     # must be 7.1.0-1001-asahi-arm
./scripts/build.sh           # downloads source + patch, then compiles the module
./scripts/install.sh         # privileged installation; requests confirmation
sudo reboot
```

**Review `scripts/install.sh` and the recovery instructions before running it.** Keep external power connected and save your work. The automated install/rollback scripts have not been independently exercised end-to-end on a clean machine; the repair was originally performed manually. Do not run the installer merely to inspect this repository or on a system where the workaround is already installed.

After reboot:

```bash
modinfo -n macsmc_power
./scripts/status.sh
```

For the tested setup, `modinfo` should resolve to `.../updates/macsmc-power.ko`. That path identifies the module *selected on disk*, not by itself the identity of the currently loaded copy. See [reproduction notes](docs/manual-reproduction.md) for the boot-image verification and live-test commands.

## Observed results

The following values were captured during the manual repair on one MacBook Air M1:

| State | Remaining energy | Full-charge energy | Reported charge |
| --- | ---: | ---: | ---: |
| Before fix (invalid sample) | −174.97 Wh | 38.79 Wh | Erratic, at times 100% |
| After reboot, charging | 33.80 Wh | 38.77 Wh | 88% |
| Later, unplugged | 29.07 Wh | 38.45 Wh | 80% |

The patched module loaded, Ubuntu rebooted using the rebuilt image, and subsequent observations were positive and plausible. This is a **single-system functional test**, not evidence of long-term reliability or compatibility with other firmware, kernels, or Mac models. The independently reported percentage can differ from the simple ratio of energy readings.

## Rollback

If Ubuntu still boots, return to the original kernel module and initramfs with:

```bash
./scripts/rollback.sh
sudo reboot
```

The installer preserves the original image at `/boot/initrd.img-7.1.0-1001-asahi-arm.original-backup`. If the system cannot boot, restoration requires another bootable Linux environment or a suitable older GRUB entry; see [troubleshooting and recovery](docs/troubleshooting.md). The original reporting bug may return after rollback.

## Known limits

- **One kernel ABI:** `7.1.0-1001-asahi-arm`. A kernel update requires a new compatibility review; do not reuse this `.ko` with another kernel.
- **One verified device:** MacBook Air M1 (2020). No validation on Fedora Asahi, other Mac models, or other Ubuntu releases.
- **Partial validation:** Longer discharge cycles, critical-battery conditions, sleep/wake and unexpected-shutdown behavior have not been exhaustively tested. Do not intentionally drain the battery to zero to test this patch.
- **Boot changes:** A damaged or mismatched initramfs can prevent Ubuntu from starting. Keep independent backups and a recovery option.

Technical notes: [Manual reproduction](docs/manual-reproduction.md) · [Troubleshooting](docs/troubleshooting.md) · [Contributing](CONTRIBUTING.md)

## Attribution and license

The upstream Linux patch **“power: supply: macsmc: Support macOS 27 SMC firmware”** was authored by **Sasha Finkelstein** and committed by Sebastian Reichel: [Linux commit `f7b253a6`](https://github.com/torvalds/linux/commit/f7b253a6e217f71d754d70c525e9b4c1dcbd4414). This repository provides build/deployment tooling and notes from applying that work to Ubuntu Asahi; it does not claim to have developed the kernel fix. Full acknowledgments are in [CREDITS.md](CREDITS.md).

Original repository scripts and documentation are available under the [MIT License](LICENSE). Downloaded Linux kernel source and the upstream patch retain their respective upstream licenses and are not redistributed as part of this repository.
