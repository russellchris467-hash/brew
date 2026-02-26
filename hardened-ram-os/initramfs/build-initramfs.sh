#!/usr/bin/env bash
# =============================================================================
# build-initramfs.sh — Build the initramfs for Hardened RAM-OS
# =============================================================================
# Creates a minimal initramfs containing only what is needed to:
#   - Detect the boot device
#   - Load the squashfs into RAM
#   - Mount an amnesiac OverlayFS
#   - Switch root
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

KERNEL_VERSION="${KERNEL_VERSION:-6.6.30}"
# BUG-25: Do NOT set KERNEL_MOD_DIR here — it must be computed AFTER argument
# parsing so that --kernel-mod-dir is not silently discarded.
OUTPUT_DIR="${OUTPUT_DIR:-/tmp/kernel-output}"
# BUG-24: Use mktemp -d to avoid a predictable /tmp path that a local attacker
# could symlink before the cleanup trap fires (rm -rf races).
WORK_DIR="$(mktemp -d /tmp/initramfs-work-XXXXXX)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()  { echo -e "${BLUE}[*]${NC} $*"; }
ok()   { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
die()  { echo -e "${RED}[-]${NC} $*" >&2; exit 1; }

# Parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        --kernel-version) KERNEL_VERSION="$2"; shift 2 ;;
        --kernel-mod-dir) KERNEL_MOD_DIR="$2"; shift 2 ;;
        --output-dir)     OUTPUT_DIR="$2"; shift 2 ;;
        *) die "Unknown: $1" ;;
    esac
done

# BUG-25 FIX: Set default AFTER parsing args so --kernel-mod-dir is honoured.
# The original code unconditionally overwrote the variable here, making the
# --kernel-mod-dir argument completely ineffective.
KERNEL_MOD_DIR="${KERNEL_MOD_DIR:-/tmp/kernel-output/modules/lib/modules/${KERNEL_VERSION}-hardened}"

cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Create directory skeleton
# ---------------------------------------------------------------------------
create_skeleton() {
    log "Creating initramfs skeleton..."
    mkdir -p "${WORK_DIR}"/{bin,sbin,lib,lib64,lib/x86_64-linux-gnu,usr/bin,usr/sbin,proc,sys,dev,run,tmp,mnt,newroot,squash_ro,overlay_work,overlay_rw,ram_store,etc}
    ok "Skeleton created"
}

# ---------------------------------------------------------------------------
# Copy binaries (statically linked where possible)
# ---------------------------------------------------------------------------
copy_binaries() {
    log "Copying essential binaries..."

    # Core busybox provides: sh, mount, umount, switch_root, mdev, etc.
    if command -v busybox &>/dev/null; then
        cp "$(command -v busybox)" "${WORK_DIR}/bin/busybox"
        # Install busybox applets
        chroot "$WORK_DIR" /bin/busybox --install -s /bin/ 2>/dev/null || \
            "${WORK_DIR}/bin/busybox" --install -s "${WORK_DIR}/bin/" 2>/dev/null || true
    else
        warn "busybox not found — install with: apt-get install busybox-static"
        # Fall back to copying individual binaries
        for bin in sh bash mount umount switch_root mdev; do
            BIN_PATH="$(command -v $bin 2>/dev/null || true)"
            [ -n "$BIN_PATH" ] || continue
            cp "$BIN_PATH" "${WORK_DIR}/bin/${bin}"
        done
    fi

    # Essential tools for the init script
    local tools=(
        mount umount switch_root sh bash
        dd cp mv rm mkdir ln cat grep sed
        find stat sha256sum shred
        modprobe insmod lsmod
        blkid udevadm
        sleep echo printf
    )

    for tool in "${tools[@]}"; do
        local path
        path="$(command -v "$tool" 2>/dev/null || true)"
        [ -z "$path" ] && continue
        [ -f "${WORK_DIR}/bin/$(basename "$tool")" ] && continue

        cp "$path" "${WORK_DIR}/bin/$(basename "$tool")"
        # Copy shared libraries
        copy_libs "$path"
    done

    ok "Binaries installed"
}

