# 🤖 AI Extension Module

> Modular AI prompt generation for bug bounty research
> Integrates with any toolkit or use standalone

## Overview

The AI Extension Module is a **focused, modular add-on** that adds AI-assisted analysis to your security research workflow. It's designed to work standalone or integrate with existing toolkits.

### Design Philosophy

- **Modular**: Source it into any script
- **Lightweight**: Core functions only
- **Focused**: AI prompt generation, nothing else
- **Portable**: Works anywhere Bash runs
- **Privacy-first**: No external calls, local only

## Quick Start

### Method 1: CLI Tool (Fastest)

```bash
# Analyze a binary
ai analyze ./vulnerable_program

# Generate ROP strategy
ai rop ./target "call system"

# Reverse engineer a function
ai reverse ./binary main

# Custom analysis
ai custom ./app "heap exploitation" "How to exploit|Mitigations"
```

### Method 2: Source Module

```bash
# In your script
source /home/user/brew/lib/ai_module.sh

# Use functions
ai_analyze /path/to/binary
ai_rop /path/to/binary "Execute shellcode"
ai_reverse /path/to/binary vulnerable_function
```

### Method 3: Integrate with Existing Toolkit

```bash
# Add to your existing toolkit
source /home/user/brew/lib/ai_module.sh

# Add menu option:
echo "16) AI: Analyze Binary"

# In your case statement:
case $CHOICE in
    16)
        read -p "Binary: " BINARY
        ai_analyze "$BINARY"
        ;;
esac
```

## Installation

Already installed! Files are in:
- **Module**: `/home/user/brew/lib/ai_module.sh`
- **CLI**: `/home/user/brew/ai`
- **Templates**: `/home/user/brew/prompts/templates/`

### Make CLI accessible system-wide:

```bash
# Option 1: Add to PATH
export PATH="$PATH:/home/user/brew"
ai analyze ./binary  # Now works from anywhere!

# Option 2: Symlink
sudo ln -s /home/user/brew/ai /usr/local/bin/ai
ai analyze ./binary  # Works globally

# Option 3: Alias (add to ~/.bashrc)
alias ai='/home/user/brew/ai'
ai analyze ./binary
```

## Core Functions

### Context Gathering

```bash
# Get binary information
ai_gather_context <binary>

# Check security features
ai_check_security <binary>

# Get interesting strings
ai_get_strings <binary> [filter]

# Get functions
ai_get_functions <binary>

# Get imports
ai_get_imports <binary>

# Get disassembly
ai_get_disasm <binary> [function] [lines]

# Find ROP gadgets
ai_find_gadgets <binary> [count]
```

### Prompt Generators

```bash
# Buffer overflow analysis prompt
ai_prompt_buffer_overflow <binary>

# ROP chain strategy prompt
ai_prompt_rop <binary> [goal]

# Reverse engineering prompt
ai_prompt_reverse_engineering <binary> [function]

# Custom analysis prompt
ai_prompt_custom <binary> <focus> <questions>
```

### Output Functions

```bash
# Display prompt with formatting
ai_display_prompt <prompt> [title]

# Save prompt to file
ai_save_prompt <prompt> [filename]

# Copy to clipboard (if available)
ai_copy_clipboard <prompt>
```

### Quick Commands

```bash
# All-in-one: analyze and display
ai_analyze <binary>

# All-in-one: ROP strategy
ai_rop <binary> [goal]

# All-in-one: reverse engineering
ai_reverse <binary> [function]

# All-in-one: custom analysis
ai_custom <binary> <focus> <questions>
```

## Usage Examples

### Example 1: Quick Binary Analysis

```bash
#!/bin/bash
source lib/ai_module.sh

# Analyze a binary
ai_analyze /path/to/suspicious_binary

# Output is automatically saved and displayed
# Copy and paste to your AI assistant!
```

### Example 2: ROP Chain Strategy

```bash
#!/bin/bash
source lib/ai_module.sh

# Generate ROP chain prompt
ai_rop /path/to/binary "Execute system('/bin/sh')"

# Get detailed ROP construction guidance from AI
```

### Example 3: Custom Analysis

```bash
#!/bin/bash
source lib/ai_module.sh

# Build custom prompt
ai_custom /path/to/app \
    "heap exploitation" \
    "How to exploit this heap overflow?|What are the mitigations?|Best approach?"
```

### Example 4: Integration with Script

