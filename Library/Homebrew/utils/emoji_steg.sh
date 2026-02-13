#!/bin/sh
# emoji_steg.sh - Emoji steganography for Alpine Linux / BusyBox / ash
#
# Zero dependencies beyond coreutils (od, tr, cut, printf).
# Works with: Alpine ash, BusyBox, iSH, dash, any POSIX sh.
#
# Methods:
#   vs   - Variation Selectors (U+FE00-U+FE0F), 2 chars per byte
#   tag  - Unicode Tag Sequences (U+E0000 block), 1 char per ASCII byte
#
# Usage:
#   ./emoji_steg.sh encode  "secret message"
#   ./emoji_steg.sh encode  "secret" "🎉🎊"
#   ./emoji_steg.sh decode  "<steg string>"
#   ./emoji_steg.sh detect  "<suspicious text>"
#   ./emoji_steg.sh sanitize "<dirty text>"
#   ./emoji_steg.sh encode -m tag "secret message"
#
# Pipe-friendly:
#   echo "secret" | ./emoji_steg.sh encode -
#   ./emoji_steg.sh encode "secret" > e.txt; ./emoji_steg.sh decode - < e.txt
#
set -e

# ---- defaults ----
METHOD="vs"
DEFAULT_CARRIER_HEX="f09f8dba f09f8fa0 e29895 f09f93a6 f09f9a80"

# ---- helpers ----

# Print a single byte (decimal) as raw output
_putbyte() {
    printf "\\$(printf '%03o' "$1")"
}

# Print hex string as raw bytes.  Uses unique var prefix _eh_ to avoid
# clobbering callers (POSIX sh has no local scope).
emit_hex() {
    _eh_data="$1"
    _eh_pos=0
    while [ "$_eh_pos" -lt "${#_eh_data}" ]; do
        _eh_pair=$(echo "$_eh_data" | cut -c$((_eh_pos+1))-$((_eh_pos+2)))
        _putbyte "$((0x${_eh_pair}))"
        _eh_pos=$((_eh_pos + 2))
    done
}

# Unicode codepoint (decimal) -> UTF-8 hex string.  Prefix _cu_.
cp_to_utf8() {
    _cu_cp=$1
    if [ "$_cu_cp" -le 127 ]; then
        printf '%02x' "$_cu_cp"
    elif [ "$_cu_cp" -le 2047 ]; then
        printf '%02x%02x' "$(( 0xC0 | (_cu_cp >> 6) ))" \
                           "$(( 0x80 | (_cu_cp & 0x3F) ))"
    elif [ "$_cu_cp" -le 65535 ]; then
        printf '%02x%02x%02x' "$(( 0xE0 | (_cu_cp >> 12) ))" \
                               "$(( 0x80 | ((_cu_cp >> 6) & 0x3F) ))" \
                               "$(( 0x80 | (_cu_cp & 0x3F) ))"
    else
        printf '%02x%02x%02x%02x' "$(( 0xF0 | (_cu_cp >> 18) ))" \
                                   "$(( 0x80 | ((_cu_cp >> 12) & 0x3F) ))" \
                                   "$(( 0x80 | ((_cu_cp >> 6) & 0x3F) ))" \
                                   "$(( 0x80 | (_cu_cp & 0x3F) ))"
    fi
}

# String -> contiguous hex bytes (no spaces).
str_to_hex() {
    printf '%s' "$1" | od -An -tx1 | tr -d ' \n'
}

# Determine UTF-8 byte length from leading byte value (decimal).
_charlen() {
    if [ "$1" -le 127 ]; then echo 2
    elif [ "$1" -le 223 ]; then echo 4
    elif [ "$1" -le 239 ]; then echo 6
    else echo 8; fi
}

# ---- VS encode ----

