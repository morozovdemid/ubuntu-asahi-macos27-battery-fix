# Contributing

Issues and focused pull requests are welcome. This repository is intentionally limited to a tested Ubuntu Asahi kernel/firmware combination; new support targets require evidence from the relevant hardware and source tree.

Before submitting a change:

1. Run `bash -n scripts/*.sh` and `shellcheck -x -s bash scripts/build.sh scripts/install.sh scripts/rollback.sh scripts/status.sh` (if ShellCheck is installed).
2. Explain why a change is needed and what environment was tested. Separate static lint results from actual boot, install and rollback tests.
3. Keep package/source versions and upstream patch provenance explicit. Never silently remove safeguards or enable fuzzy patching.
4. Preserve backups and recovery behavior when touching `/boot` or `/lib/modules`.
5. Do not commit compiled modules, kernel source archives, logs containing personal details, serial numbers, disk UUIDs or tokens.

Upstream SMC driver changes belong in the Linux kernel; this repository concerns applying and validating a specific upstream fix for one Ubuntu Asahi package build.
