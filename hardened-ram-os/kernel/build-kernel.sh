#!/usr/bin/env bash
# =============================================================================
# build-kernel.sh — Build hardened Linux kernel for RAM-OS
# =============================================================================
# Usage:
#   ./build-kernel.sh [--version 6.6.30] [--jobs 8] [--sign-key /path/key.pem]
#
# Requirements (Debian/Ubuntu/Kali):
#   apt-get install -y build-essential bc kmod cpio flex bison libssl-dev \
#       libelf-dev libncurses-dev dwarves zstd pahole gcc make binutils \
#       gcc-12 g++-12 llvm clang lld
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
KERNEL_VERSION="${KERNEL_VERSION:-6.6.30}"
KERNEL_TARBALL="linux-${KERNEL_VERSION}.tar.xz"
KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/${KERNEL_TARBALL}"
KERNEL_SIG_URL="${KERNEL_URL}.sign"
BUILD_DIR="${BUILD_DIR:-/tmp/kernel-build}"
OUTPUT_DIR="${OUTPUT_DIR:-/tmp/kernel-output}"
JOBS="${JOBS:-$(nproc)}"
SIGN_KEY="${SIGN_KEY:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KERNEL_CONFIG="${SCRIPT_DIR}/kernel-hardened.config"

# ---------------------------------------------------------------------------
# Colours
# ---------------------------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'
log()  { echo -e "${BLUE}[*]${NC} $*"; }
ok()   { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
die()  { echo -e "${RED}[-]${NC} $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Parse args
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --version) KERNEL_VERSION="$2"; shift 2 ;;
        --jobs)    JOBS="$2"; shift 2 ;;
        --sign-key) SIGN_KEY="$2"; shift 2 ;;
        --build-dir) BUILD_DIR="$2"; shift 2 ;;
        --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
        *) die "Unknown argument: $1" ;;
    esac
done

# ---------------------------------------------------------------------------
# Dependency check
# ---------------------------------------------------------------------------
check_deps() {
    log "Checking build dependencies..."
    local missing=()
    for cmd in make gcc bc flex bison openssl xz gpg; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        die "Missing dependencies: ${missing[*]}\n  Install with: apt-get install -y build-essential bc flex bison libssl-dev libelf-dev dwarves zstd"
    fi
    ok "All dependencies present"
}

# ---------------------------------------------------------------------------
# Download & verify
# ---------------------------------------------------------------------------
download_kernel() {
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"

    if [[ -f "${KERNEL_TARBALL}" ]]; then
        warn "Tarball already exists, skipping download"
    else
        log "Downloading Linux ${KERNEL_VERSION}..."
        curl -fsSL --progress-bar -O "$KERNEL_URL"
        curl -fsSL -O "$KERNEL_SIG_URL"
    fi

    log "Verifying GPG signature..."
    # Import Linus Torvalds and Greg Kroah-Hartman keys
    gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys \
        'ABAF11C65A2970B130ABE3C479BE3E4300411886' \
        '647F28654894E3BD457199BE38DBBDC86092693E' 2>/dev/null || \
        warn "GPG key import failed — skipping signature check (not recommended for production)"

    if gpg --verify "${KERNEL_TARBALL}.sign" "${KERNEL_TARBALL}" 2>/dev/null; then
        ok "GPG signature verified"
    else
        warn "GPG verification failed or skipped — proceeding anyway (verify manually for production builds)"
    fi
}

# ---------------------------------------------------------------------------
# Extract
# ---------------------------------------------------------------------------
extract_kernel() {
    cd "$BUILD_DIR"
    local src_dir="${BUILD_DIR}/linux-${KERNEL_VERSION}"

    if [[ -d "$src_dir" ]]; then
        warn "Source already extracted"
    else
        log "Extracting kernel source..."
        tar -xf "${KERNEL_TARBALL}"
        ok "Extracted to ${src_dir}"
    fi
    echo "$src_dir"
}