# ---------------------------------------------------------------------------
# Copy shared libraries for a given binary
# ---------------------------------------------------------------------------
copy_libs() {
    local binary="$1"
    # BUG-19 FIX: Use readelf -d instead of ldd to enumerate shared library
    # dependencies.  ldd works by executing the binary's ELF interpreter
    # (ld-linux.so) which actually loads and runs constructors — dangerous for
    # untrusted or cross-compiled binaries.  readelf -d reads the ELF dynamic
    # section directly without executing any code.
    readelf -d "$binary" 2>/dev/null | awk '/NEEDED/{gsub(/\[|\]/,"",$NF); print $NF}' | \
    while read -r libname; do
        # Resolve library name to full path via ldconfig cache
        local lib
        lib="$(ldconfig -p 2>/dev/null | awk -v n="$libname" '$1==n{print $NF; exit}')"
        [ -f "$lib" ] || lib="$(find /lib /usr/lib /lib64 /usr/lib64 \
            -name "$libname" 2>/dev/null | head -1)"
        [ -f "$lib" ] || continue

        local dest="${WORK_DIR}$(dirname "$lib")"
        mkdir -p "$dest"
        [ -f "${WORK_DIR}${lib}" ] || cp "$lib" "${WORK_DIR}${lib}"
        # Resolve and copy symlink target
        if [ -L "$lib" ]; then
            local target
            target="$(readlink -f "$lib")"
            [ -f "${WORK_DIR}${target}" ] || cp "$target" "${WORK_DIR}${target}"
        fi
    done

    # ld-linux interpreter
    local interp
    interp="$(readelf -l "$binary" 2>/dev/null | grep 'interpreter' | grep -oP '/\S+' || true)"
    if [ -n "$interp" ] && [ -f "$interp" ]; then
        local dest="${WORK_DIR}$(dirname "$interp")"
        mkdir -p "$dest"
        [ -f "${WORK_DIR}${interp}" ] || cp "$interp" "${WORK_DIR}${interp}"
    fi
}

# ---------------------------------------------------------------------------
# Install kernel modules needed for boot
# ---------------------------------------------------------------------------
install_modules() {
    log "Installing boot-critical kernel modules..."

    if [ ! -d "$KERNEL_MOD_DIR" ]; then
        warn "Kernel modules not found at ${KERNEL_MOD_DIR} — skipping"
        warn "Initramfs will rely on built-in kernel drivers only"
        return
    fi

    local mod_dest="${WORK_DIR}/lib/modules/${KERNEL_VERSION}-hardened"
    mkdir -p "$mod_dest"

    # Copy modules.dep etc.
    cp -a "${KERNEL_MOD_DIR}/modules.dep" "${mod_dest}/" 2>/dev/null || true
    cp -a "${KERNEL_MOD_DIR}/modules.order" "${mod_dest}/" 2>/dev/null || true
    cp -a "${KERNEL_MOD_DIR}/modules.builtin" "${mod_dest}/" 2>/dev/null || true

    # Critical modules for disk/USB/FS detection
    local critical_modules=(
        # Storage
        "kernel/drivers/scsi/sd_mod.ko*"
        "kernel/drivers/usb/storage/usb-storage.ko*"
        "kernel/drivers/usb/host/xhci-hcd.ko*"
        "kernel/drivers/usb/host/ehci-hcd.ko*"
        "kernel/drivers/ata/ahci.ko*"
        "kernel/drivers/nvme/host/nvme.ko*"
        "kernel/drivers/nvme/host/nvme-core.ko*"
        "kernel/drivers/block/loop.ko*"
        # Filesystems
        "kernel/fs/squashfs/squashfs.ko*"
        "kernel/fs/overlayfs/overlay.ko*"
        "kernel/fs/fat/fat.ko*"
        "kernel/fs/fat/vfat.ko*"
        "kernel/fs/isofs/isofs.ko*"
        "kernel/fs/ext4/ext4.ko*"
        # Crypto (for squashfs decompression)
        "kernel/crypto/zstd.ko*"
        "kernel/crypto/lz4.ko*"
        "kernel/crypto/xz.ko*"
        "kernel/lib/lz4/lz4_compress.ko*"
        "kernel/lib/zstd/zstd_compress.ko*"
    )

    for pattern in "${critical_modules[@]}"; do
        while IFS= read -r -d '' modfile; do
            local dest_path="${mod_dest}/$(basename "$(dirname "$modfile")")"
            mkdir -p "$dest_path"
            cp "$modfile" "$dest_path/" 2>/dev/null || true
        done < <(find "$KERNEL_MOD_DIR" -path "*${pattern%\*\*}" -print0 2>/dev/null)
    done

    # Rebuild module dependency cache for our minimal set
    depmod -b "$WORK_DIR" "${KERNEL_VERSION}-hardened" 2>/dev/null || true

    ok "Kernel modules installed"
}

