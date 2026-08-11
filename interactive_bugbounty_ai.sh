#!/bin/bash
# Interactive Bug Bounty Toolkit with AI Prompting
# AI-assisted security research with prompt generation
# Version 2.0 - Now with AI assistance!

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="${SCRIPT_DIR}/prompts/templates"
OUTPUT_DIR="/tmp/ai_prompts"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Source original toolkit functions (if exists)
if [ -f "${SCRIPT_DIR}/interactive_bugbounty.sh" ]; then
    # We'll include original functions inline for simplicity
    :
fi

# Banner
show_banner() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${BOLD}    INTERACTIVE BUG BOUNTY TOOLKIT v2.0 + AI${NC}${CYAN}             ║${NC}"
    echo -e "${CYAN}║${NC}  Security Research with AI Prompt Generation             ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Check tools
check_tools() {
    TOOLS_AVAILABLE=()
    TOOLS_MISSING=()
    for tool in gdb python3 gcc git objdump readelf strings nm; do
        if command -v $tool >/dev/null 2>&1; then
            TOOLS_AVAILABLE+=("$tool")
        else
            TOOLS_MISSING+=("$tool")
        fi
    done
}

# Show status
show_status() {
    echo -e "${BOLD}System:${NC} $(uname -sm)"
    check_tools
    echo -e "${BOLD}Tools:${NC} ${GREEN}${#TOOLS_AVAILABLE[@]} available${NC}"
    if [ ${#TOOLS_MISSING[@]} -gt 0 ]; then
        echo -e "${BOLD}Missing:${NC} ${RED}${#TOOLS_MISSING[@]} tools${NC}"
    fi
    echo ""
}

# Enhanced menu with AI options
show_menu() {
    show_banner
    show_status

    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}MAIN MENU${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${BOLD}🤖 AI-Assisted Analysis:${NC}"
    echo -e "  ${PURPLE}16${NC}) AI: Analyze Binary for Vulnerabilities"
    echo -e "  ${PURPLE}17${NC}) AI: Generate ROP Chain Strategy"
    echo -e "  ${PURPLE}18${NC}) AI: Reverse Engineering Assistant"
    echo -e "  ${PURPLE}19${NC}) AI: Exploit Development Roadmap"
    echo -e "  ${PURPLE}20${NC}) AI: Buffer Overflow Deep Dive"
    echo -e "  ${PURPLE}21${NC}) AI: Custom Prompt Builder"
    echo -e "  ${PURPLE}22${NC}) Browse Prompt Templates"
    echo ""
    echo -e "${BOLD}📊 Binary Analysis:${NC}"
    echo -e "  ${GREEN}1${NC}) Analyze Binary    ${GREEN}2${NC}) Debug (GDB)    ${GREEN}3${NC}) Find Functions"
    echo -e "  ${GREEN}4${NC}) Security Check"
    echo ""
    echo -e "${BOLD}🔨 Exploitation:${NC}"
    echo -e "  ${GREEN}5${NC}) Generate Pattern  ${GREEN}6${NC}) Find Offset   ${GREEN}7${NC}) ROP Gadgets"
    echo -e "  ${GREEN}8${NC}) Test Overflow"
    echo ""
    echo -e "${BOLD}🛠️ Utilities:${NC}"
    echo -e "  ${GREEN}9${NC}) Compile Program  ${GREEN}10${NC}) Trace Syscalls ${GREEN}11${NC}) Hexdump"
    echo -e "  ${GREEN}12${NC}) Create Test Vuln"
    echo ""
    echo -e "${BOLD}⚙️ Setup:${NC}"
    echo -e "  ${GREEN}13${NC}) Install Pwntools ${GREEN}14${NC}) Install Tools  ${GREEN}15${NC}) Setup GEF"
    echo ""
    echo -e "  ${YELLOW}0${NC}) Exit"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -ne "${BOLD}Select [0-22]:${NC} "
}

#===============================================================================
# AI PROMPT GENERATION FUNCTIONS
#===============================================================================

# Load template and replace placeholders
load_template() {
    local template_name="$1"
    local template_file="${TEMPLATE_DIR}/${template_name}.txt"

    if [ ! -f "$template_file" ]; then
        echo -e "${RED}Template not found: $template_name${NC}"
        return 1
    fi

    cat "$template_file"
}

# Replace placeholder in template
replace_placeholder() {
    local content="$1"
    local key="$2"
    local value="$3"
    echo "$content" | sed "s|{{${key}}}|${value}|g"
}

# Gather binary context
gather_binary_context() {
    local binary="$1"
    local context=""

    # Basic info
    context="BINARY_PATH=$binary\n"
    context+="FILE_TYPE=$(file "$binary" 2>/dev/null || echo 'unknown')\n"
    context+="ARCH=$(file "$binary" 2>/dev/null | grep -oE 'x86-64|ARM|aarch64|i386' || echo 'unknown')\n"
    context+="SIZE=$(stat -c%s "$binary" 2>/dev/null || stat -f%z "$binary" 2>/dev/null || echo 'unknown')\n"

    echo -e "$context"
}

# Check security features
check_security_features() {
    local binary="$1"
    local result=""

    # RELRO
    if readelf -l "$binary" 2>/dev/null | grep -q "GNU_RELRO"; then
        if readelf -d "$binary" 2>/dev/null | grep -q "BIND_NOW"; then
            result+="RELRO: Full RELRO\n"
        else
            result+="RELRO: Partial RELRO\n"
        fi
    else
        result+="RELRO: No RELRO\n"
    fi

    # Stack Canary
    if readelf -s "$binary" 2>/dev/null | grep -q "__stack_chk_fail"; then
        result+="CANARY: Canary found\n"
    else
        result+="CANARY: No canary\n"
    fi

    # NX
    if readelf -l "$binary" 2>/dev/null | grep "GNU_STACK" | grep -q "RW "; then
        result+="NX: NX enabled\n"
    else
        result+="NX: NX disabled (executable stack)\n"
    fi

    # PIE
    if readelf -h "$binary" 2>/dev/null | grep "Type:" | grep -q "DYN"; then
        result+="PIE: PIE enabled\n"
    else
        result+="PIE: No PIE\n"
    fi

    # FORTIFY
    if readelf -s "$binary" 2>/dev/null | grep -q "_chk"; then
        result+="FORTIFY: Some fortified functions\n"
    else
        result+="FORTIFY: No fortified functions\n"
    fi

    echo -e "$result"
}

# Display generated prompt
display_prompt() {
    local prompt="$1"
    local title="$2"
    local output_file="${OUTPUT_DIR}/prompt_$(date +%s).md"

    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${BOLD}  AI PROMPT GENERATED: $title${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Display prompt
    echo "$prompt"

    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}Prompt Actions:${NC}"
    echo "  1) Save to file ($output_file)"
    echo "  2) Copy to clipboard (if available)"
    echo "  3) View in pager (less)"
    echo "  0) Back to menu"
    echo ""
    read -p "Select action: " action

    case $action in
        1)
            echo "$prompt" > "$output_file"
            echo -e "${GREEN}✓ Saved to: $output_file${NC}"
            echo "You can now copy this file and paste to your AI assistant"
            ;;
        2)
            if command -v xclip >/dev/null 2>&1; then
                echo "$prompt" | xclip -selection clipboard
                echo -e "${GREEN}✓ Copied to clipboard${NC}"
            elif command -v pbcopy >/dev/null 2>&1; then
                echo "$prompt" | pbcopy
                echo -e "${GREEN}✓ Copied to clipboard${NC}"
            else
                echo -e "${YELLOW}Clipboard tool not available. Saved to: $output_file${NC}"
                echo "$prompt" > "$output_file"
            fi
            ;;
        3)
            echo "$prompt" | less
            ;;
    esac

    read -p "Press Enter to continue..."
}

