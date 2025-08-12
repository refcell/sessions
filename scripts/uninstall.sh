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
        echo "📝 Removing sessions hooks from Claude settings..."
        
        # Backup existing settings
        cp "$CLAUDE_SETTINGS" "$CLAUDE_SETTINGS.backup"
        
        # Remove only sessions-specific hooks from SessionStart and Stop events
        jq '
        if .hooks then
          # Process SessionStart hooks - remove only sessions-hook-start entries
          if .hooks.SessionStart then
            .hooks.SessionStart = [
              .hooks.SessionStart[] | 
              .hooks = [.hooks[] | select(.command | contains("sessions-hook-start") | not)] |
              select(.hooks | length > 0)
            ]
          else . end |
          
          # Process Stop hooks - remove only sessions-hook-stop entries
          if .hooks.Stop then
            .hooks.Stop = [
              .hooks.Stop[] | 
              .hooks = [.hooks[] | select(.command | contains("sessions-hook-stop") | not)] |
              select(.hooks | length > 0)
            ]
          else . end |
          
          # Clean up empty arrays (only if completely empty)
          if .hooks.SessionStart == [] then del(.hooks.SessionStart) else . end |
          if .hooks.Stop == [] then del(.hooks.Stop) else . end |
          
          # Remove hooks object only if completely empty
          if .hooks == {} then del(.hooks) else . end
        else . end
        ' "$CLAUDE_SETTINGS" > "$CLAUDE_SETTINGS.tmp"
        
        if [ -s "$CLAUDE_SETTINGS.tmp" ]; then
            mv "$CLAUDE_SETTINGS.tmp" "$CLAUDE_SETTINGS"
            echo "✅ Removed sessions hooks from Claude settings"
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

# Remove hook files (only sessions-specific ones)
echo "📦 Removing sessions hook files..."
if [ -d "$HOOKS_DIR" ]; then
    if [ -f "$HOOKS_DIR/sessions-hook-start" ]; then
        rm -f "$HOOKS_DIR/sessions-hook-start"
        echo "✅ Removed sessions-hook-start"
    fi
    
    if [ -f "$HOOKS_DIR/sessions-hook-stop" ]; then
        rm -f "$HOOKS_DIR/sessions-hook-stop"
        echo "✅ Removed sessions-hook-stop"
    fi
    
    # Remove hooks directory only if empty
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