```bash
#!/bin/bash
# your_security_tool.sh

# Load AI module
source /home/user/brew/lib/ai_module.sh

# Your existing code...
analyze_target() {
    local target="$1"
    
    # Your analysis code
    echo "Analyzing $target..."
    
    # Add AI assistance
    echo "Generating AI analysis prompt..."
    local prompt=$(ai_prompt_buffer_overflow "$target")
    ai_save_prompt "$prompt" "analysis_${target##*/}.md"
    
    echo "AI prompt saved! Copy to your AI assistant."
}
```

### Example 5: Batch Processing

```bash
#!/bin/bash
source lib/ai_module.sh

# Analyze multiple binaries
for binary in /path/to/binaries/*; do
    echo "Processing: $binary"
    
    # Generate prompt
    prompt=$(ai_prompt_buffer_overflow "$binary")
    
    # Save with descriptive name
    filename="analysis_$(basename "$binary")_$(date +%s).md"
    ai_save_prompt "$prompt" "$filename"
done

echo "All prompts saved to /tmp/ai_prompts/"
```

## Advanced Usage

### Custom Template

Create your own template in `prompts/templates/my_template.txt`:

```markdown
# My Custom Analysis

## Binary: {{BINARY_PATH}}
## Architecture: {{ARCH}}

## Custom Analysis Request
Please analyze this {{ARCH}} binary and focus on:
1. {{CUSTOM_FOCUS_1}}
2. {{CUSTOM_FOCUS_2}}

{{CUSTOM_CONTEXT}}
```

Use it:

```bash
source lib/ai_module.sh

my_custom_prompt() {
    local binary="$1"
    local prompt=$(ai_load_template "my_template")
    
    # Replace placeholders
    prompt=$(ai_replace "$prompt" "BINARY_PATH" "$binary")
    prompt=$(ai_replace "$prompt" "ARCH" "$(file "$binary" | grep -oE 'x86-64|ARM')")
    prompt=$(ai_replace "$prompt" "CUSTOM_FOCUS_1" "Memory corruption")
    prompt=$(ai_replace "$prompt" "CUSTOM_FOCUS_2" "Integer overflows")
    prompt=$(ai_replace "$prompt" "CUSTOM_CONTEXT" "$(objdump -d "$binary" | head -50)")
    
    ai_display_prompt "$prompt" "Custom Analysis"
}

my_custom_prompt /path/to/binary
```

### Chaining Analyses

```bash
#!/bin/bash
source lib/ai_module.sh

comprehensive_analysis() {
    local binary="$1"
    local output_base="analysis_$(basename "$binary")"
    
    # Generate multiple prompts
    echo "Generating comprehensive AI analysis..."
    
    # 1. General analysis
    ai_save_prompt "$(ai_prompt_buffer_overflow "$binary")" "${output_base}_vuln.md"
    
    # 2. ROP strategy
    ai_save_prompt "$(ai_prompt_rop "$binary")" "${output_base}_rop.md"
    
    # 3. Function analysis
    for func in $(ai_get_functions "$binary" | head -5); do
        ai_save_prompt "$(ai_prompt_reverse_engineering "$binary" "$func")" \
            "${output_base}_${func}.md"
    done
    
    echo "✓ All prompts saved to /tmp/ai_prompts/"
    echo "Use them in sequence for complete analysis"
}

comprehensive_analysis /path/to/binary
```

### Integration with Existing Toolkit

Add to `/home/user/brew/interactive_bugbounty.sh`:

```bash
# At the top, source the module
source "${SCRIPT_DIR}/lib/ai_module.sh" 2>/dev/null

# Add to menu (around line 95):
echo -e "${BOLD}AI Extensions:${NC}"
echo -e "  ${PURPLE}16${NC}) AI: Quick Analysis Prompt"
echo -e "  ${PURPLE}17${NC}) AI: ROP Strategy Prompt"
echo -e "  ${PURPLE}18${NC}) AI: RE Assistant Prompt"

# Add to case statement (around line 550):
16)
    read -p "Binary path: " BINARY
    ai_analyze "$BINARY"
    read -p "Press Enter..."
    ;;
17)
    read -p "Binary path: " BINARY
    read -p "Goal: " GOAL
    ai_rop "$BINARY" "$GOAL"
    read -p "Press Enter..."
    ;;
18)
    read -p "Binary path: " BINARY
    read -p "Function: " FUNC
    ai_reverse "$BINARY" "$FUNC"
    read -p "Press Enter..."
    ;;
```

## Output Management

### Default Output Location

```bash
/tmp/ai_prompts/
```