#===============================================================================
# AI MENU OPTIONS (16-22)
#===============================================================================

# Option 16: AI Binary Vulnerability Analysis
ai_analyze_binary() {
    echo -e "\n${BOLD}═══ AI: BINARY VULNERABILITY ANALYSIS ═══${NC}\n"
    read -p "Enter binary path: " BINARY

    if [ ! -f "$BINARY" ]; then
        echo -e "${RED}File not found${NC}"
        read -p "Press Enter..."
        return
    fi

    # Gather context
    local file_type=$(file "$BINARY")
    local arch=$(echo "$file_type" | grep -oE 'x86-64|ARM|aarch64|i386' || echo "unknown")
    local size=$(stat -c%s "$BINARY" 2>/dev/null || stat -f%z "$BINARY" 2>/dev/null)
    local security=$(check_security_features "$BINARY")
    local strings_out=$(strings "$BINARY" | grep -iE '(pass|key|admin|secret|flag)' | head -10)
    local disasm=$(objdump -d "$BINARY" 2>/dev/null | head -100 || echo "Could not disassemble")

    # Load template
    local prompt=$(load_template "buffer_overflow_analysis")

    # Replace placeholders
    prompt=$(replace_placeholder "$prompt" "BINARY_PATH" "$BINARY")
    prompt=$(replace_placeholder "$prompt" "FILE_TYPE" "$file_type")
    prompt=$(replace_placeholder "$prompt" "ARCH" "$arch")
    prompt=$(replace_placeholder "$prompt" "SIZE" "$size")
    prompt=$(replace_placeholder "$prompt" "RELRO_STATUS" "$(echo "$security" | grep RELRO | cut -d: -f2)")
    prompt=$(replace_placeholder "$prompt" "CANARY_STATUS" "$(echo "$security" | grep CANARY | cut -d: -f2)")
    prompt=$(replace_placeholder "$prompt" "NX_STATUS" "$(echo "$security" | grep NX | cut -d: -f2)")
    prompt=$(replace_placeholder "$prompt" "PIE_STATUS" "$(echo "$security" | grep PIE | cut -d: -f2)")
    prompt=$(replace_placeholder "$prompt" "FORTIFY_STATUS" "$(echo "$security" | grep FORTIFY | cut -d: -f2)")
    prompt=$(replace_placeholder "$prompt" "INTERESTING_STRINGS" "$strings_out")
    prompt=$(replace_placeholder "$prompt" "DISASSEMBLY" "$disasm")

    display_prompt "$prompt" "Binary Analysis"
}

