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
cp session-start "$HOOKS_DIR/sessions-hook-start"
cp session-stop "$HOOKS_DIR/sessions-hook-stop"
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
    echo '{"hooks": {}}' > "$CLAUDE_SETTINGS"
fi

# Backup existing settings
cp "$CLAUDE_SETTINGS" "$CLAUDE_SETTINGS.backup"
echo "📝 Backed up settings to $CLAUDE_SETTINGS.backup"

# Function to add a hook to a specific event and matcher
add_session_hook() {
    local event="$1"
    local matcher="$2"
    local command="$3"
    
    # Read current settings, modify, and write back
    CURRENT=$(cat "$CLAUDE_SETTINGS")
    UPDATED=$(echo "$CURRENT" | jq \
        --arg event "$event" \
        --arg matcher "$matcher" \
        --arg command "$command" \
        '
        # Ensure hooks object exists
        .hooks = (.hooks // {}) |
        
        # Ensure event array exists
        .hooks[$event] = (.hooks[$event] // []) |
        
        # Find if matcher already exists
        .hooks[$event] as $eventHooks |
        ($eventHooks | map(.matcher == $matcher) | index(true)) as $index |
        
        # Update or add the matcher entry
        if $index then
            # Matcher exists, add to its hooks if not already there
            .hooks[$event][$index].hooks as $hooks |
            if ($hooks | map(.command) | index($command)) then
                .
            else
                .hooks[$event][$index].hooks += [{"type": "command", "command": $command}]
            end
        else
            # Matcher does not exist, add new entry
            .hooks[$event] += [{
                "matcher": $matcher,
                "hooks": [{"type": "command", "command": $command}]
            }]
        end
        ')
    
    echo "$UPDATED" > "$CLAUDE_SETTINGS"
}

echo "📝 Adding SessionStart hooks..."
add_session_hook "SessionStart" "startup" "$HOOKS_DIR/sessions-hook-start"
add_session_hook "SessionStart" "resume" "$HOOKS_DIR/sessions-hook-start"
add_session_hook "SessionStart" "clear" "$HOOKS_DIR/sessions-hook-start"

echo "📝 Adding Stop hook..."
add_session_hook "Stop" "" "$HOOKS_DIR/sessions-hook-stop"

# Clean up
cd -
rm -rf "$TEMP_DIR"

echo "✅ Sessions hooks installed successfully!"
echo "📊 Hooks will track active sessions in ~/.sessions.json"
echo "📝 Claude settings updated at: $CLAUDE_SETTINGS"