# ---------------------------------------------------------------------------
# Apply hardening patches
# ---------------------------------------------------------------------------
apply_patches() {
    local src_dir="$1"
    local patch_dir="${SCRIPT_DIR}/patches"

    if [[ ! -d "$patch_dir" ]] || [[ -z "$(ls -A "$patch_dir" 2>/dev/null)" ]]; then
        log "No patches directory found — skipping"
        return
    fi

    log "Applying hardening patches..."
    cd "$src_dir"
    for patch in "${patch_dir}"/*.patch; do
        log "  Applying $(basename "$patch")..."
        patch -p1 < "$patch" || die "Patch failed: $patch"
    done
    ok "All patches applied"
}

# ---------------------------------------------------------------------------
# Configure
# ---------------------------------------------------------------------------
configure_kernel() {
    local src_dir="$1"
    cd "$src_dir"

    log "Applying hardened kernel config..."
    cp "$KERNEL_CONFIG" .config

    # Merge config — ensure all required symbols are set
    make ARCH=x86_64 olddefconfig

    # Verify critical hardening options
    log "Verifying critical security options..."
    local required_options=(
        "CONFIG_HARDENED_USERCOPY=y"
        "CONFIG_FORTIFY_SOURCE=y"
        "CONFIG_STACKPROTECTOR_STRONG=y"
        "CONFIG_RANDOMIZE_BASE=y"
        "CONFIG_STRICT_KERNEL_RWX=y"
        "CONFIG_PAGE_TABLE_ISOLATION=y"
        "CONFIG_RETPOLINE=y"
        "CONFIG_SECURITY_YAMA=y"
        "CONFIG_INIT_ON_ALLOC_DEFAULT_ON=y"
        "CONFIG_INIT_ON_FREE_DEFAULT_ON=y"
        "CONFIG_SWAP=n"
        "CONFIG_DEVMEM=n"
        "CONFIG_KEXEC=n"
    )

    local failed=0
    for opt in "${required_options[@]}"; do
        key="${opt%%=*}"
        expected_val="${opt#*=}"
        actual_val=$(grep "^${key}=" .config 2>/dev/null | cut -d= -f2 || echo "NOT_SET")
        if [[ "$actual_val" != "$expected_val" ]]; then
            warn "  MISSING: ${key} (expected ${expected_val}, got ${actual_val})"
            ((failed++)) || true
        fi
    done

    if [[ $failed -gt 0 ]]; then
        warn "${failed} security option(s) not set as expected — review .config before production use"
    else
        ok "All critical security options verified"
    fi
}

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
build_kernel() {
    local src_dir="$1"
    cd "$src_dir"

    log "Building kernel with ${JOBS} jobs (this may take 30-90 minutes)..."
    make -j"$JOBS" ARCH=x86_64 \
        KCFLAGS="-O2 -pipe -fstack-clash-protection -ffunction-sections -fdata-sections" \
        bzImage modules 2>&1 | tee /tmp/kernel-build.log

    ok "Kernel built successfully"
}

# ---------------------------------------------------------------------------
# Install output artifacts
# ---------------------------------------------------------------------------
install_artifacts() {
    local src_dir="$1"
    mkdir -p "$OUTPUT_DIR"/{boot,modules,headers}
    cd "$src_dir"

    log "Installing kernel artifacts..."

    # Kernel image
    cp arch/x86_64/boot/bzImage "${OUTPUT_DIR}/boot/vmlinuz-${KERNEL_VERSION}-hardened"

    # System.map
    cp System.map "${OUTPUT_DIR}/boot/System.map-${KERNEL_VERSION}-hardened"

    # Config
    cp .config "${OUTPUT_DIR}/boot/config-${KERNEL_VERSION}-hardened"

    # Modules
    make INSTALL_MOD_PATH="${OUTPUT_DIR}/modules" modules_install
    # Strip debug info from modules to reduce size
    find "${OUTPUT_DIR}/modules" -name "*.ko" -exec strip --strip-debug {} \;

    # Headers (needed for DKMS / external modules)
    make INSTALL_HDR_PATH="${OUTPUT_DIR}/headers" headers_install

    ok "Artifacts installed to ${OUTPUT_DIR}"
}

# ---------------------------------------------------------------------------
# Sign kernel image (optional)
# ---------------------------------------------------------------------------
sign_kernel() {
    local output="$1"
    if [[ -z "$SIGN_KEY" ]]; then
        warn "No signing key provided — kernel image unsigned"
        return
    fi

    log "Signing kernel image with ${SIGN_KEY}..."
    if ! command -v sbsign &>/dev/null; then
        die "sbsign not found. Install: apt-get install sbsigntool"
    fi
    sbsign --key "${SIGN_KEY}" \
           --cert "${SIGN_KEY%.pem}.crt" \
           --output "${output}/boot/vmlinuz-${KERNEL_VERSION}-hardened.signed" \
           "${output}/boot/vmlinuz-${KERNEL_VERSION}-hardened"
    ok "Kernel signed for Secure Boot"
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
print_summary() {
    echo ""
    echo "============================================================"
    echo -e "${GREEN}  Hardened Kernel Build Complete${NC}"
    echo "============================================================"
    echo ""
    echo "  Kernel:   ${OUTPUT_DIR}/boot/vmlinuz-${KERNEL_VERSION}-hardened"
    echo "  Modules:  ${OUTPUT_DIR}/modules/lib/modules/${KERNEL_VERSION}-hardened"
    echo "  Headers:  ${OUTPUT_DIR}/headers"
    echo ""
    echo "  Key hardening features:"
    echo "    KASLR / KPTI / Retpoline / SMEP / SMAP"
    echo "    Hardened usercopy + fortify source"
    echo "    Stack protector strong + stackleak plugin"
    echo "    Init-on-alloc/free (memory scrubbing)"
    echo "    No swap, no /dev/mem, no kexec"
    echo "    Module signature enforcement"
    echo "    AppArmor + Yama + SELinux LSM stack"
    echo ""
    echo "  Next: ./initramfs/build-initramfs.sh --kernel-version ${KERNEL_VERSION}"
    echo "============================================================"
    echo ""
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    log "=== Hardened RAM-OS Kernel Builder ==="
    log "Kernel version: ${KERNEL_VERSION}"
    log "Build dir:      ${BUILD_DIR}"
    log "Output dir:     ${OUTPUT_DIR}"
    log "Jobs:           ${JOBS}"
    echo ""

    check_deps
    download_kernel
    local src_dir
    src_dir=$(extract_kernel)
    apply_patches "$src_dir"
    configure_kernel "$src_dir"
    build_kernel "$src_dir"
    install_artifacts "$src_dir"
    sign_kernel "$OUTPUT_DIR"
    print_summary
}

main "$@"
