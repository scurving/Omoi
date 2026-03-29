import KeyboardShortcuts
import Carbon

struct ShortcutFormatter {
    /// Formats a keyboard shortcut with proper function key display
    static func format(_ shortcut: KeyboardShortcuts.Shortcut?) -> String {
        guard let shortcut = shortcut else {
            return "⌘⇧R"  // Fallback default display
        }

        // Build modifier string manually
        var parts: [String] = []

        if shortcut.modifiers.contains(.function) {
            parts.append("Fn")
        }
        if shortcut.modifiers.contains(.control) {
            parts.append("⌃")
        }
        if shortcut.modifiers.contains(.option) {
            parts.append("⌥")
        }
        if shortcut.modifiers.contains(.shift) {
            parts.append("⇧")
        }
        if shortcut.modifiers.contains(.command) {
            parts.append("⌘")
        }

        // Get key name
        guard let key = shortcut.key else {
            return "?"
        }
        let keyName = getKeyName(for: key)
        parts.append(keyName)

        return parts.joined(separator: "+")
    }

    /// Get human-readable key name
    private static func getKeyName(for key: KeyboardShortcuts.Key) -> String {
        // Special keys mapping
        let specialKeys: [KeyboardShortcuts.Key: String] = [
            .space: "Space",
            .return: "Return",
            .delete: "Delete",
            .deleteForward: "Del",
            .escape: "Esc",
            .tab: "Tab",
            .upArrow: "↑",
            .downArrow: "↓",
            .leftArrow: "←",
            .rightArrow: "→",
            // Add function keys F1-F20
            .f1: "F1", .f2: "F2", .f3: "F3", .f4: "F4",
            .f5: "F5", .f6: "F6", .f7: "F7", .f8: "F8",
            .f9: "F9", .f10: "F10", .f11: "F11", .f12: "F12",
            .f13: "F13", .f14: "F14", .f15: "F15", .f16: "F16",
            .f17: "F17", .f18: "F18", .f19: "F19", .f20: "F20"
        ]

        if let specialName = specialKeys[key] {
            return specialName
        }

        // For letter keys, try to get character representation
        // Fall back to the library's default
        if let char = keyToCharacter(key) {
            return char.uppercased()
        }

        return "?"
    }

    /// Map key enum to character
    private static func keyToCharacter(_ key: KeyboardShortcuts.Key) -> String? {
        // Map common letter/number keys
        let mapping: [KeyboardShortcuts.Key: String] = [
            .a: "A", .b: "B", .c: "C", .d: "D", .e: "E",
            .f: "F", .g: "G", .h: "H", .i: "I", .j: "J",
            .k: "K", .l: "L", .m: "M", .n: "N", .o: "O",
            .p: "P", .q: "Q", .r: "R", .s: "S", .t: "T",
            .u: "U", .v: "V", .w: "W", .x: "X", .y: "Y", .z: "Z",
            .zero: "0", .one: "1", .two: "2", .three: "3", .four: "4",
            .five: "5", .six: "6", .seven: "7", .eight: "8", .nine: "9"
        ]
        return mapping[key]
    }
}
