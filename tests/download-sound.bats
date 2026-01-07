#!/usr/bin/env bats
# Tests for download-sound.sh - dependency checks only
# Note: We don't test actual downloads - that would require yt-dlp and network access

load 'test_helper'

setup() {
    setup_test_env
}

teardown() {
    teardown_test_env
}

# --- Dependency Check Tests ---

@test "fails when yt-dlp is missing" {
    # Mock environment with no yt-dlp
    $REAL_MKDIR -p "$TEST_HOME/bin"
    export PATH="$TEST_HOME/bin:$PATH"

    run "$PROJECT_ROOT/download-sound.sh" marine "https://youtube.com/watch?v=test"
    [ "$status" -ne 0 ]
    [[ "$output" == *"yt-dlp"* ]] || [[ "$output" == *"Missing"* ]]
}

@test "fails when ffmpeg is missing" {
    # Mock environment with yt-dlp but no ffmpeg
    $REAL_MKDIR -p "$TEST_HOME/bin"
    $REAL_CAT > "$TEST_HOME/bin/yt-dlp" << 'EOF'
#!/bin/bash
exit 0
EOF
    $REAL_CHMOD +x "$TEST_HOME/bin/yt-dlp"
    export PATH="$TEST_HOME/bin:$PATH"

    run "$PROJECT_ROOT/download-sound.sh" marine "https://youtube.com/watch?v=test"
    [ "$status" -ne 0 ]
    [[ "$output" == *"ffmpeg"* ]] || [[ "$output" == *"Missing"* ]]
}
