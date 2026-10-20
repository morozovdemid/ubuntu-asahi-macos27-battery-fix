# Manual reproduction of the tested repair

This page documents the major commands used in the original troubleshooting session. The **automated scripts** in the repo add more safeguards, version checks, and rollback handling. Prefer them for actual installation. This document is here for review, reproducibility and debugging—not as an instruction to paste everything at once.

## Tested environment

- MacBook Air (2020) M1 with macOS 27 firmware.
- Ubuntu Asahi 26.04; kernel `7.1.0-1001-asahi-arm`.
- Original driver: `/lib/modules/7.1.0-1001-asahi-arm/kernel/drivers/power/supply/macsmc-power.ko.zst`.
- Header package: `linux-headers-7.1.0-1001-asahi-arm`.

## Establish that the battery driver is modular

```bash
grep '^CONFIG_MACSMC_POWER=' /boot/config-$(uname -r)
modinfo -n macsmc_power
lsmod | grep macsmc
```

The tested configuration returned `CONFIG_MACSMC_POWER=m`.

## Obtain Ubuntu's exact kernel source and upstream patch

```bash
mkdir -p ~/asahi-battery-fix/stage/drivers/power/supply
cd ~/asahi-battery-fix
wget -c 'https://ppa.launchpadcontent.net/ubuntu-asahi/ubuntu-asahi/ubuntu/pool/main/l/linux-asahi-arm-7.1/linux-asahi-arm-7.1_7.1.0-1001.2~26.04.1.tar.gz'
wget -O macsmc-27.patch 'https://github.com/torvalds/linux/commit/f7b253a6e217f71d754d70c525e9b4c1dcbd4414.patch'
tar -xOzf linux-asahi-arm-7.1_7.1.0-1001.2~26.04.1.tar.gz --wildcards '*/drivers/power/supply/macsmc-power.c' > stage/drivers/power/supply/macsmc-power.c
patch --dry-run --fuzz=0 -p1 -d stage < macsmc-27.patch
patch --fuzz=0 -p1 -d stage < macsmc-27.patch
```

For this Ubuntu source, all patch hunks applied with *line offsets*, not failed hunks or fuzz.

## Compile

```bash
sudo apt install build-essential linux-headers-$(uname -r)
printf 'obj-m += macsmc-power.o\n' > stage/drivers/power/supply/Makefile
make -C /lib/modules/$(uname -r)/build M="$HOME/asahi-battery-fix/stage/drivers/power/supply" modules
modinfo stage/drivers/power/supply/macsmc-power.ko | grep -E 'filename|depends|vermagic'
```

The resulting module reported:

```text
vermagic: 7.1.0-1001-asahi-arm SMP preempt mod_unload aarch64
depends: macsmc
```

The tested build reported nonfatal GCC command-name and BTF warnings; no compilation errors.

## Install only the overridden battery module (not an entire kernel)

A backup must be made **before** the first install:

```bash
mkdir -p backup
cp /lib/modules/$(uname -r)/kernel/drivers/power/supply/macsmc-power.ko.zst backup/macsmc-power-original.ko.zst
sudo mkdir -p /lib/modules/$(uname -r)/updates
sudo install -m 644 stage/drivers/power/supply/macsmc-power.ko /lib/modules/$(uname -r)/updates/macsmc-power.ko
sudo depmod -a
modinfo -n macsmc_power
```

The last command returned a path in `/updates/`, meaning the override took precedence on disk.

## Live reload (optional, risk of temporarily losing battery reporting)

Only with AC power and saved work:

```bash
sudo modprobe -r macsmc_power
sudo modprobe -v macsmc_power
```

The tested machine loaded `/lib/modules/7.1.0-1001-asahi-arm/updates/macsmc-power.ko` successfully. A subsequent battery reading showed:

```text
POWER_SUPPLY_STATUS=Discharging
POWER_SUPPLY_ENERGY_FULL=38760000
POWER_SUPPLY_ENERGY_NOW=34610400
POWER_SUPPLY_CAPACITY=94
```

## Prepare, inspect and install initramfs

The original boot image included the packaged unpatched `.ko.zst`, so a new Dracut image was generated. Dracut included **both** module files, but its `modules.dep` entry preferred the new override.

```bash
sudo dracut --force --add-drivers macsmc_power /boot/initrd.img-$(uname -r).patched $(uname -r)
sudo lsinitrd -f "usr/lib/modules/$(uname -r)/modules.dep" /boot/initrd.img-$(uname -r).patched | grep macsmc-power
```

The result was:

```text
updates/macsmc-power.ko: kernel/drivers/mfd/macsmc.ko.zst
```

The tested GRUB configuration referenced `/initrd.img-7.1.0-1001-asahi-arm`. Before changing the original boot image, it was backed up:

```bash
sudo cp -a /boot/initrd.img-$(uname -r) /boot/initrd.img-$(uname -r).original-backup
```

Then a staged image was installed and renamed to GRUB's expected file name:

```bash
sudo install -m 600 /boot/initrd.img-$(uname -r).patched /boot/initrd.img-$(uname -r).new
sudo mv -f /boot/initrd.img-$(uname -r).new /boot/initrd.img-$(uname -r)
```

No edits were made to macOS, APFS partitions or the GRUB configuration.

## Result after reboot

```text
Kernel: 7.1.0-1001-asahi-arm
Preferred module path: /lib/modules/7.1.0-1001-asahi-arm/updates/macsmc-power.ko
POWER_SUPPLY_STATUS=Charging
POWER_SUPPLY_ENERGY_FULL=38771400
POWER_SUPPLY_ENERGY_NOW=33801000
POWER_SUPPLY_CAPACITY=88
```

A normal reading on one reboot is promising but not enough for a universal reliability guarantee. Monitor normal unplugged discharge, charging, sleep/wake and shutdown behavior. Avoid intentionally deep-discharging a battery just to test critical-power behavior.
