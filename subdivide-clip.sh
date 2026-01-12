#!/bin/bash

# subdivide-clip.sh - Re-split a problematic clip that contains multiple voice lines
#
# Usage: ./subdivide-clip.sh <clip-file>
#
# Example:
#   ./subdivide-clip.sh sounds/marine/clip_007.wav
#
# The script will:
#   1. Detect silence gaps using progressively aggressive thresholds
#   2. Split into sub-clips (clip_007.wav → clip_007a.wav, clip_007b.wav, etc.)
#   3. Remove the original file

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parameters
MIN_SILENCE_DURATION="0.3"
MIN_CLIP_DURATION="0.3"

# Thresholds to try (progressively more aggressive)
THRESHOLDS=("-25dB" "-20dB" "-15dB" "-10dB")

# Check dependencies
check_deps() {
    if ! command -v ffmpeg &>/dev/null; then
        echo -e "${RED}Missing dependency: ffmpeg${NC}"
        echo "Install with: brew install ffmpeg"
        exit 1
    fi
    if ! command -v bc &>/dev/null; then
        echo -e "${RED}Missing dependency: bc${NC}"
        echo "Install with: brew install bc"
        exit 1
    fi
}

# Usage info
usage() {
    echo "Usage: $0 <clip-file>"
    echo ""
    echo "Arguments:"
    echo "  clip-file    Audio file to subdivide (wav/mp3/aiff)"
    echo ""
    echo "Example:"
    echo "  $0 sounds/marine/clip_007.wav"
    echo ""
    echo "The script will:"
    echo "  1. Detect silence gaps using progressively aggressive thresholds"
    echo "  2. Split into sub-clips (clip_007a.wav, clip_007b.wav, etc.)"
    echo "  3. Remove the original file"
    exit 1
}

# Try silence detection at a given threshold, return number of splits found
try_threshold() {
    local input_file="$1"
    local threshold="$2"
    local tmp_dir="$3"

    # Run silence detection
    local silence_output
    silence_output=$(ffmpeg -i "$input_file" -af "silencedetect=noise=$threshold:d=$MIN_SILENCE_DURATION" -f null - 2>&1)

    # Parse silence_end timestamps
    echo "$silence_output" | grep "silence_end" | sed -n 's/.*silence_end: \([0-9.]*\).*/\1/p' > "$tmp_dir/silence_ends.txt"
    echo "$silence_output" | grep "silence_start" | sed -n 's/.*silence_start: \([0-9.]*\).*/\1/p' > "$tmp_dir/silence_starts.txt"

    # Count silence gaps (potential split points)
    local num_gaps
    num_gaps=$(wc -l < "$tmp_dir/silence_ends.txt" | tr -d ' ')

    echo "$num_gaps"
}

# Main
check_deps

if [ $# -lt 1 ]; then
    usage
fi

INPUT_FILE="$1"

if [ ! -f "$INPUT_FILE" ]; then
    echo -e "${RED}Error: File not found: $INPUT_FILE${NC}"
    exit 1
fi

# Extract base name for output files (e.g., clip_007 from clip_007.wav)
INPUT_DIR=$(dirname "$INPUT_FILE")
INPUT_BASENAME=$(basename "$INPUT_FILE")
INPUT_EXT="${INPUT_BASENAME##*.}"
INPUT_NAME="${INPUT_BASENAME%.*}"

TMP_DIR=$(mktemp -d)

# Get total duration
DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$INPUT_FILE")
echo -e "${YELLOW}Analyzing: $INPUT_FILE (${DURATION}s)${NC}"

# Try each threshold until we find splits
FOUND_SPLITS=0
USED_THRESHOLD=""

for threshold in "${THRESHOLDS[@]}"; do
    num_gaps=$(try_threshold "$INPUT_FILE" "$threshold" "$TMP_DIR")

    # We need at least 2 gaps to have a split (gap before first clip, gap between clips)
    # Actually, we need silence_end entries which mark clip starts
    # If we have > 1 silence_end, we have multiple clips
    if [ "$num_gaps" -gt 1 ]; then
        echo "  Found $num_gaps segments at threshold $threshold"
        FOUND_SPLITS=1
        USED_THRESHOLD="$threshold"
        break
    else
        echo "  Threshold $threshold: no splits found"
    fi
done

if [ "$FOUND_SPLITS" -eq 0 ]; then
    echo -e "${YELLOW}No silence gaps detected at any threshold.${NC}"
    echo "This clip may need manual splitting, or it's actually a single voice line."
    rm -rf "$TMP_DIR"
    exit 0
fi

# Build clip boundaries
tail -n +2 "$TMP_DIR/silence_starts.txt" > "$TMP_DIR/clip_ends.txt"
echo "$DURATION" >> "$TMP_DIR/clip_ends.txt"
cp "$TMP_DIR/silence_ends.txt" "$TMP_DIR/clip_starts.txt"

NUM_CLIPS=$(wc -l < "$TMP_DIR/clip_starts.txt" | tr -d ' ')
echo "Extracting $NUM_CLIPS sub-clips..."

# Letter suffix generator (a, b, c, ...)
LETTERS=(a b c d e f g h i j k l m n o p q r s t u v w x y z)
CLIP_INDEX=0
SAVED_COUNT=0

paste "$TMP_DIR/clip_starts.txt" "$TMP_DIR/clip_ends.txt" | while IFS=$'\t' read -r START END; do
    # Calculate duration
    CLIP_DURATION=$(echo "$END - $START" | bc -l)

    # Skip clips that are too short
    if [ "$(echo "$CLIP_DURATION < $MIN_CLIP_DURATION" | bc -l)" -eq 1 ]; then
        echo "  Skipping short segment (${CLIP_DURATION}s)"
        continue
    fi

    # Generate output filename with letter suffix
    SAVED_SO_FAR=$(ls "$INPUT_DIR/${INPUT_NAME}"[a-z]*."${INPUT_EXT}" 2>/dev/null | wc -l | tr -d ' ')
    LETTER_INDEX=$((SAVED_SO_FAR))
    if [ "$LETTER_INDEX" -ge 26 ]; then
        echo -e "${RED}Error: Too many sub-clips (>26)${NC}"
        break
    fi
    LETTER="${LETTERS[$LETTER_INDEX]}"
    OUTPUT_FILE="$INPUT_DIR/${INPUT_NAME}${LETTER}.${INPUT_EXT}"

    # Extract and normalize clip
    ffmpeg -y -i "$INPUT_FILE" -ss "$START" -to "$END" \
        -af "loudnorm=I=-16:TP=-1.5:LRA=11" \
        -ar 44100 \
        "$OUTPUT_FILE" 2>/dev/null

    DURATION_DISPLAY=$(printf "%.1f" "$CLIP_DURATION")
    echo -e "  ${GREEN}Created: $(basename "$OUTPUT_FILE") (${DURATION_DISPLAY}s)${NC}"
done

# Count created files
CREATED_COUNT=$(ls "$INPUT_DIR/${INPUT_NAME}"[a-z]*."${INPUT_EXT}" 2>/dev/null | wc -l | tr -d ' ')

if [ "$CREATED_COUNT" -gt 0 ]; then
    # Remove original
    rm "$INPUT_FILE"
    echo -e "${GREEN}Subdivided into $CREATED_COUNT clips, removed original${NC}"
else
    echo -e "${YELLOW}No clips created (all segments too short?), original preserved${NC}"
fi

# Clean up
rm -rf "$TMP_DIR"
