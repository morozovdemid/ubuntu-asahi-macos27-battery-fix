# Changelog

## 0.1.0 — 2026-10-20

- Initial reproducible workaround for Ubuntu Asahi 26.04, kernel 7.1.0-1001-asahi-arm.
- Fetch upstream Linux macOS 27 SMC patch at commit `f7b253a6e217f71d754d70c525e9b4c1dcbd4414`.
- Compile an out-of-tree `macsmc-power` module against matching Ubuntu kernel headers.
- Install an override under `/lib/modules/<kernel>/updates/` without overwriting the packaged driver.
- Rebuild and verify Dracut initramfs, back up original, support rollback.
- Status and troubleshooting documentation.
