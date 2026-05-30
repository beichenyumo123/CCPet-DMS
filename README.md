# 🐾 DMS Claude Pet

<p align="center">
  <img src="https://img.shields.io/badge/platform-DMS%20≥%201.4.0-blue?style=flat-square" alt="DMS">
  <img src="https://img.shields.io/badge/runtime-Quickshell%20≥%200.3.0-green?style=flat-square" alt="Quickshell">
  <img src="https://img.shields.io/badge/license-MIT-yellow?style=flat-square" alt="License">
</p>

A **state-aware desktop pet plugin** for [Dank Material Shell](https://github.com/AvengeMedia/DankMaterialShell) that lives in your DankBar, reacting in real-time to [Claude Code](https://code.claude.com) activity through expressive animations and particle effects.

---

## ✨ Features

- **6 animated states** — idle, working, waking, sleeping, error, and alert — each with unique physics-driven animations
- **Eye tracking** — pupils follow your mouse cursor for a lifelike gaze effect
- **Click interaction** — squish the pet with a bouncy jelly deformation, complete with floating ❤️ particles
- **Popout panel** — click to open a detail view showing Claude's current state, event, and tool
- **Physics engine** — squash & stretch, elastic bounce, inertia — the pet feels alive
- **Material You theming** — auto-adapts to your DMS theme colors
- **Particle effects** — floating 💤 Zzz bubbles when sleeping
- **Zero external assets** — entirely vector-drawn in QML (no PNGs, no SVGs)

## 🎬 States

| State | Emoji | Animation | Trigger |
|-------|-------|-----------|---------|
| `idle` | 😌 | Breathing + blinking + occasional hops | Claude waiting for input |
| `working` | ⚡ | 15° side-to-side wobble | Tool use, code execution, prompt submission |
| `waking` | ☀️ | Stretch & bounce entrance | New Claude session started |
| `sleeping` | 💤 | Closed eyes + dimmed + slow breathing + floating Zzz | Session ended |
| `error` | 😵 | Red flash + head shake + red pupils | Tool execution failure |
| `alert` | 🚨 | Bouncing alert jump + large red mouth | User authorization required |

## 🏗 Architecture

```
Claude Code (CLI / VSCode)
  │  Hook events: SessionStart, PreToolUse, PostToolUse,
  │               UserPromptSubmit, PostToolUseFailure,
  │               Stop, StopFailure, Notification, SessionEnd
  ▼
update-claude-state.sh  ──→  ~/.cache/dms-pet/claude-state.json
                                    │
                              QML Timer polling (800ms)
                                    │
                             PetBlob animation engine
```

Hooks fire regardless of how you invoke Claude Code — CLI, VSCode extension, or any other UI. Claude Code hooks are engine-level, not UI-dependent.

## 📁 Project Structure

```
dmsPet/
├── plugin.json                    # DMS plugin manifest
├── DmsPet.qml                     # Main component: PluginComponent + PetBlob + state polling
├── PetSettings.qml                # Settings panel (name, size, speed, color, emoji)
├── scripts/
│   └── update-claude-state.sh     # Claude Code hook bridge script
└── README.md
```

## 🚀 Installation

### 1. Clone the plugin

```bash
git clone https://github.com/YOUR_USERNAME/dmsPet.git ~/.config/DankMaterialShell/plugins/dmsPet
```

Or manually:

```bash
cp -r dmsPet ~/.config/DankMaterialShell/plugins/
```

### 2. Enable the plugin

In DMS settings: **Settings → Plugins → Claude Pet → Enable**

Or via CLI:

```bash
cat ~/.config/DankMaterialShell/plugin_settings.json | \
  jq '.dmsPet = {"enabled": true}' > /tmp/ps.json && \
  mv /tmp/ps.json ~/.config/DankMaterialShell/plugin_settings.json
```

### 3. Add to DankBar

In DMS settings, add `dmsPet` to your bar widget list. Or edit `~/.config/DankMaterialShell/settings.json`:

```json
{
  "barConfigs": [{
    "centerWidgets": [
      { "id": "dmsPet", "enabled": true }
    ]
  }]
}
```

### 4. Configure Claude Code hooks

Add the hook script to `~/.claude/settings.json` for these events:

| Hook Event | Purpose |
|------------|---------|
| `SessionStart` | Pet wakes up |
| `PreToolUse` | Pet starts working |
| `PostToolUse` | Pet continues working |
| `UserPromptSubmit` | Instant activation on input |
| `PostToolUseFailure` | Pet shows error |
| `Stop` | Pet returns to idle |
| `StopFailure` | Pet shows error |
| `Notification` | Pet alerts for user attention |
| `SessionEnd` | Pet goes to sleep |

Example hook entry:

```json
{
  "matcher": "",
  "hooks": [{
    "type": "command",
    "command": "~/.config/DankMaterialShell/plugins/dmsPet/scripts/update-claude-state.sh",
    "timeout": 5
  }]
}
```

> **Tip:** Use a partial matcher like `""` to trigger on all events, or configure per-event for fine-grained control.

### 5. Restart DMS

```bash
dms restart
```

## ⚙️ Settings

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| Pet Name | String | `Clawdy` | Your pet's name (shown in popout) |
| Pet Size | Slider (50–150%) | `100%` | Size in the DankBar |
| Animation Speed | Slider (50–200%) | `100%` | Animation playback speed |
| Use Theme Color | Toggle | On | Follow Material You theme color |
| Custom Pet Color | Color | `#7C9CBF` | Color when theme is disabled |
| Show State Emoji | Toggle | Off | Display emoji label above pet |
| Show Pet Name | Toggle | Off | Display the pet's name next to it in the bar |

## 🔧 Technical Details

- **Pure QML vector graphics** — body, eyes, pupils, blush, and mouth are all `Rectangle` + `radius` shapes. No image assets needed.
- **Transform-based animations** — uses `Translate`, `Rotation`, and `Scale` transforms rather than direct `x`/`y`/`rotation` properties, avoiding conflicts with anchor layouts.
- **Squash & stretch** — scale origin is set to the bottom of the body (`origin.y: body.height`), so the pet appears grounded like a physical object.
- **Volume preservation** — breathing animation stretches on one axis while compressing on the other.
- **State polling** — `Quickshell.Io.Process` reads the state file every 800ms.
- **Stale detection** — state file older than 30 seconds auto-reverts to `idle`.
- **XDG compliant** — respects `$XDG_CACHE_HOME`, falls back to `~/.cache`.
- **Inline components** — `PetBlob` is defined with QML's `component` keyword inside `DmsPet.qml`, avoiding cross-file loading issues.

## 🧩 PetBlob Anatomy

The pet is composed entirely of layered QML primitives:

```
         💤 (Zzz particle, sleeping only)
    ⚡ (state emoji, when enabled)
        ┌──────────┐
   ┌────│ Highlight │────┐
   │    └──────────┘    │
   │  ┌──┐        ┌──┐  │  ← Eyes (squint when sleeping)
   │  │◉││  Body  │◉││  │  ← Pupils (track mouse position)
   │  └──┘  ┌──┐  └──┘  │
   │   (◡)  │口│  (◡)   │  ← Blush + Mouth (color/scale by state)
   │        └──┘         │
   └─────────────────────┘
        ░░░ shadow ░░░       ← Dynamic shadow (scales with bounce height)
```

## 📦 Dependencies

- [Dank Material Shell](https://github.com/AvengeMedia/DankMaterialShell) ≥ 1.4.0
- [Quickshell](https://quickshell.org) ≥ 0.3.0
- `jq` — required by the hook bridge script
- [Claude Code](https://code.claude.com) — any invocation method (CLI, VSCode, etc.)

## 🔗 Related Resources

- [DMS Plugin Development Docs](https://danklinux.com/docs/dankmaterialshell/plugin-development)
- [Claude Code Hooks Documentation](https://code.claude.com/docs/en/hooks)
- [DMS Source Code](https://github.com/AvengeMedia/DankMaterialShell)
- [Quickshell Documentation](https://quickshell.org)

## 📄 License

MIT
