#!/bin/bash
# ============================================================
# Hydra Amnesiac Runner
# ============================================================
# Executes the Hydra toolkit entirely from RAM-backed storage,
# suppresses all disk artifacts, and cleans up on exit.
#
# FOR EDUCATIONAL AND AUTHORIZED SECURITY TESTING ONLY.
#
# Techniques used:
#   1. /dev/shm (tmpfs) staging - code never touches disk
#   2. PYTHONDONTWRITEBYTECODE - prevents .pyc cache files
#   3. History suppression - no shell history recording
#   4. Trap-based cleanup - wipes on exit, interrupt, or term
#   5. Optional memfd mode - true fileless execution
#
# Usage:
#   ./amnesiac.sh demo
#   ./amnesiac.sh encode zwc "secret message"
#   ./amnesiac.sh scan "<suspect_text>" --verbose
#   ./amnesiac.sh --memfd demo          # fileless mode
#   ./amnesiac.sh --status              # show what's suppressed
#   ./amnesiac.sh --shell               # drop into amnesiac shell
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLKIT_SRC="${SCRIPT_DIR}"
AMNESIAC_PREFIX="hydra_amnesiac"
SHM_BASE="/dev/shm"
WORKDIR=""
MEMFD_MODE=0
SHELL_MODE=0
STATUS_MODE=0

# ── Colors ────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
DIM='\033[2m'
RESET='\033[0m'

# ── Suppress history immediately ──────────────────────────────
unset HISTFILE 2>/dev/null || true
export HISTSIZE=0
export HISTFILESIZE=0
export HISTCONTROL=ignoreboth

# ── Suppress Python disk artifacts ───────────────────────────
export PYTHONDONTWRITEBYTECODE=1
export PYTHONPYCACHEPREFIX="/dev/null"

# ── Cleanup trap ──────────────────────────────────────────────
cleanup() {
    local exit_code=$?
    if [[ -n "${WORKDIR}" && -d "${WORKDIR}" ]]; then
        # Overwrite files before deletion (paranoid wipe)
        find "${WORKDIR}" -type f -exec sh -c '
            filesize=$(stat -c%s "$1" 2>/dev/null || echo 0)
            if [ "$filesize" -gt 0 ]; then
                dd if=/dev/urandom of="$1" bs=1 count="$filesize" conv=notrunc 2>/dev/null
            fi
        ' _ {} \;
        rm -rf "${WORKDIR}"
    fi
    exit $exit_code
}

trap cleanup EXIT INT TERM HUP

# ── Parse meta-flags ─────────────────────────────────────────
HYDRA_ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --memfd)
            MEMFD_MODE=1
            shift
            ;;
        --status)
            STATUS_MODE=1
            shift
            ;;
        --shell)
            SHELL_MODE=1
            shift
            ;;
        *)
            HYDRA_ARGS+=("$1")
            shift
            ;;
    esac
done

# ── Status mode ──────────────────────────────────────────────
if [[ $STATUS_MODE -eq 1 ]]; then
    echo -e "${CYAN}Hydra Amnesiac Status${RESET}"
    echo -e "${DIM}──────────────────────────────────${RESET}"

    # Check tmpfs
    if mount | grep -q "/dev/shm.*tmpfs"; then
        echo -e "  ${GREEN}[OK]${RESET} /dev/shm is tmpfs (RAM-backed)"
    else
        echo -e "  ${RED}[!!]${RESET} /dev/shm is NOT tmpfs"
    fi

    # Check history suppression
    if [[ -z "${HISTFILE:-}" || "${HISTSIZE:-1}" -eq 0 ]]; then
        echo -e "  ${GREEN}[OK]${RESET} Shell history suppressed"
    else
        echo -e "  ${YELLOW}[--]${RESET} Shell history may be recording (HISTFILE=${HISTFILE:-unset})"
    fi

    # Check Python bytecode
    if [[ "${PYTHONDONTWRITEBYTECODE:-0}" == "1" ]]; then
        echo -e "  ${GREEN}[OK]${RESET} Python bytecode caching disabled"
    else
        echo -e "  ${YELLOW}[--]${RESET} Python may write .pyc files"
    fi

    # Check memfd support
    if python3 -c "import ctypes; libc=ctypes.CDLL('libc.so.6'); libc.memfd_create" 2>/dev/null; then
        echo -e "  ${GREEN}[OK]${RESET} memfd_create available (--memfd supported)"
    else
        echo -e "  ${YELLOW}[--]${RESET} memfd_create not available"
    fi

    # Check for existing artifacts
    existing=$(find /dev/shm -maxdepth 1 -name "${AMNESIAC_PREFIX}*" 2>/dev/null | wc -l)
    if [[ $existing -gt 0 ]]; then
        echo -e "  ${YELLOW}[!!]${RESET} Found ${existing} stale amnesiac workspace(s) in /dev/shm"
    else
        echo -e "  ${GREEN}[OK]${RESET} No stale workspaces in /dev/shm"
    fi

    echo -e "${DIM}──────────────────────────────────${RESET}"
    exit 0
fi

# ── Verify /dev/shm is tmpfs ─────────────────────────────────
if ! mount | grep -q "/dev/shm.*tmpfs"; then
    echo -e "${RED}[ERROR]${RESET} /dev/shm is not mounted as tmpfs." >&2
    echo "  Cannot guarantee RAM-only execution." >&2
    exit 1
fi

# ── Stage toolkit to RAM ─────────────────────────────────────
WORKDIR=$(mktemp -d "${SHM_BASE}/${AMNESIAC_PREFIX}.XXXXXXXXXX")
chmod 700 "${WORKDIR}"

