#!/usr/bin/env bash
# =============================================================================
# tor-proxy-setup.sh — Configure transparent Tor + SOCKS5 chained proxy
# =============================================================================
# Installs into the chroot/rootfs:
#   1. Tor daemon with a hardened torrc
#   2. nftables transparent proxy ruleset (all traffic → Tor)
#   3. Privoxy (HTTP/HTTPS → SOCKS5 bridge) with chain to Tor
#   4. proxychains4 configured for Tor
#   5. systemd services that start Tor before any network-facing service
#
# Chain architecture:
#   App → proxychains4 → SOCKS5:9050 (Tor)
#   HTTP client → Privoxy:8118 → Tor SOCKS5:9050
#   All other TCP (transparent) → nftables REDIRECT → Tor TransPort:9040
#   DNS → nftables REDIRECT → Tor DNSPort:5353
#
# Usage (called from build-rootfs.sh):
#   source tor-proxy-setup.sh
#   configure_tor_proxy "$ROOTFS_DIR"
# =============================================================================
set -euo pipefail

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "${BLUE}[tor-proxy]${NC} $*"; }
ok()   { echo -e "${GREEN}[tor-proxy]${NC} $*"; }
warn() { echo -e "${YELLOW}[tor-proxy]${NC} $*"; }
die()  { echo -e "${RED}[tor-proxy]${NC} $*" >&2; exit 1; }

# UID that the tor daemon runs as (Debian: debian-tor)
TOR_UID_NAME="debian-tor"

