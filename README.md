# session-count

A minimal session counter hook for Claude Code that tracks active sessions.

## Features

- 📊 Displays active session count on startup
- 🔒 Thread-safe concurrent access handling  
- 🦀 Written in Rust for performance and reliability
- 📁 Stores count in `~/.session-count.json`

## Quick Install

```bash
# Install with one command
curl -sSL session-count.refcell.org/install | bash

# Test installation
curl -sSL session-count.refcell.org/test | bash

# Uninstall
curl -sSL session-count.refcell.org/uninstall | bash
```

## Manual Installation

```bash
# Build from source
cargo build --release

# Install hooks
mkdir -p ~/.claude/hooks
cp target/release/session-start ~/.claude/hooks/session-start-hook
cp target/release/session-stop ~/.claude/hooks/stop-hook
chmod +x ~/.claude/hooks/*
```

## Usage

Once installed, the hooks run automatically:
- **Session start**: Shows `📊 Active sessions: N`
- **Session stop**: Silently decrements counter

## Development

```bash
# Run tests
cargo test

# Build
cargo build --release

# Format
cargo fmt

# Lint
cargo clippy -- -D warnings
```

## Configuration

Session data stored in `~/.session-count.json`:
```json
{
  "count": 0,
  "last_updated": "2025-01-12T10:30:00Z",
  "sessions": []
}
```

## License

MIT
