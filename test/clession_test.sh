#!/usr/bin/env bash
set -uo pipefail

# Test harness for clession
# Runs without tmux attach or claude — tests CLI logic, config, and clone behavior

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLESSION="$SCRIPT_DIR/../bin/clession"
TEST_HOME=$(mktemp -d)
TEST_REPO=$(mktemp -d)
PASS=0
FAIL=0

# Override clession's paths and skip interactive preflight in tests
export HOME="$TEST_HOME"
export CLESSION_SKIP_PREFLIGHT=1

cleanup() {
    rm -rf "$TEST_HOME" "$TEST_REPO"
    echo ""
    echo "=============================="
    if [[ $FAIL -eq 0 ]]; then
        echo "ALL PASSED: $PASS tests"
    else
        echo "PASSED: $PASS  FAILED: $FAIL"
    fi
    echo "=============================="
    [[ $FAIL -eq 0 ]]
}
trap cleanup EXIT

# Set up git config in test HOME so preflight doesn't prompt
git config --global user.name "Test User"
git config --global user.email "test@example.com"

# Create a bare git repo to clone from
git init --bare "$TEST_REPO/origin.git" >/dev/null 2>&1
# Add an initial commit so the branch exists
_tmp=$(mktemp -d)
git clone "$TEST_REPO/origin.git" "$_tmp/work" >/dev/null 2>&1
git -C "$_tmp/work" commit --allow-empty -m "init" >/dev/null 2>&1
git -C "$_tmp/work" push origin main >/dev/null 2>&1
git -C "$_tmp/work" checkout -b dev >/dev/null 2>&1
git -C "$_tmp/work" commit --allow-empty -m "dev branch" >/dev/null 2>&1
git -C "$_tmp/work" push origin dev >/dev/null 2>&1
rm -rf "$_tmp"

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo "  PASS: $desc"
        ((PASS++)) || true
    else
        echo "  FAIL: $desc"
        echo "    expected: $expected"
        echo "    actual:   $actual"
        ((FAIL++)) || true
    fi
}

strip_ansi() { perl -pe 's/\e\[[0-9;]*m//g'; }

assert_contains() {
    local desc="$1" needle="$2" haystack="$3"
    if echo "$haystack" | strip_ansi | grep -qF -- "$needle" 2>/dev/null; then
        echo "  PASS: $desc"
        ((PASS++)) || true
    else
        echo "  FAIL: $desc"
        echo "    expected to contain: $needle"
        echo "    got: $haystack"
        ((FAIL++)) || true
    fi
}

assert_exit() {
    local desc="$1" expected_code="$2"
    shift 2
    local actual_code=0
    "$@" >/dev/null 2>&1 || actual_code=$?
    if [[ "$expected_code" -eq "$actual_code" ]]; then
        echo "  PASS: $desc"
        ((PASS++)) || true
    else
        echo "  FAIL: $desc"
        echo "    expected exit code: $expected_code"
        echo "    actual exit code:   $actual_code"
        ((FAIL++)) || true
    fi
}

# ─── Version & Help ──────────────────────────────────────────

echo "=== Version & Help ==="

output=$("$CLESSION" --version)
assert_contains "version output" "clession" "$output"

output=$("$CLESSION" --help)
assert_contains "help mentions start" "start" "$output"
assert_contains "help mentions doctor" "doctor" "$output"
assert_contains "help mentions config alias" "config alias" "$output"

# ─── Config Alias =============================================================

echo "=== Config Alias ==="

# list with no config
output=$("$CLESSION" config alias list 2>&1)
assert_contains "empty alias list" "No aliases" "$output"

# add alias
output=$("$CLESSION" config alias add myrepo "$TEST_REPO/origin.git" 2>&1)
assert_contains "add alias" "myrepo" "$output"

# get alias
output=$("$CLESSION" config alias get myrepo 2>&1)
assert_eq "get alias returns url" "$TEST_REPO/origin.git" "$output"

# list shows alias
output=$("$CLESSION" config alias list 2>&1)
assert_contains "list shows alias" "myrepo" "$output"

# duplicate name rejected
output=$("$CLESSION" config alias add myrepo "https://other.git" 2>&1 || true)
assert_contains "duplicate name rejected" "already exists" "$output"

# duplicate url rejected
output=$("$CLESSION" config alias add other "$TEST_REPO/origin.git" 2>&1 || true)
assert_contains "duplicate url rejected" "already aliased" "$output"

