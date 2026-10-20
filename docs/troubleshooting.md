# Troubleshooting and recovery

## `command not found` after pasting commands

Copy only commands *inside fenced Bash code blocks*. Terminal prompts such as `user@host:~$` and printed output are not commands. Attempting to run a `.ko` file directly will also produce an error: a kernel module is loaded by `modprobe`, not executed by Bash.

## The build says `Hunk FAILED`

Stop. This repository pins exactly one known source version and upstream patch. A failed hunk may indicate a different source version or already-applied patch. Do **not** use `patch --force`, extra fuzz, or remove sections blindly. Compare the source and upstream patch first.

## `curl` not installed

No problem. The project uses `wget` instead. Install it with `sudo apt install wget` if needed.

## Build warnings about GCC or BTF

On the tested system, GCC 15 had the same version but a different executable name, and BTF generation was skipped due to missing `vmlinux`. The build nevertheless produced a `.ko`. Warnings alone are not a guarantee of compatibility: inspect build errors, `modinfo -F vermagic`, and the module's live behavior.

## `Permission denied` when running `lsinitrd`

The `/boot/initrd.img-*` files may be root-readable only. Use `sudo lsinitrd ...`; never change the permissions of your entire `/boot` directory.

## `modinfo -n` returns `updates/` but values still jump

`modinfo -n` describes the *module that would be selected from disk*, not necessarily which binary was already loaded. The original copy may remain active until a successful reload/reboot. Check that the correct initramfs was installed and that the running kernel matches. Examine sanitized logs with:

```bash
journalctl -k -b | grep -Ei 'macsmc|battery|power_supply'
```

Don't assume all battery problems share this root cause. SMC key reads, charging logic, firmware details and physical battery health can also matter.

## The image has both `.ko.zst` and `.ko`

This was observed in the tested Dracut build. The critical check is its dependency database:

```bash
sudo lsinitrd -f "usr/lib/modules/$(uname -r)/modules.dep" "/boot/initrd.img-$(uname -r)" | grep macsmc-power
```

It should select `updates/macsmc-power.ko: ...` for this specific kernel. Merely listing a patched file inside an initramfs does **not** prove the boot process will load it.

## A newer kernel was installed

**Stop using the old `.ko`.** This module was built for the exact kernel `7.1.0-1001-asahi-arm`. On a new kernel, first verify whether the upstream fix is already included. If not, the source, patch applicability, symbol ABI, module and initramfs must all be checked anew. This repository intentionally rejects other kernels.

## Roll back when Ubuntu boots

From the downloaded repo directory:

```bash
./scripts/rollback.sh
sudo reboot
```

This restores the original Ubuntu initramfs and removes the custom module override from this kernel. It does not remove kernel packages or the macOS installation.

## Restore manually if a script cannot run

**These commands are for the specific tested kernel only**, from a functioning Ubuntu boot or a Linux recovery session where the installed Linux root and `/boot` are properly mounted. Do not run against a different root filesystem.

```bash
sudo cp -a /boot/initrd.img-7.1.0-1001-asahi-arm.original-backup /boot/initrd.img-7.1.0-1001-asahi-arm
sudo rm -- /lib/modules/7.1.0-1001-asahi-arm/updates/macsmc-power.ko
sudo depmod -a 7.1.0-1001-asahi-arm
sync
```

Afterward, reboot. If the machine cannot boot at all, consider the previous kernel in GRUB (if installed) or a suitable rescue environment; the correct mount points depend on the rescue environment and are **not covered by a universal command**. Preserve data backups.

## The battery still says `Discharging` with the charger attached

Check the physical USB-C charging connection, adapter, battery icon and any other power supplies in `/sys/class/power_supply/`. This repository only corrects a particular battery decoding bug; it does not guarantee charging functionality.

## Relevant locations

| Path | Purpose |
|:--|:--|
| `/lib/modules/7.1.0-1001-asahi-arm/updates/macsmc-power.ko` | Custom module |
| `/lib/modules/7.1.0-1001-asahi-arm/kernel/drivers/power/supply/macsmc-power.ko.zst` | Original packaged module (left untouched) |
| `/boot/initrd.img-7.1.0-1001-asahi-arm` | Active boot image |
| `/boot/initrd.img-7.1.0-1001-asahi-arm.original-backup` | Original boot-image backup |
| `work/` | Downloaded source, patch, built module and extra module backup |

## Reporting a bug

Open a GitHub issue using the template. Supply OS version, `uname -r`, relevant command errors, and **sanitized** readings. Do not publish personal usernames, serial numbers, full disk UUIDs, addresses, or secrets.
