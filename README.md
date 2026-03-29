# Omoi (思い)

**Track everything you say and type. Locally. Privately. Beautifully.**

Omoi is a macOS app that measures your total written output — voice transcriptions and typed keystrokes — across every app, every keyboard, every hour of your day. All processing happens on your machine. Nothing leaves your computer.

Press Ctrl+Space to dictate. Type normally everywhere else. Omoi counts it all and shows you where your words go.

## What It Does

**Voice** — Press Ctrl+Space anywhere to record. Whisper transcribes locally. Text auto-pastes into your active app.

**Keystroke Tracking** — Counts every keystroke via macOS CGEvent tap. Never logs what you type — only counts. Detects which keyboard you're using (built-in, NuPhy, external) via IOKit HID.

**Unified Dashboard** — Combined word count, voice/typed WPM split, activity heatmaps (hourly/daily/monthly with hover breakdowns), per-app analytics, and LLM-generated insights via Ollama.

**Encrypted** — All typing data encrypted at rest with AES-256-GCM. Key stored in macOS Keychain.

## Requirements

| What | Version | Why |
|------|---------|-----|
| **macOS** | 14.0 (Sonoma)+ | SwiftUI, CGEvent tap, IOKit HID APIs |
| **Python** | 3.12+ | Whisper backend |
| **FFmpeg** | any | Audio processing for Whisper |
| **Ollama** | any | LLM insights + text transformation (optional but recommended) |
| **Xcode / Swift** | 15+ / 5.9+ | Building from source |
| **Disk** | ~1GB minimum | Whisper small model (~460MB) + Ollama model |
| **RAM** | 8GB min, 16GB recommended | Whisper + Ollama running concurrently |

### macOS Permissions (prompted on first launch)

| Permission | What For |
|------------|----------|
| **Microphone** | Voice recording |
| **Accessibility** | Auto-paste transcriptions + keystroke monitoring |
| **Input Monitoring** | CGEvent tap for keystroke counting + keyboard detection |

## Installation Guide

### Prerequisites

#### 1. Install Homebrew (if not already installed)
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

#### 2. Install Required System Dependencies
```bash
# FFmpeg (required for Whisper audio processing)
brew install ffmpeg

# Python 3.12 (if not already installed)
brew install python@3.12
```

#### 3. Install Ollama (Required for Text Transformation)
```bash
# Install Ollama
brew install ollama

# Start Ollama service
brew services start ollama

# Download a small, fast model (recommended: qwen3:1.7b)
ollama pull qwen3:1.7b
```

**Note**: Ollama powers dashboard insights and text transformation. Transcription and keystroke tracking work without it, but the dashboard will show "Could not generate insights" and transformation features will be unavailable.

### Backend Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/scurving/Wisprrd.git
   cd Wisprrd/backend
   ```

2. **Create Python virtual environment:**
   ```bash
   python3.12 -m venv venv
   source venv/bin/activate
   ```

3. **Install Python dependencies:**
   ```bash
   pip install --upgrade pip
   pip install -r requirements.txt
   ```

4. **Download Whisper model (automatic on first run):**
   ```bash
   # The "small" model (~460MB) will download automatically on first transcription
   # To pre-download: python -c "import whisper; whisper.load_model('small')"
   ```

5. **Optional: Install TTS support:**
   ```bash
   # Only needed if you want text-to-speech features
   pip install qwen-tts
   ```

### Frontend Setup

1. **Navigate to frontend directory:**
   ```bash
   cd ../frontend/Omoi
   ```

2. **Build the application:**
   ```bash
   bash build_app.sh
   ```

3. **The built app will be in:**
   ```
   frontend/Omoi/dist/Omoi.app
   ```

4. **Move to Applications (optional):**
   ```bash
   cp -r dist/Omoi.app /Applications/
   ```

### First Launch

1. **Grant Permissions:**
   - **Accessibility**: System Settings → Privacy & Security → Accessibility → Enable Omoi
   - **Microphone**: Will prompt automatically on first recording
   - **Keyboard Monitoring**: Will prompt automatically when setting hotkey

2. **Verify Backend:**
   - Backend starts automatically with the app
   - Check status in menu bar (should show "Backend Ready")
   - If backend fails, check Console.app for Python errors

3. **Test Recording:**
   - Press **Ctrl + Space**
   - Speak clearly
   - Release keys
   - Text should appear in active application

## Daily Usage

### Basic Transcription
1. Press **Ctrl + Space** to start recording
2. Speak into your microphone
3. Release to transcribe
4. Text automatically pastes into active application

### Transformation Presets
- Access Dashboard → History tab
- Hover over any transcription → click to expand
- Apply presets (e.g., "Fix Grammar", "Professional", "Concise")
- Chain multiple presets in parallel or sequential mode
- Copy transformed results

### Auto-Sanitize
- Enable in Dashboard → Settings
- Choose a preset to apply automatically before paste
- All future transcriptions will be transformed before pasting

## Project Structure

```
Wisprrd/
├── backend/                         # Python FastAPI backend
│   ├── main.py                     # FastAPI server (STT, TTS, transformation)
│   ├── requirements.txt            # Python dependencies
│   └── venv/                       # Virtual environment (created during setup)
├── frontend/Omoi/           # macOS SwiftUI application
│   ├── Sources/Omoi/               # Swift source files
│   │   ├── OmoiApp.swift          # Main app entry + keyboard shortcut
│   │   ├── KeystrokeMonitor.swift # CGEvent tap keystroke counting
│   │   ├── KeyboardDetector.swift # IOKit HID keyboard detection
│   │   ├── EncryptedStorageManager.swift  # AES-256-GCM typing data
│   │   ├── TypingSession.swift    # Typing data models + storage
│   │   ├── DashboardView.swift    # Stats dashboard + heatmaps
│   │   ├── HistoryView.swift      # Unified voice+typing timeline
│   │   ├── StatsManager.swift     # Analytics & history
│   │   └── ...                     # Other UI components
│   ├── Package.swift               # Swift Package Manager
│   ├── build_app.sh                # Build script
│   └── Omoi.entitlements           # macOS permissions
└── README.md                        # This file
```

## Architecture

### Frontend (SwiftUI)
- Native macOS menu bar application
- Global keyboard shortcut handling
- Audio recording and playback
- Dashboard with history, stats, and transformations
- Auto-paste functionality via Accessibility API

### Backend (Python + FastAPI)
- OpenAI Whisper for speech-to-text (small model, CPU-based)
- Optional Qwen3-TTS for text-to-speech
- Ollama integration for text transformations
- Non-blocking async I/O with thread pool
- RESTful API endpoints on `http://localhost:58724`