### Custom Output Location

```bash
export AI_OUTPUT_DIR="/path/to/your/prompts"
source lib/ai_module.sh
```

### View Recent Prompts

```bash
# List recent prompts
ls -lt /tmp/ai_prompts/

# View a prompt
cat /tmp/ai_prompts/prompt_1234567890.md

# Search prompts
grep -l "buffer overflow" /tmp/ai_prompts/*.md
```

## CLI Reference

```bash
# Analyze binary
ai analyze <binary>
ai a <binary>              # Short form

# ROP strategy
ai rop <binary> [goal]
ai r <binary> [goal]       # Short form

# Reverse engineer
ai reverse <binary> [function]
ai rev <binary> [function] # Short form
ai re <binary> [function]  # Shortest form

# Custom analysis
ai custom <binary> <focus> <questions>
ai c <binary> <focus> <q>  # Short form

# Information
ai info                    # Module info
ai help                    # Usage help
```

## Templates

### Available Templates

1. **buffer_overflow_analysis.txt**
   - Comprehensive vulnerability analysis
   - Stack layout, offset calculations
   - Exploitation strategies

2. **rop_chain_generation.txt**
   - ROP chain construction
   - Gadget selection
   - Payload building

3. **reverse_engineering.txt**
   - Function analysis
   - Algorithm identification
   - Pseudocode generation

### Template Format

Templates use `{{PLACEHOLDER}}` syntax:

```markdown
# Analysis for {{BINARY_PATH}}

Architecture: {{ARCH}}
Security: {{NX_STATUS}}

{{CUSTOM_CONTENT}}
```

## Privacy & Security

**Local Processing Only:**
- ✅ No network requests
- ✅ No external API calls
- ✅ All data stays on your machine
- ✅ You control what to share with AI

**Best Practices:**
1. Review generated prompts before sharing
2. Redact sensitive paths if needed
3. Use for authorized research only
4. Follow bug bounty program rules

## Troubleshooting

### "Module not found"

```bash
# Check module exists
ls -l /home/user/brew/lib/ai_module.sh

# Use absolute path
source /home/user/brew/lib/ai_module.sh
```

### "Template not found"

```bash
# Check templates exist
ls /home/user/brew/prompts/templates/

# Verify template name (no .txt extension)
ai_load_template "buffer_overflow_analysis"  # Correct
ai_load_template "buffer_overflow_analysis.txt"  # Wrong
```

### "Binary not found"

```bash
# Use absolute path
ai_analyze /full/path/to/binary

# Or relative from current directory
cd /path/to/binaries
ai_analyze ./target
```

## Requirements

**Required:**
- Bash 4.0+
- Standard Unix tools (file, objdump, readelf, nm, strings)

**Optional:**
- xclip / pbcopy / termux-clipboard-set (for clipboard support)
- less (for paging)
- GDB (for enhanced analysis)
- ROPgadget (for better gadget finding)

## Architecture

```
lib/ai_module.sh                    # Core module (this file)
├── Core Functions
│   ├── ai_load_template()          # Load prompt templates
│   ├── ai_gather_context()         # Gather binary info
│   ├── ai_check_security()         # Security features
│   └── ai_get_*()                  # Various getters
├── Prompt Generators
│   ├── ai_prompt_buffer_overflow() # BOF analysis
│   ├── ai_prompt_rop()             # ROP strategy
│   ├── ai_prompt_reverse_*()       # RE assistance
│   └── ai_prompt_custom()          # Custom prompts
├── Output Functions
│   ├── ai_display_prompt()         # Display with formatting
│   ├── ai_save_prompt()            # Save to file
│   └── ai_copy_clipboard()         # Clipboard support
└── Quick Commands
    ├── ai_analyze()                # All-in-one analysis
    ├── ai_rop()                    # All-in-one ROP
    ├── ai_reverse()                # All-in-one RE
    └── ai_custom()                 # All-in-one custom

ai (CLI wrapper)                    # Command-line interface
prompts/templates/                  # Prompt templates
```

## Examples Directory

See more examples:
- `/home/user/brew/examples/ai_integration.sh`
- `/home/user/brew/examples/batch_analysis.sh`
- `/home/user/brew/examples/custom_template.sh`

## Version

Current version: **1.0**

## License

Part of the Bug Bounty Toolkit suite.
For educational and authorized security research only.

---

**Ready to enhance your security research with AI assistance!** 🤖🔒

Quick start: `ai analyze /path/to/binary`
