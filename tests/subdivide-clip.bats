#!/usr/bin/env bats
#
# Tests for subdivide-clip.sh - re-split problematic clips
#
# What we test:
# - Graceful handling when dependencies or files are missing
# - Input validation
# - Preserves original when no splits found
#
# What we don't test:
# - Actual audio splitting (would require real audio files with silence gaps)
# - ffmpeg behavior (mocked)

load 'test_helper'

setup() {
    setup_test_env
    mock_ffmpeg_subdivide
}

teardown() {
    teardown_test_env
}

# Mock ffmpeg to simulate silence detection
mock_ffmpeg_subdivide() {
    export PATH="$TEST_HOME/bin:$PATH"
    $REAL_MKDIR -p "$TEST_HOME/bin"

    # Mock ffmpeg that simulates no silence found
    $REAL_CAT > "$TEST_HOME/bin/ffmpeg" << 'EOF'
#!/bin/bash
# Mock ffmpeg - simulates silence detection with no results
echo "ffmpeg version mock"
exit 0
EOF
    $REAL_CHMOD +x "$TEST_HOME/bin/ffmpeg"

    # Mock ffprobe for duration
    $REAL_CAT > "$TEST_HOME/bin/ffprobe" << 'EOF'
#!/bin/bash
echo "5.0"
EOF
    $REAL_CHMOD +x "$TEST_HOME/bin/ffprobe"
}

# --- Input Validation ---

@test "shows usage when no arguments provided" {
    run "$PROJECT_ROOT/subdivide-clip.sh"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "exits with error when file not found" {
    run "$PROJECT_ROOT/subdivide-clip.sh" "/nonexistent/clip.wav"
    [ "$status" -eq 1 ]
    [[ "$output" == *"File not found"* ]]
}

# --- Graceful Degradation ---

@test "exits gracefully when no splits found" {
    # Create a test clip file
    $REAL_MKDIR -p "$TEST_HOME/sounds/marine"
    $REAL_TOUCH "$TEST_HOME/sounds/marine/clip_007.wav"

    run "$PROJECT_ROOT/subdivide-clip.sh" "$TEST_HOME/sounds/marine/clip_007.wav"
    [ "$status" -eq 0 ]
    [[ "$output" == *"no splits found"* ]] || [[ "$output" == *"No silence gaps"* ]]
    # Original should be preserved when no splits
    [ -f "$TEST_HOME/sounds/marine/clip_007.wav" ]
}

@test "preserves original file when no clips created" {
    $REAL_MKDIR -p "$TEST_HOME/sounds/zealot"
    $REAL_TOUCH "$TEST_HOME/sounds/zealot/clip_001.wav"

    run "$PROJECT_ROOT/subdivide-clip.sh" "$TEST_HOME/sounds/zealot/clip_001.wav"
    [ "$status" -eq 0 ]
    # Original preserved
    [ -f "$TEST_HOME/sounds/zealot/clip_001.wav" ]
}

# --- Output Naming ---

@test "displays correct usage information" {
    run "$PROJECT_ROOT/subdivide-clip.sh"
    [[ "$output" == *"clip_007a.wav"* ]] || [[ "$output" == *"sub-clips"* ]]
}
