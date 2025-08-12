#!/bin/bash
set -e

echo "🗑️ Uninstalling sessions hooks for Claude Code..."

# Define paths
HOOKS_DIR="$HOME/.claude/hooks"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"

# Remove hooks from Claude settings
if [ -f "$CLAUDE_SETTINGS" ]; then
    # Check if jq is available
    if command -v jq &> /dev/null; then
        echo "📝 Removing session hooks from Claude settings..."
        
        # Backup existing settings
        cp "$CLAUDE_SETTINGS" "$CLAUDE_SETTINGS.backup"
        
        # Remove all session hooks from SessionStart and Stop events
        jq '
        if .hooks then
          # Process SessionStart hooks - remove session-start-hook entries
          if .hooks.SessionStart then
            .hooks.SessionStart = [
              .hooks.SessionStart[] | 
              .hooks = [.hooks[] | select(.command | contains("session-start-hook") | not)] |
              select(.hooks | length > 0)
            ]
          else . end |
          
          # Process Stop hooks - remove stop-hook entries
          if .hooks.Stop then
            .hooks.Stop = [
              .hooks.Stop[] | 
              .hooks = [.hooks[] | select(.command | contains("stop-hook") | not)] |
              select(.hooks | length > 0)
            ]
          else . end |
          
          # Clean up empty arrays
          if .hooks.SessionStart == [] then del(.hooks.SessionStart) else . end |
          if .hooks.Stop == [] then del(.hooks.Stop) else . end |
          
          # Remove hooks object if empty
          if .hooks == {} then del(.hooks) else . end
        else . end
        ' "$CLAUDE_SETTINGS" > "$CLAUDE_SETTINGS.tmp"
        
        if [ -s "$CLAUDE_SETTINGS.tmp" ]; then
            mv "$CLAUDE_SETTINGS.tmp" "$CLAUDE_SETTINGS"
            echo "✅ Removed session hooks from Claude settings"
        else
            echo "⚠️  Error updating settings. Backup saved at $CLAUDE_SETTINGS.backup"
            rm -f "$CLAUDE_SETTINGS.tmp"
        fi
    else
        echo "⚠️  jq not found. Please manually remove hooks from $CLAUDE_SETTINGS"
        echo "    Install jq: brew install jq (macOS) or apt-get install jq (Linux)"
    fi
else
    echo "ℹ️  No Claude settings file found"
fi

# Remove hook files
echo "📦 Removing hook files..."
if [ -d "$HOOKS_DIR" ]; then
    if [ -f "$HOOKS_DIR/session-start-hook" ]; then
        rm -f "$HOOKS_DIR/session-start-hook"
        echo "✅ Removed session-start-hook"
    fi
    
    if [ -f "$HOOKS_DIR/stop-hook" ]; then
        rm -f "$HOOKS_DIR/stop-hook"
        echo "✅ Removed stop-hook"
    fi
    
    # Remove hooks directory if empty
    if [ -z "$(ls -A "$HOOKS_DIR" 2>/dev/null)" ]; then
        rmdir "$HOOKS_DIR"
        echo "✅ Removed empty hooks directory"
    else
        echo "ℹ️  Other hooks remain in $HOOKS_DIR"
    fi
else
    echo "ℹ️  No hooks directory found"
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
echo ""
echo "To reinstall, run: just install"