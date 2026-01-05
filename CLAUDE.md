# Claude Overlord

Starcraft notification sounds for Claude Code - plays character voice lines when agents need attention.

## Quick Reference

| Task | Command |
|------|---------|
| Test sound script | `echo '{"session_id":"test123"}' \| ./claude-overlord.sh` |
| Play test sound | `afplay sounds/marine/ready.wav` |
| Check jq installed | `jq --version` |
| Install jq | `brew install jq` |

## Architecture

This is a Claude Code hook that installs into `~/.claude/`:

```
~/.claude/
├── settings.json                    # Hook config (merge with existing)
├── hooks/
│   └── claude-overlord.sh           # Main script (from this repo)
└── claude-overlord/
    └── sounds/{character}/*.wav     # Sound files
```

### Key Files

- `plan.md` - Full spec with implementation details
- `claude-overlord.sh` - Main hook script (to be created)
- `sounds/` - Sound library organized by character (to be populated)
- `install.sh` - Installation script (to be created)

### How It Works

1. Claude Code fires `Notification` (idle_prompt) or `Stop` hook
2. Hook passes JSON with `session_id` via stdin
3. Script hashes `session_id` → deterministic character selection
4. Random sound from that character's directory plays via `afplay`

## Development

### Testing the script locally

```bash
# Simulate a hook call
echo '{"session_id":"abc123","hook_event_name":"Stop"}' | ./claude-overlord.sh

# Different session_id = different character
echo '{"session_id":"xyz789","hook_event_name":"Stop"}' | ./claude-overlord.sh
```

### Adding sounds

1. Create character directory: `mkdir -p sounds/marine`
2. Add .wav/.mp3/.aiff files
3. Test: `afplay sounds/marine/ready.wav`

## Installation (for users)

```bash
# 1. Clone repo
git clone https://github.com/striglia/claude-overlord.git

# 2. Run installer (once created)
./install.sh

# Or manually:
# - Copy claude-overlord.sh to ~/.claude/hooks/
# - Copy sounds/ to ~/.claude/claude-overlord/sounds/
# - Merge hook config into ~/.claude/settings.json
```

## Gotchas

- **macOS only** - uses `afplay` which is macOS-specific
- **jq required** - install via `brew install jq`
- **Sound files not included** - must be sourced separately (see plan.md)
- **Tilde expansion** - `~/.claude/hooks/claude-overlord.sh` in settings.json may need full path on some systems
