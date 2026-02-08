# Omoi Quick Start

Get up and running with Omoi (思い) in 5 minutes.

## Prerequisites

- macOS 14.0+ (Sonoma or later)
- Homebrew installed
- 10 minutes for initial setup

## 1. Install Dependencies (2 minutes)

```bash
# Install required system tools
brew install ffmpeg python@3.12 ollama

# Start Ollama service
brew services start ollama

# Download LLM model for text transformations
ollama pull qwen3:1.7b
```

## 2. Backend Setup (3 minutes)

```bash
# Clone repository
git clone https://github.com/yourusername/omoi.git
cd omoi/backend

# Create and activate virtual environment
python3.12 -m venv venv
source venv/bin/activate

# Install Python dependencies
pip install --upgrade pip
pip install -r requirements.txt
```

**Note**: Whisper model (~460MB) will download automatically on first use.

## 3. Build App (2 minutes)

```bash
cd ../frontend/SuperWhispr
bash build_app.sh
```

## 4. Install and Launch

```bash
# Install to Applications
cp -r dist/Omoi.app /Applications/

# Launch
open -a Omoi
```

## 5. Grant Permissions

When prompted:
1. **Accessibility**: System Settings → Privacy & Security → Accessibility → Enable Omoi
2. **Microphone**: Click "Allow" when prompted
3. **Keyboard Monitoring**: Click "Allow" when prompted

## 6. Test It

1. Click in any text field (Notes, TextEdit, etc.)
2. Press **⌘ + Shift + R**
3. Speak: "This is a test"
4. Release keys
5. Text should auto-paste!

---

## Daily Usage

```bash
# Launch Omoi
open -a Omoi

# Wait for "Backend Ready" status

# Record anywhere
# Press ⌘ + Shift + R, speak, release
```

---

## Troubleshooting

**Backend won't start?**
```bash
# Test manually
cd backend
source venv/bin/activate
python main.py
```

**Ollama not working?**
```bash
# Restart service
brew services restart ollama
```

**Auto-paste not working?**
- System Settings → Privacy & Security → Accessibility
- Find **Omoi** in list
- Toggle OFF then ON
- Restart Omoi

---

## Next Steps

- View Dashboard for stats (words dictated, WPM, streaks)
- Explore History to see past transcriptions
- Apply transformation presets to clean up text
- Enable auto-sanitize for automatic text processing

For detailed installation instructions, see [INSTALLATION.md](INSTALLATION.md).
