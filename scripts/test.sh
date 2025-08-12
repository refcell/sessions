#!/bin/bash
set -e

echo "Testing sessions hooks for Claude Code..."
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Test function
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_result="$3"
    
    echo -n "Testing: $test_name... "
    
    if eval "$test_command"; then
        if [ "$expected_result" = "pass" ]; then
            echo -e "${GREEN}✓${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}✗ (expected to fail but passed)${NC}"
            ((TESTS_FAILED++))
        fi
    else
        if [ "$expected_result" = "fail" ]; then
            echo -e "${GREEN}✓ (correctly failed)${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}✗${NC}"
            ((TESTS_FAILED++))
        fi
    fi
}

# Check if hooks are installed
echo "=== Installation Tests ==="
run_test "Session start hook exists" "[ -f '$HOME/.claude/hooks/session-start-hook' ]" "pass"
run_test "Stop hook exists" "[ -f '$HOME/.claude/hooks/stop-hook' ]" "pass"
run_test "Session start hook is executable" "[ -x '$HOME/.claude/hooks/session-start-hook' ]" "pass"
run_test "Stop hook is executable" "[ -x '$HOME/.claude/hooks/stop-hook' ]" "pass"

# Check Claude settings
echo ""
echo "=== Settings Tests ==="
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
run_test "Claude settings file exists" "[ -f '$CLAUDE_SETTINGS' ]" "pass"

if [ -f "$CLAUDE_SETTINGS" ] && command -v jq &> /dev/null; then
    run_test "Settings contains session-start-hook" \
        "jq -e '.hooks[\"session-start-hook\"]' '$CLAUDE_SETTINGS' > /dev/null 2>&1" "pass"
    run_test "Settings contains stop-hook" \
        "jq -e '.hooks[\"stop-hook\"]' '$CLAUDE_SETTINGS' > /dev/null 2>&1" "pass"
    run_test "Session-start-hook path is correct" \
        "[ \"\$(jq -r '.hooks[\"session-start-hook\"]' '$CLAUDE_SETTINGS')\" = '$HOME/.claude/hooks/session-start-hook' ]" "pass"
    run_test "Stop-hook path is correct" \
        "[ \"\$(jq -r '.hooks[\"stop-hook\"]' '$CLAUDE_SETTINGS')\" = '$HOME/.claude/hooks/stop-hook' ]" "pass"
else
    echo -e "${YELLOW}⚠ Skipping settings content tests (jq not found or settings file missing)${NC}"
fi

# Test hook functionality
echo ""
echo "=== Functionality Tests ==="

# Backup existing sessions file if it exists
SESSIONS_FILE="$HOME/.sessions.json"
BACKUP_FILE=""
if [ -f "$SESSIONS_FILE" ]; then
    BACKUP_FILE="$SESSIONS_FILE.test_backup"
    cp "$SESSIONS_FILE" "$BACKUP_FILE"
fi

# Test session start hook
echo "{}" > "$SESSIONS_FILE"  # Start with empty sessions
"$HOME/.claude/hooks/session-start-hook" 2>/dev/null || true

if [ -f "$SESSIONS_FILE" ] && command -v jq &> /dev/null; then
    SESSION_COUNT=$(jq -r '.session_count // 0' "$SESSIONS_FILE" 2>/dev/null || echo "0")
    run_test "Session start hook increments counter" "[ '$SESSION_COUNT' -ge 1 ]" "pass"
    
    # Test stop hook
    "$HOME/.claude/hooks/stop-hook" 2>/dev/null || true
    ACTIVE_AFTER_STOP=$(jq -r '.active_sessions // 0' "$SESSIONS_FILE" 2>/dev/null || echo "0")
    run_test "Stop hook decrements active sessions" "[ '$ACTIVE_AFTER_STOP' -eq 0 ]" "pass"
else
    echo -e "${YELLOW}⚠ Skipping functionality tests (jq not found or sessions file missing)${NC}"
fi

# Restore backup if it existed
if [ -n "$BACKUP_FILE" ]; then
    mv "$BACKUP_FILE" "$SESSIONS_FILE"
fi

# Print summary
echo ""
echo "=== Test Summary ==="
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
else
    echo -e "Tests failed: $TESTS_FAILED"
fi

echo ""
if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some tests failed${NC}"
    exit 1
fi