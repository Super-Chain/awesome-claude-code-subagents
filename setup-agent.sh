#!/bin/bash

# Setup script for awesome Claude Code subagents
# Usage: ./setup-agent.sh <category>/<agent-name>

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_error() {
    echo -e "${RED}Error: $1${NC}" >&2
}

print_success() {
    echo -e "${GREEN}Success: $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}Warning: $1${NC}"
}

print_info() {
    echo -e "$1"
}

# Show usage and available agents
show_usage() {
    echo "Usage: $0 <category>/<agent-name>"
    echo ""
    echo "Available agents:"
    for category_dir in categories/*/; do
        if [ -d "$category_dir" ]; then
            category=$(basename "$category_dir")
            echo "  $category:"
            for agent_file in "$category_dir"*.md; do
                if [ -f "$agent_file" ] && [ "$(basename "$agent_file")" != "README.md" ]; then
                    agent=$(basename "$agent_file" .md)
                    echo "    - $category/$agent"
                fi
            done
            echo ""
        fi
    done
}

# Check if agent path is provided
if [ $# -eq 0 ]; then
    print_error "Please provide the agent path as an argument"
    show_usage
    exit 1
fi

AGENT_PATH="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse category and agent name
if [[ "$AGENT_PATH" == *"/"* ]]; then
    CATEGORY=$(echo "$AGENT_PATH" | cut -d'/' -f1)
    AGENT_NAME=$(echo "$AGENT_PATH" | cut -d'/' -f2)
else
    print_error "Invalid agent path format. Use: <category>/<agent-name>"
    show_usage
    exit 1
fi

CATEGORY_DIR="$SCRIPT_DIR/categories/$CATEGORY"
AGENT_FILE="$CATEGORY_DIR/${AGENT_NAME}.md"
MCP_FILE="$SCRIPT_DIR/mcp/${AGENT_NAME}.json"

# Check if Claude CLI is installed
print_info "Checking Claude CLI installation..."
if ! command -v claude &> /dev/null; then
    print_error "Claude CLI is not installed or not in PATH"
    print_info "Please install Claude CLI first: https://github.com/anthropics/claude-code"
    exit 1
fi

print_success "Claude CLI is installed"

# Check if category directory exists
if [ ! -d "$CATEGORY_DIR" ]; then
    print_error "Category not found: $CATEGORY"
    show_usage
    exit 1
fi

# Check if agent file exists
if [ ! -f "$AGENT_FILE" ]; then
    print_error "Agent file not found: $AGENT_FILE"
    print_info "Available agents in $CATEGORY:"
    for agent_file in "$CATEGORY_DIR"*.md; do
        if [ -f "$agent_file" ] && [ "$(basename "$agent_file")" != "README.md" ]; then
            agent=$(basename "$agent_file" .md)
            echo "  - $agent"
        fi
    done
    exit 1
fi

# Create Claude agents directory if it doesn't exist
CLAUDE_AGENTS_DIR="$HOME/.claude/agents"
if [ ! -d "$CLAUDE_AGENTS_DIR" ]; then
    print_info "Creating Claude agents directory: $CLAUDE_AGENTS_DIR"
    mkdir -p "$CLAUDE_AGENTS_DIR"
fi

# Copy agent file
print_info "Copying agent file..."
cp "$AGENT_FILE" "$CLAUDE_AGENTS_DIR/"
print_success "Agent file copied to $CLAUDE_AGENTS_DIR/$(basename "$AGENT_FILE")"

# Handle MCP configuration if MCP file exists
if [ -f "$MCP_FILE" ]; then
    CURSOR_MCP_FILE="$HOME/.cursor/mcp.json"
    
    # Create .cursor directory if it doesn't exist
    if [ ! -d "$HOME/.cursor" ]; then
        print_info "Creating .cursor directory"
        mkdir -p "$HOME/.cursor"
    fi
    
    # Handle MCP configuration
    if [ ! -f "$CURSOR_MCP_FILE" ]; then
        print_info "Creating new MCP configuration file"
        cp "$MCP_FILE" "$CURSOR_MCP_FILE"
        print_success "MCP configuration created at $CURSOR_MCP_FILE"
    else
        print_info "Merging MCP configuration..."
        
        # Create a backup
        cp "$CURSOR_MCP_FILE" "$CURSOR_MCP_FILE.backup"
        print_info "Backup created at $CURSOR_MCP_FILE.backup"
        
        # Use jq to merge JSON files if available, otherwise manual merge
        if command -v jq &> /dev/null; then
            # Merge the mcpServers objects
            jq -s '.[0] * .[1]' "$CURSOR_MCP_FILE" "$MCP_FILE" > "$CURSOR_MCP_FILE.tmp"
            mv "$CURSOR_MCP_FILE.tmp" "$CURSOR_MCP_FILE"
            print_success "MCP configuration merged successfully"
        else
            print_warning "jq not found. Please manually merge the MCP configuration from:"
            print_info "  Source: $MCP_FILE"
            print_info "  Target: $CURSOR_MCP_FILE"
        fi
    fi
else
    print_info "No MCP configuration file found for this agent"
fi

print_success "Agent '$AGENT_NAME' from category '$CATEGORY' setup completed!"
print_info "Please restart Claude CLI to load the new agent:"
print_info "  exit"
print_info "  claude"