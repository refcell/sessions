#!/bin/bash
set -e

echo "📊 Installing session-count hooks locally..."

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
echo "Config file: ~/.session-count.json"