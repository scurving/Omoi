# Omoi Installation Guide

Complete setup guide for installing Omoi (思い) - a privacy-first macOS speech-to-text application with AI-powered text transformation.

## Prerequisites

Before starting, ensure you have:
- **macOS 14.0 (Sonoma) or later**
- **Python 3.12+** (check with `python3.12 --version`)
- **Xcode 15+** (for building the macOS app)
- **Homebrew** (for installing system dependencies)
- **Terminal access**

## Step 1: Install System Dependencies

Open Terminal and run:

```bash
# Install FFmpeg (required for Whisper audio processing)
brew install ffmpeg

# Install Python 3.12 (if not already installed)
brew install python@3.12

# Install Ollama (required for text transformation features)
brew install ollama

# Start Ollama service
brew services start ollama

# Download the LLM model for text transformations
ollama pull qwen3:1.7b
```

**Important Notes**:
- `ffmpeg` is required by Whisper for audio processing
- `ollama` and `qwen3:1.7b` are required for transformation presets
- Text transformation will NOT work without Ollama running

---

## Step 2: Backend Setup

### 2.1 Clone and Navigate to Repository

```bash
git clone https://github.com/yourusername/omoi.git
cd omoi/backend
```

### 2.2 Create Python Virtual Environment

```bash
# Create virtual environment with Python 3.12
python3.12 -m venv venv

# Activate the virtual environment
source venv/bin/activate
```

**Note**: Your prompt should now show `(venv)` at the beginning.

### 2.3 Install Python Dependencies

```bash
# Upgrade pip first
pip install --upgrade pip

# Install all required packages
pip install -r requirements.txt
```

**Expected time**: 2-5 minutes (downloads PyTorch and other large packages)

### 2.4 AI Model Downloads

The Whisper model will download automatically on first use (~460MB for "small" model).

**Optional: Pre-download the model:**
```bash
python -c "import whisper; whisper.load_model('small')"
```

**Optional: Install TTS support:**
```bash
# Only needed if you want text-to-speech features
pip install qwen-tts
```

**What downloads automatically**:
- Whisper "small" model (~460MB) - downloads on first transcription
- TTS model (~1.2GB) - only if you installed qwen-tts

### 2.5 Verify Backend Setup

Test that the backend works:

```bash
# Make sure you're still in the venv (should see (venv) in prompt)
python main.py
```

**Expected output**:
```
🚀 Server starting - loading models in background...
✅ Whisper model loaded
✅ All models ready!
INFO:     Uvicorn running on http://0.0.0.0:58724
```

Press `Ctrl+C` to stop the test server (the app will auto-start it later).

---

## Step 3: Build and Install the App

### 3.1 Build via Script (Recommended)

```bash
cd ../frontend/SuperWhispr
bash build_app.sh
```

This script will:
- ✅ Build the Swift executable
- ✅ Create the macOS app bundle
- ✅ Code sign the app
- ✅ Output to `dist/Omoi.app`

### 3.2 Install to Applications

```bash
# Copy the built app to Applications
cp -r dist/Omoi.app /Applications/

# Or open from dist folder
open dist/Omoi.app
```

### 3.3 Alternative: Build via Xcode

If you prefer to use Xcode:

1. Open **Xcode**
2. Go to **File > Open...**
3. Navigate to the cloned repo: `frontend/SuperWhispr`
4. Select the **SuperWhispr** folder (with `Package.swift`)
5. Click **Open**
6. Wait for dependencies to resolve (progress bar in top toolbar)
7. Press **⌘ + B** to build

The build creates an executable in `.build/release/Omoi`.

---

## Step 4: Configure Permissions

### 4.1 Grant Accessibility Permission (Required for Auto-Paste)

1. Open **System Settings** → **Privacy & Security** → **Accessibility**
2. Click the **+** button to add an app (if Omoi not listed)
3. Navigate to `/Applications/Omoi.app` and select it
4. Toggle the switch **ON** for Omoi
5. **Restart Omoi** for changes to take effect

**Why this is needed**: Omoi uses the Accessibility API to post keyboard events (Cmd+V) for auto-paste functionality.

### 4.2 Microphone Permission

On first recording, macOS will prompt for **Microphone Permission** → Click **Allow**.

### 4.3 Keyboard Monitoring Permission

When you first launch Omoi, macOS may prompt for **Keyboard Monitoring** permission for the global hotkey. Click **Allow**.

---

## Step 5: Verify Installation

### 5.1 Launch the App

```bash
open -a Omoi
```

Or find **Omoi** in Applications and double-click it.

**First Launch**:
- The app icon appears in your **menu bar** (top right)
- Backend auto-starts (may take 10-30 seconds on first launch)
- Status should show "Backend Ready"

### 5.2 Verify Ollama is Running

```bash
# Check Ollama status
curl http://localhost:11434/api/generate -d '{"model":"qwen3:1.7b","prompt":"test"}'

# Should return JSON response, not "connection refused"
```

If connection refused:
```bash
brew services start ollama
# Or run manually: ollama serve
```

### 5.3 Test Recording

1. Click in any text field (Notes, TextEdit, etc.)
2. Press **⌘ + Shift + R** to start recording
3. Speak clearly: "This is a test"
4. Release keys to stop
5. Text should appear in the app AND auto-paste

**Troubleshooting test**:
- If text doesn't paste: Check Accessibility permission (Step 4.1)
- If transcription fails: Check backend status (should be green "Backend Ready")
- If transformation fails: Check Ollama is running (Step 5.2)

---

## Daily Usage

Once installed:

