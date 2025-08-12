#!/bin/bash
set -e

echo "Installing sessions hooks for Claude Code..."

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
LATEST_RELEASE=$(curl -s https://api.github.com/repos/refcell/sessions/releases/latest | grep "tag_name" | cut -d '"' -f 4)
DOWNLOAD_URL="https://github.com/refcell/sessions/releases/download/${LATEST_RELEASE}/sessions-${PLATFORM}.tar.gz"

echo "Downloading from: $DOWNLOAD_URL"

# Create temp directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Download and extract
curl -L -o sessions.tar.gz "$DOWNLOAD_URL"
tar xzf sessions.tar.gz

# Install hooks to their location
HOOKS_DIR="$HOME/.claude/hooks"
mkdir -p "$HOOKS_DIR"
cp session-start "$HOOKS_DIR/session-start-hook"
cp session-stop "$HOOKS_DIR/stop-hook"
chmod +x "$HOOKS_DIR"/*

# Update Claude settings file
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
mkdir -p "$(dirname "$CLAUDE_SETTINGS")"

# Check if settings file exists and has content
if [ -f "$CLAUDE_SETTINGS" ] && [ -s "$CLAUDE_SETTINGS" ]; then
    # Backup existing settings
    cp "$CLAUDE_SETTINGS" "$CLAUDE_SETTINGS.backup"
    
    # Update settings with new hooks using proper format
    jq --arg start "$HOOKS_DIR/session-start-hook" \
       --arg stop "$HOOKS_DIR/stop-hook" \
       '
       .hooks.SessionStart = [
         {
           "matcher": "startup",
           "hooks": [
             {
               "type": "command",
               "command": $start
             }
           ]
         },
         {
           "matcher": "resume",
           "hooks": [
             {
               "type": "command",
               "command": $start
             }
           ]
         },
         {
           "matcher": "clear",
           "hooks": [
             {
               "type": "command",
               "command": $start
             }
           ]
         }
       ] |
       .hooks.Stop = [
         {
           "matcher": "",
           "hooks": [
             {
               "type": "command",
               "command": $stop
             }
           ]
         }
       ]' \
       "$CLAUDE_SETTINGS" > "$CLAUDE_SETTINGS.tmp"
    mv "$CLAUDE_SETTINGS.tmp" "$CLAUDE_SETTINGS"
else
    # Create new settings file with hooks
    cat > "$CLAUDE_SETTINGS" <<EOF
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup",
        "hooks": [
          {
            "type": "command",
            "command": "$HOOKS_DIR/session-start-hook"
          }
        ]
      },
      {
        "matcher": "resume",
        "hooks": [
          {
            "type": "command",
            "command": "$HOOKS_DIR/session-start-hook"
          }
        ]
      },
      {
        "matcher": "clear",
        "hooks": [
          {
            "type": "command",
            "command": "$HOOKS_DIR/session-start-hook"
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "$HOOKS_DIR/stop-hook"
          }
        ]
      }
    ]
  }
}
EOF
fi

# Clean up
cd -
rm -rf "$TEMP_DIR"

echo "✅ Sessions hooks installed successfully!"
echo "📊 Hooks will track active sessions in ~/.sessions.json"
echo "📝 Claude settings updated at: $CLAUDE_SETTINGS"