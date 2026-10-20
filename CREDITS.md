# Credits

## Upstream kernel fix

The macOS 27 Apple SMC compatibility patch was authored by **Sasha Finkelstein**.

- Commit: [`f7b253a6e217f71d754d70c525e9b4c1dcbd4414`](https://github.com/torvalds/linux/commit/f7b253a6e217f71d754d70c525e9b4c1dcbd4414)
- Subject: `power: supply: macsmc: Support macOS 27 SMC firmware`
- Committer: **Sebastian Reichel**
- Reviewed by: Sven Peter, Joshua Peisach and Janne Grunau

The original patch changes handling of the `B0RM` remaining-charge reading and the `BCF0` battery-critical flag after changes in macOS 27 SMC firmware. The upstream kernel commit and its review history are the authoritative sources for the kernel fix.

## Related work

- [Linux kernel](https://github.com/torvalds/linux): upstream implementation and patch.
- [Ubuntu Asahi](https://github.com/UbuntuAsahi): downstream kernel packaging for Ubuntu on Apple Silicon.
- [Asahi Linux](https://asahilinux.org/): Linux enablement on Apple Silicon.

This repository documents the Ubuntu-specific backport procedure and supplies build, installation, verification and recovery scripts. It is not affiliated with or endorsed by the upstream author or the projects above. Linux kernel code and patches remain under their applicable original licenses; this repository does not redistribute compiled kernel binaries.
