#!/usr/bin/env bash
# =============================================================================
# build.sh — Hardened RAM-OS Master Build Orchestrator
# =============================================================================
# Runs the full build pipeline:
#   1. Build hardened Linux kernel
#   2. Build initramfs (amnesiac boot logic)
#   3. Build root filesystem (Kali-based, hardened)
#   4. Pack everything into a bootable ISO
#
# Usage:
#   sudo ./build.sh [OPTIONS]
#
# Options:
#   --kernel-version VER    Linux kernel version (default: 6.6.30)
#   --jobs N                Parallel build jobs (default: nproc)
#   --output-dir DIR        Output directory (default: /tmp/ramOS-output)
#   --skip-kernel           Skip kernel build (use existing)
#   --skip-initramfs        Skip initramfs build
#   --skip-rootfs           Skip rootfs build
#   --skip-iso              Skip ISO build
#   --sign-key PATH         Path to Secure Boot signing key (.pem)
#   --usb-dev DEV           USB device to write ISO to (e.g. /dev/sdb)
#   --help                  Show this help
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
KERNEL_VERSION="6.6.30"
JOBS="$(nproc)"
OUTPUT_DIR="/tmp/ramOS-output"
SKIP_KERNEL=0
SKIP_INITRAMFS=0
SKIP_ROOTFS=0
SKIP_ISO=0
SIGN_KEY=""
USB_DEV=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# Colours & logging
# ---------------------------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; MAGENTA='\033[0;35m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
log()     { echo -e "${BLUE}[*]${NC} $*"; }
ok()      { echo -e "${GREEN}[+]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
die()     { echo -e "${RED}[-]${NC} $*" >&2; exit 1; }
phase()   { echo -e "\n${MAGENTA}${BOLD}══════════════════════════════════════${NC}"; echo -e "${MAGENTA}${BOLD}  $*${NC}"; echo -e "${MAGENTA}${BOLD}══════════════════════════════════════${NC}\n"; }
elapsed() { echo -e "${CYAN}  ⏱  $(date -u -d @$((SECONDS - START_SECONDS)) '+%H:%M:%S')${NC}"; }

START_SECONDS=$SECONDS

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
usage() {
    grep '^#' "$0" | grep -v '^#!' | sed 's/^# \?//'
    exit 0
}

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --kernel-version)  KERNEL_VERSION="$2"; shift 2 ;;
        --jobs)            JOBS="$2"; shift 2 ;;
        --output-dir)      OUTPUT_DIR="$2"; shift 2 ;;
        --skip-kernel)     SKIP_KERNEL=1; shift ;;
        --skip-initramfs)  SKIP_INITRAMFS=1; shift ;;
        --skip-rootfs)     SKIP_ROOTFS=1; shift ;;
        --skip-iso)        SKIP_ISO=1; shift ;;
        --sign-key)        SIGN_KEY="$2"; shift 2 ;;
        --usb-dev)         USB_DEV="$2"; shift 2 ;;
        --help|-h)         usage ;;
        *) die "Unknown argument: $1\n  Use --help for usage" ;;
    esac
done

# ---------------------------------------------------------------------------
# Environment checks
# ---------------------------------------------------------------------------
preflight_check() {
    log "Running preflight checks..."

    # Must be root for rootfs build (debootstrap/chroot)
    if [[ $EUID -ne 0 ]]; then
        warn "Not running as root — rootfs build will fail"
        warn "Re-run with: sudo $0 $*"
        if [[ $SKIP_ROOTFS -eq 0 ]]; then
            die "Exiting. Use --skip-rootfs to build without root, or run as root."
        fi
    fi

    # Disk space check (need ~15GB for full build)
    local free_gb
    free_gb=$(df -BG "${OUTPUT_DIR%/*}" 2>/dev/null | awk 'NR==2{print $4}' | tr -d G || echo 0)
    if [[ "${free_gb:-0}" -lt 15 ]]; then
        warn "Low disk space: ${free_gb}GB free (recommend 15+ GB for full build)"
    fi

    ok "Preflight checks passed"
}