# add second alias
"$CLESSION" config alias add second "https://example.com/repo.git" >/dev/null 2>&1

# rm alias
output=$("$CLESSION" config alias rm second 2>&1)
assert_contains "rm alias" "removed" "$output"

# rm nonexistent
assert_exit "rm nonexistent alias fails" 1 "$CLESSION" config alias rm nope

# get nonexistent
assert_exit "get nonexistent alias fails" 1 "$CLESSION" config alias get nope

# ─── Config file format ──────────────────────────────────────

echo "=== Config File ==="

config_content=$(cat "$TEST_HOME/.clession/config")
assert_contains "config has [aliases] section" "[aliases]" "$config_content"
assert_contains "config has alias entry" "myrepo" "$config_content"

# ─── Start (clone only — skip tmux/claude) ════════════════════

echo "=== Start (clone logic) ==="

# We can't test full start (needs tmux + claude), but we can test
# argument validation and the clone step by mocking tmux

# missing session name
assert_exit "start with no args fails" 1 "$CLESSION" start

# missing --repo
output=$("$CLESSION" start testsess --base-branch main 2>&1 || true)
assert_contains "start without --repo errors" "--repo is required" "$output"

# missing --base-branch
output=$("$CLESSION" start testsess --repo foo 2>&1 || true)
assert_contains "start without --base-branch errors" "--base-branch is required" "$output"

# ─── List (empty) ════════════════════════════════════════════

echo "=== List ==="

output=$("$CLESSION" list 2>&1)
assert_contains "list empty" "No sessions" "$output"

# ─── Resume / Stop (nonexistent) ═════════════════════════════

echo "=== Resume / Stop (nonexistent) ==="

assert_exit "resume nonexistent fails" 1 "$CLESSION" resume nope
assert_exit "stop nonexistent fails" 1 "$CLESSION" stop nope

# ─── Simulate a session directory for list/stop ═══════════════

echo "=== List / Stop (with session dir) ==="

SESSION_DIR="$TEST_HOME/.clession/sessions/fakesess/repo"
mkdir -p "$SESSION_DIR"
git clone --branch main "$TEST_REPO/origin.git" "$SESSION_DIR" >/dev/null 2>&1 || {
    # If clone fails because dir exists, init instead
    git init "$SESSION_DIR" >/dev/null 2>&1
}

output=$("$CLESSION" list 2>&1)
assert_contains "list shows fake session" "fakesess" "$output"

# stop with 'n' should abort
output=$(echo "n" | "$CLESSION" stop fakesess 2>&1)
assert_contains "stop aborted" "Aborted" "$output"

# directory should still exist
if [[ -d "$TEST_HOME/.clession/sessions/fakesess" ]]; then
    assert_eq "session dir still exists after abort" "yes" "yes"
else
    assert_eq "session dir still exists after abort" "yes" "no"
fi

# stop with 'y' should remove
output=$(echo "y" | "$CLESSION" stop fakesess 2>&1)
assert_contains "stop confirmed" "stopped and removed" "$output"

# directory gone
if [[ ! -d "$TEST_HOME/.clession/sessions/fakesess" ]]; then
    assert_eq "session dir removed after stop" "yes" "yes"
else
    assert_eq "session dir removed after stop" "yes" "no"
fi

# ─── Alias resolution ════════════════════════════════════════

echo "=== Alias Resolution ==="

# start with alias should resolve (will fail at tmux but after clone)
# We test that the clone uses the resolved URL
mkdir -p "$TEST_HOME/.clession/sessions"

# Use a subshell to catch the clone step
output=$("$CLESSION" start aliasclone --repo myrepo --base-branch dev 2>&1 || true)
assert_contains "alias resolved in start" "Resolved alias" "$output"

# Check clone happened with right branch if it got that far
if [[ -d "$TEST_HOME/.clession/sessions/aliasclone/repo" ]]; then
    branch=$(git -C "$TEST_HOME/.clession/sessions/aliasclone/repo" branch --show-current 2>/dev/null || echo "")
    assert_eq "cloned on correct branch via alias" "dev" "$branch"
fi

# ─── Unknown command ═════════════════════════════════════════

echo "=== Error handling ==="

assert_exit "unknown command fails" 1 "$CLESSION" bogus
assert_exit "unknown config section fails" 1 "$CLESSION" config bogus
assert_exit "unknown alias subcommand fails" 1 "$CLESSION" config alias bogus