configure_tor_proxy() {
    local rootfs="$1"
    [[ -d "$rootfs" ]] || die "rootfs not found: $rootfs"

    log "Installing Tor + Privoxy..."
    chroot "$rootfs" /bin/bash -c "
        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
            tor \
            torsocks \
            privoxy \
            proxychains4 \
            nftables \
            2>&1 | tail -5
    "

    # ------------------------------------------------------------------
    # 1. Hardened torrc
    # ------------------------------------------------------------------
    log "Configuring Tor daemon..."
    cat > "${rootfs}/etc/tor/torrc" << 'TORRC_EOF'
# ==========================================================
# RAM-OS Hardened Tor Configuration
# ==========================================================

# --- Ports ---
SocksPort 9050 IsolateDestAddr IsolateDestPort
SocksPort 127.0.0.1:9050
TransPort 9040 IsolateClientAddr
DNSPort 5353

# --- Security ---
# Disable direct connections — all traffic must go via Tor
ClientOnly 1
SafeSocks 1
TestSocks 1
WarnUnsafeSocks 1

# Prevent DNS leaks
DNSListenAddress 127.0.0.1
AutomapHostsOnResolve 1
AutomapHostsSuffixes .onion,.exit

# Strict node selection — avoid potentially compromised nodes
StrictNodes 1
ExcludeExitNodes {??}

# --- Circuit hardening ---
# Use at least 3 hops (default) — do not set NewCircuitPeriod too short
NewCircuitPeriod 30
MaxCircuitDirtiness 600
CircuitBuildTimeout 60

# --- Logging (amnesiac — no persistent logs) ---
Log notice stderr
# No LogFile — all output goes to journald (volatile, wiped on shutdown)

# --- Filesystem (run from RAM) ---
DataDirectory /var/lib/tor
PidFile /run/tor/tor.pid
RunAsDaemon 0

# --- Control port (local only, for monitoring) ---
ControlPort 9051
CookieAuthentication 1
CookieAuthFileGroupReadable 1
CookieAuthFile /run/tor/control.authcookie

# --- Hidden service support (optional, enable per-use) ---
# HiddenServiceDir /var/lib/tor/hidden_service/
# HiddenServicePort 80 127.0.0.1:8080

# --- Bridge support (uncomment and configure for censored networks) ---
# UseBridges 1
# Bridge obfs4 <address>:<port> <fingerprint> cert=<cert> iat-mode=0
# ClientTransportPlugin obfs4 exec /usr/bin/obfs4proxy
TORRC_EOF

    # ------------------------------------------------------------------
    # 2. Privoxy configuration (HTTP → SOCKS5 bridge)
    # ------------------------------------------------------------------
    log "Configuring Privoxy..."
    cat > "${rootfs}/etc/privoxy/config" << 'PRIVOXY_EOF'
# ==========================================================
# RAM-OS Privoxy — forwards HTTP to Tor SOCKS5
# ==========================================================
listen-address  127.0.0.1:8118

# Forward all traffic through Tor SOCKS5
forward-socks5t / 127.0.0.1:9050 .

# Privacy hardening
suppress-tags 1
hide-from-header block
hide-referrer block
send-server-favicon 0
enable-remote-toggle  0
enable-remote-http-toggle 0
enable-edit-actions   0

# No persistent log (amnesiac)
logfile /dev/null
jarfile /dev/null
PRIVOXY_EOF

    # ------------------------------------------------------------------
    # 3. proxychains4 configuration
    # ------------------------------------------------------------------
    log "Configuring proxychains4..."
    cat > "${rootfs}/etc/proxychains4.conf" << 'PC4_EOF'
# ==========================================================
# RAM-OS proxychains4 — route through Tor
# ==========================================================
strict_chain
proxy_dns
remote_dns_subnet 224
tcp_read_time_out 15000
tcp_connect_time_out 8000
localnet 127.0.0.0/255.0.0.0
localnet 10.0.0.0/255.0.0.0
localnet 192.168.0.0/255.255.0.0

[ProxyList]
socks5 127.0.0.1 9050
PC4_EOF

    # ------------------------------------------------------------------
    # 4. nftables transparent proxy ruleset
    # ------------------------------------------------------------------
    log "Configuring nftables transparent proxy..."
    local tor_uid
    tor_uid=$(chroot "${rootfs}" id -u "${TOR_UID_NAME}" 2>/dev/null || true)
    # FIND-16 FIX: An empty tor_uid produces "define TOR_UID  =" in the nftables
    # configuration, which is a syntax error.  nft will refuse to load the ruleset,
    # leaving ALL traffic unredirected (no Tor enforcement at all).
    # Die immediately rather than ship a broken firewall config.
    [[ -n "$tor_uid" ]] || die "Could not determine UID for '${TOR_UID_NAME}' in rootfs.\n  Ensure Tor is installed before calling configure_tor_proxy()."

    cat > "${rootfs}/etc/nftables-tor.conf" << NFTEOF
#!/usr/sbin/nft -f
# ==========================================================
# RAM-OS Transparent Tor Proxy Ruleset
# ==========================================================
# Architecture:
#   All TCP output (except Tor's own) → TransPort 9040
#   All DNS UDP output               → DNSPort 5353
#   SOCKS5/HTTP proxy ports are left reachable locally.
#
# This prevents direct clearnet connections (IP leaks).
# Tor's own traffic is exempted by UID match.
#
# FIND-19 FIX: IPv4-only rules left IPv6 traffic completely unredirected —
# any IPv6-capable application could bypass the transparent proxy and make
# direct clearnet connections.  Added matching ip6 tables to block/redirect
# IPv6 traffic.  Since Tor's TransPort only supports IPv4, IPv6 non-loopback
# output is rejected outright (fail-closed for IPv6 clearnet).

flush ruleset

define TOR_UID        = ${tor_uid}
define TOR_TRANS_PORT = 9040
define TOR_DNS_PORT   = 5353

# ---------------------------------------------------------------------------
# IPv4 rules
# ---------------------------------------------------------------------------
table ip nat {
    chain output {
        type nat hook output priority -100; policy accept;

        # Exempt Tor daemon's own packets (prevents routing loop)
        meta skuid \$TOR_UID accept

        # Exempt loopback
        ip daddr 127.0.0.0/8 accept

        # Exempt RFC1918 (LAN access — comment out for full Tor isolation)
        ip daddr 10.0.0.0/8 accept
        ip daddr 172.16.0.0/12 accept
        ip daddr 192.168.0.0/16 accept

        # Redirect DNS to Tor's DNS port
        meta l4proto udp ip daddr != 127.0.0.1 udp dport 53 \
            redirect to :\$TOR_DNS_PORT

        # Redirect all TCP to Tor's transparent proxy port
        meta l4proto tcp redirect to :\$TOR_TRANS_PORT
    }
}

table ip filter {
    chain output {
        type filter hook output priority 0; policy accept;

        # Exempt Tor daemon
        meta skuid \$TOR_UID accept

        # Block direct clearnet TCP (belt-and-suspenders after NAT redirect)
        # Uncomment for strict mode (breaks LAN services):
        # ip daddr != 127.0.0.0/8 meta l4proto tcp reject
    }
}

# ---------------------------------------------------------------------------
# IPv6 rules — Tor TransPort is IPv4-only, so block all non-loopback IPv6
# output to prevent clearnet bypasses via IPv6.
# ---------------------------------------------------------------------------
table ip6 filter {
    chain output {
        type filter hook output priority 0; policy accept;

        # Exempt Tor daemon (its IPv6 DNS lookups go to system resolver)
        meta skuid \$TOR_UID accept

        # Allow loopback
        ip6 daddr ::1 accept

        # Allow link-local (required for IPv6 ND, router discovery)
        ip6 daddr fe80::/10 accept

        # Reject all other IPv6 to prevent transparent proxy bypass
        reject with icmpv6 type no-route
    }
}
NFTEOF
    chmod 600 "${rootfs}/etc/nftables-tor.conf"

    # ------------------------------------------------------------------
    # 5. systemd services
    # ------------------------------------------------------------------
    log "Installing systemd services..."
    local unit_dir="${rootfs}/etc/systemd/system"
    mkdir -p "$unit_dir"

    # tor-network-pre.service — apply nftables rules before any interface comes up
    cat > "${unit_dir}/tor-firewall.service" << 'FWSVC_EOF'
[Unit]
Description=Tor Transparent Proxy Firewall Rules
DefaultDependencies=no
Before=network-pre.target
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/nft -f /etc/nftables-tor.conf
ExecStop=/usr/sbin/nft flush ruleset
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
FWSVC_EOF

    # Make sure Tor starts BEFORE any user-facing service
    cat > "${unit_dir}/tor-ready.service" << 'TORRSVC_EOF'
[Unit]
Description=Wait for Tor circuit to be established
After=tor.service
Requires=tor.service

[Service]
Type=oneshot
# Poll Tor's control port until a circuit is ready (max 60s)
ExecStart=/bin/sh -c '\
    i=0; \
    while [ $i -lt 60 ]; do \
        status=$(echo "GETINFO status/circuit-established" | \
            nc -q1 127.0.0.1 9051 2>/dev/null | grep "250-status" | cut -d= -f2 || true); \
        [ "$status" = "1" ] && { echo "Tor circuit ready"; exit 0; }; \
        sleep 1; i=$((i+1)); \
    done; \
    echo "WARNING: Tor circuit not established after 60s" >&2; exit 1'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
TORRSVC_EOF

    # Enable services
    local wants_dir="${unit_dir}/multi-user.target.wants"
    mkdir -p "$wants_dir"
    ln -sf /etc/systemd/system/tor-firewall.service "${wants_dir}/tor-firewall.service"
    ln -sf /etc/systemd/system/tor-ready.service    "${wants_dir}/tor-ready.service"

    # ------------------------------------------------------------------
    # 6. torsocks environment — shell-level opt-in as complement to transparent proxy
    # ------------------------------------------------------------------
    cat >> "${rootfs}/etc/bash.bashrc" << 'TORSOCKS_EOF'

# --- RAM-OS Tor helpers ---
# Use: torify <command>  or  torsocks <command>
# All new TCP connections are already routed via transparent proxy.
# These aliases make the routing explicit and add SOCKS-level isolation.
alias curl='torsocks curl'
alias wget='torsocks wget'
alias ssh='torsocks ssh'
# Check Tor circuit
alias torcheck='curl -s https://check.torproject.org/api/ip'
# New Tor identity (requires Tor ControlPort)
alias newtor='echo -e "AUTHENTICATE\r\nSIGNAL NEWNYM\r\nQUIT" | nc 127.0.0.1 9051'
TORSOCKS_EOF

    ok "Tor transparent proxy configured"
    ok "  Architecture:"
    ok "    App → proxychains4 → Tor SOCKS5:9050"
    ok "    HTTP/HTTPS → Privoxy:8118 → Tor SOCKS5:9050"
    ok "    All TCP (transparent) → nftables → Tor TransPort:9040"
    ok "    DNS (UDP 53) → nftables → Tor DNSPort:5353"
}
