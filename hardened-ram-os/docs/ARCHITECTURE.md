# Hardened RAM-OS — Architecture

## Overview

Hardened RAM-OS is a security-focused, fully amnesiac live operating system.
Every session starts fresh — no data persists across reboots.

```
┌─────────────────────────────────────────────────────────────┐
│                        Boot Media                           │
│              (USB / CD — read-only, removable)              │
│                                                             │
│   /boot/vmlinuz        ← Hardened Linux 6.6 LTS            │
│   /boot/initrd.img     ← Amnesiac initramfs                 │
│   /live/filesystem.squashfs  ← Compressed root FS          │
└──────────────────────────┬──────────────────────────────────┘
                           │ GRUB loads kernel + initrd
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    Initramfs (PID 1)                        │
│                                                             │
│  1. Mount /proc, /sys, /dev, /run                           │
│  2. Detect boot device                                      │
│  3. Copy squashfs → /ram_store (tmpfs)  ← toram=1          │
│  4. Unmount boot device (can now be removed)                │
│  5. SHA256 verify squashfs                                  │
│  6. Mount squashfs read-only (lower layer)                  │
│  7. Mount tmpfs as upper + work dirs                        │
│  8. Mount OverlayFS → /newroot                              │
│  9. Install amnesiac-wipe.service                           │
│ 10. switch_root → /sbin/init (systemd)                      │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    Running System (RAM)                      │
│                                                             │
│   ┌──────────────────────────────────────────────┐          │
│   │  OverlayFS (all writes go here → RAM only)   │          │
│   │  ┌─────────────────┐  ┌──────────────────┐  │          │
│   │  │ Lower (squashfs)│  │ Upper (tmpfs RW) │  │          │
│   │  │   Read-only     │  │  Volatile writes │  │          │
│   │  │ base system +   │  │  Disappear on    │  │          │
│   │  │ Kali tools      │  │  shutdown/reboot │  │          │
│   │  └─────────────────┘  └──────────────────┘  │          │
│   └──────────────────────────────────────────────┘          │
│                                                             │
│   /tmp   → tmpfs (512M)                                     │
│   /var/log → tmpfs (128M)                                   │
│   /var/tmp → tmpfs (256M)                                   │
│   /run   → tmpfs                                            │
│   SWAP   → DISABLED                                         │
│                                                             │
└──────────────────────────┬──────────────────────────────────┘
                           │ shutdown / reboot
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                  amnesiac-wipe.service                       │
│                                                             │
│  • 3-pass zero-wipe of all tmpfs upper directories          │
│  • shred: ~/.bash_history, ~/.ssh, credentials              │
│  • Remove: /tmp, /var/tmp, /run/user, NM connections        │
│  • sync → power off                                         │
│  • All session data is gone                                 │
└─────────────────────────────────────────────────────────────┘
```

## Kernel Hardening

| Feature | Config | Effect |
|---|---|---|
| KASLR | `RANDOMIZE_BASE=y` | Randomize kernel base address |
| KPTI | `PAGE_TABLE_ISOLATION=y` | Mitigate Meltdown |
| Retpoline | `RETPOLINE=y` | Mitigate Spectre v2 |
| SMEP/SMAP | `X86_SMEP/SMAP=y` | Prevent userspace code exec from kernel |
| Hardened usercopy | `HARDENED_USERCOPY=y` | Bounds-check all user↔kernel copies |
| Fortify source | `FORTIFY_SOURCE=y` | Compile-time buffer overflow detection |
| Stack protector | `STACKPROTECTOR_STRONG=y` | Canary on all functions |
| Stackleak GCC plugin | `GCC_PLUGIN_STACKLEAK=y` | Erase kernel stack between syscalls |
| Init on alloc/free | `INIT_ON_ALLOC/FREE=y` | Zero DRAM on every alloc/free |
| SLAB hardening | `SLAB_FREELIST_HARDENED=y` | Freelist pointer obfuscation |
| Module signing | `MODULE_SIG_FORCE=y` | Only signed modules load |
| Kernel lockdown | `SECURITY_LOCKDOWN_LSM=y` | Restrict root to kernel tampering |
| No /dev/mem | `DEVMEM=n` | Prevent physical memory access |
| No kexec | `KEXEC=n` | Prevent kernel replacement at runtime |
| No swap | `SWAP=n` | Prevent secrets leaking to disk |

