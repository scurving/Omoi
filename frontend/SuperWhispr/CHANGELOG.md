# Changelog

All notable changes to Omoi are documented here.

---

## [1.0.0] - 2026-02

### Brand
- Renamed from SuperWhispr to **Omoi**
- New brutalist design system: sharp edges, flat colors, monospace typography
- Responsive window layout

### Core
- Global hotkey for push-to-talk recording
- Real-time transcription via local Whisper backend
- Auto-paste into the app you were using
- Session history with search and filtering

### Analytics Dashboard
- Words per day chart with WPM toggle
- 7-day moving average trend lines
- Week-over-week comparison
- Peak productivity hour detection
- App-specific WPM breakdown
- Interactive charts with drill-down to individual sessions
- CSV export for all analytics data

### Tagging System
- Manual tags on any session
- LLM-powered tag suggestions (via local Ollama)
- Filter dashboard by tag
- Smart fallback when LLM unavailable

### Goal Tracking
- Daily/weekly word count goals
- Session count goals
- Streak tracking with visual progress

### Privacy
- Sanitization rules for sensitive content
- All processing happens locally
- Audio playback toggle (save or discard recordings)

### Data Protection
- Automatic backups before each build
- Manual backup/restore
- Import/export history as JSON
- Data integrity verification

---

## Development History

Built iteratively with continuous testing:

1. **Dashboard foundations** — WPM tracking, time-of-day analysis
2. **Interactive analytics** — Chart drill-downs, data export
3. **Personalization** — Trend lines, tagging, goal tracking
4. **LLM integration** — Smart tag suggestions via Ollama
5. **Brand refresh** — Omoi identity, brutalist design, responsive layout

---

*First public release.*
