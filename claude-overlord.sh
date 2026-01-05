#!/bin/bash

# Claude Overlord - Starcraft notification sounds for Claude Code
# Plays character voice lines when hooks trigger

# Read hook input from stdin (JSON with session_id, hook_event_name, etc.)
read -r hook_input

# Check for jq dependency
if ! command -v jq &> /dev/null; then
  echo "jq is required but not installed. Run: brew install jq" >&2
  exit 0
fi

# Extract session_id for deterministic character assignment
session_id=$(echo "$hook_input" | jq -r '.session_id // "default"')

# Sound library location (can be overridden via env var)
SOUND_DIR="${CLAUDE_OVERLORD_SOUNDS:-$HOME/.claude/claude-overlord/sounds}"

# Exit gracefully if sounds directory doesn't exist
if [ ! -d "$SOUND_DIR" ]; then
  exit 0
fi

# Get list of character directories
characters=()
while IFS= read -r -d '' dir; do
  characters+=("$(basename "$dir")")
done < <(find "$SOUND_DIR" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)

if [ ${#characters[@]} -eq 0 ]; then
  exit 0
fi

# Hash session_id to pick a character (deterministic per-tab)
hash=$(echo -n "$session_id" | md5 | cut -c1-8)
char_index=$(( 16#$hash % ${#characters[@]} ))
character="${characters[$char_index]}"

# Collect all sound files from character directory
sounds=()
while IFS= read -r -d '' file; do
  sounds+=("$file")
done < <(find "$SOUND_DIR/$character" -maxdepth 1 -type f \( -name "*.wav" -o -name "*.mp3" -o -name "*.aiff" \) -print0 2>/dev/null)

if [ ${#sounds[@]} -eq 0 ]; then
  exit 0
fi

# Pick a random sound
sound_index=$((RANDOM % ${#sounds[@]}))
sound_file="${sounds[$sound_index]}"

# Play sound (non-blocking via &, afplay is macOS native)
afplay "$sound_file" &

exit 0
