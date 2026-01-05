# Claude Overlord

Starcraft notification sounds for Claude Code sessions on macOS.

## Overview

Play Starcraft (Brood War / SC2) character voice lines when Claude Code needs attention. Each terminal tab gets a persistent "character" so you can recognize which agent is calling. Designed for managing 5-10 concurrent Claude Code sessions ("the swarm").

---

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Hook mechanism | Claude Code hooks | Native support via `Notification` and `Stop` events - no shell hacks needed |
| Trigger event | `idle_prompt` notification | Fires when Claude is waiting for user input (60+ seconds idle) |
| Overlap handling | Allow concurrent sounds | Authentic chaos, like a real SC battle - no queueing complexity |
| Character assignment | Per-tab via session_id hash | Deterministic: same session always gets same character, no state file needed |
| Sound sourcing | Curated starter pack + guide | Will provide sources for extracting/finding sounds |
| Muting | System volume | No custom toggle for v1 - just mute macOS when needed |
| Tab icons | Out of scope for v1 | Nice-to-have, adds complexity |

---

## Interview Insights

- **Primary use case**: Managing 5-10 concurrent Claude Code tabs, need audio cues to know which agent needs attention
- **"Minimal viable" scope**: Get sounds playing reliably first, polish later
- **Per-tab character is key**: Even with overlapping sounds, recognizing "that's the Marine tab" helps mental model
- **Chaos is acceptable**: Overlapping sounds are fine - adds to the Starcraft atmosphere

---

## Technical Design

### Hook Configuration

**File: `~/.claude/settings.json`** (or project-local `.claude/settings.json`)

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "idle_prompt",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/claude-overlord.sh",
            "timeout": 5
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/claude-overlord.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

### Sound Selector Script

**File: `~/.claude/hooks/claude-overlord.sh`**

```bash
#!/bin/bash

# Read hook input from stdin (JSON with session_id, hook_event_name, etc.)
read -r hook_input

# Extract session_id for deterministic character assignment
session_id=$(echo "$hook_input" | jq -r '.session_id // "default"')

# Sound library location
SOUND_DIR="${CLAUDE_OVERLORD_SOUNDS:-$HOME/.claude/claude-overlord/sounds}"

# Get list of character directories
characters=($(ls -d "$SOUND_DIR"/*/ 2>/dev/null | xargs -n1 basename))

if [ ${#characters[@]} -eq 0 ]; then
  echo "No sounds found in $SOUND_DIR" >&2
  exit 0
fi

# Hash session_id to pick a character (deterministic per-tab)
hash=$(echo -n "$session_id" | md5 | cut -c1-8)
char_index=$(( 16#$hash % ${#characters[@]} ))
character="${characters[$char_index]}"

# Pick a random sound from that character's directory
sounds=("$SOUND_DIR/$character"/*.{wav,mp3,aiff} 2>/dev/null)
sounds=(${sounds[@]})

if [ ${#sounds[@]} -eq 0 ]; then
  exit 0
fi

sound_index=$((RANDOM % ${#sounds[@]}))
sound_file="${sounds[$sound_index]}"

# Play sound (non-blocking via &, afplay is macOS native)
afplay "$sound_file" &

exit 0
```

### Directory Structure

```
~/.claude/
├── settings.json              # Hook configuration
├── hooks/
│   └── claude-overlord.sh     # Sound selector script
└── claude-overlord/
    └── sounds/
        ├── marine/
        │   ├── ready.wav
        │   ├── yes_sir.wav
        │   └── go_go_go.wav
        ├── zealot/
        │   ├── my_life_for_aiur.wav
        │   └── en_taro_adun.wav
        ├── zergling/
        │   └── (zergling sounds are just screeches)
        ├── battlecruiser/
        │   ├── battlecruiser_operational.wav
        │   └── set_a_course.wav
        └── ... (more characters)
```

---

## Sound Sourcing

### Option 1: Extract from Game Files (Recommended if you own the games)

**Starcraft Remastered / Brood War:**
- Sounds are in `.wav` format in the game's CASC archives
- Tool: [CascView](http://www.zezula.net/en/casc/main.html) can extract
- Path: `Sound/` directory contains unit responses

**Starcraft 2:**
- Sounds in CASC archives
- Tool: CascView or [SC2 Mapster tools](https://sc2mapster.gamepedia.com/)
- Higher quality audio, more voice lines

### Option 2: Fan Archives

- **SC Sounds Archive**: Various fan sites host extracted sounds
- **YouTube**: Many "all unit quotes" compilations - can use `yt-dlp` to download, then split
- **Liquipedia/Wiki**: Often link to sound files

### Option 3: Starter Pack (for v1)

For minimal viable, grab 10-15 iconic lines:
- Marine: "You want a piece of me, boy?"
- SCV: "SCV ready!" / "Yes sir?"
- Zealot: "My life for Aiur!"
- Carrier: "Carrier has arrived"
- Battlecruiser: "Battlecruiser operational"
- Hydralisk: (hissing sounds)
- Siege Tank: "Ready to roll out!"

---

## Edge Cases & Error Handling

| Scenario | Behavior | Rationale |
|----------|----------|-----------|
| No sounds directory | Silent exit (exit 0) | Don't break Claude Code if sounds missing |
| No sounds for character | Silent exit | Graceful degradation |
| afplay fails | Ignore (backgrounded) | Sound is non-critical |
| Very rapid notifications | All play (overlap) | User preference - let them stack |
| jq not installed | Script fails | Document as dependency |

---

## Implementation Plan

### Phase 1: Minimal Viable (v1)

1. **Create directory structure**
   - `~/.claude/hooks/`
   - `~/.claude/claude-overlord/sounds/`

2. **Write `claude-overlord.sh` script**
   - Parse JSON input for session_id
   - Hash-based character selection
   - Random sound from character directory
   - Non-blocking `afplay`

3. **Configure hooks in `settings.json`**
   - `Notification` with `idle_prompt` matcher
   - `Stop` hook for task completion

4. **Add starter sounds**
   - 3-5 characters
   - 2-3 sounds each
   - Normalize volume levels

5. **Test with multiple tabs**
   - Verify per-tab character consistency
   - Verify overlapping sounds work

### Phase 2: Polish (Future)

- [ ] More characters/sounds
- [ ] Install script for easy setup
- [ ] Volume normalization tooling
- [ ] Optional: Different sounds for `idle_prompt` vs `Stop`
- [ ] Optional: Tab title icons (needs Ghostty research)

---

## Dependencies

- **macOS** (uses `afplay`)
- **jq** (JSON parsing in bash) - `brew install jq`
- **Claude Code** with hooks support

---

## Files to Create

| File | Purpose |
|------|---------|
| `~/.claude/hooks/claude-overlord.sh` | Main sound selector script |
| `~/.claude/settings.json` | Hook configuration (or merge into existing) |
| `~/.claude/claude-overlord/sounds/*/` | Sound files organized by character |

---

*Enriched spec developed using `/enrich-plan`.*