# Copy only source files (no .git, no __pycache__)
mkdir -p "${WORKDIR}/lib" "${WORKDIR}/bin" "${WORKDIR}/test"
cp "${TOOLKIT_SRC}/lib/"*.py "${WORKDIR}/lib/"
cp "${TOOLKIT_SRC}/bin/hydra" "${WORKDIR}/bin/"
cp "${TOOLKIT_SRC}/test/"*.py "${WORKDIR}/test/" 2>/dev/null || true

# ── Memfd mode: true fileless execution ──────────────────────
if [[ $MEMFD_MODE -eq 1 ]]; then
    # Build a self-contained Python script in memory via memfd
    # then exec() it in-process so no file ever touches disk
    python3 -B -c "
import ctypes, os, sys

# Build the combined script from RAM-staged sources
script_parts = []

# Collect a single __future__ import at the top
script_parts.append('from __future__ import annotations')

# Read all library modules into a flat namespace
lib_dir = '${WORKDIR}/lib'
for mod in ['core', 'zwc_smuggler', 'variation_steg', 'emoji_cipher', 'regional_encoder', 'detector']:
    with open(os.path.join(lib_dir, mod + '.py')) as f:
        content = f.read()
        # Strip __future__ and relative imports (everything is flat)
        # Handle multi-line imports by tracking open parens
        raw_lines = content.split('\n')
        lines = []
        in_skip_block = False
        for l in raw_lines:
            if 'from __future__' in l or l.strip().startswith('from .'):
                in_skip_block = '(' in l and ')' not in l
                continue
            if in_skip_block:
                if ')' in l:
                    in_skip_block = False
                continue
            lines.append(l)
        script_parts.append(f'# --- {mod}.py ---')
        script_parts.append('\n'.join(lines))

# Read the CLI, stripping its import lines (everything is already inline)
with open('${WORKDIR}/bin/hydra') as f:
    cli_code = f.read()
    lines = cli_code.split('\n')
    filtered = []
    skip_imports = {'from lib.', 'sys.path.insert', 'from __future__'}
    for line in lines:
        if not any(line.strip().startswith(s) for s in skip_imports):
            filtered.append(line)
    script_parts.append('\n'.join(filtered))

combined = '\n'.join(script_parts)

# Create anonymous memory-only file descriptor via memfd_create
libc = ctypes.CDLL('libc.so.6')
# Use flags=0 (NOT MFD_CLOEXEC) so fd survives if needed
fd = libc.memfd_create(b'hydra', 0)
if fd < 0:
    print('memfd_create failed', file=sys.stderr)
    sys.exit(1)

# Write combined script to memfd (lives only in kernel memory)
os.write(fd, combined.encode())
os.lseek(fd, 0, os.SEEK_SET)

# Read back and exec() in-process - the code runs entirely from RAM
# The memfd is just proof the code was memory-resident
code = os.read(fd, os.path.getsize(f'/proc/self/fd/{fd}'))
os.close(fd)

# Inject CLI args so argparse picks them up
sys.argv = ['hydra'] + sys.argv[1:]
exec(compile(code.decode(), '<memfd:hydra>', 'exec'))
" "${HYDRA_ARGS[@]}"
    exit $?
fi

# ── Shell mode: drop into amnesiac bash ──────────────────────
if [[ $SHELL_MODE -eq 1 ]]; then
    echo -e "${CYAN}Hydra Amnesiac Shell${RESET}"
    echo -e "${DIM}Working directory: ${WORKDIR} (RAM only)${RESET}"
    echo -e "${DIM}History: disabled | Bytecache: disabled${RESET}"
    echo -e "${DIM}Type 'exit' to wipe and leave.${RESET}"
    echo ""

    export PS1="\[${RED}\][amnesiac]\[${RESET}\] \w \$ "
    export HYDRA_HOME="${WORKDIR}"

    # Create convenience aliases
    RCFILE=$(mktemp "${WORKDIR}/.bashrc.XXXX")
    cat > "${RCFILE}" << 'ALIASES'
alias hydra='python3 -B ${HYDRA_HOME}/bin/hydra'
alias hydra-test='python3 -B ${HYDRA_HOME}/test/test_hydra.py'
alias wipe='echo "Wiping..."; exit'
unset HISTFILE
export HISTSIZE=0
ALIASES

    cd "${WORKDIR}"
    bash --rcfile "${RCFILE}" --norc -i
    exit $?
fi

# ── Standard execution ───────────────────────────────────────
if [[ ${#HYDRA_ARGS[@]} -eq 0 ]]; then
    echo -e "${CYAN}Hydra Amnesiac Runner${RESET}"
    echo -e "${DIM}──────────────────────────────────${RESET}"
    echo -e "  Workspace: ${YELLOW}${WORKDIR}${RESET} (RAM)"
    echo -e "  History:   ${GREEN}suppressed${RESET}"
    echo -e "  Bytecache: ${GREEN}disabled${RESET}"
    echo -e ""
    echo -e "Usage:"
    echo -e "  $0 demo                        # run demo"
    echo -e "  $0 encode zwc \"secret\"          # encode"
    echo -e "  $0 scan \"<text>\" --verbose      # scan"
    echo -e "  $0 --memfd demo                # fileless mode"
    echo -e "  $0 --shell                     # amnesiac shell"
    echo -e "  $0 --status                    # check environment"
    echo -e ""
    echo -e "${DIM}All artifacts are wiped on exit.${RESET}"
    exit 0
fi

python3 -B "${WORKDIR}/bin/hydra" "${HYDRA_ARGS[@]}"
