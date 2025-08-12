#!/bin/bash
set -e

echo "📊 Installing sessions hooks locally..."

# Check if binaries exist
if [ ! -f "target/release/session-start" ] || [ ! -f "target/release/session-stop" ]; then
    echo "❌ Release binaries not found. Please run 'just build' first."
    exit 1
fi

# Check if Claude Code is installed
if [ ! -d "$HOME/.claude" ]; then
    echo "⚠️  Claude Code directory not found. Creating ~/.claude/hooks..."
fi

# Create hooks directory
HOOKS_DIR="$HOME/.claude/hooks"
mkdir -p "$HOOKS_DIR"

# Install hooks
echo "📦 Installing hooks..."
cp target/release/session-start "$HOOKS_DIR/session-start-hook"
cp target/release/session-stop "$HOOKS_DIR/stop-hook"
chmod +x "$HOOKS_DIR/session-start-hook" "$HOOKS_DIR/stop-hook"

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
add_session_hook "SessionStart" "startup" "$HOOKS_DIR/session-start-hook"
add_session_hook "SessionStart" "resume" "$HOOKS_DIR/session-start-hook"
add_session_hook "SessionStart" "clear" "$HOOKS_DIR/session-start-hook"

echo "📝 Adding Stop hook..."
add_session_hook "Stop" "" "$HOOKS_DIR/stop-hook"

# Test installation
echo "🧪 Testing installation..."
if "$HOOKS_DIR/session-start-hook" >/dev/null 2>&1; then
    OUTPUT=$("$HOOKS_DIR/session-start-hook" 2>&1)
    echo "✅ Installation successful!"
    echo "   $OUTPUT"
else
    echo "⚠️  Installation completed but test failed."
fi

echo ""
echo "Hooks installed in: $HOOKS_DIR"
echo "Config file: ~/.sessions.json"
echo "Claude settings: $CLAUDE_SETTINGS"