# Keyboard Shortcuts in Omoi

Omoi uses the KeyboardShortcuts Swift package for reliable global hotkey support.

## Default Shortcut

**⌘ + Shift + R** - Toggle recording

Press once to start recording, release to stop and transcribe.

## How It Works

KeyboardShortcuts is **already configured** in Omoi! The package is automatically downloaded by Xcode when you open the project.

### Setup in Code

1. **Package Dependency**: Defined in `Package.swift`:
   ```swift
   dependencies: [
       .package(url: "https://github.com/p-x9/KeyboardShortcuts", from: "2.0.0")
   ]
   ```

2. **Registration**: The shortcut is registered in `OmoiApp.swift`:
   ```swift
   import KeyboardShortcuts

   extension KeyboardShortcuts.Name {
       static let toggleRecording = Self("toggleRecording", default: .init(.r, modifiers: [.command, .shift]))
   }
   ```

3. **Handler**: In `ContentView.swift`:
   ```swift
   .onAppear {
       KeyboardShortcuts.onKeyDown(for: .toggleRecording) {
           // Start recording
       }
       KeyboardShortcuts.onKeyUp(for: .toggleRecording) {
           // Stop recording
       }
   }
   ```

## Testing the Shortcut

1. Open Omoi
2. Press **⌘ + Shift + R** from any app
   - You should see "Recording... Speak now!" in the Omoi window
3. Release to stop and transcribe

## Troubleshooting

### Shortcut not triggering

**Check for conflicts:**
- Another app might be using ⌘⇧R
- macOS system shortcuts take precedence
- Check System Settings → Keyboard → Keyboard Shortcuts

**Grant permissions:**
- System Settings → Privacy & Security → Accessibility
   - Ensure Omoi is enabled (if required)

**Restart Omoi:**
```bash
killall Omoi && open -a Omoi
```

### Changing the Default Shortcut

To change the default shortcut in code, edit `OmoiApp.swift`:

```swift
extension KeyboardShortcuts.Name {
    // Change from ⌘⇧R to your preferred shortcut
    static let toggleRecording = Self("toggleRecording", default: .init(.r, modifiers: [.command, .shift]))

    // Examples:
    // .init(.space, modifiers: [.command, .option])        // ⌘⌥Space
    // .init(.m, modifiers: [.control, .shift])             // ⌃⇧M
    // .init(.return, modifiers: [.command])                // ⌘Return
}
```

After editing, rebuild the app:
```bash
cd frontend/Omoi
bash build_app.sh
```

## Available Modifiers

- `.command` - ⌘ (Command)
- `.option` - ⌥ (Option/Alt)
- `.control` - ⌃ (Control)
- `.shift` - ⇧ (Shift)

You can combine multiple modifiers: `[.command, .option, .shift]`

## Best Practices

1. **Avoid conflicts** - Don't use shortcuts already taken by macOS or popular apps
2. **Easy to reach** - Choose shortcuts that don't require hand gymnastics
3. **Memorable** - Use mnemonics (R for Record)
4. **Modifier-heavy** - Use 2+ modifiers to avoid accidental triggers

### Commonly Conflicting Shortcuts

Avoid these (already used by system or popular apps):
- ⌘C, ⌘V, ⌘X - System clipboard
- ⌘Q, ⌘W - Quit/Close
- ⌘Space - Spotlight
- ⌘Tab - App Switcher
- ⌘` - Window Switcher

### Good Alternatives

If ⌘⇧R conflicts:
- ⌘⌥R (Command + Option + R)
- ⌃⇧R (Control + Shift + R)
- ⌘⇧Space (Command + Shift + Space)
- ⌘⌥M (Command + Option + M) - "M" for Microphone

## References

- [KeyboardShortcuts Package](https://github.com/p-x9/KeyboardShortcuts) - Official documentation
- [macOS Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/macos/user-interaction/keyboard/) - Apple's keyboard shortcut guidelines
