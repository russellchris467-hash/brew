#!/bin/bash
# Example: Integrating AI Module with Existing Toolkit
# Shows how to add AI capabilities to any security tool

# Colors for output
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  AI Module Integration Example${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════${NC}"
echo ""

# Load AI module
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/ai_module.sh"

# Your existing toolkit function
analyze_target() {
    local target="$1"

    echo "Running traditional analysis..."
    file "$target"
    readelf -h "$target" 2>/dev/null | grep "Entry point"
    echo ""
}

# Enhanced with AI
analyze_target_with_ai() {
    local target="$1"

    # Run your existing analysis
    analyze_target "$target"

    # Add AI assistance
    echo -e "${GREEN}Generating AI analysis prompt...${NC}"
    ai_analyze "$target"
}

# Example usage
if [ $# -lt 1 ]; then
    cat << 'EOF'
Usage: ./integrate_ai.sh <binary>

This example shows:
1. How to source the AI module
2. How to keep existing functions
3. How to add AI capabilities

Try:
  ./integrate_ai.sh /bin/ls
EOF
    exit 1
fi

# Run enhanced analysis
analyze_target_with_ai "$1"

echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Integration complete!${NC}"
echo ""
echo "Key points:"
echo "  1. Source AI module: source lib/ai_module.sh"
echo "  2. Use AI functions: ai_analyze, ai_rop, ai_reverse"
echo "  3. Integrate seamlessly with existing code"
echo ""
echo "Your prompt is saved to: /tmp/ai_prompts/"