# Option 17: AI ROP Chain Strategy
ai_rop_strategy() {
    echo -e "\n${BOLD}═══ AI: ROP CHAIN STRATEGY ═══${NC}\n"
    read -p "Enter binary path: " BINARY

    if [ ! -f "$BINARY" ]; then
        echo -e "${RED}File not found${NC}"
        read -p "Press Enter..."
        return
    fi

    read -p "Enter goal (e.g., 'call system(\"/bin/sh\")'): " GOAL

    # Gather ROP gadgets
    local gadgets=$(objdump -d "$BINARY" 2>/dev/null | grep -E "ret$|pop.*ret" | head -30 || echo "Run ROPgadget tool for better results")
    local functions=$(nm "$BINARY" 2>/dev/null | grep " T " | head -20 || echo "Binary is stripped")
    local security=$(check_security_features "$BINARY")

    # Load template
    local prompt=$(load_template "rop_chain_generation")

    # Replace placeholders
    prompt=$(replace_placeholder "$prompt" "BINARY_PATH" "$BINARY")
    prompt=$(replace_placeholder "$prompt" "ARCH" "$(file "$BINARY" | grep -oE 'x86-64|ARM|aarch64')")
    prompt=$(replace_placeholder "$prompt" "BASE_ADDR" "0x400000")
    prompt=$(replace_placeholder "$prompt" "PIE_STATUS" "$(echo "$security" | grep PIE | cut -d: -f2)")
    prompt=$(replace_placeholder "$prompt" "NX_STATUS" "$(echo "$security" | grep NX | cut -d: -f2)")
    prompt=$(replace_placeholder "$prompt" "RELRO_STATUS" "$(echo "$security" | grep RELRO | cut -d: -f2)")
    prompt=$(replace_placeholder "$prompt" "CANARY_STATUS" "$(echo "$security" | grep CANARY | cut -d: -f2)")
    prompt=$(replace_placeholder "$prompt" "ROP_GADGETS" "$gadgets")
    prompt=$(replace_placeholder "$prompt" "FUNCTIONS" "$functions")
    prompt=$(replace_placeholder "$prompt" "GOAL" "$GOAL")
    prompt=$(replace_placeholder "$prompt" "ADDITIONAL_CONSTRAINTS" "None specified")

    display_prompt "$prompt" "ROP Chain Strategy"
}

