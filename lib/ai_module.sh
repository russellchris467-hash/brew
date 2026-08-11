#!/bin/bash
# AI Extension Module for Bug Bounty Toolkit
# Modular AI prompt generation functions
# Source this file to add AI capabilities to any toolkit

# Module version
AI_MODULE_VERSION="1.0"

# Paths
AI_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AI_TEMPLATE_DIR="${AI_MODULE_DIR}/../prompts/templates"
AI_OUTPUT_DIR="${AI_OUTPUT_DIR:-/tmp/ai_prompts}"

# Ensure output directory exists
mkdir -p "$AI_OUTPUT_DIR"

#===============================================================================
# CORE AI FUNCTIONS
#===============================================================================

# Load template file
ai_load_template() {
    local template_name="$1"
    local template_file="${AI_TEMPLATE_DIR}/${template_name}.txt"

    if [ -f "$template_file" ]; then
        cat "$template_file"
        return 0
    else
        echo "# Template not found: $template_name" >&2
        return 1
    fi
}

# Replace placeholder in text
ai_replace() {
    local text="$1"
    local key="$2"
    local value="$3"
    echo "$text" | sed "s|{{${key}}}|${value}|g"
}

# Gather binary context
ai_gather_context() {
    local binary="$1"

    if [ ! -f "$binary" ]; then
        echo "Error: Binary not found" >&2
        return 1
    fi

    # Gather all context
    cat << EOF
FILE_PATH=$binary
FILE_TYPE=$(file "$binary" 2>/dev/null)
ARCH=$(file "$binary" 2>/dev/null | grep -oE 'x86-64|ARM|aarch64|i386|ARM64' || echo 'unknown')
SIZE=$(stat -c%s "$binary" 2>/dev/null || stat -f%z "$binary" 2>/dev/null || echo 'unknown')
MD5=$(md5sum "$binary" 2>/dev/null | cut -d' ' -f1 || echo 'unavailable')
EOF
}

# Check security features
ai_check_security() {
    local binary="$1"
    local output=""

    # RELRO
    if readelf -l "$binary" 2>/dev/null | grep -q "GNU_RELRO"; then
        if readelf -d "$binary" 2>/dev/null | grep -q "BIND_NOW"; then
            output+="RELRO: Full RELRO|"
        else
            output+="RELRO: Partial RELRO|"
        fi
    else
        output+="RELRO: No RELRO|"
    fi

    # Stack Canary
    if readelf -s "$binary" 2>/dev/null | grep -q "__stack_chk_fail"; then
        output+="CANARY: Found|"
    else
        output+="CANARY: No canary|"
    fi

    # NX
    if readelf -l "$binary" 2>/dev/null | grep "GNU_STACK" | grep -q "RW "; then
        output+="NX: Enabled|"
    else
        output+="NX: Disabled|"
    fi

    # PIE
    if readelf -h "$binary" 2>/dev/null | grep "Type:" | grep -q "DYN"; then
        output+="PIE: Enabled|"
    else
        output+="PIE: No PIE|"
    fi

    # FORTIFY
    if readelf -s "$binary" 2>/dev/null | grep -q "_chk"; then
        output+="FORTIFY: Yes"
    else
        output+="FORTIFY: No"
    fi

    echo "$output" | tr '|' '\n'
}

# Get interesting strings
ai_get_strings() {
    local binary="$1"
    local filter="${2:-.*}"

    strings "$binary" 2>/dev/null | grep -iE "$filter" | head -20
}

# Get functions
ai_get_functions() {
    local binary="$1"

    nm "$binary" 2>/dev/null | grep " T " | awk '{print $3}' | head -30
}

# Get imports
ai_get_imports() {
    local binary="$1"

    nm "$binary" 2>/dev/null | grep " U " | awk '{print $3}' | head -30
}