1. **Launch Omoi**: `open -a Omoi` (or from Applications)
2. **Wait for "Backend Ready"** status in menu bar icon
3. **Record anywhere**: Press **⌘ + Shift + R**, speak, release
4. **Text auto-pastes** into active application

**View Dashboard**: Click menu bar icon → Dashboard tab for stats
**View History**: Click menu bar icon → History tab to see past transcriptions

---

## Troubleshooting

### Backend Issues

#### Backend won't start
**Symptoms**: "Backend Not Ready" or "Backend Failed" status

**Solution**:
```bash
# Check if backend process is running
ps aux | grep "python.*main.py"

# Check port 58724
lsof -i :58724

# Test backend manually
cd backend
source venv/bin/activate
python main.py
```

#### `ffmpeg: command not found`
```bash
brew install ffmpeg
```

#### `python3.12: command not found`
```bash
brew install python@3.12
```

#### Port 58724 already in use
```bash
# Kill process using port 58724
lsof -ti:58724 | xargs kill -9
# Restart Omoi
```

#### Models loading slowly
**Expected**: First startup takes 2-5 minutes while Whisper downloads.

Check progress:
```bash
ls -lh ~/.cache/whisper/
# Should see: small.pt (~460MB when complete)
```

### Frontend Issues

#### App crashes on launch
- Check Console.app for error messages
- Verify backend is running: `curl http://127.0.0.1:58724/health`
- Check microphone permissions in System Settings

#### Auto-paste doesn't work
**Solution**:
1. System Settings → Privacy & Security → Accessibility
2. Find Omoi in the list
3. Toggle it OFF then ON
4. Restart Omoi

#### Keyboard shortcut doesn't trigger
**Solution**:
- Another app might be using ⌘⇧R
- Open Omoi settings to choose a different shortcut

#### Can't see menu bar icon
- Check if app is running: `ps aux | grep Omoi`
- Look for icon in menu bar (may be hidden behind other icons)
- Try quitting and relaunching: `killall Omoi && open -a Omoi`

### Transformation/Sanitization Issues

#### Transformations fail with "Connection refused"
**Problem**: Ollama not running

**Solution**:
```bash
# Start Ollama service
brew services start ollama

# Or run manually
ollama serve

# Verify it's running
ollama list
# Should show: qwen3:1.7b
```

#### "Model not found" error
```bash
# Download the model
ollama pull qwen3:1.7b

# Restart Ollama
brew services restart ollama
```

### Permission Issues

#### Microphone permission denied
1. System Settings → Privacy & Security → Microphone
2. Enable Omoi
3. Restart app

#### Accessibility permission not working after granted
1. Remove Omoi from Accessibility list
2. **Restart Mac** (required for some macOS versions)
3. Launch Omoi, re-grant permission

### Transcription Quality Issues

#### Poor transcription quality / gibberish output
**Solution**: Check your microphone settings
```bash
# System Settings → Sound → Input
# Ensure correct microphone is selected
# Test with "feedback" - should NOT produce "Peate back back"
```

**Upgrade to better model** (if quality still poor):
```bash
# Edit backend/main.py line 52
# Change: whisper.load_model("small", ...)
# To:     whisper.load_model("medium", ...)
# Note: medium model is ~1.5GB download
```

---

## Advanced Configuration

### Change Whisper Model

Edit `backend/main.py` line 52:
```python
whisper_model = __import__('whisper').load_model("small", device="cpu")
```

Available models (size / quality trade-off):
- `tiny`: 75MB (fastest, lowest quality)
- `base`: 140MB (fast, lower quality)
- `small`: 460MB (balanced - current default)
- `medium`: 1.5GB (slower, better quality)
- `large`: 2.9GB (slowest, best quality)

### Change Ollama Model

Edit `backend/main.py` line 32:
```python
OLLAMA_MODEL = "qwen3:1.7b"
```

Other compatible models:
- `llama3.2:3b` (larger, slower, possibly better)
- `phi3:mini` (similar size, different style)
- Run `ollama list` to see installed models

### Environment Variables

```bash
# Backend configuration
export OLLAMA_URL=http://localhost:11434
export OLLAMA_MODEL=qwen3:1.7b
export LOG_LEVEL=DEBUG  # For verbose logging
```

---

## Quick Start Checklist

**One-Time Setup:**
- [ ] Installed system dependencies: `brew install ffmpeg python@3.12 ollama`
- [ ] Started Ollama: `brew services start ollama`
- [ ] Downloaded Ollama model: `ollama pull qwen3:1.7b`
- [ ] Created Python venv: `python3.12 -m venv venv`
- [ ] Activated venv: `source venv/bin/activate`
- [ ] Installed Python deps: `pip install -r requirements.txt`
- [ ] Built app: `bash build_app.sh`
- [ ] Installed to Applications: `cp -r dist/Omoi.app /Applications/`
- [ ] Granted **Accessibility** permission (required for auto-paste)
- [ ] Granted **Microphone** permission (prompted on first use)

**Daily Use:**
- [ ] Launch: `open -a Omoi`
- [ ] Wait for "Backend Ready" status
- [ ] Press **⌘ + Shift + R** anywhere to record
- [ ] Speak clearly
- [ ] Release keys to transcribe and auto-paste

---

## Need Help?

1. Check the [main README](README.md) troubleshooting section
2. Review Console.app for error messages (filter: "Omoi")
3. Verify all prerequisites are installed
4. Ensure Ollama service is running
5. Check backend is accessible: `curl http://127.0.0.1:58724/health`

For issues not covered here, please open an issue on GitHub with:
- Your macOS version
- Error messages from Console.app
- Output from `curl http://127.0.0.1:58724/health`
- Output from `ollama list`
