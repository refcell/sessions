export default function handler(req, res) {
  const script = `#!/bin/bash
set -e

echo "🗑️  Uninstalling sessions hooks..."

HOOKS_DIR="$HOME/.claude/hooks"
CONFIG_FILE="$HOME/.sessions.json"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"

# Remove hooks from Claude settings
if [ -f "$CLAUDE_SETTINGS" ]; then
  echo "📝 Updating Claude settings..."
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
REMOVED=0

if [ -f "$HOOKS_DIR/session-start-hook" ]; then
  # Check if it's our sessions hook
  if file "$HOOKS_DIR/session-start-hook" | grep -q "ELF\\|Mach-O" || 
     strings "$HOOKS_DIR/session-start-hook" 2>/dev/null | grep -q "sessions"; then
    rm -f "$HOOKS_DIR/session-start-hook"
    echo "✅ Removed session-start-hook"
    REMOVED=$((REMOVED + 1))
  else
    echo "⚠️  session-start-hook exists but doesn't appear to be sessions. Skipping."
  fi
fi

if [ -f "$HOOKS_DIR/stop-hook" ]; then
  # Check if it's our sessions hook  
  if file "$HOOKS_DIR/stop-hook" | grep -q "ELF\\|Mach-O" ||
     strings "$HOOKS_DIR/stop-hook" 2>/dev/null | grep -q "sessions"; then
    rm -f "$HOOKS_DIR/stop-hook"
    echo "✅ Removed stop-hook"
    REMOVED=$((REMOVED + 1))
  else
    echo "⚠️  stop-hook exists but doesn't appear to be sessions. Skipping."
  fi
fi

# Ask about removing config file
if [ -f "$CONFIG_FILE" ]; then
  echo ""
  read -p "Remove session count data file (~/.sessions.json)? [y/N] " -n 1 -r
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -f "$CONFIG_FILE"
    echo "✅ Removed session count data"
  else
    echo "ℹ️  Keeping session count data at $CONFIG_FILE"
  fi
fi

if [ $REMOVED -eq 0 ]; then
  echo "ℹ️  No sessions hooks found to remove"
else
  echo ""
  echo "✅ Session-count hooks uninstalled successfully!"
fi

echo ""
echo "To reinstall, run:"
echo "  curl -sSL sessions.refcell.org/install | bash"
`;

  res.setHeader('Content-Type', 'text/plain');
  res.status(200).send(script);
}