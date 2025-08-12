export default function handler(req, res) {
  const script = `#!/bin/bash
set -e

echo "📊 Installing sessions hooks for Claude Code..."

# Check if Claude Code is installed
if [ ! -d "$HOME/.claude" ]; then
  echo "❌ Claude Code not found. Please install Claude Code first."
  echo "   Visit: https://claude.ai/code"
  exit 1
fi

# Detect OS and architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$OS" in
    linux)
        PLATFORM="x86_64-unknown-linux-gnu"
        ;;
    darwin)
        if [ "$ARCH" = "arm64" ]; then
            PLATFORM="aarch64-apple-darwin"
        else
            PLATFORM="x86_64-apple-darwin"
        fi
        ;;
    *)
        echo "❌ Unsupported OS: $OS"
        exit 1
        ;;
esac

# Create temp directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

cd "$TEMP_DIR"

# Get latest release
echo "⬇️  Downloading sessions for $PLATFORM..."
LATEST_RELEASE=$(curl -s https://api.github.com/repos/refcell/sessions/releases/latest | grep "tag_name" | cut -d '"' -f 4)

if [ -z "$LATEST_RELEASE" ]; then
  echo "❌ Could not fetch latest release. Building from source..."
  
  # Clone and build from source
  git clone https://github.com/refcell/sessions.git
  cd sessions
  
  if ! command -v cargo &> /dev/null; then
    echo "❌ Rust/Cargo not found. Please install Rust first:"
    echo "   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    exit 1
  fi
  
  cargo build --release
  cd ..
  cp sessions/target/release/session-start .
  cp sessions/target/release/session-stop .
else
  DOWNLOAD_URL="https://github.com/refcell/sessions/releases/download/\${LATEST_RELEASE}/sessions-\${PLATFORM}.tar.gz"
  
  if ! curl -L -f -o sessions.tar.gz "$DOWNLOAD_URL" 2>/dev/null; then
    echo "⚠️  Pre-built binary not available. Building from source..."
    
    # Clone and build from source
    git clone https://github.com/refcell/session-count.git
    cd session-count
    
    if ! command -v cargo &> /dev/null; then
      echo "❌ Rust/Cargo not found. Please install Rust first:"
      echo "   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
      exit 1
    fi
    
    cargo build --release
    cd ..
    cp session-count/target/release/session-start .
    cp session-count/target/release/session-stop .
  else
    tar xzf sessions.tar.gz
  fi
fi

# Install hooks
HOOKS_DIR="$HOME/.claude/hooks"
mkdir -p "$HOOKS_DIR"

echo "📦 Installing hooks..."
cp session-start "$HOOKS_DIR/sessions-hook-start"
cp session-stop "$HOOKS_DIR/sessions-hook-stop"
chmod +x "$HOOKS_DIR/sessions-hook-start" "$HOOKS_DIR/sessions-hook-stop"

# Update Claude settings file
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
echo "📝 Updating Claude settings..."

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "⚠️  jq not found. Installing hooks manually may be required."
    echo "   Install jq for automatic configuration:"
    echo "   On macOS: brew install jq"
    echo "   On Ubuntu/Debian: sudo apt-get install jq"
else
    # Initialize settings file if it doesn't exist
    if [ ! -f "$CLAUDE_SETTINGS" ] || [ ! -s "$CLAUDE_SETTINGS" ]; then
        echo '{"hooks": {}}' > "$CLAUDE_SETTINGS"
    fi
    
    # Backup existing settings
    cp "$CLAUDE_SETTINGS" "$CLAUDE_SETTINGS.backup"
    
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
    
    # Add SessionStart hooks for different matchers
    add_session_hook "SessionStart" "startup" "$HOOKS_DIR/sessions-hook-start"
    add_session_hook "SessionStart" "resume" "$HOOKS_DIR/sessions-hook-start"
    add_session_hook "SessionStart" "clear" "$HOOKS_DIR/sessions-hook-start"
    
    # Add Stop hook
    add_session_hook "Stop" "" "$HOOKS_DIR/sessions-hook-stop"
fi

# Test installation
echo "🧪 Testing installation..."
if "$HOOKS_DIR/sessions-hook-start" >/dev/null 2>&1; then
  echo "✅ Session-count hooks installed successfully!"
  echo ""
  echo "📊 Hooks are now tracking active sessions in ~/.sessions.json"
  echo "📝 Claude settings updated at: $CLAUDE_SETTINGS"
  echo ""
  echo "To uninstall, run:"
  echo "  curl -sSL sessions.refcell.org/uninstall | bash"
else
  echo "⚠️  Installation completed but test failed. Please check the hooks manually."
fi
`;

  res.setHeader('Content-Type', 'text/plain');
  res.status(200).send(script);
}