## LSM Stack

```
lockdown → yama → loadpin → safesetid → apparmor → bpf
```

- **Lockdown (confidentiality)**: Prevents root from modifying kernel
- **Yama**: `ptrace_scope=2` — ptrace only by parent processes
- **AppArmor**: Enforcing mandatory access control profiles
- **BPF LSM**: Fine-grained BPF program restrictions

## Amnesiac Guarantees

1. **Boot device removable after POST**: squashfs is fully copied to RAM
2. **No writes to disk**: OverlayFS upper layer is tmpfs
3. **No swap**: kernel config + fstab + sysctl `swappiness=0`
4. **Volatile logs**: systemd journal is `Storage=volatile`
5. **Shutdown wipe**: 3-pass zero wipe of all writable RAM regions
6. **No shell history**: `HISTFILE=/dev/null` globally
7. **MAC randomisation**: per-connection and per-boot
8. **Random hostname**: regenerated each boot
9. **Forensic mode**: boot with `forensic=1` to prevent any auto-mount

## Build Pipeline

```
build.sh
├── kernel/build-kernel.sh
│   ├── Download + GPG verify linux-6.6.30.tar.xz
│   ├── Apply kernel-hardened.config
│   ├── Verify 13 critical security options
│   └── Output: vmlinuz, modules, headers
│
├── initramfs/build-initramfs.sh
│   ├── Create minimal busybox skeleton
│   ├── Install boot-critical kernel modules
│   ├── Install init (amnesiac boot logic)
│   └── Output: initramfs-6.6.30-hardened.img (zstd)
│
├── rootfs/build-rootfs.sh
│   ├── debootstrap Kali rolling base
│   ├── Install 150+ security tools
│   ├── Apply sysctl / AppArmor / sudo hardening
│   ├── Configure amnesiac behaviour
│   └── Output: filesystem.squashfs (zstd-19)
│
└── iso/build-iso.sh
    ├── Stage kernel + initrd + squashfs
    ├── Write GRUB config (BIOS + UEFI)
    ├── grub-mkrescue → hybrid ISO
    └── Output: hardened-ramOS-6.6.30-YYYYMMDD.iso
```

## Boot Modes

| Mode | Kernel Parameters | Use Case |
|---|---|---|
| Full Amnesiac | `toram=1 forensic=0` | Normal operation |
| Forensic | `toram=1 forensic=1` | Incident response (no auto-mount of local disks) |
| Debug | `loglevel=7 debug` | Troubleshooting boot issues |
| Safe Mode | `nomodeset acpi=off` | Hardware compatibility issues |

## Wireless Tooling

The kernel includes packet injection support:
- `CONFIG_MAC80211_MONITOR=y` — monitor mode
- `CONFIG_CFG80211_WEXT=y` — wireless extensions (aircrack-ng compat)
- Wide wireless adapter support: Atheros, Realtek, Ralink, Intel

Tools: `aircrack-ng`, `hcxtools`, `bettercap`, `wifite`, `kismet`, `reaver`

## Security Hardening vs. Usability Trade-offs

| Trade-off | Decision | Rationale |
|---|---|---|
| `KALLSYMS=n` | Disable | Prevents kernel symbol leak; breaks some debugging |
| `KEXEC=n` | Disable | Prevents runtime kernel replacement |
| `SWAP=n` | Disable | Amnesiac guarantee; no secrets on disk |
| `MAGIC_SYSRQ=n` | Disable | Prevents emergency root access via keyboard |
| `ptrace_scope=2` | Restrict | Attaches only to children; breaks some debuggers |
| Module signing | Enforce | Blocks unsigned drivers; must sign custom modules |