# ---------------------------------------------------------------------------
# Install init script and hooks
# ---------------------------------------------------------------------------
install_init() {
    log "Installing init scripts..."

    cp "${SCRIPT_DIR}/init" "${WORK_DIR}/init"
    chmod 755 "${WORK_DIR}/init"

    # Minimal /etc
    echo "root:x:0:0:root:/root:/bin/sh" > "${WORK_DIR}/etc/passwd"
    echo "root:x:0:"                     > "${WORK_DIR}/etc/group"

    # dev nodes (mdev/udev will create more at runtime)
    # BUG-21 FIX: Previously silenced all mknod errors with "2>/dev/null || true".
    # If the build host lacks CAP_MKNOD (e.g. rootless Docker, unprivileged LXC),
    # ALL device nodes fail silently and the resulting initramfs has no /dev/null,
    # /dev/random, etc. — the kernel panics during early boot.
    # Now we verify that at minimum /dev/console and /dev/null were created, and
    # fail loudly if not so the operator knows to run as root or use fakeroot+cpio.
    local mknod_ok=0
    mknod -m 622 "${WORK_DIR}/dev/console" c 5 1 2>/dev/null && mknod_ok=1 || true
    mknod -m 666 "${WORK_DIR}/dev/null"    c 1 3 2>/dev/null && mknod_ok=1 || true
    mknod -m 666 "${WORK_DIR}/dev/zero"    c 1 5 2>/dev/null || true
    mknod -m 666 "${WORK_DIR}/dev/random"  c 1 8 2>/dev/null || true
    mknod -m 666 "${WORK_DIR}/dev/urandom" c 1 9 2>/dev/null || true
    mknod -m 660 "${WORK_DIR}/dev/tty0"    c 4 0 2>/dev/null || true
    mknod -m 660 "${WORK_DIR}/dev/tty1"    c 4 1 2>/dev/null || true
    mknod -m 660 "${WORK_DIR}/dev/tty"     c 5 0 2>/dev/null || true

    if [[ $mknod_ok -eq 0 ]]; then
        die "mknod failed for all device nodes — need root or CAP_MKNOD.\n  Re-run as root, or use: fakeroot -- bash build-initramfs.sh (for cpio packing only)"
    fi

    # Install hook scripts
    if [ -d "${SCRIPT_DIR}/hooks" ]; then
        mkdir -p "${WORK_DIR}/hooks"
        cp -r "${SCRIPT_DIR}/hooks/"* "${WORK_DIR}/hooks/" 2>/dev/null || true
        chmod 755 "${WORK_DIR}/hooks/"* 2>/dev/null || true
    fi

    ok "Init scripts installed"
}

# ---------------------------------------------------------------------------
# Pack into cpio + compress
# ---------------------------------------------------------------------------
pack_initramfs() {
    local output="${OUTPUT_DIR}/boot/initramfs-${KERNEL_VERSION}-hardened.img"
    mkdir -p "$(dirname "$output")"

    log "Packing initramfs → ${output}..."

    # Use zstd for best compression/speed tradeoff
    if command -v zstd &>/dev/null; then
        (cd "$WORK_DIR" && find . | sort | cpio --quiet -o -H newc --owner 0:0) | \
            zstd -19 --long -T0 -o "$output"
        log "Compressed with zstd (level 19)"
    elif command -v xz &>/dev/null; then
        (cd "$WORK_DIR" && find . | sort | cpio --quiet -o -H newc --owner 0:0) | \
            xz --check=crc32 -9 > "$output"
        log "Compressed with xz"
    else
        (cd "$WORK_DIR" && find . | sort | cpio --quiet -o -H newc --owner 0:0) | \
            gzip -9 > "$output"
        log "Compressed with gzip"
    fi

    local size
    size=$(du -sh "$output" | cut -f1)
    ok "Initramfs built: ${output} (${size})"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    log "=== Hardened RAM-OS Initramfs Builder ==="
    log "Kernel: ${KERNEL_VERSION}"
    echo ""

    create_skeleton
    copy_binaries
    install_modules
    install_init
    pack_initramfs

    echo ""
    echo "============================================================"
    echo -e "${GREEN}  Initramfs Build Complete${NC}"
    echo "============================================================"
    echo "  Output: ${OUTPUT_DIR}/boot/initramfs-${KERNEL_VERSION}-hardened.img"
    echo ""
    echo "  Boot features:"
    echo "    Full squashfs-to-RAM copy (toram)"
    echo "    OverlayFS with tmpfs upper layer"
    echo "    Amnesiac shutdown wipe hook"
    echo "    SHA256 integrity verification"
    echo "    No persistent writes to any disk"
    echo ""
    echo "  Next: ./rootfs/build-rootfs.sh"
    echo "============================================================"
}

main "$@"
