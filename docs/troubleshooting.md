# Troubleshooting and recovery

This project changes the Ubuntu kernel-module search path and the current kernel's initramfs. It does not alter macOS partitions. All paths below apply only to `7.1.0-1001-asahi-arm`.

## Build or patch failure

The source version and upstream commit are pinned. If a patch hunk fails, **stop**; do not enable fuzz or force the patch onto another kernel revision. Confirm that the running kernel and headers match:

```bash
uname -r
grep '^CONFIG_MACSMC_POWER=' "/boot/config-$(uname -r)"
ls -ld "/lib/modules/$(uname -r)/build"
```

Warnings about BTF generation or the compiler executable name were nonfatal on the tested machine. A nonzero `make` exit code or a mismatched `vermagic` is not safe to ignore.

## `modinfo` points to the override but readings are still wrong

`modinfo -n macsmc_power` reports module resolution from disk, not which binary was loaded during early boot. Check the dependency metadata inside the active initramfs:

```bash
sudo lsinitrd -f "usr/lib/modules/$(uname -r)/modules.dep" \
  "/boot/initrd.img-$(uname -r)" | grep macsmc-power
```

On the tested setup the line begins `updates/macsmc-power.ko:`. The image may include both original and override `.ko` files; dependency resolution is the relevant check.

For runtime clues:

```bash
journalctl -k -b | grep -Ei 'macsmc|battery|power_supply'
```

Check charging hardware separately if the status says `Discharging` while a power supply is attached. Not every battery issue is caused by this SMC decoding bug.

## Roll back from a working Ubuntu installation

From the repository directory:

```bash
./scripts/rollback.sh
sudo reboot
```

The rollback script requires the saved initramfs, restores it, removes the specific override module, and runs `depmod`. It does not remove Linux packages or touch macOS. Restoring the original driver may also restore the original reporting bug.

For manual recovery on the **installed Ubuntu root**, with `/boot` correctly mounted:

```bash
sudo cp -a /boot/initrd.img-7.1.0-1001-asahi-arm.original-backup \
  /boot/initrd.img-7.1.0-1001-asahi-arm
sudo rm -f /lib/modules/7.1.0-1001-asahi-arm/updates/macsmc-power.ko
sudo depmod -a 7.1.0-1001-asahi-arm
sync
```

If Ubuntu cannot boot, use an older kernel entry if available, or a suitable Linux recovery environment. Recovery-environment device names and mount points vary; the commands above **must not** be run against an unrelated root filesystem. Maintain an independent data backup.

## New kernel release

An override built for `7.1.0-1001-asahi-arm` will not follow a kernel upgrade. First determine whether the updated Ubuntu kernel already contains the upstream fix. If it does not, repeat compatibility analysis against the new source and header versions; do not reuse the old module binary.

## Issue reports

Use the [bug-report template](../.github/ISSUE_TEMPLATE/bug_report.md) and include the exact failing command, Ubuntu version, kernel version, and sanitized driver diagnostics. Remove hardware serials, full filesystem UUIDs and private information before posting logs.
