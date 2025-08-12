export default function handler(req, res) {
  const script = `#!/bin/bash
set -e

echo "🗑️  Uninstalling session-count hooks..."

HOOKS_DIR="$HOME/.claude/hooks"
CONFIG_FILE="$HOME/.session-count.json"

# Remove hook files
REMOVED=0

if [ -f "$HOOKS_DIR/session-start-hook" ]; then
  # Check if it's our session-count hook
  if file "$HOOKS_DIR/session-start-hook" | grep -q "ELF\\|Mach-O" || 
     strings "$HOOKS_DIR/session-start-hook" 2>/dev/null | grep -q "session-count"; then
    rm -f "$HOOKS_DIR/session-start-hook"
    echo "✅ Removed session-start-hook"
    REMOVED=$((REMOVED + 1))
  else
    echo "⚠️  session-start-hook exists but doesn't appear to be session-count. Skipping."
  fi
fi

if [ -f "$HOOKS_DIR/stop-hook" ]; then
  # Check if it's our session-count hook  
  if file "$HOOKS_DIR/stop-hook" | grep -q "ELF\\|Mach-O" ||
     strings "$HOOKS_DIR/stop-hook" 2>/dev/null | grep -q "session-count"; then
    rm -f "$HOOKS_DIR/stop-hook"
    echo "✅ Removed stop-hook"
    REMOVED=$((REMOVED + 1))
  else
    echo "⚠️  stop-hook exists but doesn't appear to be session-count. Skipping."
  fi
fi

# Ask about removing config file
if [ -f "$CONFIG_FILE" ]; then
  echo ""
  read -p "Remove session count data file (~/.session-count.json)? [y/N] " -n 1 -r
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -f "$CONFIG_FILE"
    echo "✅ Removed session count data"
  else
    echo "ℹ️  Keeping session count data at $CONFIG_FILE"
  fi
fi

if [ $REMOVED -eq 0 ]; then
  echo "ℹ️  No session-count hooks found to remove"
else
  echo ""
  echo "✅ Session-count hooks uninstalled successfully!"
fi

echo ""
echo "To reinstall, run:"
echo "  curl -sSL session-count.refcell.org/install | bash"
`;

  res.setHeader('Content-Type', 'text/plain');
  res.status(200).send(script);
}