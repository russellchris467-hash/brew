# UTM SE Sandbox Security: Academic Research for Bug Bounty

## Abstract

This document presents an academic analysis of the security architecture of
UTM SE, the App Store-distributed variant of the UTM virtual machine for
iOS and macOS. UTM SE uses QEMU's Tiny Code Generator Threaded Interpreter
(TCTI) for full software emulation without JIT compilation. We examine the
sandbox architecture, identify attack surfaces, catalog applicable
vulnerability classes from QEMU's history, and assess the overall security
posture from a bug bounty research perspective.

**Keywords:** UTM SE, QEMU, TCG, TCI, sandbox escape, virtual machine
security, iOS sandboxing, device emulation, bug bounty

---

## 1. Introduction

UTM is an open-source virtual machine application for Apple platforms built
on QEMU. It ships in two variants:

| Attribute              | UTM (Full)                        | UTM SE ("Slow Edition")              |
|------------------------|-----------------------------------|--------------------------------------|
| Emulation engine       | QEMU TCG with JIT                 | QEMU TCG Threaded Interpreter (TCTI) |
| Virtualization         | Apple Hypervisor Framework (macOS) | Not available on iOS                 |
| JIT compilation        | Yes (requires W+X memory)         | No (interpreter only)                |
| iOS distribution       | Sideloading / AltStore            | App Store                            |
| Performance            | Faster emulation                  | ~2-10x slower                        |
| Guest architectures    | 30+                               | ARM64, PPC, PPC64, RISC-V64, x86, x86_64, M68K |
| W^X compliance         | No                                | Yes                                  |

UTM SE exists because Apple prohibits JIT compilation in App Store apps.
The TCTI backend interprets TCG intermediate representation rather than
generating native code, eliminating the need for writable+executable (W+X)
memory pages.

**Security implication:** QEMU upstream explicitly states that TCG-mode bugs
are *not* considered security vulnerabilities:

