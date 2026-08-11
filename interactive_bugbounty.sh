#!/bin/bash
# Interactive Bug Bounty Toolkit
# Full-featured interactive security research environment
# No demo - real tools, real workflows

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

# Clear screen and show banner
show_banner() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${BOLD}         INTERACTIVE BUG BOUNTY TOOLKIT v1.0${NC}${CYAN}              ║${NC}"
    echo -e "${CYAN}║${NC}     Professional Security Research Environment            ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Check available tools
check_tools() {
    TOOLS_AVAILABLE=()
    TOOLS_MISSING=()

    for tool in gdb python3 gcc git objdump readelf strings nm strace ltrace; do
        if command -v $tool >/dev/null 2>&1; then
            TOOLS_AVAILABLE+=("$tool")
        else
            TOOLS_MISSING+=("$tool")
        fi
    done
}

# Show tool status
show_status() {
    echo -e "${BOLD}System Information:${NC}"
    echo -e "  OS: ${GREEN}$(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)${NC}"
    echo -e "  Arch: ${GREEN}$(uname -m)${NC}"
    echo -e "  Kernel: ${GREEN}$(uname -r)${NC}"
    echo ""

    echo -e "${BOLD}Available Tools:${NC}"
    check_tools
    for tool in "${TOOLS_AVAILABLE[@]}"; do
        echo -e "  ${GREEN}✓${NC} $tool"
    done

    if [ ${#TOOLS_MISSING[@]} -gt 0 ]; then
        echo ""
        echo -e "${BOLD}Missing Tools:${NC}"
        for tool in "${TOOLS_MISSING[@]}"; do
            echo -e "  ${RED}✗${NC} $tool"
        done
    fi
    echo ""
}

# Main menu
show_menu() {
    show_banner
    show_status

    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}MAIN MENU${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${BOLD}Binary Analysis:${NC}"
    echo -e "  ${GREEN}1${NC}) Analyze Binary (file, strings, objdump)"
    echo -e "  ${GREEN}2${NC}) Debug with GDB (interactive session)"
    echo -e "  ${GREEN}3${NC}) Find Functions & Symbols"
    echo -e "  ${GREEN}4${NC}) Check Security Features"
    echo ""
    echo -e "${BOLD}Exploitation:${NC}"
    echo -e "  ${GREEN}5${NC}) Generate Exploit Pattern (Cyclic)"
    echo -e "  ${GREEN}6${NC}) Find Pattern Offset"
    echo -e "  ${GREEN}7${NC}) Build ROP Chain (manual)"
    echo -e "  ${GREEN}8${NC}) Test Buffer Overflow"
    echo ""
    echo -e "${BOLD}Utilities:${NC}"
    echo -e "  ${GREEN}9${NC}) Compile C Program"
    echo -e "  ${GREEN}10${NC}) Trace System Calls (strace)"
    echo -e "  ${GREEN}11${NC}) Hexdump File"
    echo -e "  ${GREEN}12${NC}) Create Vulnerable Test Program"
    echo ""
    echo -e "${BOLD}Tools Installation:${NC}"
    echo -e "  ${GREEN}13${NC}) Install Python Pwntools"
    echo -e "  ${GREEN}14${NC}) Install Additional Tools"
    echo -e "  ${GREEN}15${NC}) Setup GDB Enhanced Features (GEF)"
    echo ""
    echo -e "  ${YELLOW}0${NC}) Exit"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -ne "${BOLD}Select option [0-15]:${NC} "
}

# Binary Analysis
analyze_binary() {
    echo -e "\n${BOLD}═══ BINARY ANALYSIS ═══${NC}\n"
    read -p "Enter binary path: " BINARY

    if [ ! -f "$BINARY" ]; then
        echo -e "${RED}Error: File not found${NC}"
        read -p "Press Enter to continue..."
        return
    fi

    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  BINARY ANALYSIS: $(basename $BINARY)"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    echo -e "${BOLD}1. File Information:${NC}"
    file "$BINARY"
    echo ""

    echo -e "${BOLD}2. File Size:${NC}"
    ls -lh "$BINARY" | awk '{print $5}'
    echo ""

    echo -e "${BOLD}3. Checksums:${NC}"
    md5sum "$BINARY" 2>/dev/null || echo "md5sum not available"
    sha256sum "$BINARY" 2>/dev/null || echo "sha256sum not available"
    echo ""

    if file "$BINARY" | grep -q "ELF"; then
        echo -e "${BOLD}4. ELF Header:${NC}"
        readelf -h "$BINARY" 2>/dev/null || echo "readelf not available"
        echo ""

        echo -e "${BOLD}5. Program Headers:${NC}"
        readelf -l "$BINARY" 2>/dev/null | grep -A 5 "GNU_STACK\|GNU_RELRO" || echo "No security headers found"
        echo ""
    fi

    echo -e "${BOLD}6. Interesting Strings (first 20):${NC}"
    strings "$BINARY" | head -20
    echo ""

    echo -e "${BOLD}7. Symbols (first 20):${NC}"
    nm "$BINARY" 2>/dev/null | head -20 || echo "Binary is stripped"
    echo ""

    read -p "Press Enter to continue..."
}

# Debug with GDB
debug_gdb() {
    echo -e "\n${BOLD}═══ GDB DEBUGGER ═══${NC}\n"
    read -p "Enter binary path: " BINARY

    if [ ! -f "$BINARY" ]; then
        echo -e "${RED}Error: File not found${NC}"
        read -p "Press Enter to continue..."
        return
    fi

    read -p "Enter arguments (optional): " ARGS

    echo -e "\n${GREEN}Starting GDB...${NC}"
    echo -e "${YELLOW}Useful commands:${NC}"
    echo -e "  run $ARGS          - Run the program"
    echo -e "  break main         - Set breakpoint at main"
    echo -e "  info registers     - Show registers"
    echo -e "  x/20x \$rsp         - Examine stack"
    echo -e "  disassemble main   - Disassemble function"
    echo -e "  quit               - Exit GDB"
    echo ""
    read -p "Press Enter to start GDB..."

    if [ -n "$ARGS" ]; then
        gdb "$BINARY" -ex "set args $ARGS"
    else
        gdb "$BINARY"
    fi
}

# Find functions
find_functions() {
    echo -e "\n${BOLD}═══ FUNCTION FINDER ═══${NC}\n"
    read -p "Enter binary path: " BINARY

    if [ ! -f "$BINARY" ]; then
        echo -e "${RED}Error: File not found${NC}"
        read -p "Press Enter to continue..."
        return
    fi

    clear
    echo -e "${CYAN}Functions and Symbols in $(basename $BINARY):${NC}\n"

    echo -e "${BOLD}User Functions:${NC}"
    nm "$BINARY" 2>/dev/null | grep " T " || echo "No symbols (binary is stripped)"
    echo ""

    echo -e "${BOLD}Imported Functions:${NC}"
    nm "$BINARY" 2>/dev/null | grep " U " | head -20 || objdump -T "$BINARY" 2>/dev/null | grep "DF" | head -20
    echo ""

    read -p "Press Enter to continue..."
}

# Check security features
check_security() {
    echo -e "\n${BOLD}═══ SECURITY FEATURES CHECK ═══${NC}\n"
    read -p "Enter binary path: " BINARY

    if [ ! -f "$BINARY" ]; then
        echo -e "${RED}Error: File not found${NC}"
        read -p "Press Enter to continue..."
        return
    fi

    clear
    echo -e "${CYAN}Security Analysis for $(basename $BINARY):${NC}\n"

    # Check RELRO
    echo -e "${BOLD}RELRO:${NC}"
    if readelf -l "$BINARY" 2>/dev/null | grep -q "GNU_RELRO"; then
        if readelf -d "$BINARY" 2>/dev/null | grep -q "BIND_NOW"; then
            echo -e "  ${GREEN}Full RELRO enabled${NC}"
        else
            echo -e "  ${YELLOW}Partial RELRO${NC}"
        fi
    else
        echo -e "  ${RED}No RELRO${NC}"
    fi

    # Check Stack Canary
    echo -e "${BOLD}Stack Canary:${NC}"
    if readelf -s "$BINARY" 2>/dev/null | grep -q "__stack_chk_fail"; then
        echo -e "  ${GREEN}Canary found${NC}"
    else
        echo -e "  ${RED}No canary${NC}"
    fi

    # Check NX
    echo -e "${BOLD}NX (Non-Executable Stack):${NC}"
    if readelf -l "$BINARY" 2>/dev/null | grep "GNU_STACK" | grep -q "RW "; then
        echo -e "  ${GREEN}NX enabled${NC}"
    else
        echo -e "  ${RED}NX disabled (stack is executable)${NC}"
    fi

    # Check PIE
    echo -e "${BOLD}PIE (Position Independent Executable):${NC}"
    if readelf -h "$BINARY" 2>/dev/null | grep "Type:" | grep -q "DYN"; then
        echo -e "  ${GREEN}PIE enabled${NC}"
    else
        echo -e "  ${YELLOW}PIE disabled${NC}"
    fi

    # Check FORTIFY
    echo -e "${BOLD}FORTIFY_SOURCE:${NC}"
    if readelf -s "$BINARY" 2>/dev/null | grep -q "_chk"; then
        echo -e "  ${GREEN}Some fortified functions found${NC}"
    else
        echo -e "  ${YELLOW}No fortified functions${NC}"
    fi

    echo ""
    read -p "Press Enter to continue..."
}

# Generate pattern
generate_pattern() {
    echo -e "\n${BOLD}═══ PATTERN GENERATOR ═══${NC}\n"
    read -p "Enter pattern length: " LENGTH

    # Simple cyclic pattern generator
    python3 << EOF
def cyclic(length):
    pattern = ""
    for i in range(length):
        pattern += chr(ord('A') + (i % 26))
    return pattern

print("Generated pattern (length $LENGTH):")
print(cyclic($LENGTH))
print("\nSave to file? (y/n)")
EOF

    read -p "> " SAVE
    if [ "$SAVE" = "y" ]; then
        read -p "Filename: " FILENAME
        python3 -c "print(''.join([chr(ord('A') + (i % 26)) for i in range($LENGTH)]))" > "$FILENAME"
        echo -e "${GREEN}Saved to $FILENAME${NC}"
    fi

    read -p "Press Enter to continue..."
}

# Find offset
find_offset() {
    echo -e "\n${BOLD}═══ PATTERN OFFSET FINDER ═══${NC}\n"
    read -p "Enter crashed value (e.g., 0x41414141): " VALUE

    # Remove 0x if present
    VALUE=${VALUE#0x}

    python3 << EOF
def find_offset(value):
    # Convert hex to characters
    try:
        val = int("$VALUE", 16)
        chars = []
        for i in range(4):
            chars.append(chr((val >> (i*8)) & 0xFF))

        # Find in pattern
        pattern_char = chars[0]
        offset = ord(pattern_char) - ord('A')

        print(f"Value: 0x$VALUE")
        print(f"Characters: {''.join(chars)}")
        print(f"Approximate offset: {offset}")
        print(f"\nNote: This is a simple calculation.")
        print(f"For accurate results, use pwntools cyclic_find()")
    except:
        print("Invalid hex value")

find_offset("$VALUE")
EOF

    read -p "\nPress Enter to continue..."
}

# Test buffer overflow
test_overflow() {
    echo -e "\n${BOLD}═══ BUFFER OVERFLOW TESTER ═══${NC}\n"
    read -p "Enter binary path: " BINARY

    if [ ! -f "$BINARY" ]; then
        echo -e "${RED}Error: File not found${NC}"
        read -p "Press Enter to continue..."
        return
    fi

    echo -e "\n${BOLD}Testing with increasing payload sizes...${NC}\n"

    for size in 10 50 100 200 500 1000; do
        PAYLOAD=$(python3 -c "print('A'*$size)")
        echo -ne "Testing size ${size}... "

        timeout 2 "$BINARY" "$PAYLOAD" >/dev/null 2>&1
        RESULT=$?

        if [ $RESULT -eq 139 ]; then
            echo -e "${RED}SEGFAULT! (crash at ~$size bytes)${NC}"
            echo -e "${YELLOW}Potential vulnerability found!${NC}"
            break
        elif [ $RESULT -eq 124 ]; then
            echo -e "${YELLOW}timeout${NC}"
        else
            echo -e "${GREEN}ok${NC}"
        fi
    done

    echo ""
    read -p "Press Enter to continue..."
}

# Compile C program
compile_program() {
    echo -e "\n${BOLD}═══ C COMPILER ═══${NC}\n"
    read -p "Enter source file (.c): " SOURCE

    if [ ! -f "$SOURCE" ]; then
        echo -e "${RED}Error: File not found${NC}"
        read -p "Press Enter to continue..."
        return
    fi

    BASENAME=$(basename "$SOURCE" .c)
    OUTPUT="${BASENAME}_vuln"

    echo -e "\n${BOLD}Compilation options:${NC}"
    echo "1) Normal compilation"
    echo "2) Debug build (-g)"
    echo "3) Vulnerable (no stack protector, executable stack)"
    echo "4) Custom flags"
    read -p "Select [1-4]: " OPTION

    case $OPTION in
        1)
            gcc "$SOURCE" -o "$OUTPUT"
            ;;
        2)
            gcc -g "$SOURCE" -o "$OUTPUT"
            ;;
        3)
            gcc -fno-stack-protector -z execstack -no-pie -g "$SOURCE" -o "$OUTPUT"
            echo -e "${YELLOW}Warning: Created intentionally vulnerable binary${NC}"
            ;;
        4)
            read -p "Enter custom flags: " FLAGS
            gcc $FLAGS "$SOURCE" -o "$OUTPUT"
            ;;
    esac

    if [ $? -eq 0 ]; then
        echo -e "\n${GREEN}Compiled successfully: $OUTPUT${NC}"
        ls -lh "$OUTPUT"
    else
        echo -e "\n${RED}Compilation failed${NC}"
    fi

    read -p "\nPress Enter to continue..."
}

