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
    # Remove only sessions-specific hooks
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
      
      # Clean up empty arrays
      if .hooks.SessionStart == [] then del(.hooks.SessionStart) else . end |
      if .hooks.Stop == [] then del(.hooks.Stop) else . end |
      
      # Remove hooks object if empty
      if .hooks == {} then del(.hooks) else . end
    else . end
    ' "$CLAUDE_SETTINGS" > "$CLAUDE_SETTINGS.tmp"
    
    mv "$CLAUDE_SETTINGS.tmp" "$CLAUDE_SETTINGS"
    echo "✅ Removed sessions hooks from Claude settings"
  else
    echo "⚠️  jq not found. Please manually remove hooks from $CLAUDE_SETTINGS"
  fi
fi

# Remove hook files
REMOVED=0

if [ -f "$HOOKS_DIR/sessions-hook-start" ]; then
  rm -f "$HOOKS_DIR/sessions-hook-start"
  echo "✅ Removed sessions-hook-start"
  REMOVED=$((REMOVED + 1))
fi

if [ -f "$HOOKS_DIR/sessions-hook-stop" ]; then
  rm -f "$HOOKS_DIR/sessions-hook-stop"
  echo "✅ Removed sessions-hook-stop"
  REMOVED=$((REMOVED + 1))
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
  echo "✅ Sessions hooks uninstalled successfully!"
fi

echo ""
echo "To reinstall, run:"
echo "  curl -sSL sessions.refcell.org/install | bash"
`;

  res.setHeader('Content-Type', 'text/plain');
  res.status(200).send(script);
}