#!/bin/bash
set -e

echo "Installing session-count hooks for Claude Code..."

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
        echo "Unsupported OS: $OS"
        exit 1
        ;;
esac

# Download latest release
LATEST_RELEASE=$(curl -s https://api.github.com/repos/andreasbigger/session-count/releases/latest | grep "tag_name" | cut -d '"' -f 4)
DOWNLOAD_URL="https://github.com/andreasbigger/session-count/releases/download/${LATEST_RELEASE}/session-count-${PLATFORM}.tar.gz"

echo "Downloading from: $DOWNLOAD_URL"

# Create temp directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Download and extract
curl -L -o session-count.tar.gz "$DOWNLOAD_URL"
tar xzf session-count.tar.gz

# Install hooks
HOOKS_DIR="$HOME/.claude/hooks"
mkdir -p "$HOOKS_DIR"

cp session-start "$HOOKS_DIR/session-start-hook"
cp session-stop "$HOOKS_DIR/stop-hook"
chmod +x "$HOOKS_DIR"/*

# Clean up
cd -
rm -rf "$TEMP_DIR"

echo "✅ Session-count hooks installed successfully!"
echo "📊 Hooks will track active sessions in ~/.session-count.json"