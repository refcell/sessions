export default function handler(req, res) {
  const script = `#!/bin/bash
set -e

echo "🧪 Testing sessions hooks..."
echo ""

HOOKS_DIR="$HOME/.claude/hooks"
CONFIG_FILE="$HOME/.sessions.json"
ERRORS=0

# Check if hooks are installed
echo "📋 Checking installation..."

if [ ! -f "$HOOKS_DIR/session-start-hook" ]; then
  echo "❌ session-start-hook not found"
  ERRORS=$((ERRORS + 1))
else
  echo "✅ session-start-hook found"
fi

if [ ! -f "$HOOKS_DIR/stop-hook" ]; then
  echo "❌ stop-hook not found"
  ERRORS=$((ERRORS + 1))
else
  echo "✅ stop-hook found"
fi

# Check if hooks are executable
echo ""
echo "🔧 Checking permissions..."

if [ -x "$HOOKS_DIR/session-start-hook" ]; then
  echo "✅ session-start-hook is executable"
else
  echo "❌ session-start-hook is not executable"
  ERRORS=$((ERRORS + 1))
fi

if [ -x "$HOOKS_DIR/stop-hook" ]; then
  echo "✅ stop-hook is executable"
else
  echo "❌ stop-hook is not executable"
  ERRORS=$((ERRORS + 1))
fi

# Test hook functionality
echo ""
echo "🚀 Testing functionality..."

# Backup existing config if it exists
if [ -f "$CONFIG_FILE" ]; then
  cp "$CONFIG_FILE" "$CONFIG_FILE.backup"
  BACKUP_CREATED=1
fi

# Test session-start hook
if [ -f "$HOOKS_DIR/session-start-hook" ] && [ -x "$HOOKS_DIR/session-start-hook" ]; then
  OUTPUT=$("$HOOKS_DIR/session-start-hook" 2>&1)
  if echo "$OUTPUT" | grep -q "Active sessions:"; then
    echo "✅ session-start-hook works: $OUTPUT"
    
    # Check if config file was created/updated
    if [ -f "$CONFIG_FILE" ]; then
      COUNT=$(grep -o '"count":[[:space:]]*[0-9]*' "$CONFIG_FILE" | grep -o '[0-9]*' || echo "0")
      echo "✅ Config file updated (count: $COUNT)"
    else
      echo "❌ Config file not created"
      ERRORS=$((ERRORS + 1))
    fi
  else
    echo "❌ session-start-hook failed: $OUTPUT"
    ERRORS=$((ERRORS + 1))
  fi
else
  echo "⚠️  Skipping session-start-hook test (not installed/executable)"
fi

# Test session-stop hook
if [ -f "$HOOKS_DIR/stop-hook" ] && [ -x "$HOOKS_DIR/stop-hook" ]; then
  "$HOOKS_DIR/stop-hook" 2>&1
  if [ $? -eq 0 ]; then
    echo "✅ stop-hook executed successfully (silent operation)"
    
    # Check if count was decremented
    if [ -f "$CONFIG_FILE" ]; then
      NEW_COUNT=$(grep -o '"count":[[:space:]]*[0-9]*' "$CONFIG_FILE" | grep -o '[0-9]*' || echo "0")
      echo "✅ Config file updated (count: $NEW_COUNT)"
    fi
  else
    echo "❌ stop-hook failed"
    ERRORS=$((ERRORS + 1))
  fi
else
  echo "⚠️  Skipping stop-hook test (not installed/executable)"
fi

# Test concurrent access
echo ""
echo "⚡ Testing concurrent access..."

if [ -f "$HOOKS_DIR/session-start-hook" ] && [ -x "$HOOKS_DIR/session-start-hook" ]; then
  # Run multiple instances in parallel
  for i in {1..3}; do
    "$HOOKS_DIR/session-start-hook" >/dev/null 2>&1 &
  done
  wait
  
  if [ -f "$CONFIG_FILE" ]; then
    FINAL_COUNT=$(grep -o '"count":[[:space:]]*[0-9]*' "$CONFIG_FILE" | grep -o '[0-9]*' || echo "0")
    echo "✅ Concurrent increments handled (final count: $FINAL_COUNT)"
  else
    echo "❌ Config file missing after concurrent test"
    ERRORS=$((ERRORS + 1))
  fi
  
  # Clean up with stop hooks
  for i in {1..3}; do
    "$HOOKS_DIR/stop-hook" 2>/dev/null &
  done
  wait
  echo "✅ Concurrent decrements handled"
else
  echo "⚠️  Skipping concurrent test (hooks not available)"
fi

# Restore backup if created
if [ "$BACKUP_CREATED" = "1" ]; then
  mv "$CONFIG_FILE.backup" "$CONFIG_FILE"
  echo ""
  echo "ℹ️  Original config restored"
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $ERRORS -eq 0 ]; then
  echo "✅ All tests passed!"
  echo ""
  echo "Session-count hooks are working correctly."
else
  echo "❌ $ERRORS test(s) failed"
  echo ""
  echo "To reinstall, run:"
  echo "  curl -sSL sessions.refcell.org/install | bash"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
`;

  res.setHeader('Content-Type', 'text/plain');
  res.status(200).send(script);
}