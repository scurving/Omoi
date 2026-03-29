import SwiftUI

struct PipelinesView: View {
    @State private var sanitizationManager = SanitizationManager.shared
    @ObservedObject var statsManager: StatsManager
    
    // State for Sanitization
    @State private var isPreviewLoading = false
    @State private var previewSanitized: String?
    @State private var previewError: String?
    @State private var showPreviewError = false
    @State private var isSanitizingAll = false
    @State private var sanitizationProgress = 0
    @State private var selectedSessions: Set<UUID> = []
    @State private var showSavePresetSheet = false
    @State private var newPresetName = ""
    
    // UI State
    @State private var expandedSection: PipelineSection? = .input // Default to input expanded
    
    enum PipelineSection: String, Identifiable {
        case input = "INPUT LAYER"
        case output = "SYNTHESIS LAYER"
        case system = "SYSTEM CORE"
        var id: String { rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("INTELLIGENCE PIPELINES")
                            .font(OmoiFont.brand(size: 18))
                            .foregroundStyle(Color.omoiWhite)
                        Text("Configure how Omoi transforms your data.")
                            .font(OmoiFont.body(size: 12))
                            .foregroundStyle(Color.omoiMuted)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                // 1. Input Layer (Sanitization)
                pipelineCard(
                    title: "INPUT LAYER",
                    subtitle: "Real-time Sanitization & Privacy",
                    icon: "shield.checkerboard",
                    color: Color.omoiTeal,
                    section: .input
                ) {
                    inputLayerContent()
                }
                
                // 2. Synthesis Layer (Retrospective)
                pipelineCard(
                    title: "SYNTHESIS LAYER",
                    subtitle: "Daily Retrospective & Analysis",
                    icon: "brain.head.profile",
                    color: Color.omoiPurple, // Using Purple if available, else fallback
                    section: .output
                ) {
                    outputLayerContent()
                }
                
                // 3. System Core (Permissions)
                pipelineCard(
                    title: "SYSTEM CORE",
                    subtitle: "Permissions & Health",
                    icon: "cpu",
                    color: Color.omoiGray,
                    section: .system
                ) {
                    systemCoreContent()
                }
            }
            .padding(.bottom, 40)
        }
        .background(Color.omoiBlack)
        .sheet(isPresented: $showSavePresetSheet) {
            savePresetSheet()
        }
    }
    
    // MARK: - Card Component
    
    @ViewBuilder
    private func pipelineCard<Content: View>(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        section: PipelineSection,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            // Card Header
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    if expandedSection == section {
                        expandedSection = nil
                    } else {
                        expandedSection = section
                    }
                }
            }) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.1))
                            .frame(width: 40, height: 40)
                        Image(systemName: icon)
                            .font(.system(size: 18))
                            .foregroundStyle(color)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(OmoiFont.label(size: 12))
                            .foregroundStyle(color)
                            .kerning(1.0)
                        Text(subtitle)
                            .font(OmoiFont.body(size: 13))
                            .foregroundStyle(Color.omoiOffWhite)
                    }
                    
                    Spacer()
                    
                    if section == .input {
                        // Mini status indicator for Input
                        Text(sanitizationManager.rules.enabled ? "ACTIVE" : "OFF")
                            .font(OmoiFont.mono(size: 10))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(sanitizationManager.rules.enabled ? Color.omoiGreen.opacity(0.2) : Color.omoiGray)
                            .foregroundStyle(sanitizationManager.rules.enabled ? Color.omoiGreen : Color.omoiMuted)
                            .cornerRadius(4)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.omoiGray)
                        .rotationEffect(.degrees(expandedSection == section ? 90 : 0))
                }
                .padding(20)
                .background(Color.omoiDarkGray)
            }
            .buttonStyle(.plain)
            
            // Expanded Content
            if expandedSection == section {
                VStack(spacing: 0) {
                    Divider().overlay(Color.omoiGray.opacity(0.5))
                    content()
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                .background(Color.omoiDarkGray.opacity(0.5))
            }
        }
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.omoiGray, lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }
    
    // MARK: - Layer Contents
    
    @ViewBuilder
    private func inputLayerContent() -> some View {
        VStack(spacing: 24) {
            // 1. Master Toggle & Instructions
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Toggle(isOn: $sanitizationManager.rules.enabled) {
                        Text("ENABLE FIREWALL")
                            .font(OmoiFont.label(size: 11))
                            .foregroundStyle(Color.omoiWhite)
                    }
                    .toggleStyle(.switch)
                    
                    Spacer()
                    
                    Toggle(isOn: $sanitizationManager.rules.autoSanitizeBeforePaste) {
                        Text("AUTO-PASTE")
                            .font(OmoiFont.label(size: 11))
                            .foregroundStyle(Color.omoiWhite)
                    }
                    .toggleStyle(.switch)
                    .disabled(!sanitizationManager.rules.enabled)
                    .opacity(sanitizationManager.rules.enabled ? 1 : 0.5)
                }
                
                // Presets Scroller
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(sanitizationManager.presets) { preset in
                            presetPill(preset)
                        }
                    }
                }
                .disabled(!sanitizationManager.rules.enabled)
                .opacity(sanitizationManager.rules.enabled ? 1 : 0.5)
                
                // Instructions Editor
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("INSTRUCTION SET")
                            .font(OmoiFont.label(size: 10))
                            .foregroundStyle(Color.omoiMuted)
                        Spacer()
                        Button(action: { showSavePresetSheet = true }) {
                            Text("SAVE AS PRESET")
                                .font(OmoiFont.label(size: 10))
                                .foregroundStyle(Color.omoiTeal)
                        }
                        .buttonStyle(.plain)
                        .disabled(sanitizationManager.rules.instructions.isEmpty)
                        .opacity(sanitizationManager.rules.instructions.isEmpty ? 0.3 : 1.0)
                    }

                    TextEditor(text: $sanitizationManager.rules.instructions)
                        .font(OmoiFont.body(size: 13))
                        .scrollContentBackground(.hidden)
                        .background(Color.omoiBlack)
                        .foregroundStyle(Color.omoiWhite)
                        .frame(height: 100)
                        .overlay(Rectangle().stroke(Color.omoiGray, lineWidth: 1))
                        .disabled(!sanitizationManager.rules.enabled)
                        .opacity(sanitizationManager.rules.enabled ? 1 : 0.5)
                        .overlay(alignment: .topLeading) {
                            if sanitizationManager.rules.instructions.isEmpty {
                                Text("Type here to create new preset...")
                                    .font(OmoiFont.body(size: 13))
                                    .foregroundStyle(Color.omoiMuted.opacity(0.5))
                                    .padding(8)
                                    .allowsHitTesting(false)
                            }
                        }
                }
            }
            .padding(20)
            
            Divider().overlay(Color.omoiGray.opacity(0.5))
            
            // 2. Interactive Preview
            if let mostRecent = statsManager.sessions.first {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "eye")
                        Text("SIMULATION")
                    }
                    .font(OmoiFont.label(size: 11))
                    .foregroundStyle(Color.omoiMuted)
                    
                    HStack(spacing: 0) {
                        // Original
                        Text(mostRecent.text)
                            .font(OmoiFont.body(size: 11))
                            .foregroundStyle(Color.omoiMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color.omoiBlack)
                            .overlay(Rectangle().stroke(Color.omoiGray, lineWidth: 1))
                        
                        // Arrow
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.omoiGray)
                            .frame(width: 32)
                        
                        // Result
                        Group {
                            if isPreviewLoading {
                                ProgressView().scaleEffect(0.5)
                            } else if let sanitized = previewSanitized {
                                Text(sanitized)
                                    .foregroundStyle(Color.omoiTeal)
                            } else if let error = previewError {
                                Text(error).foregroundStyle(Color.omoiOrange)
                            } else {
                                Text("Run simulation...")
                                    .foregroundStyle(Color.omoiMuted)
                                    .italic()
                            }
                        }
                        .font(OmoiFont.body(size: 11))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.omoiBlack)
                        .overlay(Rectangle().stroke(Color.omoiGray, lineWidth: 1))
                    }
                    .frame(height: 80)
                    
                    Button(action: previewSanitization) {
                        Text("RUN SIMULATION")
                            .font(OmoiFont.label(size: 11))
                            .frame(maxWidth: .infinity)
                            .padding(10)
                            .background(Color.omoiGray)
                            .foregroundStyle(Color.omoiWhite)
                            .overlay(Rectangle().stroke(Color.omoiGray, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(isPreviewLoading || !sanitizationManager.rules.enabled)
                }
                .padding(20)
            }
            
            // 3. Batch Actions (Collapsed feel)
            if !statsManager.sessions.isEmpty {
                VStack(spacing: 0) {
                    Divider().overlay(Color.omoiGray.opacity(0.5))
                    Button(action: sanitizeSelected) { // Simplified batch for now, could expand
                        HStack {
                            Text("APPLY TO \(selectedSessions.isEmpty ? "ALL" : "\(selectedSessions.count)") PAST SESSIONS")
                                .font(OmoiFont.label(size: 11))
                            Spacer()
                            Image(systemName: "play.fill")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(Color.omoiTeal)
                        .padding(20)
                    }
                    .buttonStyle(.plain)
                    .disabled(isSanitizingAll)
                }
            }
        }
    }
    
    @ViewBuilder
    private func outputLayerContent() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            
            HStack {
                Text("RETROSPECTIVE PROMPT")
                    .font(OmoiFont.label(size: 10))
                    .foregroundStyle(Color.omoiMuted)
                Spacer()
                Button("Reset Default") {
                    sanitizationManager.retrospectivePrompt = SanitizationManager.defaultRetrospectivePrompt
                }
                .font(OmoiFont.label(size: 10))
                .foregroundStyle(Color.omoiOrange)
                .buttonStyle(.plain)
            }
            
            TextEditor(text: $sanitizationManager.retrospectivePrompt)
                .font(OmoiFont.mono(size: 12))
                .scrollContentBackground(.hidden)
                .background(Color.omoiBlack)
                .foregroundStyle(Color.omoiOffWhite)
                .frame(minHeight: 250)
                .overlay(Rectangle().stroke(Color.omoiGray, lineWidth: 1))
            
            HStack(spacing: 12) {
                Image(systemName: "info.circle")
                Text("This prompt is used by the Retro tab to generate your daily synthesis.")
                    .font(OmoiFont.caption)
            }
            .foregroundStyle(Color.omoiMuted)
        }
        .padding(20)
    }
    
    @ViewBuilder
    private func systemCoreContent() -> some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ACCESSIBILITY")
                        .font(OmoiFont.label(size: 11))
                        .foregroundStyle(Color.omoiWhite)
                    Text("Required for auto-paste functionality.")
                        .font(OmoiFont.caption)
                        .foregroundStyle(Color.omoiMuted)
                }
                Spacer()
                if AccessibilityPermissions.hasAccessibilityPermission() {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("GRANTED")
                    }
                    .font(OmoiFont.label(size: 11))
                    .foregroundStyle(Color.omoiGreen)
                } else {
                    Button("GRANT PERMISSION") {
                        AccessibilityPermissions.openAccessibilitySettings()
                    }
                    .font(OmoiFont.label(size: 10))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.omoiOrange)
                    .foregroundStyle(Color.omoiBlack)
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
    }
    
    // MARK: - Helpers
    
    @ViewBuilder
    private func presetPill(_ preset: SanitizationPreset) -> some View {
        Button(action: { sanitizationManager.applyPreset(preset) }) {
            Text(preset.name.uppercased())
                .font(OmoiFont.label(size: 10))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    sanitizationManager.rules.activePresetId == preset.id
                    ? Color.omoiTeal
                    : Color.omoiBlack
                )
                .foregroundStyle(
                    sanitizationManager.rules.activePresetId == preset.id
                    ? Color.omoiBlack
                    : Color.omoiWhite
                )
                .overlay(Rectangle().stroke(Color.omoiGray, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .contextMenu {
            if !preset.isBuiltIn {
                Button(role: .destructive) {
                    sanitizationManager.deletePreset(preset)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
    
    @ViewBuilder
    private func savePresetSheet() -> some View {
        VStack(spacing: 20) {
            Text("SAVE PRESET")
                .font(OmoiFont.heading(size: 16))
                .foregroundStyle(Color.omoiWhite)
            
            TextField("Preset Name", text: $newPresetName)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color.omoiGray)
                .foregroundStyle(Color.omoiWhite)
            
            HStack {
                Button("Cancel") { showSavePresetSheet = false }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.omoiMuted)
                Spacer()
                Button("Save") {
                    if !newPresetName.isEmpty {
                        sanitizationManager.addPreset(name: newPresetName, instructions: sanitizationManager.rules.instructions)
                        newPresetName = ""
                        showSavePresetSheet = false
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.omoiTeal)
                .foregroundStyle(Color.omoiBlack)
            }
        }
        .padding(24)
        .background(Color.omoiDarkGray)
        .frame(width: 300, height: 200)
    }
    
    // MARK: - Logic
    
    private func previewSanitization() {
        guard let mostRecent = statsManager.sessions.first else { return }
        isPreviewLoading = true
        previewError = nil
        previewSanitized = nil
        
        Task {
            do {
                let sanitized = try await APIService().sanitizeText(
                    text: mostRecent.text,
                    instructions: sanitizationManager.rules.instructions
                )
                await MainActor.run {
                    previewSanitized = sanitized
                    isPreviewLoading = false
                }
            } catch {
                await MainActor.run {
                    previewError = error.localizedDescription
                    showPreviewError = true
                    isPreviewLoading = false
                }
            }
        }
    }
    
    private func sanitizeSelected() {
        let sessions = statsManager.sessions
        guard !sessions.isEmpty else { return }
        
        isSanitizingAll = true
        
        Task {
            let api = APIService()
            for session in sessions {
                do {
                    let sanitized = try await api.sanitizeText(text: session.text, instructions: sanitizationManager.rules.instructions)
                    await MainActor.run {
                        statsManager.updateSessionSanitized(session.id, sanitizedText: sanitized)
                    }
                } catch {
                    print("Failed to sanitize session: \(session.id)")
                }
            }
            await MainActor.run { isSanitizingAll = false }
        }
    }
}