# Trace system calls
trace_syscalls() {
    echo -e "\n${BOLD}═══ SYSTEM CALL TRACER ═══${NC}\n"
    read -p "Enter binary path: " BINARY

    if [ ! -f "$BINARY" ]; then
        echo -e "${RED}Error: File not found${NC}"
        read -p "Press Enter to continue..."
        return
    fi

    read -p "Enter arguments (optional): " ARGS

    if command -v strace >/dev/null 2>&1; then
        echo -e "\n${GREEN}Tracing system calls...${NC}\n"
        strace -e trace=all "$BINARY" $ARGS
    else
        echo -e "${RED}strace not installed${NC}"
        echo "Install with: sudo apt install strace"
    fi

    read -p "\nPress Enter to continue..."
}

# Hexdump
hexdump_file() {
    echo -e "\n${BOLD}═══ HEXDUMP ═══${NC}\n"
    read -p "Enter file path: " FILE

    if [ ! -f "$FILE" ]; then
        echo -e "${RED}Error: File not found${NC}"
        read -p "Press Enter to continue..."
        return
    fi

    read -p "Number of bytes to show (default: 256): " BYTES
    BYTES=${BYTES:-256}

    echo -e "\n${BOLD}Hex dump of $(basename $FILE):${NC}\n"
    hexdump -C "$FILE" | head -n $((BYTES/16))

    echo ""
    read -p "Press Enter to continue..."
}