# Get disassembly
ai_get_disasm() {
    local binary="$1"
    local function="${2:-main}"
    local lines="${3:-50}"

    if [ "$function" = "all" ]; then
        objdump -d "$binary" 2>/dev/null | head -$lines
    else
        objdump -d "$binary" 2>/dev/null | sed -n "/<$function>:/,/^$/p" | head -$lines
    fi
}

# Find ROP gadgets (simple)
ai_find_gadgets() {
    local binary="$1"
    local count="${2:-30}"

    objdump -d "$binary" 2>/dev/null | grep -E "ret$|pop.*ret|call.*ret" | head -$count
}

#===============================================================================
# PROMPT GENERATORS
#===============================================================================

# Generate buffer overflow analysis prompt
ai_prompt_buffer_overflow() {
    local binary="$1"

    if [ ! -f "$binary" ]; then
        echo "Error: Binary not found" >&2
        return 1
    fi

    # Load template
    local prompt=$(ai_load_template "buffer_overflow_analysis")

    # Gather context
    local context=$(ai_gather_context "$binary")
    local security=$(ai_check_security "$binary")
    local strings_out=$(ai_get_strings "$binary" "pass|key|admin|flag|secret")
    local disasm=$(ai_get_disasm "$binary" "main" 60)

    # Replace placeholders
    prompt=$(ai_replace "$prompt" "BINARY_PATH" "$binary")
    prompt=$(ai_replace "$prompt" "FILE_TYPE" "$(echo "$context" | grep FILE_TYPE | cut -d= -f2-)")
    prompt=$(ai_replace "$prompt" "ARCH" "$(echo "$context" | grep ARCH | cut -d= -f2)")
    prompt=$(ai_replace "$prompt" "SIZE" "$(echo "$context" | grep SIZE | cut -d= -f2)")
    prompt=$(ai_replace "$prompt" "RELRO_STATUS" "$(echo "$security" | grep RELRO | cut -d: -f2-)")
    prompt=$(ai_replace "$prompt" "CANARY_STATUS" "$(echo "$security" | grep CANARY | cut -d: -f2-)")
    prompt=$(ai_replace "$prompt" "NX_STATUS" "$(echo "$security" | grep NX | cut -d: -f2-)")
    prompt=$(ai_replace "$prompt" "PIE_STATUS" "$(echo "$security" | grep PIE | cut -d: -f2-)")
    prompt=$(ai_replace "$prompt" "FORTIFY_STATUS" "$(echo "$security" | grep FORTIFY | cut -d: -f2-)")
    prompt=$(ai_replace "$prompt" "INTERESTING_STRINGS" "$strings_out")
    prompt=$(ai_replace "$prompt" "DISASSEMBLY" "$disasm")

    echo "$prompt"
}

# Generate ROP chain prompt
ai_prompt_rop() {
    local binary="$1"
    local goal="${2:-Execute arbitrary code}"

    if [ ! -f "$binary" ]; then
        echo "Error: Binary not found" >&2
        return 1
    fi

    local prompt=$(ai_load_template "rop_chain_generation")
    local security=$(ai_check_security "$binary")
    local gadgets=$(ai_find_gadgets "$binary" 40)
    local functions=$(ai_get_functions "$binary")
    local arch=$(file "$binary" | grep -oE 'x86-64|ARM|aarch64')

    prompt=$(ai_replace "$prompt" "BINARY_PATH" "$binary")
    prompt=$(ai_replace "$prompt" "ARCH" "$arch")
    prompt=$(ai_replace "$prompt" "BASE_ADDR" "0x400000")
    prompt=$(ai_replace "$prompt" "PIE_STATUS" "$(echo "$security" | grep PIE | cut -d: -f2-)")
    prompt=$(ai_replace "$prompt" "NX_STATUS" "$(echo "$security" | grep NX | cut -d: -f2-)")
    prompt=$(ai_replace "$prompt" "RELRO_STATUS" "$(echo "$security" | grep RELRO | cut -d: -f2-)")
    prompt=$(ai_replace "$prompt" "CANARY_STATUS" "$(echo "$security" | grep CANARY | cut -d: -f2-)")
    prompt=$(ai_replace "$prompt" "ROP_GADGETS" "$gadgets")
    prompt=$(ai_replace "$prompt" "FUNCTIONS" "$functions")
    prompt=$(ai_replace "$prompt" "GOAL" "$goal")
    prompt=$(ai_replace "$prompt" "ADDITIONAL_CONSTRAINTS" "None")

    echo "$prompt"
}

