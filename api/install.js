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
cp session-start "$HOOKS_DIR/session-start-hook"
cp session-stop "$HOOKS_DIR/stop-hook"
chmod +x "$HOOKS_DIR/session-start-hook" "$HOOKS_DIR/stop-hook"

# Test installation
echo "🧪 Testing installation..."
if "$HOOKS_DIR/session-start-hook" >/dev/null 2>&1; then
  echo "✅ Session-count hooks installed successfully!"
  echo ""
  echo "📊 Hooks are now tracking active sessions in ~/.sessions.json"
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