# Option 18: AI Reverse Engineering
ai_reverse_engineer() {
    echo -e "\n${BOLD}═══ AI: REVERSE ENGINEERING ASSISTANT ═══${NC}\n"
    read -p "Enter binary path: " BINARY

    if [ ! -f "$BINARY" ]; then
        echo -e "${RED}File not found${NC}"
        read -p "Press Enter..."
        return
    fi

    read -p "Enter function name (or 'main'): " FUNC_NAME
    FUNC_NAME=${FUNC_NAME:-main}

    # Gather context
    local func_disasm=$(objdump -d "$BINARY" 2>/dev/null | sed -n "/<$FUNC_NAME>:/,/^$/p" | head -50 || echo "Function not found")
    local strings_out=$(strings "$BINARY" | head -30)
    local imports=$(nm "$BINARY" 2>/dev/null | grep " U " | head -20)

    # Load template
    local prompt=$(load_template "reverse_engineering")

    # Replace placeholders
    prompt=$(replace_placeholder "$prompt" "BINARY_PATH" "$BINARY")
    prompt=$(replace_placeholder "$prompt" "FILE_TYPE" "$(file "$BINARY")")
    prompt=$(replace_placeholder "$prompt" "ARCH" "$(file "$BINARY" | grep -oE 'x86-64|ARM|aarch64')")
    prompt=$(replace_placeholder "$prompt" "SYMBOLS_STATUS" "$(nm "$BINARY" >/dev/null 2>&1 && echo 'Not stripped' || echo 'Stripped')")
    prompt=$(replace_placeholder "$prompt" "FUNCTION_COUNT" "$(nm "$BINARY" 2>/dev/null | grep " T " | wc -l)")
    prompt=$(replace_placeholder "$prompt" "FUNCTION_NAME" "$FUNC_NAME")
    prompt=$(replace_placeholder "$prompt" "FUNCTION_DISASSEMBLY" "$func_disasm")
    prompt=$(replace_placeholder "$prompt" "INTERESTING_STRINGS" "$strings_out")
    prompt=$(replace_placeholder "$prompt" "IMPORTED_FUNCTIONS" "$imports")
    prompt=$(replace_placeholder "$prompt" "CROSS_REFERENCES" "Run with radare2 for xrefs")

    display_prompt "$prompt" "Reverse Engineering"
}

# Option 19: AI Exploit Roadmap
ai_exploit_roadmap() {
    echo -e "\n${BOLD}═══ AI: EXPLOIT DEVELOPMENT ROADMAP ═══${NC}\n"

    cat << 'ROADMAP_EOF'
# Exploit Development Roadmap Prompt Generator

This will create a comprehensive exploitation strategy prompt.

Please provide:
ROADMAP_EOF

    read -p "Binary path: " BINARY
    read -p "Vulnerability type (buffer overflow/format string/heap): " VULN_TYPE
    read -p "Vulnerability location (function name): " VULN_LOC

    if [ ! -f "$BINARY" ]; then
        echo -e "${RED}File not found${NC}"
        read -p "Press Enter..."
        return
    fi

    local security=$(check_security_features "$BINARY")

    # Create custom roadmap prompt
    local prompt=$(cat << EOF
# Exploit Development Roadmap

## Target Analysis
- Binary: $BINARY
- Vulnerability Type: $VULN_TYPE
- Location: $VULN_LOC

## Security Mitigations
$(echo "$security")

## Exploitation Request

Please create a comprehensive exploitation roadmap for this vulnerability:

### Phase 1: Vulnerability Understanding
- Explain the $VULN_TYPE mechanism
- Identify the root cause in $VULN_LOC
- Assess exploitability

### Phase 2: Primitive Development
- What primitive can we achieve?
- How to trigger reliably?
- Constraints and limitations?

### Phase 3: Mitigation Bypass
Given the security features:
- Best exploitation approach?
- Information leaks needed?
- Bypass strategy for each mitigation?

### Phase 4: Payload Construction
- Payload structure design
- Shellcode vs ROP decision
- Delivery mechanism

### Phase 5: Exploit Reliability
- Edge case handling
- Stability improvements
- Testing methodology

Provide step-by-step technical roadmap with code examples.
EOF
)

    display_prompt "$prompt" "Exploit Roadmap"
}