# Generate reverse engineering prompt
ai_prompt_reverse_engineering() {
    local binary="$1"
    local function="${2:-main}"

    if [ ! -f "$binary" ]; then
        echo "Error: Binary not found" >&2
        return 1
    fi

    local prompt=$(ai_load_template "reverse_engineering")
    local func_disasm=$(ai_get_disasm "$binary" "$function" 80)
    local strings_out=$(ai_get_strings "$binary")
    local imports=$(ai_get_imports "$binary")
    local func_count=$(ai_get_functions "$binary" | wc -l)
    local stripped=$(nm "$binary" >/dev/null 2>&1 && echo "Not stripped" || echo "Stripped")

    prompt=$(ai_replace "$prompt" "BINARY_PATH" "$binary")
    prompt=$(ai_replace "$prompt" "FILE_TYPE" "$(file "$binary")")
    prompt=$(ai_replace "$prompt" "ARCH" "$(file "$binary" | grep -oE 'x86-64|ARM|aarch64')")
    prompt=$(ai_replace "$prompt" "SYMBOLS_STATUS" "$stripped")
    prompt=$(ai_replace "$prompt" "FUNCTION_COUNT" "$func_count")
    prompt=$(ai_replace "$prompt" "FUNCTION_NAME" "$function")
    prompt=$(ai_replace "$prompt" "FUNCTION_DISASSEMBLY" "$func_disasm")
    prompt=$(ai_replace "$prompt" "INTERESTING_STRINGS" "$strings_out")
    prompt=$(ai_replace "$prompt" "IMPORTED_FUNCTIONS" "$imports")
    prompt=$(ai_replace "$prompt" "CROSS_REFERENCES" "Use radare2 for xrefs")

    echo "$prompt"
}

