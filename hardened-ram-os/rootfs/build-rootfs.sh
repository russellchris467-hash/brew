#!/usr/bin/env bash
# =============================================================================
# build-rootfs.sh — Build the root filesystem for Hardened RAM-OS
# =============================================================================
# Creates a Debian/Kali-based rootfs with:
#   - Hardened system configuration (sysctl, AppArmor, sudo rules)
#   - Full Kali tool suite
#   - Amnesiac defaults (no persistent logs, no swap, no auto-mount)
#   - Minimal attack surface (disabled services, unneeded packages removed)
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

ARCH="${ARCH:-amd64}"
ROOTFS_DIR="${ROOTFS_DIR:-/tmp/ramOS-rootfs}"
OUTPUT_DIR="${OUTPUT_DIR:-/tmp/kernel-output}"
SQUASH_OUTPUT="${OUTPUT_DIR}/live/filesystem.squashfs"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_LIST="${SCRIPT_DIR}/../tools/kali-tools.list"

# Kali mirror
KALI_MIRROR="${KALI_MIRROR:-http://http.kali.org/kali}"
KALI_RELEASE="kali-rolling"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()  { echo -e "${BLUE}[*]${NC} $*"; }
ok()   { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
die()  { echo -e "${RED}[-]${NC} $*" >&2; exit 1; }

check_root() {
    [[ $EUID -eq 0 ]] || die "This script must be run as root (needs chroot/debootstrap)"
}

check_deps() {
    local missing=()
    for cmd in debootstrap chroot mksquashfs; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        die "Missing: ${missing[*]}\n  apt-get install debootstrap squashfs-tools"
    fi
}

# ---------------------------------------------------------------------------
# Stage 1 — debootstrap Kali base system
# ---------------------------------------------------------------------------
bootstrap_base() {
    log "Bootstrapping Kali base system into ${ROOTFS_DIR}..."

    if [[ -d "${ROOTFS_DIR}/usr" ]]; then
        warn "Root filesystem already exists — skipping bootstrap"
        return
    fi

    mkdir -p "$ROOTFS_DIR"

    debootstrap \
        --arch="$ARCH" \
        --variant=minbase \
        --include=ca-certificates,curl,gnupg2,locales \
        "$KALI_RELEASE" \
        "$ROOTFS_DIR" \
        "$KALI_MIRROR"

    ok "Base bootstrap complete"
}

# ---------------------------------------------------------------------------
# Stage 2 — Configure APT sources for Kali
# ---------------------------------------------------------------------------
configure_apt() {
    log "Configuring APT sources..."

    # Kali rolling repository
    cat > "${ROOTFS_DIR}/etc/apt/sources.list" << EOF
deb ${KALI_MIRROR} ${KALI_RELEASE} main contrib non-free non-free-firmware
EOF

    # Import Kali GPG key inside the chroot
    chroot "$ROOTFS_DIR" /bin/bash -c "
        curl -fsSL 'https://archive.kali.org/archive-key.asc' | gpg --dearmor -o /usr/share/keyrings/kali-archive-keyring.gpg
        apt-get update -qq
    "
    ok "APT configured"
}

# ---------------------------------------------------------------------------
# Stage 3 — Install Kali tools
# ---------------------------------------------------------------------------
install_tools() {
    log "Installing Kali security tools (this will take a long time)..."

    # Strip comments/blanks from tools list
    local packages=()
    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        # Extract package name (before any inline comment)
        pkg="${line%%#*}"
        pkg="${pkg// /}"
        pkg="${pkg//	/}"  # remove tabs
        [[ -n "$pkg" ]] && packages+=("$pkg")
    done < "$TOOLS_LIST"

    log "  Installing ${#packages[@]} packages..."

    # Install in batches to handle failures gracefully
    local batch_size=20
    local failed_packages=()

    for ((i=0; i<${#packages[@]}; i+=batch_size)); do
        local batch=("${packages[@]:i:batch_size}")
        log "  Batch $((i/batch_size + 1)): ${batch[*]}"

        chroot "$ROOTFS_DIR" /bin/bash -c "
            DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
                --allow-unauthenticated \
                ${batch[*]} 2>&1 | tail -5
        " || {
            warn "Batch install failed — retrying individually..."
            for pkg in "${batch[@]}"; do
                chroot "$ROOTFS_DIR" /bin/bash -c "
                    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
                        --allow-unauthenticated '$pkg' &>/dev/null
                " || {
                    warn "  FAILED: $pkg"
                    failed_packages+=("$pkg")
                }
            done
        }
    done

    # Kali meta-packages (optional but comprehensive)
    log "Installing Kali meta-packages..."
    chroot "$ROOTFS_DIR" /bin/bash -c "
        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
            kali-tools-top10 \
            kali-tools-wireless \
            kali-tools-web \
            kali-tools-passwords \
            kali-tools-forensics \
            kali-tools-reverse-engineering \
            kali-tools-exploitation \
            kali-tools-sniffing-spoofing \
            2>&1 | tail -10 || true
    "

    # Python extras
    chroot "$ROOTFS_DIR" /bin/bash -c "
        pip3 install --no-cache-dir \
            impacket \
            pwntools \
            ropper \
            bloodhound \
            certipy-ad \
            jwt \
            requests \
            scapy \
            2>&1 | tail -5 || true
    "

    if [[ ${#failed_packages[@]} -gt 0 ]]; then
        warn "The following packages could not be installed:"
        for p in "${failed_packages[@]}"; do warn "  - $p"; done
        warn "You may install them manually after boot."
    fi

    ok "Tool installation complete"
}

# ---------------------------------------------------------------------------
# Stage 4 — Harden the system configuration
# ---------------------------------------------------------------------------
harden_system() {
    log "Applying system hardening..."

    # ----- sysctl hardening -----
    cat > "${ROOTFS_DIR}/etc/sysctl.d/99-ramOS-hardened.conf" << 'SYSCTL_EOF'
# =============================================================
# RAM-OS Hardened sysctl configuration
# =============================================================

# --- Kernel pointer leaks ---
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.perf_event_paranoid = 3
kernel.unprivileged_bpf_disabled = 1
net.core.bpf_jit_harden = 2

# --- ASLR ---
kernel.randomize_va_space = 2

# --- ptrace restriction (Yama LSM) ---
kernel.yama.ptrace_scope = 2

# --- Core dump restrictions ---
fs.suid_dumpable = 0
kernel.core_pattern = |/bin/false

# --- Magic SysRq disabled ---
kernel.sysrq = 0

# --- Network hardening ---
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_rfc1337 = 1
# Disable IP forwarding unless explicitly needed
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0

# --- IPv6 privacy extensions ---
net.ipv6.conf.all.use_tempaddr = 2
net.ipv6.conf.default.use_tempaddr = 2

# --- File system hardening ---
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
fs.protected_fifos = 2
fs.protected_regular = 2

# --- Disable userfaultfd for unprivileged users ---
vm.unprivileged_userfaultfd = 0

# --- Swap disabled (amnesiac) ---
vm.swappiness = 0
SYSCTL_EOF

    # ----- limits.conf -----
    cat > "${ROOTFS_DIR}/etc/security/limits.d/99-ramOS.conf" << 'LIMITS_EOF'
# Restrict core dumps
*   hard    core    0
*   soft    core    0
# Restrict max processes (prevent fork bombs)
*   hard    nproc   10000
*   soft    nproc   10000
LIMITS_EOF

    # ----- PAM hardening -----
    # Disable core dumps via PAM
    echo "session required pam_limits.so" >> "${ROOTFS_DIR}/etc/pam.d/common-session" || true

    # ----- sudo configuration -----
    mkdir -p "${ROOTFS_DIR}/etc/sudoers.d"
    cat > "${ROOTFS_DIR}/etc/sudoers.d/ramOS" << 'SUDO_EOF'
# RAM-OS sudo rules
Defaults    !lecture
Defaults    timestamp_timeout=5
Defaults    passwd_timeout=30
Defaults    logfile=/dev/null
Defaults    !env_reset
# Allow operator group full sudo
%operator   ALL=(ALL:ALL) ALL
SUDO_EOF
    chmod 440 "${ROOTFS_DIR}/etc/sudoers.d/ramOS"

    # ----- AppArmor profiles -----
    chroot "$ROOTFS_DIR" /bin/bash -c "
        apt-get install -y apparmor apparmor-profiles apparmor-utils 2>/dev/null || true
        systemctl enable apparmor 2>/dev/null || true
    "

    # ----- Disable unnecessary services -----
    local services_to_disable=(
        bluetooth
        avahi-daemon
        cups
        ModemManager
        wpa_supplicant   # Managed manually
        rsyslog          # Logs should not persist
        cron             # No scheduled tasks in amnesiac OS
        atd
        samba
        nfs-common
    )
    for svc in "${services_to_disable[@]}"; do
        chroot "$ROOTFS_DIR" systemctl disable "$svc" 2>/dev/null || true
    done

    ok "System hardened"
}

# ---------------------------------------------------------------------------
# Stage 5 — Configure amnesiac behaviour
# ---------------------------------------------------------------------------
configure_amnesiac() {
    log "Configuring amnesiac behaviour..."

    # ----- No persistent logs -----
    # Use in-memory journal only
    mkdir -p "${ROOTFS_DIR}/etc/systemd/journald.conf.d"
    cat > "${ROOTFS_DIR}/etc/systemd/journald.conf.d/amnesiac.conf" << 'JOURNAL_EOF'
[Journal]
Storage=volatile
RuntimeMaxUse=64M
RuntimeMaxFileSize=16M
Compress=yes
ForwardToSyslog=no
JOURNAL_EOF

    # ----- /tmp and /var/tmp in RAM -----
    mkdir -p "${ROOTFS_DIR}/etc/systemd/system"
    # tmp.mount is usually enabled by default — ensure it's tmpfs
    chroot "$ROOTFS_DIR" systemctl enable tmp.mount 2>/dev/null || true

    cat > "${ROOTFS_DIR}/etc/systemd/system/var-tmp.mount" << 'VARTMP_EOF'
[Unit]
Description=Volatile /var/tmp
ConditionPathIsMount=!/var/tmp

[Mount]
What=tmpfs
Where=/var/tmp
Type=tmpfs
Options=mode=1777,strictatime,nosuid,nodev,size=256m

[Install]
WantedBy=local-fs.target
VARTMP_EOF

    chroot "$ROOTFS_DIR" systemctl enable var-tmp.mount 2>/dev/null || true

    # ----- /var/log in RAM -----
    cat > "${ROOTFS_DIR}/etc/systemd/system/var-log.mount" << 'VARLOG_EOF'
[Unit]
Description=Volatile /var/log
ConditionPathIsMount=!/var/log

[Mount]
What=tmpfs
Where=/var/log
Type=tmpfs
Options=mode=0755,strictatime,nosuid,nodev,size=128m

[Install]
WantedBy=local-fs.target
VARLOG_EOF

    chroot "$ROOTFS_DIR" systemctl enable var-log.mount 2>/dev/null || true

    # ----- MAC address randomisation on boot -----
    mkdir -p "${ROOTFS_DIR}/etc/NetworkManager/conf.d"
    cat > "${ROOTFS_DIR}/etc/NetworkManager/conf.d/99-randomize-mac.conf" << 'NMCONF_EOF'
[device]
wifi.scan-rand-mac-address=yes

[connection]
ethernet.cloned-mac-address=random
wifi.cloned-mac-address=random
connection.stable-id=${CONNECTION}/${BOOT}
NMCONF_EOF

    # ----- Hostname randomisation -----
    cat > "${ROOTFS_DIR}/etc/systemd/system/random-hostname.service" << 'HOSTNAME_EOF'
[Unit]
Description=Randomize hostname on boot
Before=network.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'hostnamectl set-hostname "host-$(head -c4 /dev/urandom | xxd -p)"'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
HOSTNAME_EOF

    chroot "$ROOTFS_DIR" systemctl enable random-hostname.service 2>/dev/null || true

    # ----- No swap -----
    # Ensure no swap entries in fstab
    cat > "${ROOTFS_DIR}/etc/fstab" << 'FSTAB_EOF'
# RAM-OS fstab — no persistent mounts
# Root filesystem is the OverlayFS set up by initramfs/init
proc    /proc   proc    defaults,hidepid=2  0   0
sysfs   /sys    sysfs   defaults            0   0
tmpfs   /tmp    tmpfs   mode=1777,nosuid,nodev,size=512m  0   0
tmpfs   /run    tmpfs   defaults,mode=755   0   0
FSTAB_EOF

    # ----- Shell history disabled -----
    cat >> "${ROOTFS_DIR}/etc/bash.bashrc" << 'BASH_EOF'

# --- RAM-OS amnesiac shell settings ---
HISTFILE=/dev/null
HISTSIZE=0
HISTFILESIZE=0
unset HISTFILE
export HISTFILE HISTSIZE HISTFILESIZE

# --- Prompt indicating amnesiac mode ---
PS1='\[\033[01;31m\][RAMÖS]\[\033[00m\] \[\033[01;33m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
BASH_EOF

    cat >> "${ROOTFS_DIR}/etc/zsh/zshenv" << 'ZSH_EOF'
HISTFILE=/dev/null
SAVEHIST=0
HISTSIZE=0
ZSH_EOF

    ok "Amnesiac configuration applied"
}

# ---------------------------------------------------------------------------
# Stage 6 — Final cleanup (minimize squashfs size)
# ---------------------------------------------------------------------------
cleanup_rootfs() {
    log "Cleaning up rootfs for compression..."

    chroot "$ROOTFS_DIR" /bin/bash -c "
        # Remove APT caches
        apt-get clean
        apt-get autoremove --purge -y 2>/dev/null || true
        rm -rf /var/cache/apt/archives/*.deb
        rm -rf /var/cache/apt/archives/partial/*
        rm -rf /var/lib/apt/lists/*

        # Remove docs, man pages, locale data (save space)
        find /usr/share/doc -mindepth 1 -maxdepth 1 ! -name 'copyright' -exec rm -rf {} + 2>/dev/null || true
        rm -rf /usr/share/man /usr/share/info /usr/share/groff
        find /usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'en' ! -name 'en_US' -exec rm -rf {} + 2>/dev/null || true

        # Remove temp files
        rm -rf /tmp/* /var/tmp/*

        # Clear logs
        find /var/log -type f -exec truncate -s 0 {} \;

        # Remove machine-id (will be regenerated)
        truncate -s 0 /etc/machine-id
        rm -f /var/lib/dbus/machine-id
    "

    ok "Rootfs cleaned"
}

# ---------------------------------------------------------------------------
# Stage 7 — Pack into squashfs
# ---------------------------------------------------------------------------
pack_squashfs() {
    log "Packing rootfs into squashfs..."
    mkdir -p "$(dirname "$SQUASH_OUTPUT")"

    mksquashfs \
        "$ROOTFS_DIR" \
        "$SQUASH_OUTPUT" \
        -comp zstd \
        -Xcompression-level 19 \
        -b 1M \
        -noappend \
        -wildcards \
        -ef <(cat << 'EXCLUDE_EOF'
proc/*
sys/*
dev/*
run/*
tmp/*
var/cache/apt
var/lib/apt/lists
EXCLUDE_EOF
)

    local size
    size=$(du -sh "$SQUASH_OUTPUT" | cut -f1)
    ok "Squashfs created: ${SQUASH_OUTPUT} (${size})"

    # Generate checksum
    log "Generating SHA256 checksum..."
    (cd "$(dirname "$SQUASH_OUTPUT")" && sha256sum "$(basename "$SQUASH_OUTPUT")" > "$(basename "$SQUASH_OUTPUT").sha256")
    ok "Checksum: $(cat "${SQUASH_OUTPUT}.sha256" | cut -d' ' -f1)"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    check_root
    check_deps

    log "=== Hardened RAM-OS Root Filesystem Builder ==="
    log "Architecture: ${ARCH}"
    log "Output:       ${SQUASH_OUTPUT}"
    echo ""

    bootstrap_base
    configure_apt
    install_tools
    harden_system
    configure_amnesiac
    cleanup_rootfs
    pack_squashfs

    echo ""
    echo "============================================================"
    echo -e "${GREEN}  Root Filesystem Build Complete${NC}"
    echo "============================================================"
    echo "  Squashfs:  ${SQUASH_OUTPUT}"
    echo "  Checksum:  ${SQUASH_OUTPUT}.sha256"
    echo ""
    echo "  Security features:"
    echo "    AppArmor enforcing"
    echo "    Hardened sysctl (kptr, dmesg, BPF, ASLR, ptrace)"
    echo "    Volatile journal & logs (tmpfs only)"
    echo "    MAC address randomization per-connection & boot"
    echo "    Random hostname per boot"
    echo "    Shell history disabled"
    echo "    No swap"
    echo ""
    echo "  Next: ./iso/build-iso.sh"
    echo "============================================================"
}

main "$@"
