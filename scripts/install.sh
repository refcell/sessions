#!/bin/bash
set -e

echo "Installing sessions hooks for Claude Code..."

# Detect OS and architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$OS" in
    linux)
        PLATFORM="x86_64-unknown-linux-gnu"
        ;;
    darwin)
        if [ "$ARCH" = "arm64" ]; then
            PLATFORM="aarch64-apple-darwin"
        else
            PLATFORM="x86_64-apple-darwin"
        fi
        ;;
    *)
        echo "Unsupported OS: $OS"
        exit 1
        ;;
esac

# Download latest release
LATEST_RELEASE=$(curl -s https://api.github.com/repos/refcell/sessions/releases/latest | grep "tag_name" | cut -d '"' -f 4)
DOWNLOAD_URL="https://github.com/refcell/sessions/releases/download/${LATEST_RELEASE}/sessions-${PLATFORM}.tar.gz"

echo "Downloading from: $DOWNLOAD_URL"

# Create temp directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Download and extract
curl -L -o sessions.tar.gz "$DOWNLOAD_URL"
tar xzf sessions.tar.gz

# Install hooks to their location
HOOKS_DIR="$HOME/.claude/hooks"
mkdir -p "$HOOKS_DIR"
cp session-start "$HOOKS_DIR/session-start-hook"
cp session-stop "$HOOKS_DIR/stop-hook"
chmod +x "$HOOKS_DIR"/*

# Update Claude settings file
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
mkdir -p "$(dirname "$CLAUDE_SETTINGS")"

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "❌ jq is required for safe hook installation. Please install jq first."
    echo "   On macOS: brew install jq"
    echo "   On Ubuntu/Debian: sudo apt-get install jq"
    exit 1
fi

# Initialize settings file if it doesn't exist
if [ ! -f "$CLAUDE_SETTINGS" ] || [ ! -s "$CLAUDE_SETTINGS" ]; then
    echo "{\"hooks\": {}}" > "$CLAUDE_SETTINGS"
fi

# Backup existing settings
cp "$CLAUDE_SETTINGS" "$CLAUDE_SETTINGS.backup"

# Function to add a hook entry (appends to existing hooks)
add_hook_entry() {
    local event="$1"
    local matcher="$2"
    local command="$3"
    
    # Add hook to the appropriate event and matcher
    jq --arg event "$event" \
       --arg matcher "$matcher" \
       --arg command "$command" \
       '
       # Ensure hooks object exists
       .hooks = (.hooks // {}) |
       
       # Ensure event array exists
       .hooks[$event] = (.hooks[$event] // []) |
       
       # Find existing matcher entry or create new one
       (.hooks[$event] | map(.matcher) | index($matcher)) as $idx |
       if $idx != null then
         # Matcher exists, append to its hooks if not already present
         .hooks[$event][$idx].hooks = (
           .hooks[$event][$idx].hooks | 
           if map(.command) | index($command) == null then
             . + [{"type": "command", "command": $command}]
           else . end
         )
       else
         # Matcher doesn\'t exist, add new entry
         .hooks[$event] += [{
           "matcher": $matcher,
           "hooks": [{"type": "command", "command": $command}]
         }]
       end
       ' "$CLAUDE_SETTINGS" > "$CLAUDE_SETTINGS.tmp" && mv "$CLAUDE_SETTINGS.tmp" "$CLAUDE_SETTINGS"
}

# Add SessionStart hooks for different matchers
echo "📝 Adding SessionStart hooks..."
add_hook_entry "SessionStart" "startup" "$HOOKS_DIR/session-start-hook"
add_hook_entry "SessionStart" "resume" "$HOOKS_DIR/session-start-hook"
add_hook_entry "SessionStart" "clear" "$HOOKS_DIR/session-start-hook"

# Add Stop hook
echo "📝 Adding Stop hook..."
add_hook_entry "Stop" "" "$HOOKS_DIR/stop-hook"

# Clean up
cd -
rm -rf "$TEMP_DIR"

echo "✅ Sessions hooks installed successfully!"
echo "📊 Hooks will track active sessions in ~/.sessions.json"
echo "📝 Claude settings updated at: $CLAUDE_SETTINGS"