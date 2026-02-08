# Omoi

**Capture your thoughts, not your keyboard.**

Omoi is a macOS voice transcription app that turns speech into text instantly. Press a hotkey, speak, and your words appear in whatever app you're using. No copy-paste. No context switching. Just thoughts flowing directly from your voice to your screen.

*Omoi (思い) — Japanese for "thought" or "feeling"*

---

## What It Does

1. **Press your hotkey** (default: `Ctrl+Shift+Space`)
2. **Speak** your thoughts
3. **Release** — text appears in your active app

That's it. Omoi captures the app you were in, transcribes your speech, and pastes the result back. Your cursor never leaves where you were working.

## Why Omoi

- **Zero friction** — One hotkey. No windows to manage, no apps to switch to.
- **Context-aware** — Knows which app you're in and pastes directly there.
- **Private by design** — Your audio goes to your own backend. No cloud services required.
- **Built for focus** — Minimal UI that stays out of your way.

## Design

Omoi uses a brutalist aesthetic: sharp edges, high contrast, monospace stats. No rounded corners, no gradients, no visual noise. The interface exists to show you information, not to decorate your screen.

## Requirements

- macOS 14.0+
- Local transcription backend (Whisper-based)

## Build

```bash
./build_app.sh
```

The app installs to `/Applications/Omoi.app` and launches automatically.

**First run:** Grant Accessibility permission in System Settings → Privacy & Security → Accessibility. This allows Omoi to paste text into other apps.

## Architecture

```
Omoi (macOS app)
    ↓ audio
Backend (local Whisper server)
    ↓ transcription
Omoi → paste into target app
```

Your voice data stays on your machine.

## Features

- **Global hotkey** — Configurable keyboard shortcut
- **Auto-paste** — Transcription appears where you were typing
- **Session history** — Browse and search past transcriptions
- **Analytics dashboard** — Track usage patterns and trends
- **Audio playback** — Optionally save recordings for review
- **Privacy controls** — Sanitization rules for sensitive content

## Development

```bash
# Build and run
./build_app.sh

# Clean build (removes .build cache)
./build_app.sh --clean
```

The project uses Swift Package Manager. Source code is in `Sources/Omoi/`.

## License

MIT

---

*Built with voice, for voice.*