# ---------------------------------------------------------------------------
# Export common environment variables for sub-scripts
# ---------------------------------------------------------------------------
export_env() {
    export KERNEL_VERSION
    export JOBS
    export OUTPUT_DIR
    export SIGN_KEY
    export USB_DEV
    export KERNEL_MOD_DIR="${OUTPUT_DIR}/modules/lib/modules/${KERNEL_VERSION}-hardened"
    export SQUASH_OUTPUT="${OUTPUT_DIR}/live/filesystem.squashfs"

    mkdir -p "$OUTPUT_DIR"
}

# ---------------------------------------------------------------------------
# Phase 1 — Kernel
# ---------------------------------------------------------------------------
build_kernel_phase() {
    [[ $SKIP_KERNEL -eq 1 ]] && { warn "Skipping kernel build"; return; }

    phase "Phase 1/4: Hardened Linux Kernel (${KERNEL_VERSION})"
    local phase_start=$SECONDS

    BUILD_DIR="${OUTPUT_DIR}/kernel-src" \
    KERNEL_VERSION="$KERNEL_VERSION" \
    JOBS="$JOBS" \
    OUTPUT_DIR="$OUTPUT_DIR" \
    SIGN_KEY="$SIGN_KEY" \
    bash "${SCRIPT_DIR}/kernel/build-kernel.sh" || die "Kernel build failed"

    ok "Kernel phase complete"; elapsed
}

# ---------------------------------------------------------------------------
# Phase 2 — Initramfs
# ---------------------------------------------------------------------------
build_initramfs_phase() {
    [[ $SKIP_INITRAMFS -eq 1 ]] && { warn "Skipping initramfs build"; return; }

    phase "Phase 2/4: Amnesiac Initramfs"
    local phase_start=$SECONDS

    KERNEL_VERSION="$KERNEL_VERSION" \
    KERNEL_MOD_DIR="$KERNEL_MOD_DIR" \
    OUTPUT_DIR="$OUTPUT_DIR" \
    bash "${SCRIPT_DIR}/initramfs/build-initramfs.sh" || die "Initramfs build failed"

    ok "Initramfs phase complete"; elapsed
}

# ---------------------------------------------------------------------------
# Phase 3 — Root Filesystem
# ---------------------------------------------------------------------------
build_rootfs_phase() {
    [[ $SKIP_ROOTFS -eq 1 ]] && { warn "Skipping rootfs build"; return; }

    phase "Phase 3/4: Root Filesystem + Kali Tools"
    log "NOTE: This phase downloads ~3-8 GB of packages"

    ROOTFS_DIR="${OUTPUT_DIR}/rootfs" \
    OUTPUT_DIR="$OUTPUT_DIR" \
    bash "${SCRIPT_DIR}/rootfs/build-rootfs.sh" || die "Rootfs build failed"

    ok "Rootfs phase complete"; elapsed
}

# ---------------------------------------------------------------------------
# Phase 4 — ISO
# ---------------------------------------------------------------------------
build_iso_phase() {
    [[ $SKIP_ISO -eq 1 ]] && { warn "Skipping ISO build"; return; }

    phase "Phase 4/4: Bootable ISO / USB Image"

    KERNEL_VERSION="$KERNEL_VERSION" \
    OUTPUT_DIR="$OUTPUT_DIR" \
    SIGN_KEY="$SIGN_KEY" \
    USB_DEV="$USB_DEV" \
    bash "${SCRIPT_DIR}/iso/build-iso.sh" || die "ISO build failed"

    ok "ISO phase complete"; elapsed
}

