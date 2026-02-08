# Contributing to Omoi

Thank you for your interest in contributing to Omoi (思い)! This guide will help you understand the codebase and development workflow.

## Refactoring Opportunities (Pre-Stable Release)

Before deploying v1.0, consider these improvements:

### High Priority

1. **Error Recovery**: Backend crash recovery is basic
   - Add exponential backoff for retries
   - Show user-friendly error messages
   - Log errors to file for debugging

2. **Settings Persistence**: Some settings are not persisted
   - Auto-sanitize toggle state  
   - Active preset selection
   - UI preferences (collapsed/expanded sections)

3. **Model Selection UI**: Currently hardcoded to "small"
   - Add settings UI to switch Whisper models
   - Show model size and expected quality
   - Auto-download selected model

4. **Ollama Health Check**: No validation that Ollama is running
   - Add startup check for Ollama connectivity
   - Show clear error if Ollama unavailable
   - Gracefully degrade (disable transformations)

### Medium Priority

5. **Audio Storage Limits**: Recording files accumulate
   - Add automatic cleanup of old recordings
   - User-configurable retention policy
   - Show disk space usage

6. **Keyboard Shortcut Customization**: Hardcoded to ⌘⇧R
   - Add UI for shortcut customization
   - Validate no conflicts with system shortcuts
   - Allow multiple shortcuts for different actions

7. **Export/Import Presets**: Presets only stored locally
   - Add export to JSON
   - Import custom presets
   - Share preset packs

8. **Multi-Language Support**: Currently English-only
   - Add language selector
   - Pass language to Whisper transcription
   - Adjust Ollama prompts per language

See full development guide and code architecture details in the README.