### Communication
- Frontend ↔ Backend: HTTP REST API (localhost only)
- Backend ↔ Ollama: HTTP API on port 11434
- All processing is local (no cloud dependencies)

## Technologies

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Frontend** | SwiftUI | Native macOS UI |
| **Backend** | Python 3.12 + FastAPI | AI model serving |
| **STT Model** | OpenAI Whisper (small) | Speech recognition |
| **TTS Model** | Qwen3-TTS (optional) | Speech synthesis |
| **LLM** | Ollama (qwen3:1.7b) | Text transformation |
| **Global Shortcuts** | KeyboardShortcuts Swift Package | Hotkey management |
| **Audio** | AVFoundation | Microphone & playback |

## Troubleshooting

### Installation Issues

#### ❌ `ModuleNotFoundError: No module named 'whisper'`
**Problem**: Python dependencies not installed correctly
**Solution**:
```bash
cd backend
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

#### ❌ `ffmpeg: command not found`
**Problem**: FFmpeg not installed (required by Whisper)
**Solution**:
```bash
brew install ffmpeg
```

#### ❌ `xcrun: error: unable to find utility "xcodebuild"`
**Problem**: Xcode Command Line Tools not installed
**Solution**:
```bash
xcode-select --install
```

#### ❌ Ollama connection refused
**Problem**: Ollama service not running
**Solution**:
```bash
# Start Ollama service
brew services start ollama

# Or run manually
ollama serve

# Verify it's running
curl http://localhost:11434/api/generate -d '{"model":"qwen3:1.7b","prompt":"test"}'
```

#### ❌ Python version mismatch
**Problem**: Wrong Python version
**Solution**:
```bash
# Check version
python3 --version  # Should be 3.12+

# Install Python 3.12
brew install python@3.12

# Create venv with specific version
python3.12 -m venv venv
```

### Runtime Issues

#### ❌ Backend not starting
**Symptoms**: "Backend Not Ready" status in app
**Debugging**:
```bash
# Check if backend process is running
ps aux | grep "python.*main.py"

# Check port 58724
lsof -i :58724

# Test backend manually
cd backend
source venv/bin/activate
python main.py
# Should see: "🚀 Server starting - loading models in background..."
```

#### ❌ Models loading slowly
**Expected**: First startup can take 2-5 minutes while Whisper model downloads
**Check progress**:
```bash
# Watch model download
ls -lh ~/.cache/whisper/
# Should see: small.pt (~460MB when complete)
```

#### ❌ Auto-paste not working
**Problem**: Missing Accessibility permission
**Solution**:
1. System Settings → Privacy & Security → Accessibility
2. Find Omoi in the list
3. Toggle it OFF then ON
4. Restart Omoi

#### ❌ Transcription quality poor
**Problem**: Using wrong microphone or noisy environment
**Solution**:
- Check System Settings → Sound → Input
- Ensure correct microphone is selected
- Test with "feedback" → should NOT produce "Peate back back"
- If quality is still poor, consider upgrading to `medium` model:
  ```bash
  # Edit backend/main.py line 52
  # Change: whisper.load_model("small", ...)
  # To:     whisper.load_model("medium", ...)
  # Note: medium is ~1.5GB download
  ```

#### ❌ Transformation/Sanitization fails
**Problem**: Ollama not running or model not downloaded
**Solution**:
```bash
# Check Ollama status
ollama list

# Should show: qwen3:1.7b
# If not, download:
ollama pull qwen3:1.7b

