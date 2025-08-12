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
# Prerequisites: Rust and Just
# Install Just: cargo install just

# Build and install locally
just install

# Or if you don't have Just:
./scripts/install-local.sh
```

## Usage

Once installed, the hooks run automatically:
- **Session start**: Shows `📊 Active sessions: N`
- **Session stop**: Silently decrements counter

## Development

Requires [Just](https://github.com/casey/just) command runner:

```bash
# Show available commands
just

# Build release version
just build

# Run tests
just test

# Format code
just fmt

# Run linter
just lint

# Run all checks (format, lint, test)
just check

# Install hooks locally
just install

# Test installed hooks
just test-hooks

# Show current session count
just status

# Reset session count
just reset
```

### Common Tasks

```bash
# Run specific test
just test-filter test_name

# Clean build artifacts
just clean

# Create a new release
just release 0.2.0

# Deploy to Vercel
just deploy
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
