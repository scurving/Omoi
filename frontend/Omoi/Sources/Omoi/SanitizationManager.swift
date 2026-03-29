import Foundation
import Observation

@Observable
class SanitizationManager {
    static let shared = SanitizationManager()

    @ObservationIgnored private let rulesKey = "Omoi.SanitizationRules"
    @ObservationIgnored private let presetsKey = "Omoi.SanitizationPresets"
    @ObservationIgnored private let pipelinesKey = "Omoi.SavedPipelines"
    @ObservationIgnored private let retroPromptKey = "Omoi.RetroPrompt"
    
    var retrospectivePrompt: String {
        didSet {
            UserDefaults.standard.set(retrospectivePrompt, forKey: retroPromptKey)
        }
    }

    var rules: SanitizationRules {
        didSet {
            saveRules()
        }
    }

    var presets: [SanitizationPreset] {
        didSet {
            savePresets()
        }
    }

    var savedPipelines: [SavedPipeline] = []

    init() {
        // Load rules from UserDefaults or use defaults
        if let data = UserDefaults.standard.data(forKey: rulesKey),
           let decoded = try? JSONDecoder().decode(SanitizationRules.self, from: data) {
            self.rules = decoded
        } else {
            self.rules = SanitizationRules()
        }

        // After loading rules, load presets
        if let data = UserDefaults.standard.data(forKey: presetsKey),
           let decoded = try? JSONDecoder().decode([SanitizationPreset].self, from: data) {
            // Merge built-in presets with saved custom presets
            let customPresets = decoded.filter { !$0.isBuiltIn }
            self.presets = SanitizationPreset.defaultPresets + customPresets
        } else {
            self.presets = SanitizationPreset.defaultPresets
        }

        // Load saved pipelines
        if let data = UserDefaults.standard.data(forKey: pipelinesKey),
           let decoded = try? JSONDecoder().decode([SavedPipeline].self, from: data) {
            self.savedPipelines = decoded
        }
        
        // Load retro prompt
        self.retrospectivePrompt = UserDefaults.standard.string(forKey: retroPromptKey) ?? SanitizationManager.defaultRetrospectivePrompt
    }
    
    // MARK: - Defaults
    
    static let defaultRetrospectivePrompt = """
You are a personal retrospective assistant. Analyze the following voice memos recorded throughout the day.

Group your analysis by Application Context (e.g., Slack, Notes, Cursor).

For each group:
1. Summarize the key themes or tasks.
2. Identify any action items or outstanding questions.
3. Provide a brief "Insight" or "Reflection" on the content.

Finally, provide a "Daily Synthesis" summarizing the overall day.

Format the output in Markdown.
"""

    func saveRules() {
        if let encoded = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(encoded, forKey: rulesKey)
        }
    }

    func resetRules() {
        rules = SanitizationRules()
    }

    func markAllSessionsAsStale() {
        // This will be called from StatsManager when rules change
        // The actual implementation will invalidate cached sanitized text
    }

    func savePresets() {
        // Only save custom presets (built-ins are always added from code)
        let customPresets = presets.filter { !$0.isBuiltIn }
        if let encoded = try? JSONEncoder().encode(customPresets) {
            UserDefaults.standard.set(encoded, forKey: presetsKey)
        }
    }

    func addPreset(name: String, instructions: String) {
        let preset = SanitizationPreset(name: name, instructions: instructions)
        presets.append(preset)
    }

    func deletePreset(_ preset: SanitizationPreset) {
        guard !preset.isBuiltIn else { return }
        presets.removeAll { $0.id == preset.id }
        if rules.activePresetId == preset.id {
            rules.activePresetId = nil
        }
    }

    func applyPreset(_ preset: SanitizationPreset) {
        rules.instructions = preset.instructions
        rules.activePresetId = preset.id
        rules.enabled = true
    }

    func activePreset() -> SanitizationPreset? {
        guard let id = rules.activePresetId else { return nil }
        return presets.first { $0.id == id }
    }

    // MARK: - Pipeline Management

    func savePipelines() {
        if let encoded = try? JSONEncoder().encode(savedPipelines) {
            UserDefaults.standard.set(encoded, forKey: pipelinesKey)
        }
    }

    func addPipeline(name: String, presetIds: [UUID], mode: TransformationMode) {
        let pipeline = SavedPipeline(name: name, presetIds: presetIds, mode: mode)
        savedPipelines.append(pipeline)
        savePipelines()
    }

    func deletePipeline(_ pipeline: SavedPipeline) {
        savedPipelines.removeAll { $0.id == pipeline.id }
        savePipelines()
    }

    func presetNames(for ids: [UUID]) -> [String] {
        ids.compactMap { id in presets.first { $0.id == id }?.name }
    }
}