# Create test program
create_test_program() {
    echo -e "\n${BOLD}═══ CREATE TEST PROGRAM ═══${NC}\n"

    FILENAME="test_vuln_$(date +%s).c"

    cat > "$FILENAME" << 'TESTEOF'
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

// Vulnerable function with buffer overflow
void vulnerable(char *input) {
    char buffer[64];
    printf("Buffer address: %p\n", buffer);
    strcpy(buffer, input);  // VULNERABILITY: No bounds checking!
    printf("Input received: %s\n", buffer);
}

// Secret function (goal: call this)
void secret_function() {
    printf("\n🎉 SECRET FUNCTION CALLED! You win!\n");
    printf("In a real exploit, this would be system(\"/bin/sh\")\n\n");
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        printf("Usage: %s <input>\n", argv[0]);
        printf("Vulnerable buffer overflow challenge\n");
        printf("Goal: Overflow the buffer and call secret_function()\n");
        printf("Secret function address: %p\n", secret_function);
        return 1;
    }

    printf("Starting vulnerable program...\n");
    vulnerable(argv[1]);
    printf("Program completed normally\n");

    return 0;
}
TESTEOF

    echo -e "${GREEN}Created: $FILENAME${NC}\n"

    read -p "Compile now? (y/n): " COMPILE
    if [ "$COMPILE" = "y" ]; then
        OUTPUT="${FILENAME%.c}"
        gcc -fno-stack-protector -z execstack -no-pie -g "$FILENAME" -o "$OUTPUT" 2>&1

        if [ $? -eq 0 ]; then
            echo -e "\n${GREEN}Compiled successfully: $OUTPUT${NC}"
            echo -e "${YELLOW}This binary is intentionally vulnerable!${NC}\n"
            echo "Try: ./$OUTPUT 'Hello'"
            echo "Then: ./$OUTPUT \$(python3 -c 'print(\"A\"*100)')"
            echo "Debug: gdb ./$OUTPUT"
        fi
    fi

    read -p "\nPress Enter to continue..."
}