# Restart Ollama service
brew services restart ollama
```

#### ❌ High CPU usage
**Expected behavior**: Whisper uses 100-200% CPU during transcription (lasts 2-5 seconds)
**If sustained high CPU**:
- Check Console.app for errors
- Restart backend: kill backend process, relaunch app
- Consider `base` model for lower CPU usage (trades quality for speed)

### Permissions Issues

#### ❌ Microphone permission denied
**Solution**:
1. System Settings → Privacy & Security → Microphone
2. Enable Omoi
3. Restart app

#### ❌ Accessibility permission not working after granted
**Solution**:
1. Remove Omoi from Accessibility list
2. Restart Mac (required for some macOS versions)
3. Launch Omoi, re-grant permission

#### ❌ Keyboard shortcut not triggering
**Problem**: Another app is using Ctrl+Space
**Solution**:
- Open Omoi settings
- Choose different keyboard shortcut
- Avoid conflicts with system shortcuts

### Advanced Debugging

#### Enable verbose logging
```bash
# Backend logs
cd backend
source venv/bin/activate
LOG_LEVEL=DEBUG python main.py

# Frontend logs (via Console.app)
# Open Console.app → Filter: "Omoi"
```

#### Reset all settings
```bash
# Remove stored data
rm -rf ~/Library/Application\ Support/Omoi
rm -rf ~/Library/Caches/Omoi

# Restart app
```

#### Check model sizes
```bash
# Whisper cache
ls -lh ~/.cache/whisper/

# Ollama models
ollama list
```

## Performance Notes

### Model Performance
- **Whisper Small**: ~3-5 seconds for 10s audio on M1, ~5-8s on Intel
- **Ollama qwen3:1.7b**: ~1-2 seconds for short text transformations
- **Memory Usage**: ~2-3GB during active transcription

### Optimization Tips
- Use `small` model for balanced quality/speed (current default)
- Use `base` model for fastest transcription (lower quality)
- Use `medium` model for best quality (slower, more RAM)
- Keep Ollama service running to avoid cold-start delays
- Close other memory-intensive apps during heavy use

### Cold Start Times
- **First Launch**: 2-5 minutes (Whisper model download)
- **Subsequent Launches**: 5-10 seconds (model loading)
- **Backend Ready**: ~3-5 seconds after app launch

## Privacy & Security

**100% Local Processing**: All audio and text processing happens on your machine. No data is sent to external servers.

**Data Storage**:
- Transcription history: `~/Documents/Omoi/history.json`
- Audio recordings: `~/Documents/Omoi/recordings/`
- Typing data: `~/Documents/Omoi/typing.enc` (AES-256-GCM encrypted, key in macOS Keychain)

**Network Usage**:
- Initial model downloads only (Whisper, Ollama)
- No telemetry or analytics
- No cloud API calls

**Permissions Scope**:
- Microphone: Only when recording (Ctrl+Space pressed)
- Accessibility: Only for auto-paste (can be disabled)
- Keyboard: Only for global hotkey monitoring

## Development

### Running in Development

1. **Backend**:
   ```bash
   cd backend
   source venv/bin/activate
   python main.py
   # Server runs on http://localhost:58724
   ```

2. **Frontend**:
   ```bash
   cd frontend/Omoi
   open -a Xcode .
   # Build and run from Xcode
   ```

### Build from Source

```bash
cd frontend/Omoi
bash build_app.sh
# App will be in dist/Omoi.app
```

### Environment Variables

```bash
# Backend
OLLAMA_URL=http://localhost:11434  # Ollama endpoint
OLLAMA_MODEL=qwen3:1.7b            # LLM model for transformations
LOG_LEVEL=INFO                      # DEBUG for verbose logs
```

## Known Issues

1. **macOS Sonoma 14.0**: Accessibility permission may require restart after granting
2. **Apple Silicon + Rosetta**: Backend must use native ARM Python, not x86_64
3. **Microphone switching**: May require app restart to detect new input device
4. **Large audio files**: Files >5 minutes may timeout (by design, use for short clips)

## Roadmap

- [ ] Whisper model selection in UI
- [ ] Custom transformation preset editor
- [ ] Export/import presets
- [ ] Cloud sync for history (opt-in)
- [ ] Multi-language support beyond English
- [ ] iOS companion app

## Contributing

Contributions welcome! Please open an issue first to discuss proposed changes.

## License

MIT License - see [LICENSE](LICENSE)

## Acknowledgments

Built with:
- [OpenAI Whisper](https://github.com/openai/whisper) - Speech recognition
- [Qwen3-TTS](https://github.com/QwenLM/Qwen3-TTS) - Text-to-speech
- [Ollama](https://ollama.ai/) - Local LLM runtime
- [FastAPI](https://fastapi.tiangolo.com/) - Backend framework
- [SwiftUI](https://developer.apple.com/swiftui/) - Frontend framework
- [KeyboardShortcuts](https://github.com/p-x9/KeyboardShortcuts) - Global hotkeys

## Support

For issues, questions, or suggestions:
- Open an issue on GitHub
- Check troubleshooting section above
- Review closed issues for similar problems

---

**Built with ❤️ for macOS** • Privacy-first • Local-first • Open Source
