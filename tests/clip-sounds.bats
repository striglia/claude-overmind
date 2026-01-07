#!/usr/bin/env bats
# Tests for clip-sounds.sh - dependency and argument checks only
# Note: We don't test actual audio processing - that requires ffmpeg and real audio files

load 'test_helper'

setup() {
    setup_test_env
}

teardown() {
    teardown_test_env
}

# --- Dependency Check Tests ---

@test "fails when ffmpeg is missing" {
    # Mock environment with no ffmpeg
    $REAL_MKDIR -p "$TEST_HOME/bin"
    export PATH="$TEST_HOME/bin:$PATH"

    run "$PROJECT_ROOT/clip-sounds.sh" marine "$TEST_HOME/input.wav"
    [ "$status" -ne 0 ]
    [[ "$output" == *"ffmpeg"* ]] || [[ "$output" == *"Missing"* ]]
}