vs_encode() {
    _ve_secret="$1"
    # $2..$N are carrier hex chunks (space-separated in one string)
    _ve_carrier="$2"

    # Split carrier into first + rest
    set -- $_ve_carrier
    emit_hex "$1"
    shift
    _ve_rest="$*"

    # Secret -> hex -> nibble pairs -> variation selectors
    _ve_shex=$(str_to_hex "$_ve_secret")
    _ve_pos=0
    while [ "$_ve_pos" -lt "${#_ve_shex}" ]; do
        _ve_bh=$(echo "$_ve_shex" | cut -c$((_ve_pos+1))-$((_ve_pos+2)))
        _ve_byte=$((0x${_ve_bh}))
        _ve_hi=$(( (_ve_byte >> 4) & 0x0F ))
        _ve_lo=$(( _ve_byte & 0x0F ))

        emit_hex "$(cp_to_utf8 $(( 0xFE00 + _ve_hi )) )"
        emit_hex "$(cp_to_utf8 $(( 0xFE00 + _ve_lo )) )"

        _ve_pos=$((_ve_pos + 2))
    done

    for _ve_chunk in $_ve_rest; do
        emit_hex "$_ve_chunk"
    done
    printf '\n'
}

# ---- VS decode ----

vs_decode() {
    _vd_hex=$(str_to_hex "$1")
    _vd_nibbles=""
    _vd_pos=0
    _vd_len=${#_vd_hex}

    while [ "$_vd_pos" -lt "$_vd_len" ]; do
        _vd_b1h=$(echo "$_vd_hex" | cut -c$((_vd_pos+1))-$((_vd_pos+2)))
        if [ "$_vd_b1h" = "ef" ]; then
            _vd_b2h=$(echo "$_vd_hex" | cut -c$((_vd_pos+3))-$((_vd_pos+4)))
            _vd_b3h=$(echo "$_vd_hex" | cut -c$((_vd_pos+5))-$((_vd_pos+6)))
            if [ "$_vd_b2h" = "b8" ]; then
                _vd_b3=$((0x${_vd_b3h}))
                if [ "$_vd_b3" -ge 128 ] && [ "$_vd_b3" -le 143 ]; then
                    _vd_nibbles="${_vd_nibbles} $((_vd_b3 - 128))"
                    _vd_pos=$((_vd_pos + 6))
                    continue
                fi
            fi
            _vd_pos=$((_vd_pos + 6))
            continue
        fi
        _vd_pos=$((_vd_pos + $(_charlen "$((0x${_vd_b1h}))" ) ))
    done

    if [ -z "$_vd_nibbles" ]; then
        echo "Error: no hidden data found" >&2; return 1
    fi

    set -- $_vd_nibbles
    if [ $(($# % 2)) -ne 0 ]; then
        echo "Error: corrupt data (odd nibble count: $#)" >&2; return 1
    fi

    while [ $# -ge 2 ]; do
        _putbyte "$(( ($1 << 4) | $2 ))"
        shift 2
    done
    printf '\n'
}

# ---- Tag encode ----

tag_encode() {
    _te_secret="$1"
    _te_carrier="$2"

    set -- $_te_carrier
    emit_hex "$1"
    shift
    _te_rest="$*"

    _te_shex=$(str_to_hex "$_te_secret")
    _te_pos=0
    while [ "$_te_pos" -lt "${#_te_shex}" ]; do
        _te_bh=$(echo "$_te_shex" | cut -c$((_te_pos+1))-$((_te_pos+2)))
        _te_byte=$((0x${_te_bh}))
        emit_hex "$(cp_to_utf8 $(( 0xE0000 + _te_byte )) )"
        _te_pos=$((_te_pos + 2))
    done

    for _te_chunk in $_te_rest; do
        emit_hex "$_te_chunk"
    done
    printf '\n'
}

# ---- Tag decode ----

tag_decode() {
    _td_hex=$(str_to_hex "$1")
    _td_bytes=""
    _td_pos=0
    _td_len=${#_td_hex}

    while [ "$_td_pos" -lt "$_td_len" ]; do
        _td_b1h=$(echo "$_td_hex" | cut -c$((_td_pos+1))-$((_td_pos+2)))
        if [ "$_td_b1h" = "f3" ]; then
            _td_b2h=$(echo "$_td_hex" | cut -c$((_td_pos+3))-$((_td_pos+4)))
            if [ "$_td_b2h" = "a0" ]; then
                _td_b3h=$(echo "$_td_hex" | cut -c$((_td_pos+5))-$((_td_pos+6)))
                _td_b4h=$(echo "$_td_hex" | cut -c$((_td_pos+7))-$((_td_pos+8)))
                _td_b3=$((0x${_td_b3h}))
                _td_b4=$((0x${_td_b4h}))
                _td_val=$(( (_td_b3 & 0x3F) << 6 | (_td_b4 & 0x3F) ))
                # Skip tag cancel U+E007F
                if [ "$_td_b3h" != "81" ] || [ "$_td_b4h" != "bf" ]; then
                    _td_bytes="${_td_bytes} ${_td_val}"
                fi
                _td_pos=$((_td_pos + 8))
                continue
            fi
        fi
        _td_pos=$((_td_pos + $(_charlen "$((0x${_td_b1h}))" ) ))
    done

    if [ -z "$_td_bytes" ]; then
        echo "Error: no tag data found" >&2; return 1
    fi

    for _td_b in $_td_bytes; do
        _putbyte "$_td_b"
    done
    printf '\n'
}

# ---- Detect ----

detect() {
    _dt_hex=$(str_to_hex "$1")
    _dt_vs=0; _dt_zw=0; _dt_tag=0
    _dt_pos=0; _dt_len=${#_dt_hex}

    while [ "$_dt_pos" -lt "$_dt_len" ]; do
        _dt_b1h=$(echo "$_dt_hex" | cut -c$((_dt_pos+1))-$((_dt_pos+2)))

        if [ "$_dt_b1h" = "ef" ]; then
            _dt_b2h=$(echo "$_dt_hex" | cut -c$((_dt_pos+3))-$((_dt_pos+4)))
            _dt_b3h=$(echo "$_dt_hex" | cut -c$((_dt_pos+5))-$((_dt_pos+6)))
            if [ "$_dt_b2h" = "b8" ]; then
                _dt_b3=$((0x${_dt_b3h}))
                [ "$_dt_b3" -ge 128 ] && [ "$_dt_b3" -le 143 ] && _dt_vs=$((_dt_vs + 1))
            fi
            _dt_pos=$((_dt_pos + 6)); continue
        fi

        if [ "$_dt_b1h" = "e2" ]; then
            _dt_b2h=$(echo "$_dt_hex" | cut -c$((_dt_pos+3))-$((_dt_pos+4)))
            _dt_b3h=$(echo "$_dt_hex" | cut -c$((_dt_pos+5))-$((_dt_pos+6)))
            if [ "$_dt_b2h" = "80" ]; then
                _dt_b3=$((0x${_dt_b3h}))
                [ "$_dt_b3" -ge 139 ] && [ "$_dt_b3" -le 141 ] && _dt_zw=$((_dt_zw + 1))
            elif [ "$_dt_b2h" = "81" ] && [ "$_dt_b3h" = "a0" ]; then
                _dt_zw=$((_dt_zw + 1))
            fi
            _dt_pos=$((_dt_pos + 6)); continue
        fi

        if [ "$_dt_b1h" = "f3" ]; then
            _dt_b2h=$(echo "$_dt_hex" | cut -c$((_dt_pos+3))-$((_dt_pos+4)))
            [ "$_dt_b2h" = "a0" ] && _dt_tag=$((_dt_tag + 1))
            _dt_pos=$((_dt_pos + 8)); continue
        fi

        _dt_pos=$((_dt_pos + $(_charlen "$((0x${_dt_b1h}))" ) ))
    done

    if [ "$_dt_vs" -eq 0 ] && [ "$_dt_zw" -eq 0 ] && [ "$_dt_tag" -eq 0 ]; then
        echo "Clean: no hidden steganographic content detected."
        return 0
    fi

    echo "Hidden content detected:"
    echo ""
    [ "$_dt_vs" -gt 0 ]  && echo "  Variation Selectors: $_dt_vs chars (~$((_dt_vs / 2)) hidden bytes)"
    [ "$_dt_zw" -gt 0 ]  && echo "  Zero-Width Chars:    $_dt_zw chars"
    [ "$_dt_tag" -gt 0 ] && echo "  Tag Sequences:       $_dt_tag chars (~$_dt_tag hidden bytes)"
    echo ""
    [ "$_dt_vs" -gt 0 ]  && echo "  [vs] decoded: $(vs_decode "$1" 2>/dev/null || echo '<failed>')"
    [ "$_dt_tag" -gt 0 ] && echo "  [tag] decoded: $(tag_decode "$1" 2>/dev/null || echo '<failed>')"
    return 0
}

# ---- Sanitize ----

sanitize() {
    _sa_hex=$(str_to_hex "$1")
    _sa_clean=""; _sa_rm=0
    _sa_pos=0; _sa_len=${#_sa_hex}

    while [ "$_sa_pos" -lt "$_sa_len" ]; do
        _sa_b1h=$(echo "$_sa_hex" | cut -c$((_sa_pos+1))-$((_sa_pos+2)))
        _sa_skip=0

        if [ "$_sa_b1h" = "ef" ]; then
            _sa_b2h=$(echo "$_sa_hex" | cut -c$((_sa_pos+3))-$((_sa_pos+4)))
            _sa_b3h=$(echo "$_sa_hex" | cut -c$((_sa_pos+5))-$((_sa_pos+6)))
            if [ "$_sa_b2h" = "b8" ]; then
                _sa_b3=$((0x${_sa_b3h}))
                [ "$_sa_b3" -ge 128 ] && [ "$_sa_b3" -le 143 ] && _sa_skip=1 && _sa_rm=$((_sa_rm+1))
            fi
            [ "$_sa_skip" -eq 0 ] && _sa_clean="${_sa_clean}$(echo "$_sa_hex" | cut -c$((_sa_pos+1))-$((_sa_pos+6)))"
            _sa_pos=$((_sa_pos + 6)); continue
        fi

        if [ "$_sa_b1h" = "e2" ]; then
            _sa_b2h=$(echo "$_sa_hex" | cut -c$((_sa_pos+3))-$((_sa_pos+4)))
            _sa_b3h=$(echo "$_sa_hex" | cut -c$((_sa_pos+5))-$((_sa_pos+6)))
            if [ "$_sa_b2h" = "80" ]; then
                _sa_b3=$((0x${_sa_b3h}))
                [ "$_sa_b3" -ge 139 ] && [ "$_sa_b3" -le 143 ] && _sa_skip=1 && _sa_rm=$((_sa_rm+1))
            elif [ "$_sa_b2h" = "81" ] && [ "$_sa_b3h" = "a0" ]; then
                _sa_skip=1; _sa_rm=$((_sa_rm+1))
            fi
            [ "$_sa_skip" -eq 0 ] && _sa_clean="${_sa_clean}$(echo "$_sa_hex" | cut -c$((_sa_pos+1))-$((_sa_pos+6)))"
            _sa_pos=$((_sa_pos + 6)); continue
        fi

        if [ "$_sa_b1h" = "f3" ]; then
            _sa_b2h=$(echo "$_sa_hex" | cut -c$((_sa_pos+3))-$((_sa_pos+4)))
            [ "$_sa_b2h" = "a0" ] && _sa_skip=1 && _sa_rm=$((_sa_rm+1))
            [ "$_sa_skip" -eq 0 ] && _sa_clean="${_sa_clean}$(echo "$_sa_hex" | cut -c$((_sa_pos+1))-$((_sa_pos+8)))"
            _sa_pos=$((_sa_pos + 8)); continue
        fi

        _sa_clen=$(_charlen "$((0x${_sa_b1h}))")
        _sa_clean="${_sa_clean}$(echo "$_sa_hex" | cut -c$((_sa_pos+1))-$((_sa_pos+_sa_clen)))"
        _sa_pos=$((_sa_pos + _sa_clen))
    done

    if [ "$_sa_rm" -eq 0 ]; then
        echo "Clean: no steganographic characters found."
    else
        echo "Removed $_sa_rm hidden character(s)."
    fi
    echo ""
    emit_hex "$_sa_clean"
    printf '\n'
}

# ---- Carrier string -> space-separated hex chunks ----

carrier_to_hex() {
    _ch_hex=$(str_to_hex "$1")
    _ch_out=""; _ch_pos=0; _ch_len=${#_ch_hex}
    while [ "$_ch_pos" -lt "$_ch_len" ]; do
        _ch_b1h=$(echo "$_ch_hex" | cut -c$((_ch_pos+1))-$((_ch_pos+2)))
        _ch_clen=$(_charlen "$((0x${_ch_b1h}))")
        _ch_out="${_ch_out} $(echo "$_ch_hex" | cut -c$((_ch_pos+1))-$((_ch_pos+_ch_clen)))"
        _ch_pos=$((_ch_pos + _ch_clen))
    done
    echo "$_ch_out"
}

# ---- Usage ----

usage() {
    cat <<'USAGE'
emoji_steg.sh - Emoji steganography for Alpine Linux / ash / BusyBox

Usage:
  emoji_steg.sh encode  [-m vs|tag] "secret" ["carrier emojis"]
  emoji_steg.sh decode  [-m vs|tag] "steg text"
  emoji_steg.sh detect  "suspicious text"
  emoji_steg.sh sanitize "dirty text"

  Use "-" as text argument to read from stdin.

Options:
  -m METHOD   Encoding method: vs (default) or tag

Methods:
  vs    Variation Selectors (U+FE00-U+FE0F) - 2 invisible chars per byte
  tag   Unicode Tag Sequences (U+E0000)      - 1 invisible char per byte

Examples:
  ./emoji_steg.sh encode "flag{alpine_steg}"
  ./emoji_steg.sh encode -m tag "secret msg" "🏔🐧"
  ./emoji_steg.sh decode "🍺︆︂..."
  ./emoji_steg.sh detect "🍺︆︂..."
  ./emoji_steg.sh sanitize "🍺︆︂..."

  echo "secret" | ./emoji_steg.sh encode -
  ./emoji_steg.sh encode "data" > e.txt
  ./emoji_steg.sh decode - < e.txt
USAGE
    exit 0
}

# ---- Main ----

[ $# -eq 0 ] && usage

ACTION="$1"; shift

while [ $# -gt 0 ]; do
    case "$1" in
        -m)    METHOD="$2"; shift 2 ;;
        -h|--help) usage ;;
        *)     break ;;
    esac
done

if [ "${1:-}" = "-" ]; then
    INPUT=$(cat)
else
    INPUT="${1:-}"
fi

[ -z "$INPUT" ] && { echo "Error: no input text provided" >&2; exit 1; }

CARRIER_ARG="${2:-}"

case "$ACTION" in
    encode)
        if [ -n "$CARRIER_ARG" ]; then
            CHEX=$(carrier_to_hex "$CARRIER_ARG")
        else
            CHEX="$DEFAULT_CARRIER_HEX"
        fi
        case "$METHOD" in
            vs)  vs_encode "$INPUT" "$CHEX" ;;
            tag) tag_encode "$INPUT" "$CHEX" ;;
            *)   echo "Error: unknown method: $METHOD" >&2; exit 1 ;;
        esac ;;
    decode)
        case "$METHOD" in
            vs)  vs_decode "$INPUT" ;;
            tag) tag_decode "$INPUT" ;;
            *)   echo "Error: unknown method: $METHOD" >&2; exit 1 ;;
        esac ;;
    detect)   detect "$INPUT" ;;
    sanitize) sanitize "$INPUT" ;;
    -h|--help|help) usage ;;
    *) echo "Error: unknown action: $ACTION" >&2; exit 1 ;;
esac
