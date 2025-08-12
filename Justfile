set positional-arguments := true

# Default recipe - show available commands
default:
    @just --list

# Build the project in release mode
build:
    cargo build --release

# Build the project in debug mode
build-debug:
    cargo build

# Run all tests
test:
    cargo test --verbose

# Run tests with a specific filter
test-filter filter:
    cargo test {{filter}} --verbose

# Format code
fmt:
    cargo fmt

# Check formatting without making changes
fmt-check:
    cargo fmt -- --check

# Run clippy linter
lint:
    cargo clippy -- -D warnings

# Run all checks (format, lint, test)
check: fmt-check lint test

# Clean build artifacts
clean:
    cargo clean

# Install hooks locally
install: build
    ./scripts/install-local.sh

# Uninstall hooks
uninstall:
    #!/bin/bash
    set -e
    HOOKS_DIR="$HOME/.claude/hooks"
    echo "🗑️  Uninstalling session-count hooks..."
    rm -f "$HOOKS_DIR/session-start-hook" "$HOOKS_DIR/stop-hook"
    echo "✅ Hooks uninstalled"
    echo "ℹ️  Config file preserved at ~/.session-count.json"

# Test installed hooks
test-hooks:
    #!/bin/bash
    set -e
    HOOKS_DIR="$HOME/.claude/hooks"
    if [ -f "$HOOKS_DIR/session-start-hook" ]; then
        echo "Testing session-start-hook..."
        "$HOOKS_DIR/session-start-hook"
        echo ""
        echo "Testing stop-hook (silent)..."
        "$HOOKS_DIR/stop-hook"
        echo "✅ Hooks are working"
    else
        echo "❌ Hooks not installed. Run 'just install' first."
        exit 1
    fi

# Run the session-start binary directly
run-start:
    ./target/release/session-start

# Run the session-stop binary directly
run-stop:
    ./target/release/session-stop

# Watch for changes and rebuild
watch:
    cargo watch -x build

# Create a new release tag
release version:
    #!/bin/bash
    set -e
    echo "Creating release {{version}}..."
    git tag -a "v{{version}}" -m "Release v{{version}}"
    git push origin "v{{version}}"
    echo "✅ Release v{{version}} created"

# Run development server for Vercel
dev:
    vercel dev

# Deploy to Vercel production
deploy:
    vercel --prod

# Show current session count
status:
    #!/bin/bash
    if [ -f "$HOME/.session-count.json" ]; then
        cat "$HOME/.session-count.json" | jq .
    else
        echo "No session count file found"
    fi

# Reset session count
reset:
    #!/bin/bash
    set -e
    rm -f "$HOME/.session-count.json"
    echo "✅ Session count reset"

# Run all CI checks locally
ci: check build
    @echo "✅ All CI checks passed!"