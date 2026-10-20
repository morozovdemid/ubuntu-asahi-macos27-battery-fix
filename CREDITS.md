# Credits and attribution

## Original upstream Linux kernel fix

**Author:** Sasha Finkelstein <k@chaosmail.tech>  
**Title:** `power: supply: macsmc: Support macOS 27 SMC firmware`  
**Commit:** [`f7b253a6e217f71d754d70c525e9b4c1dcbd4414`](https://github.com/torvalds/linux/commit/f7b253a6e217f71d754d70c525e9b4c1dcbd4414)  
**Committer:** Sebastian Reichel <sebastian.reichel@collabora.com>  
**Reviewed by:** Sven Peter, Joshua Peisach, Janne Grunau.

The upstream patch addresses the `BCF0` battery critical-state key size and the `B0RM` charge-reading byte order on macOS 27 firmware. The Linux commit and its associated development history are the primary sources of this fix.

**This repository does not claim ownership or authorship of the upstream Linux kernel patch.** It downloads that patch from the upstream Linux repository and applies it to a matching Ubuntu Asahi kernel source tree using local scripts. Original Linux kernel code and upstream modifications remain under their applicable upstream license terms.

## Related projects

- [Linux kernel](https://github.com/torvalds/linux): upstream kernel driver and patch.
- [Ubuntu Asahi](https://github.com/UbuntuAsahi): downstream Ubuntu Asahi distribution and Linux kernel packaging.
- [Asahi Linux](https://asahilinux.org/): broader Apple Silicon Linux enablement project.

## This repository

The Bash scripts, explanatory documentation, and test reproduction are a separate community packaging and troubleshooting effort. No endorsement by the original patch author, Ubuntu Asahi, Asahi Linux, or Linux kernel maintainers is implied.

For the one-machine validation results and limitations, see [README.md](README.md).
