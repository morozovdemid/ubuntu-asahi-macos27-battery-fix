# Contributing

PRs and issue reports are welcome. Keep changes focused and testable.

1. Run `bash -n scripts/*.sh` and `shellcheck -s bash scripts/*.sh` locally.
2. Do not commit binaries, downloaded kernel source, patches, logs containing personal information, UUIDs, serial numbers, or private home paths.
3. Keep the upstream commit SHA and Ubuntu source version explicit; do not silently expand supported kernels.
4. Any change to boot or kernel-module installation must preserve an independently restorable original and must not automatically reboot.
5. Explain new distributions and kernel versions only after they have been tested with actual module loading and battery readings.

This repository is an independently documented workaround, not an official Ubuntu Asahi kernel release.