# Option 20: Buffer Overflow Deep Dive
ai_buffer_overflow_deep() {
    echo -e "\n${BOLD}═══ AI: BUFFER OVERFLOW DEEP DIVE ═══${NC}\n"
    read -p "Enter binary path: " BINARY

    if [ ! -f "$BINARY" ]; then
        echo -e "${RED}File not found${NC}"
        read -p "Press Enter..."
        return
    fi

    # This uses the buffer overflow template with extra detail
    ai_analyze_binary
}

# Option 21: Custom Prompt Builder
ai_custom_prompt() {
    echo -e "\n${BOLD}═══ AI: CUSTOM PROMPT BUILDER ═══${NC}\n"

    echo "Build a custom security analysis prompt"
    echo ""
    read -p "Binary path: " BINARY
    read -p "Analysis focus (vulnerability/RE/exploitation): " FOCUS
    read -p "Specific questions (separate with |): " QUESTIONS

    if [ ! -f "$BINARY" ]; then
        echo -e "${RED}File not found${NC}"
        read -p "Press Enter..."
        return
    fi

    local security=$(check_security_features "$BINARY")
    local disasm=$(objdump -d "$BINARY" 2>/dev/null | head -50)

    # Build custom prompt
    local prompt=$(cat << EOF
# Custom Security Analysis Request

## Binary: $BINARY
## Focus: $FOCUS

## Binary Information
$(file "$BINARY")

## Security Features
$security

## Code Sample
\`\`\`assembly
$disasm
\`\`\`

## Specific Questions
$(echo "$QUESTIONS" | tr '|' '\n' | sed 's/^/- /')

Please provide detailed analysis addressing each question above.
EOF
)

    display_prompt "$prompt" "Custom Analysis"
}

# Option 22: Browse Templates
browse_templates() {
    echo -e "\n${BOLD}═══ PROMPT TEMPLATE LIBRARY ═══${NC}\n"

    if [ ! -d "$TEMPLATE_DIR" ]; then
        echo -e "${RED}Template directory not found: $TEMPLATE_DIR${NC}"
        read -p "Press Enter..."
        return
    fi

    echo "Available prompt templates:"
    echo ""

    local i=1
    for template in "$TEMPLATE_DIR"/*.txt; do
        if [ -f "$template" ]; then
            local name=$(basename "$template" .txt)
            echo "  $i) $name"
            ((i++))
        fi
    done

    echo ""
    read -p "Enter number to view template (0 to cancel): " choice

    if [ "$choice" -gt 0 ] 2>/dev/null; then
        local template_file=$(ls "$TEMPLATE_DIR"/*.txt | sed -n "${choice}p")
        if [ -f "$template_file" ]; then
            echo ""
            echo -e "${CYAN}Template: $(basename "$template_file")${NC}"
            echo ""
            cat "$template_file" | less
        fi
    fi

    read -p "Press Enter to continue..."
}

#===============================================================================
# ORIGINAL TOOLKIT FUNCTIONS (Simplified versions)
#===============================================================================

# We'll include key original functions here...
# For brevity, showing main integration point

#===============================================================================
# MAIN LOOP
#===============================================================================

main() {
    while true; do
        show_menu
        read -r CHOICE

        case $CHOICE in
            # AI Options
            16) ai_analyze_binary ;;
            17) ai_rop_strategy ;;
            18) ai_reverse_engineer ;;
            19) ai_exploit_roadmap ;;
            20) ai_buffer_overflow_deep ;;
            21) ai_custom_prompt ;;
            22) browse_templates ;;

            # Original options would go here (1-15)
            # For now, referring to original toolkit
            [1-9]|1[0-5])
                echo -e "${YELLOW}Feature $CHOICE: Run original toolkit${NC}"
                if [ -f "${SCRIPT_DIR}/interactive_bugbounty.sh" ]; then
                    bash "${SCRIPT_DIR}/interactive_bugbounty.sh"
                else
                    echo -e "${RED}Original toolkit not found${NC}"
                fi
                read -p "Press Enter..."
                ;;

            0)
                clear
                echo -e "${GREEN}Thank you for using AI-Enhanced Bug Bounty Toolkit!${NC}"
                echo -e "${CYAN}Copy your prompts from: $OUTPUT_DIR${NC}"
                echo -e "${PURPLE}Happy hunting with AI assistance! 🤖🎯💰${NC}\n"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                sleep 1
                ;;
        esac
    done
}

# Run
main