> "The non-virtualization use case covers emulation using the Tiny Code
> Generator (TCG). [...] Bugs affecting the non-virtualization use case are
> not considered security bugs at this time."
> — [QEMU Security Documentation](https://qemu-project.gitlab.io/qemu/system/security.html)

This means the entire emulation engine in UTM SE falls outside QEMU's
security-supported perimeter, making it a compelling target for academic
security research.

---

## 2. Architecture Analysis

### 2.1 iOS Runtime Model (UTM SE)

On iOS, UTM SE operates under significant platform constraints:

- QEMU is linked as a **shared library** and runs its main loop in a
  **pthread** within the same process as the UTM app.
- There is **no process-level isolation** between the emulation engine and
  the host application. A crash in QEMU crashes UTM SE entirely.
- Only one QEMU instance can run at a time.
- The **iOS App Sandbox** is the sole confinement layer — no `seccomp`,
  SELinux, or AppArmor is available.
- If the QEMU emulation engine is compromised, the attacker gains access to
  the full UTM SE app sandbox (all VM disk images, configurations, shared
  directories).

### 2.2 macOS Runtime Model (UTM, for comparison)

On macOS, QEMU runs in a **separate XPC process** (`QEMUHelper`) with its
own App Sandbox, providing process-level isolation that UTM SE on iOS lacks.

### 2.3 Guest CPU Emulation

The TCTI interpreter executes guest code through the following pipeline:

1. **Frontend decode:** Guest instructions are decoded into TCG
   intermediate representation (TCG ops).
2. **Threaded interpretation:** The TCTI backend chains together C function
   pointers representing TCG ops, executing them in sequence.
3. **SoftMMU:** Guest memory access goes through per-vCPU TLB structures
   for address translation, all in software.

There is **no hardware-enforced isolation** between guest and host code
paths. The interpreter runs in the same address space with the same
privileges as the rest of the QEMU process.

```
┌──────────────────────────────────────────────────────┐
│                    iOS Process                        │
│  ┌─────────────┐  ┌──────────────────────────────┐   │
│  │   UTM SE     │  │         QEMU (pthread)        │  │
│  │   Swift UI   │  │  ┌────────┐  ┌────────────┐  │  │
│  │             │◄─►│  │ TCTI   │  │ Device     │  │  │
│  │             │  │  │Interp. │  │ Models     │  │  │
│  │             │  │  ├────────┤  ├────────────┤  │  │
│  │             │  │  │SoftMMU │  │ 9pfs/SPICE │  │  │
│  └─────────────┘  │  └────────┘  └────────────┘  │  │
│                    └──────────────────────────────┘   │
│  ════════════════════════════════════════════════════ │
│                   iOS App Sandbox                     │
└──────────────────────────────────────────────────────┘
│                   iOS Kernel (XNU)                    │
```

---

## 3. Attack Surface Enumeration

### 3.1 Layer 1 — TCG/TCI Interpreter (CPU Emulation)

| Component          | Risk                                                  |
|--------------------|-------------------------------------------------------|
| Instruction decode | Malformed guest instructions may trigger parsing bugs  |
| TCTI op chaining   | Novel execution model with limited security audit      |
| SoftMMU TLB        | TLB handling bugs could corrupt host memory mappings   |
| FPU/SIMD emulation | Complex floating-point edge cases                     |

**Known CVE:** CVE-2020-24165 — TCG accelerator mishandling allowing
potential code execution with elevated privileges.

### 3.2 Layer 2 — Emulated Device Models

This is the **largest and most historically vulnerable** attack surface.
Guest code interacts with emulated hardware through MMIO and PIO, and
the C implementations of these device models have produced many
vulnerabilities.

| Category    | Devices                                      | Primary Vectors                         |
|-------------|----------------------------------------------|-----------------------------------------|
| Storage     | IDE, AHCI/SATA, virtio-blk, NVMe, floppy, SD | DMA reentrancy, OOB read/write          |
| Network     | e1000, e1000e, rtl8139, virtio-net, Tulip    | DMA reentrancy, RSS OOB, buffer overflow |
| Display     | VGA, QXL, virtio-gpu                         | Double-fetch, OOB read, heap overflow   |
| USB         | EHCI, xHCI, USB device emulation             | DMA reentrancy, use-after-free          |
| Audio       | AC97, Intel HDA, virtio-snd                  | Heap overflow in PCM callbacks          |
| SCSI        | lsi53c895a, MegaRAID                         | DMA reentrancy, use-after-free          |
| Crypto      | virtio-crypto                                | Heap overflow from size mismatch        |

### 3.3 Layer 3 — Host-Guest Sharing Interfaces

| Interface         | Mechanism                    | Known Risks                                          |
|-------------------|------------------------------|------------------------------------------------------|
| VirtFS / 9pfs     | 9P protocol over virtio     | CVE-2023-2861 (special file escape), CVE-2023-1386 (SUID preservation) |
| SPICE display     | Unix socket + SPICE protocol | Clipboard sharing, rendering bugs                    |
| SPICE WebDAV      | WebDAV on localhost          | File transfer attack surface                         |
| Clipboard sharing | SPICE guest agent            | Data exfiltration path (by design)                   |

### 3.4 Layer 4 — Platform Sandboxing

On iOS (UTM SE), the platform sandbox is the **only** barrier between a
compromised QEMU and the rest of the system:

- No process isolation (QEMU is a thread)
- No seccomp/AppArmor/SELinux
- iOS kernel protections (AMFI, code signing, sandbox) are the last line of defense
- A QEMU compromise grants access to all UTM SE app data

---

## 4. Vulnerability Classes in Detail

### 4.1 DMA Reentrancy

DMA reentrancy is a class of bugs where a device's MMIO handler writes
to a DMA buffer that overlaps the device's own MMIO region, causing the
handler to re-enter itself. This can lead to use-after-free, double-free,
or stack overflow conditions.

**Mechanism:**
```
Guest writes to Device A MMIO
  → Device A MMIO handler fires
    → Handler performs DMA read/write
      → DMA target overlaps Device A (or Device B) MMIO region
        → Second MMIO handler invocation (reentrant call)
          → Corrupted state: double-free, UAF, stack overflow
```

**Historical CVEs:**

| CVE            | Device          | Impact                              |
|----------------|-----------------|-------------------------------------|
| CVE-2022-2962  | Tulip NIC       | Stack/heap overflow                 |
| CVE-2021-3750  | USB EHCI        | Use-after-free, potential code exec |
| CVE-2024-3446  | virtio-gpu/serial/crypto | Double free                |

**Research approach:** Identify device models where MMIO handlers perform
DMA operations, then test whether the DMA target address can be set to
overlap with MMIO regions.

### 4.2 Heap Buffer Overflows

Occur when device emulation code writes beyond allocated buffer boundaries,
typically due to insufficient validation of guest-controlled size parameters.

| CVE / Bug        | Device             | Root Cause                          |
|------------------|--------------------|-------------------------------------|
| fdc overflow     | Floppy controller  | Unchecked DMA read size             |
| SDHCI overflow   | SD Host Controller | OOB write when buffer sizes match   |
| virtio-snd       | virtio sound       | Missing iov capacity check          |
| virtio-crypto    | virtio crypto      | Mismatched src_len/dst_len          |
| QXL overflow     | QXL display        | Double-fetch of width/height        |

### 4.3 Out-of-Bounds Read/Write

| CVE / Bug          | Device       | Root Cause                              |
|--------------------|--------------|-----------------------------------------|
| CVE-2020-25085     | SDHCI        | Integer overflow in ADMA/SDMA           |
| virtio-net RSS     | virtio-net   | Controllable indirection table index    |
| NVMe OOB read      | NVMe         | Unvalidated guest-supplied offset       |
| QXL OOB read       | QXL display  | Missing size check in phys2virt         |

### 4.4 Filesystem Escape via 9pfs

The 9pfs (VirtFS) shared directory feature has a history of escape
vulnerabilities:

| CVE            | Description                                              |
|----------------|----------------------------------------------------------|
| CVE-2023-2861  | Guest can open special/device files on host, escaping 9p export tree |
| CVE-2023-1386  | SUID/SGID bits not dropped on guest-written executables  |
| CVE-2021-20181 | Race condition leading to use-after-free                 |

**Research approach:** Test boundary conditions in 9p path resolution,
symlink handling, and special file access from within the guest.

---

## 5. Research Methodology

### 5.1 Recommended Approach for Bug Bounty Research

1. **Identify exposed device models:** Determine which QEMU device models
   are compiled into UTM SE and which are enabled by default in VM
   configurations.

2. **Audit MMIO/PIO handlers:** For each exposed device, review the MMIO
   and PIO read/write handlers for:
   - Insufficient bounds checking on guest-supplied values
   - DMA operations that could trigger reentrancy
   - Race conditions in multi-threaded contexts
   - Integer overflow/underflow in size calculations

3. **Fuzz device interfaces:** Use QEMU's built-in fuzzing infrastructure
   (`tests/qtest/fuzz/`) or external fuzzers to generate malformed device
   interactions from the guest side.

4. **Test 9pfs boundary conditions:** If directory sharing is enabled,
   probe for path traversal, symlink attacks, and special file access.

5. **Analyze TCTI interpreter:** Review the threaded interpreter for
   correctness in handling edge-case guest instructions, particularly
   around memory access translation.

### 5.2 Tools

| Tool                          | Purpose                                    |
|-------------------------------|--------------------------------------------|
| QEMU's qtest framework        | Scripted device interaction testing        |
| AFL/libFuzzer with qtest      | Fuzz testing of device models              |
| AddressSanitizer (ASan)       | Detect memory corruption at runtime        |
| GDB with QEMU debug builds    | Analyze crashes and control flow           |
| Ghidra / IDA Pro              | Static analysis of compiled device models  |

### 5.3 Setting Up a Research Environment

```bash
# Clone UTM and its QEMU fork
git clone --recursive https://github.com/utmapp/UTM.git
cd UTM

# Build QEMU with sanitizers for testing
cd qemu
mkdir build && cd build
../configure --target-list=x86_64-softmmu \
    --enable-tcg-interpreter \
    --enable-sanitizers \
    --enable-debug
make -j$(nproc)
```

---

## 6. Disclosure Considerations

### 6.1 UTM's Security Posture

- **No bug bounty program** exists for UTM or UTM SE.
- **No SECURITY.md** or formal vulnerability disclosure policy.
- Past vulnerabilities were reported via GitHub issues (Google Vulnerability
  Reports #6155, #6156, #6252).

### 6.2 Recommended Disclosure Channels

1. **GitHub Security Advisories** (private reporting, if enabled)
2. **GitHub Issues** on `utmapp/UTM`
3. **Direct contact** with the maintainer (osy) via GitHub
4. **QEMU upstream** (`secalert@redhat.com`) for bugs in QEMU itself

### 6.3 Responsible Disclosure

When reporting vulnerabilities discovered through this research:

- Provide a clear proof-of-concept that demonstrates the issue
- Include affected versions and configurations
- Allow reasonable time for patches before public disclosure
- Consider that QEMU upstream does not treat TCG bugs as security issues,
  so UTM-specific reports may be more appropriate for the UTM project

---

## 7. Key Findings Summary

1. **UTM SE runs QEMU in a mode that QEMU itself does not consider
   security-supported.** TCG/TCI bugs are explicitly outside the upstream
   security boundary.

2. **On iOS, there is zero process isolation.** QEMU runs as a thread in
   the same process as UTM SE. The iOS App Sandbox is the only confinement
   mechanism.

3. **Device emulation is the primary attack surface**, with well-documented
   vulnerability classes (DMA reentrancy, heap overflows, OOB access,
   use-after-free) all exploitable from guest code.

4. **9pfs/VirtFS has a history of host filesystem escape vulnerabilities**,
   notably CVE-2023-2861.

5. **The TCI interpreter has one security advantage**: no W+X memory
   requirement, making it compatible with W^X policies and CFI. However,
   this is an architectural property, not a guest isolation mechanism.

6. **No bug bounty program exists**, but the project has accepted and acted
   on externally reported vulnerabilities.

---

## References

1. QEMU Security Documentation — https://qemu-project.gitlab.io/qemu/system/security.html
2. QEMU Security Process — https://www.qemu.org/contribute/security-process/
3. UTM GitHub Repository — https://github.com/utmapp/UTM
4. UTM Architecture Documentation — https://github.com/utmapp/UTM/blob/main/Documentation/Architecture.md
5. UTM SE Documentation — https://docs.getutm.app/
6. QEMU TCG Multi-thread Documentation — https://www.qemu.org/docs/master/devel/multi-thread-tcg.html
7. CVE-2023-2861 (9pfs escape) — https://www.mail-archive.com/qemu-devel@nongnu.org/msg967749.html
8. CVE-2024-3446 (DMA reentrancy) — https://github.com/advisories/GHSA-rgvf-j3x5-6277
9. CVE-2020-24165 (TCG) — https://ubuntu.com/security/notices/USN-6567-1
10. Google Vulnerability Report #6156 — https://github.com/utmapp/UTM/issues/6156

---

*This document is intended for academic security research and authorized
bug bounty activities. Always follow responsible disclosure practices.*
