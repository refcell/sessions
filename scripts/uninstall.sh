#!/bin/bash
set -e

echo "Uninstalling sessions hooks for Claude Code..."

# Define paths
HOOKS_DIR="$HOME/.claude/hooks"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"

if [ -f "$CLAUDE_SETTINGS" ]; then
    # Check if jq is available
    if command -v jq &> /dev/null; then
        echo "📝 Removing session hooks from Claude settings..."
        
        # Function to remove a specific hook command
        remove_hook_command() {
            local command="$1"
            
            jq --arg cmd "$command" '
            if .hooks then
              # Process SessionStart hooks
              if .hooks.SessionStart then
                .hooks.SessionStart = (.hooks.SessionStart | map(
                  .hooks = (.hooks | map(select(.command != $cmd))) |
                  if .hooks == [] then empty else . end
                ))
              else . end |
              
              # Process Stop hooks
              if .hooks.Stop then
                .hooks.Stop = (.hooks.Stop | map(
                  .hooks = (.hooks | map(select(.command != $cmd))) |
                  if .hooks == [] then empty else . end
                ))
              else . end |
              
              # Clean up empty arrays
              if .hooks.SessionStart == [] then del(.hooks.SessionStart) else . end |
              if .hooks.Stop == [] then del(.hooks.Stop) else . end |
              
              # Remove hooks object if empty
              if .hooks == {} then del(.hooks) else . end
            else . end
            ' "$CLAUDE_SETTINGS" > "$CLAUDE_SETTINGS.tmp" && mv "$CLAUDE_SETTINGS.tmp" "$CLAUDE_SETTINGS"
        }
        
        # Remove our specific hook commands
        remove_hook_command "$HOOKS_DIR/session-start-hook"
        remove_hook_command "$HOOKS_DIR/stop-hook"
        
        echo "✅ Removed session hooks from Claude settings"
    else
        echo "⚠️  jq not found. Please manually remove hooks from $CLAUDE_SETTINGS"
    fi
fi

# Remove hook files
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