# Install pwntools
install_pwntools() {
    echo -e "\n${BOLD}═══ INSTALL PWNTOOLS ═══${NC}\n"

    echo "Installing pwntools (Python exploitation framework)..."
    echo "This may take a few minutes..."
    echo ""

    pip3 install --user pwntools

    if [ $? -eq 0 ]; then
        echo -e "\n${GREEN}Pwntools installed successfully!${NC}"
        echo -e "\nTest with:"
        echo "  python3 -c 'from pwn import *; print(cyclic(100))'"
    else
        echo -e "\n${RED}Installation failed${NC}"
        echo "You may need internet access or try:"
        echo "  pip3 install --user pwntools"
    fi

    read -p "\nPress Enter to continue..."
}

# Install additional tools
install_tools() {
    echo -e "\n${BOLD}═══ INSTALL ADDITIONAL TOOLS ═══${NC}\n"

    echo "Available installations:"
    echo "1) Radare2 (reverse engineering)"
    echo "2) Nmap (network scanner)"
    echo "3) Netcat (network tool)"
    echo "4) Strace (system call tracer)"
    echo "5) All of the above"
    echo "0) Cancel"

    read -p "Select [0-5]: " CHOICE

    case $CHOICE in
        1) sudo apt install -y radare2 ;;
        2) sudo apt install -y nmap ;;
        3) sudo apt install -y netcat-openbsd ;;
        4) sudo apt install -y strace ltrace ;;
        5) sudo apt install -y radare2 nmap netcat-openbsd strace ltrace ;;
        0) return ;;
    esac

    read -p "\nPress Enter to continue..."
}

