# Ubuntu Asahi macOS 27 Battery Fix

**A reproducible, reversible workaround for incorrect battery reporting on Apple Silicon running Ubuntu Asahi 26.04 after installing macOS 27 firmware.**

The issue can produce wildly jumping battery percentages, impossible negative energy readings, and potentially misleading critical-battery states. This repository backports an **existing upstream Linux kernel fix** into a loadable Ubuntu Asahi battery driver—**without reinstalling Ubuntu, replacing the kernel, or modifying macOS**.

> [!IMPORTANT]
> **Tested combination only:** MacBook Air M1 (2020), Ubuntu Asahi **26.04**, Linux **`7.1.0-1001-asahi-arm`**, macOS **27** firmware. The script **refuses other kernels** by design. This is a community workaround, **not** an official Ubuntu Asahi package or a guarantee against shutdowns. Read the safety section before modifying your boot image.

## Evidence from the tested machine

| Measurement | Before patch | After live reload and post-reboot |
|:--|:--|:--|
| `ENERGY_NOW` | `-174967200` µWh (**−174.97 Wh**, impossible) | `33801000` µWh (**33.80 Wh**) |
| `ENERGY_FULL` | around `38794200` µWh | `38771400` µWh (**38.77 Wh**) |
| Battery percentage | Jumps between values, including 100% | **88%** on the recorded post-reboot reading |
| Battery state | Erratic readings | `Charging` on the recorded post-reboot reading |
| Module load | Packaged `macsmc-power.ko.zst` | Patched `updates/macsmc-power.ko` selected |

**Interpretation:** The negative-energy error disappeared, and the system booted using the patched initramfs. Longer-term discharge stability and protection from unexpected shutdowns still require observation; a single reasonable reading does **not** prove a 100% fix.

## Why this happens

The macOS 27 firmware changed two SMC (System Management Controller) interfaces that the Linux `macsmc-power` driver reads:

- **`B0RM`:** remaining-charge data changed byte order (endianness). Older code always swapped the bytes; that can misinterpret charge as a negative or otherwise implausible value.
- **`BCF0`:** the critical-battery flag changed size from **4 bytes to 1 byte**. The driver needs to detect the key size and read it correctly.

Upstream Linux addressed both in Sasha Finkelstein's patch:

**[`f7b253a6e217f71d754d70c525e9b4c1dcbd4414` — power: supply: macsmc: Support macOS 27 SMC firmware](https://github.com/torvalds/linux/commit/f7b253a6e217f71d754d70c525e9b4c1dcbd4414)**.

This repository **does not invent a new battery algorithm**. It obtains that exact upstream patch and applies it to the matching Ubuntu Asahi kernel source.

## Supported configuration

| Component | Value |
|:--|:--|
| Computer tested | Apple MacBook Air, M1 (2020) |
| Linux distribution | Ubuntu Asahi Desktop 26.04 (`resolute`) |
| Running kernel | `7.1.0-1001-asahi-arm` |
| Kernel source package | `linux-asahi-arm-7.1_7.1.0-1001.2~26.04.1.tar.gz` |
| Upstream Linux patch | `f7b253a6e217f71d754d70c525e9b4c1dcbd4414` |
| Battery module | `macsmc-power` (`CONFIG_MACSMC_POWER=m`) |
| Boot image generator | Dracut |
| Boot loader observed | GRUB |

**Not validated:** Fedora Asahi, other Ubuntu Asahi releases, different kernels, different Mac models, or later kernel builds. Never reuse the compiled `.ko` after changing kernel versions; kernel modules are ABI-specific.

## Already applied the fix manually?

If you already followed the repair steps on your own Mac and successfully rebooted, **you do not need to rebuild or reinstall the module** just to publish this project. The scripts document and automate the procedure for a fresh, matching setup. `./scripts/status.sh` is read-only.

## Quick start

### 1. Install prerequisites

Keep the **charger connected** and save your work. Check the kernel:

```bash
uname -r
```

It **must** say `7.1.0-1001-asahi-arm` for these scripts.

Install required build tools and matching headers:

```bash
sudo apt update
sudo apt install build-essential patch wget dracut-core linux-headers-$(uname -r)
```

`dracut-core` is the Ubuntu package that normally supplies Dracut. If `dracut` and `lsinitrd` already work, no additional Dracut installation is necessary.

### 2. Clone and build

```bash
git clone https://github.com/YOUR_USERNAME/ubuntu-asahi-macos27-battery-fix.git
cd ubuntu-asahi-macos27-battery-fix
./scripts/build.sh
```

**Replace `YOUR_USERNAME` with the GitHub account or organization that hosts this repository.** Until published, extract this project's ZIP and open a terminal inside the extracted directory instead.

The script downloads the **254 MiB Ubuntu kernel source archive**, fetches the pinned upstream patch, extracts only `drivers/power/supply/macsmc-power.c`, patches a **working copy**, and compiles a module against the **running kernel's headers**.

Nothing under `/lib/modules` or `/boot` changes during the build.

### 3. Optional: test the patched module live

A live reload was successful on the tested M1. It is **optional and carries risk**: battery reporting may temporarily disappear. **Keep external power connected** and save work before attempting this.

Do **not** perform this until after running `./scripts/install.sh` (which installs the override to `/lib/modules`) or explicitly staging the module yourself. For the documented reproduction, the live test was performed after installing the module override and before replacing the initramfs:

```bash
sudo modprobe -r macsmc_power
sudo modprobe -v macsmc_power
./scripts/status.sh
```

The printed `insmod` path should contain `/updates/macsmc-power.ko`. If unloading or reloading fails, **stop** and review the error. Don't force-unload other Apple SMC modules.

### 4. Install the override and boot image

```bash
./scripts/install.sh
```

The installer requires you to type `INSTALL`. It will:

1. Verify the kernel, matching `vermagic`, and original packaged module.
2. Save the **original packaged driver** under `work/backup/`.
3. Back up the **original initramfs** to `/boot/initrd.img-7.1.0-1001-asahi-arm.original-backup` (without overwriting a previous backup).
4. Install the patched `.ko` into `/lib/modules/7.1.0-1001-asahi-arm/updates/`.
5. Run `depmod` and check which module will be selected.
6. Generate `/boot/initrd.img-7.1.0-1001-asahi-arm.patched` using Dracut.
7. Inspect the generated image's `modules.dep` and ensure the patched module exists inside it.
8. Atomically replace only the **matching version's Ubuntu initramfs**.

**It does not reboot automatically.** The original driver inside the packaged kernel module directory remains untouched, and macOS/APFS partitions are not accessed.

Once the script reports success, save your work and reboot:

```bash
sudo reboot
```

### 5. Verify and test

After reboot:

```bash
uname -r
modinfo -n macsmc_power
./scripts/status.sh
```

The expected **on-disk module selection** is:

```text
/lib/modules/7.1.0-1001-asahi-arm/updates/macsmc-power.ko
```

**Important:** `modinfo -n` tells you what would be selected from the root filesystem; by itself it does not prove the identity of the already-loaded module. The installer also checks the actual initramfs module database, and a live `modprobe -v` can show the selected path when reloading.

To monitor discharge, **unplug the charger only when the battery is sufficiently charged**:

```bash
watch -n 5 'grep -E "STATUS=|ENERGY_NOW=|ENERGY_FULL=|CAPACITY=" /sys/class/power_supply/macsmc-battery/uevent'
```

Use Ubuntu normally for 15–20 minutes. `STATUS` should say `Discharging`, remaining energy should stay positive and decline, and the percentage should change reasonably gradually. Stop the watch with **Ctrl+C**.

Do not intentionally discharge to 0% to test the critical-battery flag. If readings jump, become negative, or Ubuntu shuts down unexpectedly, reconnect power, collect sanitized logs, and consider rollback.

## Rollback

If the custom driver causes problems **and Ubuntu still boots**, run:

```bash
./scripts/rollback.sh
sudo reboot
```

Type `ROLLBACK` when prompted. The rollback script restores the saved original initramfs, removes **only this kernel's** override module, runs `depmod`, and leaves macOS untouched. **Battery readings may become incorrect again** when the original driver is restored.

**If Ubuntu does not boot**, boot via the older GRUB kernel entry when available (the tested GRUB menu also listed `7.0.0-1001-asahi-arm`) or use a suitable Linux recovery environment to restore `/boot/initrd.img-7.1.0-1001-asahi-arm.original-backup` and remove the override. This is not a guaranteed recovery mechanism; make a normal backup before changing boot files.

For manual recovery commands and additional guidance, see [docs/troubleshooting.md](docs/troubleshooting.md).

## Limitations and maintenance

- **One tested configuration:** scripts intentionally refuse any other running kernel or Ubuntu version. A different kernel requires its **own source**, patch compatibility assessment, build, and initramfs.
- **Custom modules do not automatically follow future kernel upgrades.** Verify that the replacement kernel includes the macOS 27 SMC fix before upgrading or booting it. Never blindly install a module built for kernel 7.1 into 7.2.
- **Firmware identification:** upstream detects the new behavior using the `BCF0` key size. The fix isn't simply "always stop swapping bytes"; older firmware still needs the old interpretation.
- **Partial validation:** initial post-reboot measurements looked healthy, but this workaround has not been proven safe on every charge level, suspend state, device, or firmware revision.
- **No magic health restoration:** this fixes decoding/reporting; it does not repair an aging physical battery.
- **Read before use:** kernel module and initramfs changes can make Linux unstable or temporarily unbootable. Keep power connected, preserve backups, and understand how to access a recovery environment.

## Repository structure

```text
ubuntu-asahi-macos27-battery-fix/
├── .github/
│   ├── ISSUE_TEMPLATE/bug_report.md
│   └── workflows/shell-check.yml
├── docs/
│   ├── manual-reproduction.md
│   └── troubleshooting.md
├── scripts/
│   ├── build.sh           # Exact source + official patch + matching kernel module
│   ├── common.sh          # Version guards, paths, preflight checks
│   ├── install.sh         # Backups, module override, Dracut, atomic image update
│   ├── rollback.sh        # Restore original initramfs and packaged module
│   └── status.sh          # Read-only diagnostics
├── .gitignore
├── CHANGELOG.md
├── CONTRIBUTING.md
├── LICENSE
└── README.md
```

Downloaded kernel code, patch, build objects and original module backup go into `work/` (ignored by Git).

## Publish on GitHub

Once this project is unzipped and reviewed, create an **empty public repository** named `ubuntu-asahi-macos27-battery-fix` on GitHub (do **not** initialize the remote with a second README). Then run inside the project directory:

```bash
git init -b main
git add .
git commit -m "Initial Ubuntu Asahi macOS 27 battery fix"
git remote add origin https://github.com/YOUR_USERNAME/ubuntu-asahi-macos27-battery-fix.git
git push -u origin main
```

Replace `YOUR_USERNAME` with your GitHub username. You'll need GitHub authentication configured (typically via SSH or a personal access token). Never push anything in `work/`; the `.gitignore` excludes it.

## Credits and licensing

- **Upstream fix:** Sasha Finkelstein, with reviews and sign-offs recorded in [Linux commit `f7b253a6`](https://github.com/torvalds/linux/commit/f7b253a6e217f71d754d70c525e9b4c1dcbd4414). This project is a backporting workflow, **not** the author of that patch.
- **Ubuntu Asahi:** distribution and kernel packaging from the [Ubuntu Asahi project](https://github.com/UbuntuAsahi).
- **Linux `macsmc-power` driver:** maintained upstream as part of Linux.

Original scripts and documentation in this repo are licensed under **MIT**. Downloaded Linux kernel code and patch remain under **their upstream Linux kernel licenses (GPL-2.0-only where applicable)**; these are not relicensed by this repository. The project does **not** bundle Linux source or a compiled kernel module.

## References

- [Official upstream Linux patch — macOS 27 SMC firmware](https://github.com/torvalds/linux/commit/f7b253a6e217f71d754d70c525e9b4c1dcbd4414)
- [Upstream patch discussion](https://patchew.org/linux/20260712-gate-power-v4-1-aa59c6583247%40chaosmail.tech/)
- [Ubuntu Asahi kernel package repository](https://ppa.launchpadcontent.net/ubuntu-asahi/ubuntu-asahi/ubuntu/pool/main/l/linux-asahi-arm-7.1/)
- [Linux kernel docs — building external modules](https://docs.kernel.org/kbuild/modules.html)
- [Dracut](https://github.com/dracutdevs/dracut)

---

**Project status:** Initial working proof of concept with successful module reload and reboot on one Apple M1 Ubuntu Asahi 26.04 installation. Further unplugged discharge testing required; this is not a 100%-verified universal fix.
