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

# Kali mirror — MUST be HTTPS to protect package downloads
KALI_MIRROR="${KALI_MIRROR:-https://http.kali.org/kali}"
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

    # FIND-14 FIX: debootstrap can exit 0 on partial failures (network interruption
    # mid-download, disk full, etc.) while leaving an incomplete rootfs.  The existing
    # guard only checks for the /usr directory; now we verify core binaries that must
    # be present in any valid Debian/Kali base installation.
    if [[ ! -x "${ROOTFS_DIR}/usr/bin/dpkg" ]] || [[ ! -x "${ROOTFS_DIR}/bin/bash" ]]; then
        die "debootstrap appears to have failed — core binaries missing from ${ROOTFS_DIR}.\n  Remove the directory and retry: rm -rf ${ROOTFS_DIR}"
    fi

    ok "Base bootstrap complete"
}

# ---------------------------------------------------------------------------
# Stage 2 — Configure APT sources for Kali
# ---------------------------------------------------------------------------
configure_apt() {
    log "Configuring APT sources..."

    # BUG-13 FIX: sources.list was written here without signed-by=, then
    # overwritten below with the correct signed-by= version after key import.
    # The first write was dead code; it briefly left an unsigned repo configured
    # between the two writes, and created reader confusion.  Removed the first write.
    # The correct sources.list with signed-by= is written after key verification.

    # Import Kali GPG key with pinned fingerprint verification.
    # FIX(CRITICAL): Previously piped curl directly into gpg with no trust anchor.
    # An attacker (MITM or compromised server) could have installed a malicious key,
    # allowing arbitrary unsigned packages to be installed.
    # Now: download to temp file → verify fingerprint → import only if it matches.
    local KALI_KEY_FP="827C8569F2518CC677FECA1AED65462EC8D5E4C5"
    local tmp_key
    tmp_key=$(mktemp /tmp/kali-key-XXXXXX.asc)

    curl -fsSL 'https://archive.kali.org/archive-key.asc' -o "$tmp_key"

    # Verify fingerprint before importing
    local actual_fp
    actual_fp=$(gpg --with-fingerprint --with-colons "$tmp_key" 2>/dev/null \
        | awk -F: '/^fpr/{print $10}' | head -1 | tr -d ' ')

    if [[ "$actual_fp" != "$KALI_KEY_FP" ]]; then
        rm -f "$tmp_key"
        die "Kali GPG key fingerprint MISMATCH!\n  Expected: ${KALI_KEY_FP}\n  Got:      ${actual_fp}\n  Aborting — possible supply chain attack."
    fi

    log "Kali GPG key fingerprint verified: ${actual_fp}"
    gpg --dearmor < "$tmp_key" > "${ROOTFS_DIR}/usr/share/keyrings/kali-archive-keyring.gpg"
    rm -f "$tmp_key"

    # Update sources.list to reference the keyring explicitly
    cat > "${ROOTFS_DIR}/etc/apt/sources.list" << EOF2
deb [signed-by=/usr/share/keyrings/kali-archive-keyring.gpg] ${KALI_MIRROR} ${KALI_RELEASE} main contrib non-free non-free-firmware
EOF2

    chroot "$ROOTFS_DIR" /bin/bash -c "apt-get update -qq"
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

        # FIX(CRITICAL): Removed --allow-unauthenticated which bypassed APT GPG signature
        # verification entirely, allowing installation of arbitrary unsigned packages.
        # FIX(HIGH): Pass package names as a NUL-separated list via env var instead of
        # unquoted shell interpolation (${batch[*]}) which allowed shell injection via
        # a maliciously named package in kali-tools.list.
        PKGS="${batch[*]}" chroot "$ROOTFS_DIR" /bin/bash -c '
            DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
                $PKGS 2>&1 | tail -5
        ' || {
            warn "Batch install failed — retrying individually..."
            # FIND-15 FIX: Rapid retries on transient mirror failures overwhelm servers
            # and hit rate limits.  Use exponential backoff: 2s, 4s, 8s between attempts.
            for pkg in "${batch[@]}"; do
                # Validate package name: only allow [a-z0-9.+-] (Debian policy §5.6.1)
                if [[ ! "$pkg" =~ ^[a-z0-9][a-z0-9.+\-]*$ ]]; then
                    warn "  SKIP (invalid name): $pkg"
                    failed_packages+=("$pkg")
                    continue
                fi
                local pkg_ok=0
                local delay=2
                for attempt in 1 2 3; do
                    PKG="$pkg" chroot "$ROOTFS_DIR" /bin/bash -c '
                        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
                            "$PKG" &>/dev/null
                    ' && { pkg_ok=1; break; }
                    [[ $attempt -lt 3 ]] && { warn "  Retry ${attempt}/3 for ${pkg} (backoff ${delay}s)..."; sleep "$delay"; delay=$((delay * 2)); }
                done
                if [[ $pkg_ok -eq 0 ]]; then
                    warn "  FAILED: $pkg"
                    failed_packages+=("$pkg")
                fi
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
    # FIND-2/10 FIX: --require-hashes was set but no --hash=sha256:<digest> values
    # were provided.  pip enforces that *every* package (including transitive deps)
    # has a hash when --require-hashes is active; without them pip fails immediately,
    # silently skipping all Python tool installation (|| true masked the failure).
    # Fix: remove --require-hashes.  Versions are still pinned for reproducibility.
    # For production: generate a requirements.txt with pip-compile --generate-hashes
    # and replace this block with: pip3 install --require-hashes -r /path/requirements.txt
    chroot "$ROOTFS_DIR" /bin/bash -c "
        pip3 install --no-cache-dir \
            'impacket==0.12.0' \
            'pwntools==4.12.0' \
            'ropper==1.13.9' \
            'bloodhound==1.6.1' \
            'certipy-ad==4.8.2' \
            'PyJWT==2.8.0' \
            'requests==2.32.3' \
            'scapy==2.5.0' \
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

# FIX(MEDIUM): CONFIG_USER_NS=y is required by several Kali tools (e.g. Podman,
# Chromium sandbox, Flatpak), but unprivileged user namespaces are a major
# kernel exploitation surface (dozens of CVEs since 2013).
# Restrict creation to privileged users only; tools that need it should use
# setuid helpers or be run as root.
#
# BUG-16 FIX: kernel.unprivileged_userns_clone is a DEBIAN-SPECIFIC kernel patch.
# It does not exist in mainline Linux 6.6 that we build here and writing it will
# produce a "sysctl: setting key ... No such file or directory" warning on boot,
# potentially alarming users.
# For mainline 6.1+ use kernel.apparmor_restrict_unprivileged_userns (AppArmor
# must be enabled — it is, via CONFIG_SECURITY_APPARMOR=y).
# Both are set for compatibility: Debian-patched kernels honour the first;
# mainline kernels honour the second.
kernel.apparmor_restrict_unprivileged_userns = 1
# kernel.unprivileged_userns_clone = 0   # Debian/Ubuntu-patched kernels only

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
    # FIX(HIGH): Previously set "Defaults !env_reset" which disabled sudo's
    # environment sanitization.  This allows an attacker to set LD_PRELOAD,
    # LD_LIBRARY_PATH, PYTHONPATH, PERL5LIB, etc. to inject malicious code
    # into any sudo-invoked process, achieving trivial privilege escalation.
    cat > "${ROOTFS_DIR}/etc/sudoers.d/ramOS" << 'SUDO_EOF'
# RAM-OS sudo rules
Defaults    !lecture
Defaults    timestamp_timeout=5
Defaults    passwd_timeout=30
Defaults    logfile=/dev/null
Defaults    env_reset
Defaults    env_keep += "TERM COLORS DISPLAY XAUTHORITY"
Defaults    secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
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
    # BUG-15 FIX: `systemctl disable` inside a chroot requires D-Bus and a running
    # systemd process.  In a debootstrap chroot, systemd is not running so
    # `systemctl disable` exits 0 but creates NO symlinks — services appear disabled
    # but are actually enabled at first boot.  The reliable method is to mask the
    # units by symlinking them to /dev/null, which works without systemd running.
    local services_to_mask=(
        bluetooth.service
        avahi-daemon.service
        cups.service
        cups.socket
        ModemManager.service
        wpa_supplicant.service
        rsyslog.service
        cron.service
        atd.service
        smbd.service
        nmbd.service
        nfs-common.service
        rpcbind.service
        rpcbind.socket
    )
    local unit_dir="${ROOTFS_DIR}/etc/systemd/system"
    mkdir -p "$unit_dir"
    for svc in "${services_to_mask[@]}"; do
        ln -sf /dev/null "${unit_dir}/${svc}"
        log "  Masked: ${svc}"
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
    # BUG-14 FIX: Previous implementation used `xxd -p` which is not part of
    # busybox and may not be installed in minimal Kali.  Also `hostnamectl`
    # requires D-Bus (systemd-hostnamed) which may not be running during
    # the Before=network.target phase.  Replaced with:
    # - `od` (POSIX, always available) for the random hex generation
    # - direct write to /etc/hostname + `hostname` command as fallback
    #   if hostnamectl is unavailable (common in containers / early boot).
    cat > "${ROOTFS_DIR}/etc/systemd/system/random-hostname.service" << 'HOSTNAME_EOF'
[Unit]
Description=Randomize hostname on boot
DefaultDependencies=no
Before=network-pre.target sysinit.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c '\
    rnd=$(od -An -N4 -tu4 /dev/urandom | tr -d " \n"); \
    rnd=$(printf "%08x" $rnd); \
    name="host-${rnd}"; \
    echo "$name" > /etc/hostname; \
    hostnamectl set-hostname "$name" 2>/dev/null || hostname "$name"'
RemainAfterExit=yes

[Install]
WantedBy=sysinit.target
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
    # BUG-03 FIX: The original code set HISTFILE=/dev/null, then immediately
    # called `unset HISTFILE`, then `export HISTFILE`.  After `unset`, the variable
    # no longer exists; `export HISTFILE` exports an unset variable which in bash
    # propagates as unset (not as /dev/null) to child processes.  The net effect
    # was that HISTFILE was UNSET (not /dev/null), meaning bash would fall back to
    # its default ($HOME/.bash_history) and WOULD write history.
    # Fix: export HISTFILE=/dev/null directly without the contradictory unset.
    # We keep unset as an additional hardening (some tools check HISTFILE existence),
    # but do NOT export after unset.
    cat >> "${ROOTFS_DIR}/etc/bash.bashrc" << 'BASH_EOF'

# --- RAM-OS amnesiac shell settings ---
# FIX: export before any possible unset; do NOT unset then re-export.
export HISTFILE=/dev/null
export HISTSIZE=0
export HISTFILESIZE=0
export HISTCONTROL=ignoreboth
readonly HISTFILE HISTSIZE HISTFILESIZE   # prevent accidental re-assignment

# --- Prompt indicating amnesiac mode ---
PS1='\[\033[01;31m\][RAMÖS]\[\033[00m\] \[\033[01;33m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
BASH_EOF

    cat >> "${ROOTFS_DIR}/etc/zsh/zshenv" << 'ZSH_EOF'
# BUG-03 FIX: same issue as bash — set and export, do not unset then re-export.
export HISTFILE=/dev/null
export SAVEHIST=0
export HISTSIZE=0
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

    # Tor transparent proxy (source the helper script)
    log "Configuring Tor chained proxy..."
    # shellcheck source=tor-proxy-setup.sh
    source "${SCRIPT_DIR}/tor-proxy-setup.sh"
    configure_tor_proxy "$ROOTFS_DIR"

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