# Setup GEF
setup_gef() {
    echo -e "\n${BOLD}═══ SETUP GDB ENHANCED FEATURES (GEF) ═══${NC}\n"

    echo "Installing GEF - GDB Enhanced Features..."
    echo "This adds powerful commands to GDB"
    echo ""

    wget -q https://github.com/hugsy/gef/raw/main/gef.py -O ~/.gdbinit-gef.py

    if [ $? -eq 0 ]; then
        echo "source ~/.gdbinit-gef.py" > ~/.gdbinit
        echo -e "\n${GREEN}GEF installed successfully!${NC}"
        echo -e "\nNew GDB commands available:"
        echo "  checksec - Check binary protections"
        echo "  vmmap - Show memory mappings"
        echo "  pattern create 200 - Generate cyclic pattern"
        echo "  pattern offset 0x61616161 - Find offset"
        echo "  heap chunks - Analyze heap"
        echo "  rop - Find ROP gadgets"
    else
        echo -e "\n${RED}Installation failed (no internet?)${NC}"
    fi

    read -p "\nPress Enter to continue..."
}

# Manual ROP chain builder
build_rop() {
    echo -e "\n${BOLD}═══ ROP CHAIN BUILDER ═══${NC}\n"
    read -p "Enter binary path: " BINARY

    if [ ! -f "$BINARY" ]; then
        echo -e "${RED}Error: File not found${NC}"
        read -p "Press Enter to continue..."
        return
    fi

    echo -e "\n${BOLD}Finding ROP gadgets...${NC}\n"

    echo "Common ROP gadgets:"
    objdump -d "$BINARY" | grep -E "ret$|pop.*ret" | head -20

    echo ""
    read -p "Press Enter to continue..."
}

# Main loop
main() {
    while true; do
        show_menu
        read -r CHOICE

        case $CHOICE in
            1) analyze_binary ;;
            2) debug_gdb ;;
            3) find_functions ;;
            4) check_security ;;
            5) generate_pattern ;;
            6) find_offset ;;
            7) build_rop ;;
            8) test_overflow ;;
            9) compile_program ;;
            10) trace_syscalls ;;
            11) hexdump_file ;;
            12) create_test_program ;;
            13) install_pwntools ;;
            14) install_tools ;;
            15) setup_gef ;;
            0)
                clear
                echo -e "${GREEN}Thank you for using Interactive Bug Bounty Toolkit!${NC}"
                echo -e "${CYAN}Happy hunting! 🎯💰${NC}\n"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                sleep 1
                ;;
        esac
    done
}

# Run main program
main
