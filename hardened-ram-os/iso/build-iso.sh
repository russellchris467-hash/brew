#!/usr/bin/env bash
# =============================================================================
# build-iso.sh — Build bootable ISO and USB image for Hardened RAM-OS
# =============================================================================
# Produces:
#   - A hybrid ISO (boots from CD/DVD and USB)
#   - A raw disk image with a GRUB EFI + BIOS combo bootloader
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

KERNEL_VERSION="${KERNEL_VERSION:-6.6.30}"
OUTPUT_DIR="${OUTPUT_DIR:-/tmp/kernel-output}"
# BUG-04 FIX: "/tmp/ramOS-iso-$$" is predictable.  A local attacker can race to
# create /tmp/ramOS-iso-<PID> as a symlink before this script runs; the cleanup
# trap then does `rm -rf <symlink_target>`, wiping an arbitrary directory.
# mktemp -d creates a directory with a random suffix and only the current user
# can access it (mode 0700), eliminating both the symlink race and info leakage.
ISO_WORK="$(mktemp -d /tmp/ramOS-iso-XXXXXX)"
ISO_NAME="hardened-ramOS-${KERNEL_VERSION}-$(date +%Y%m%d).iso"
ISO_OUTPUT="${OUTPUT_DIR}/${ISO_NAME}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()  { echo -e "${BLUE}[*]${NC} $*"; }
ok()   { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
die()  { echo -e "${RED}[-]${NC} $*" >&2; exit 1; }

cleanup() { rm -rf "$ISO_WORK"; }
trap cleanup EXIT

check_deps() {
    local missing=()
    for cmd in grub-mkrescue xorriso mtools; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    [[ ${#missing[@]} -gt 0 ]] && die "Missing: ${missing[*]}\n  apt-get install grub-pc-bin grub-efi-amd64-bin xorriso mtools"
}

# ---------------------------------------------------------------------------
# Set up ISO staging area
# ---------------------------------------------------------------------------
prepare_iso_tree() {
    log "Preparing ISO tree..."
    mkdir -p "${ISO_WORK}"/{boot/{grub,grub/fonts},live,EFI/BOOT}

    # Copy kernel
    local vmlinuz="${OUTPUT_DIR}/boot/vmlinuz-${KERNEL_VERSION}-hardened"
    local initrd="${OUTPUT_DIR}/boot/initramfs-${KERNEL_VERSION}-hardened.img"
    local squash="${OUTPUT_DIR}/live/filesystem.squashfs"

    [[ -f "$vmlinuz" ]] || die "Kernel not found: ${vmlinuz}\n  Run kernel/build-kernel.sh first"
    [[ -f "$initrd" ]] || die "Initramfs not found: ${initrd}\n  Run initramfs/build-initramfs.sh first"
    [[ -f "$squash" ]] || die "Squashfs not found: ${squash}\n  Run rootfs/build-rootfs.sh first"

    cp "$vmlinuz" "${ISO_WORK}/boot/vmlinuz"
    cp "$initrd"  "${ISO_WORK}/boot/initrd.img"
    cp "$squash"  "${ISO_WORK}/live/filesystem.squashfs"
    cp "${squash}.sha256" "${ISO_WORK}/live/filesystem.squashfs.sha256" 2>/dev/null || true

    ok "Kernel, initramfs, and squashfs staged"
}

# ---------------------------------------------------------------------------
# GRUB configuration
# ---------------------------------------------------------------------------
write_grub_config() {
    log "Writing GRUB configuration..."

    local KERNEL_CMDLINE="quiet splash loglevel=3 apparmor=1 security=apparmor selinux=0"
    # FIX(LOW): Added TAA (tsx_async_abort), SRBDS (srbds), and MMIO stale data
    # mitigations which were absent from the original cmdline.
    local HARDEN_CMDLINE="init_on_alloc=1 init_on_free=1 slab_nomerge vsyscall=none page_alloc.shuffle=1 randomize_kstack_offset=on spectre_v2=on spec_store_bypass_disable=on l1tf=full,force mds=full,nosmt pti=on tsx=off tsx_async_abort=full,nosmt srbds=full mmio_stale_data=full,nosmt"
    local AMNESIAC_CMDLINE="toram=1 forensic=0"

    # FIX(HIGH): GRUB superuser was declared but no password_pbkdf2 line was present,
    # meaning ANY user could edit boot entries and inject arbitrary kernel parameters
    # (e.g. init=/bin/sh, removing apparmor=1, disabling toram).
    # Now we require a GRUB_ADMIN_HASH env var containing a grub-mkpasswd-pbkdf2 hash.
    # Generate with:  grub-mkpasswd-pbkdf2 | grep -oP 'grub\.pbkdf2\S+'
    local grub_password_line=""
    if [[ -n "${GRUB_ADMIN_HASH:-}" ]]; then
        grub_password_line="password_pbkdf2 admin ${GRUB_ADMIN_HASH}"
        log "GRUB admin password hash set"
    else
        warn "GRUB_ADMIN_HASH not set — boot menu entries will NOT be password-protected."
        warn "Anyone with physical access can edit kernel parameters (e.g. disable apparmor, toram)."
        warn "Generate a hash: grub-mkpasswd-pbkdf2 | grep -oP 'grub\\.pbkdf2\\S+'"
        warn "Then re-run with: GRUB_ADMIN_HASH=<hash> ./build-iso.sh"
        grub_password_line="# WARNING: no password set — boot entries are unprotected"
    fi

    cat > "${ISO_WORK}/boot/grub/grub.cfg" << GRUB_EOF
# ===========================================================================
# Hardened RAM-OS GRUB Configuration
# ===========================================================================
set default=0
# BUG-23 FIX: 10-second timeout is too long for a security-focused system.
# It gives a bystander ample time to read all boot option labels (revealing the
# system's purpose) and attempt to interact with the menu.  Reduced to 5s.
set timeout=5
set timeout_style=countdown

set superusers="admin"
${grub_password_line}

insmod all_video
insmod gfxterm
insmod png

if loadfont /boot/grub/fonts/unicode.pf2; then
    terminal_output gfxterm
fi

# Color scheme
set color_normal=cyan/black
set color_highlight=black/cyan
set menu_color_normal=cyan/black
set menu_color_highlight=black/cyan

# ---------------------------------------------------------------------------
menuentry "Hardened RAM-OS (Full Amnesiac)" --id ramOS-default {
    linux  /boot/vmlinuz ${KERNEL_CMDLINE} ${HARDEN_CMDLINE} ${AMNESIAC_CMDLINE}
    initrd /boot/initrd.img
}

menuentry "Hardened RAM-OS (Forensic Mode — No Auto-Mount)" --id ramOS-forensic {
    linux  /boot/vmlinuz ${KERNEL_CMDLINE} ${HARDEN_CMDLINE} toram=1 forensic=1
    initrd /boot/initrd.img
}

menuentry "Hardened RAM-OS (Debug — verbose boot)" --id ramOS-debug {
    linux  /boot/vmlinuz ${KERNEL_CMDLINE} ${HARDEN_CMDLINE} ${AMNESIAC_CMDLINE} debug loglevel=7
    initrd /boot/initrd.img
}

menuentry "Hardened RAM-OS (Safe Mode — basic drivers)" --id ramOS-safe {
    linux  /boot/vmlinuz ${KERNEL_CMDLINE} nomodeset ${AMNESIAC_CMDLINE} acpi=off
    initrd /boot/initrd.img
}

# BUG-05 FIX: `chainloader +1` is a BIOS/MBR-specific mechanism that reads the
# first sector of the current partition's disk.  On UEFI systems (the dominant
# boot mode since ~2012) this causes a GRUB error: "error: invalid signature".
# Fix: detect the platform at runtime and use the appropriate chainloader.
menuentry "Boot from local disk" --id local-boot {
    if [ "${grub_platform}" = "efi" ]; then
        # UEFI: boot the EFI system partition's default loader
        chainloader /EFI/BOOT/bootx64.efi 2>/dev/null || \
        chainloader /EFI/Microsoft/Boot/bootmgfw.efi 2>/dev/null || \
        exit 1
    else
        # BIOS/MBR: chainload first sector
        chainloader +1
    fi
}

menuentry "Reboot" --id reboot {
    reboot
}

menuentry "Power Off" --id poweroff {
    halt
}
GRUB_EOF

    ok "GRUB config written"
}

# ---------------------------------------------------------------------------
# Build the hybrid ISO
# ---------------------------------------------------------------------------
build_iso() {
    log "Building hybrid ISO (BIOS + UEFI)..."
    mkdir -p "$(dirname "$ISO_OUTPUT")"

    grub-mkrescue \
        --output="$ISO_OUTPUT" \
        --compress=xz \
        "$ISO_WORK" \
        -- \
        -V "HARDENED-RAMOS" \
        -publisher "Hardened RAM-OS Project" \
        -appid "HARDENED-RAMOS-$(date +%Y%m%d)" 2>&1 | tail -5

    local size
    size=$(du -sh "$ISO_OUTPUT" | cut -f1)
    ok "ISO built: ${ISO_OUTPUT} (${size})"

    # Generate checksums
    log "Computing ISO checksums..."
    (cd "$(dirname "$ISO_OUTPUT")" && {
        sha256sum "$(basename "$ISO_OUTPUT")" > "${ISO_NAME}.sha256"
        sha512sum "$(basename "$ISO_OUTPUT")" > "${ISO_NAME}.sha512"
    })
    ok "SHA256: $(cat "${OUTPUT_DIR}/${ISO_NAME}.sha256" | cut -d' ' -f1)"
}

# ---------------------------------------------------------------------------
# Sign the ISO (optional, for Secure Boot chain)
# ---------------------------------------------------------------------------
sign_iso() {
    local sign_key="${SIGN_KEY:-}"
    [[ -z "$sign_key" ]] && { warn "No SIGN_KEY set — ISO unsigned"; return; }

    log "Signing ISO with GPG key ${sign_key}..."
    gpg --armor --detach-sign \
        --default-key "$sign_key" \
        --output "${ISO_OUTPUT}.asc" \
        "$ISO_OUTPUT"
    ok "ISO signed: ${ISO_OUTPUT}.asc"
}

# ---------------------------------------------------------------------------
# Optionally write directly to a USB device
# ---------------------------------------------------------------------------
write_usb() {
    local target="${USB_DEV:-}"
    [[ -z "$target" ]] && { warn "USB_DEV not set — skipping USB write"; return; }
    [[ -b "$target" ]] || die "USB_DEV=${target} is not a block device"

    warn "About to write to ${target} — THIS WILL ERASE THE DEVICE"
    warn "Press Ctrl-C within 5 seconds to abort..."
    sleep 5

    log "Writing ISO to ${target}..."
    dd if="$ISO_OUTPUT" of="$target" bs=4M status=progress conv=fsync
    sync
    ok "Written to ${target}"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    check_deps

    log "=== Hardened RAM-OS ISO Builder ==="
    log "Kernel version: ${KERNEL_VERSION}"
    log "ISO output:     ${ISO_OUTPUT}"
    echo ""

    prepare_iso_tree
    write_grub_config
    build_iso
    sign_iso
    write_usb

    echo ""
    echo "============================================================"
    echo -e "${GREEN}  ISO Build Complete${NC}"
    echo "============================================================"
    echo "  ISO:    ${ISO_OUTPUT}"
    echo "  SHA256: ${OUTPUT_DIR}/${ISO_NAME}.sha256"
    echo ""
    echo "  Write to USB:"
    echo "    sudo USB_DEV=/dev/sdX ./iso/build-iso.sh"
    echo "  OR manually:"
    echo "    sudo dd if=${ISO_OUTPUT} of=/dev/sdX bs=4M status=progress conv=fsync"
    echo ""
    echo "  Boot options:"
    echo "    Full Amnesiac  — Default. Loads all to RAM, no persistence."
    echo "    Forensic Mode  — Prevents auto-mounting local disks."
    echo "    Debug          — Verbose kernel messages for troubleshooting."
    echo "    Safe Mode      — Basic drivers, no ACPI, for compatibility."
    echo "============================================================"
}

main "$@"