# ---------------------------------------------------------------------------
# Final summary
# ---------------------------------------------------------------------------
print_final_summary() {
    local total_time
    total_time=$(date -u -d @$((SECONDS - START_SECONDS)) '+%H:%M:%S')

    local iso_name
    iso_name=$(find "$OUTPUT_DIR" -name "*.iso" 2>/dev/null | head -1)
    local iso_size=""
    [[ -n "$iso_name" ]] && iso_size=" ($(du -sh "$iso_name" | cut -f1))"

    echo ""
    echo -e "${GREEN}${BOLD}"
    echo "  ╔══════════════════════════════════════════════════════╗"
    echo "  ║          HARDENED RAM-OS BUILD COMPLETE              ║"
    echo "  ╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo "  Total build time: ${total_time}"
    echo ""
    echo "  Artifacts:"
    if [[ -n "$iso_name" ]]; then
        echo "    ISO:      ${iso_name}${iso_size}"
        echo "    SHA256:   ${iso_name}.sha256"
    fi
    echo "    Kernel:   ${OUTPUT_DIR}/boot/vmlinuz-${KERNEL_VERSION}-hardened"
    echo "    Initrd:   ${OUTPUT_DIR}/boot/initramfs-${KERNEL_VERSION}-hardened.img"
    echo "    Squashfs: ${OUTPUT_DIR}/live/filesystem.squashfs"
    echo ""
    echo "  Security highlights:"
    echo -e "    ${GREEN}✔${NC} KASLR + KPTI + Retpoline + SMEP/SMAP"
    echo -e "    ${GREEN}✔${NC} Hardened usercopy + fortify + stackleak GCC plugin"
    echo -e "    ${GREEN}✔${NC} Init-on-alloc/free (DRAM cleared every allocation)"
    echo -e "    ${GREEN}✔${NC} Module signature enforcement (SHA-512)"
    echo -e "    ${GREEN}✔${NC} AppArmor + Yama LSM stack"
    echo -e "    ${GREEN}✔${NC} No /dev/mem, no kexec, no swap"
    echo -e "    ${GREEN}✔${NC} OverlayFS + tmpfs (100% RAM-resident writes)"
    echo -e "    ${GREEN}✔${NC} Squashfs loaded entirely into RAM (toram=1)"
    echo -e "    ${GREEN}✔${NC} Shutdown wipe: 3-pass zero wipe of RAM layers"
    echo -e "    ${GREEN}✔${NC} MAC address + hostname randomisation per boot"
    echo -e "    ${GREEN}✔${NC} Volatile journal, no persistent logs"
    echo -e "    ${GREEN}✔${NC} Shell history disabled (/dev/null)"
    echo -e "    ${GREEN}✔${NC} Full Kali tool suite (recon/wireless/exploit/forensics)"
    echo ""
    echo "  Write to USB:"
    echo "    sudo dd if=${iso_name:-output.iso} of=/dev/sdX bs=4M status=progress conv=fsync"
    echo ""
    echo "  IMPORTANT: This system is entirely amnesiac."
    echo "  All data is destroyed on shutdown or power loss."
    echo "  The boot device can be removed after the squashfs is loaded."
    echo ""
}

# ---------------------------------------------------------------------------
# Banner
# ---------------------------------------------------------------------------
print_banner() {
    echo -e "${RED}${BOLD}"
    echo "  ██╗  ██╗ █████╗ ██████╗ ██████╗ ███████╗███╗   ██╗███████╗██████╗ "
    echo "  ██║  ██║██╔══██╗██╔══██╗██╔══██╗██╔════╝████╗  ██║██╔════╝██╔══██╗"
    echo "  ███████║███████║██████╔╝██║  ██║█████╗  ██╔██╗ ██║█████╗  ██║  ██║"
    echo "  ██╔══██║██╔══██║██╔══██╗██║  ██║██╔══╝  ██║╚██╗██║██╔══╝  ██║  ██║"
    echo "  ██║  ██║██║  ██║██║  ██║██████╔╝███████╗██║ ╚████║███████╗██████╔╝"
    echo "  ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ ╚══════╝╚═╝  ╚═══╝╚══════╝╚═════╝ "
    echo -e "${NC}"
    echo -e "${CYAN}${BOLD}  RAM-OS: Hardened • Amnesiac • Kali-Powered${NC}"
    echo -e "${CYAN}  Kernel ${KERNEL_VERSION} LTS  |  $(date '+%Y-%m-%d %H:%M')${NC}"
    echo ""
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    print_banner
    preflight_check
    export_env

    build_kernel_phase
    build_initramfs_phase
    build_rootfs_phase
    build_iso_phase

    print_final_summary
}

main "$@"