# Generate custom prompt
ai_prompt_custom() {
    local binary="$1"
    local focus="$2"
    local questions="$3"

    if [ ! -f "$binary" ]; then
        echo "Error: Binary not found" >&2
        return 1
    fi

    local security=$(ai_check_security "$binary")
    local disasm=$(ai_get_disasm "$binary" "main" 60)

    cat << EOF
# Custom Security Analysis

## Target Binary
**File:** $binary
**Focus:** $focus

## Binary Information
$(file "$binary")

## Security Features
\`\`\`
$security
\`\`\`

## Sample Disassembly
\`\`\`assembly
$disasm
\`\`\`

## Analysis Questions
$(echo "$questions" | tr '|' '\n' | sed 's/^/- /')

## Request
Please provide detailed technical analysis addressing each question above.
Consider the security features and code patterns shown.
EOF
}

#===============================================================================
# OUTPUT FUNCTIONS
#===============================================================================

# Save prompt to file
ai_save_prompt() {
    local prompt="$1"
    local filename="${2:-prompt_$(date +%s).md}"
    local output_file="${AI_OUTPUT_DIR}/${filename}"

    echo "$prompt" > "$output_file"
    echo "$output_file"
}

# Display prompt with options
ai_display_prompt() {
    local prompt="$1"
    local title="${2:-Generated Prompt}"

    echo "════════════════════════════════════════════════════════"
    echo "  AI PROMPT: $title"
    echo "════════════════════════════════════════════════════════"
    echo ""
    echo "$prompt"
    echo ""
    echo "════════════════════════════════════════════════════════"

    # Save automatically
    local saved_file=$(ai_save_prompt "$prompt")
    echo "✓ Saved to: $saved_file"
    echo ""
    echo "Copy this prompt and paste it into your AI assistant"
    echo "(ChatGPT, Claude, etc.)"
}

# Quick copy (if clipboard available)
ai_copy_clipboard() {
    local prompt="$1"

    if command -v xclip >/dev/null 2>&1; then
        echo "$prompt" | xclip -selection clipboard
        echo "✓ Copied to clipboard (xclip)"
        return 0
    elif command -v pbcopy >/dev/null 2>&1; then
        echo "$prompt" | pbcopy
        echo "✓ Copied to clipboard (pbcopy)"
        return 0
    elif command -v termux-clipboard-set >/dev/null 2>&1; then
        echo "$prompt" | termux-clipboard-set
        echo "✓ Copied to clipboard (termux)"
        return 0
    else
        echo "⚠ Clipboard tool not available"
        return 1
    fi
}

#===============================================================================
# CONVENIENCE WRAPPERS
#===============================================================================

# All-in-one: analyze and display
ai_analyze() {
    local binary="$1"
    local prompt=$(ai_prompt_buffer_overflow "$binary")
    ai_display_prompt "$prompt" "Binary Analysis"
}

# All-in-one: ROP strategy
ai_rop() {
    local binary="$1"
    local goal="${2:-Execute code}"
    local prompt=$(ai_prompt_rop "$binary" "$goal")
    ai_display_prompt "$prompt" "ROP Strategy"
}

# All-in-one: reverse engineering
ai_reverse() {
    local binary="$1"
    local function="${2:-main}"
    local prompt=$(ai_prompt_reverse_engineering "$binary" "$function")
    ai_display_prompt "$prompt" "Reverse Engineering"
}

# All-in-one: custom analysis
ai_custom() {
    local binary="$1"
    local focus="$2"
    local questions="$3"
    local prompt=$(ai_prompt_custom "$binary" "$focus" "$questions")
    ai_display_prompt "$prompt" "Custom Analysis"
}

#===============================================================================
# MODULE INFO
#===============================================================================

ai_module_info() {
    cat << EOF
AI Extension Module v${AI_MODULE_VERSION}
Location: ${AI_MODULE_DIR}
Templates: ${AI_TEMPLATE_DIR}
Output: ${AI_OUTPUT_DIR}

Available Functions:
  Core:
    ai_load_template <name>
    ai_gather_context <binary>
    ai_check_security <binary>

  Prompt Generators:
    ai_prompt_buffer_overflow <binary>
    ai_prompt_rop <binary> [goal]
    ai_prompt_reverse_engineering <binary> [function]
    ai_prompt_custom <binary> <focus> <questions>

  Output:
    ai_display_prompt <prompt> [title]
    ai_save_prompt <prompt> [filename]
    ai_copy_clipboard <prompt>

  Quick Commands:
    ai_analyze <binary>
    ai_rop <binary> [goal]
    ai_reverse <binary> [function]
    ai_custom <binary> <focus> <questions>

Usage:
  source lib/ai_module.sh
  ai_analyze /path/to/binary
EOF
}

# Export functions
export -f ai_load_template
export -f ai_replace
export -f ai_gather_context
export -f ai_check_security
export -f ai_get_strings
export -f ai_get_functions
export -f ai_get_imports
export -f ai_get_disasm
export -f ai_find_gadgets
export -f ai_prompt_buffer_overflow
export -f ai_prompt_rop
export -f ai_prompt_reverse_engineering
export -f ai_prompt_custom
export -f ai_display_prompt
export -f ai_save_prompt
export -f ai_copy_clipboard
export -f ai_analyze
export -f ai_rop
export -f ai_reverse
export -f ai_custom
export -f ai_module_info

echo "✓ AI Module loaded (v${AI_MODULE_VERSION})"
