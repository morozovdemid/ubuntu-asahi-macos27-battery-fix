# Reproduction notes

These notes record the procedure used on the tested MacBook Air M1. They are a record of the manual investigation; the scripted workflow follows the same broad steps but has **not** been independently validated end-to-end on a fresh machine.

## Environment

| Item | Value |
| --- | --- |
| Hardware | MacBook Air M1 (2020) |
| Distribution | Ubuntu Asahi 26.04 (`resolute`) |
| Kernel | `7.1.0-1001-asahi-arm` |
| Firmware | macOS 27 |
| Driver configuration | `CONFIG_MACSMC_POWER=m` |
| Headers | `linux-headers-7.1.0-1001-asahi-arm` |
| Initramfs | Dracut |
| Bootloader | GRUB (`/boot/grub/grub.cfg`) |

## Initial evidence

The original `macsmc-power.ko.zst` was supplied by Ubuntu under the kernel's `drivers/power/supply` module directory. Before the patch, `POWER_SUPPLY_ENERGY_NOW` sometimes became negative (`-174967200` µWh) despite a reported full-charge energy near 38.8 Wh. The displayed percentage oscillated between implausible values.

The Ubuntu kernel source used unconditional `swab16` conversions for `B0RM` and read `BCF0` as a 32-bit value. The upstream patch changes both paths based on the `BCF0` key size. See [upstream commit](https://github.com/torvalds/linux/commit/f7b253a6e217f71d754d70c525e9b4c1dcbd4414).

## Source and build

The matching kernel source was downloaded from the Ubuntu Asahi PPA:

```text
linux-asahi-arm-7.1_7.1.0-1001.2~26.04.1.tar.gz
```

Only `drivers/power/supply/macsmc-power.c` was extracted. All ten hunks of upstream patch `f7b253a6e217f71d754d70c525e9b4c1dcbd4414` applied with **zero fuzz**; some applied with line offsets. The module was compiled out-of-tree using the installed kernel headers:

```bash
printf 'obj-m += macsmc-power.o\n' > stage/drivers/power/supply/Makefile
make -C /lib/modules/$(uname -r)/build \
  M="$HOME/asahi-battery-fix/stage/drivers/power/supply" modules
```

The built module reported:

```text
vermagic: 7.1.0-1001-asahi-arm SMP preempt mod_unload aarch64
depends: macsmc
```

The manual session reported nonfatal GCC executable-name and missing-BTF warnings. No module build error occurred.

## Module override

The original packaged module was backed up. The new driver was installed under:

```text
/lib/modules/7.1.0-1001-asahi-arm/updates/macsmc-power.ko
```

`depmod -a` and `modinfo -n macsmc_power` confirmed that the override would be selected. A live `modprobe -r macsmc_power` followed by `modprobe -v macsmc_power` successfully loaded that override. A first reading showed:

```text
POWER_SUPPLY_STATUS=Discharging
POWER_SUPPLY_ENERGY_FULL=38760000
POWER_SUPPLY_ENERGY_NOW=34610400
POWER_SUPPLY_CAPACITY=94
```

This manual reload temporarily removes the battery driver and is **not** part of the automated installer. It should not be attempted casually on an unplugged machine.

## Initramfs and reboot

The original Ubuntu initramfs contained the unpatched packaged module. Dracut generated an image that contained both original and replacement module files. Its dependency metadata selected the override:

```text
updates/macsmc-power.ko: kernel/drivers/mfd/macsmc.ko.zst
```

GRUB referenced `/initrd.img-7.1.0-1001-asahi-arm`, so the original image was preserved as `/boot/initrd.img-7.1.0-1001-asahi-arm.original-backup` before installing the new image at that same expected filename.

After reboot, `uname -r` still reported kernel `7.1.0-1001-asahi-arm`, and `modinfo -n` selected the override. The battery reported 33.80 Wh remaining of 38.77 Wh full-charge energy at 88% (`Charging`). A later unplugged observation showed 29.07 Wh remaining of 38.45 Wh at 80% (`Discharging`). These observations are compatible with the intended correction but do not prove long-term stability.

## Reproduce the checks

Inspect only; these commands do not modify the system:

```bash
uname -r
modinfo -n macsmc_power
sudo lsinitrd -f "usr/lib/modules/$(uname -r)/modules.dep" \
  "/boot/initrd.img-$(uname -r)" | grep macsmc-power
cat /sys/class/power_supply/macsmc-battery/uevent | \
  grep -E '^POWER_SUPPLY_(STATUS|ENERGY_NOW|ENERGY_FULL|CAPACITY)='
```

Do not infer the loaded module's identity from `modinfo -n` alone; it reports disk resolution. Do not intentionally deep-discharge the device to evaluate the critical-battery path.
