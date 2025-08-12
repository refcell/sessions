#!/bin/bash
set -e

echo "Uninstalling sessions hooks for Claude Code..."

# Remove hooks from Claude settings
CLAUDE_SETTINGS="$HOME/.claude/settings.json"

if [ -f "$CLAUDE_SETTINGS" ]; then
    # Check if jq is available
    if command -v jq &> /dev/null; then
        # Remove SessionStart and Stop hooks
        jq 'del(.hooks.SessionStart) | del(.hooks.Stop)' \
           "$CLAUDE_SETTINGS" > "$CLAUDE_SETTINGS.tmp"
        
        # Check if hooks object is empty and remove it if so
        jq 'if .hooks == {} then del(.hooks) else . end' \
           "$CLAUDE_SETTINGS.tmp" > "$CLAUDE_SETTINGS"
        
        rm -f "$CLAUDE_SETTINGS.tmp"
        echo "✅ Removed hooks from Claude settings"
    else
        echo "⚠️  jq not found. Please manually remove hooks from $CLAUDE_SETTINGS"
    fi
fi

# Remove hook files
HOOKS_DIR="$HOME/.claude/hooks"
if [ -d "$HOOKS_DIR" ]; then
    rm -f "$HOOKS_DIR/session-start-hook"
    rm -f "$HOOKS_DIR/stop-hook"
    
    # Remove hooks directory if empty
    if [ -z "$(ls -A "$HOOKS_DIR" 2>/dev/null)" ]; then
        rmdir "$HOOKS_DIR"
        echo "✅ Removed hooks directory"
    else
        echo "✅ Removed session hooks (other hooks remain)"
    fi
fi

# Optionally remove sessions data
echo ""
read -p "Do you want to remove sessions data (~/.sessions.json)? [y/N]: " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -f "$HOME/.sessions.json"
    echo "✅ Removed sessions data"
else
    echo "📊 Sessions data preserved at ~/.sessions.json"
fi

echo ""
echo "✅ Sessions hooks uninstalled successfully!"