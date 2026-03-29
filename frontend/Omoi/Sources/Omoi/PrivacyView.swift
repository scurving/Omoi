import SwiftUI

// MARK: - Omoi Privacy View

struct PrivacyView: View {
    @State private var sanitizationManager = SanitizationManager.shared
    @ObservedObject var statsManager: StatsManager
    @State private var isPreviewLoading = false
    @State private var previewSanitized: String?
    @State private var previewError: String?
    @State private var showPreviewError = false
    @State private var isSanitizingAll = false
    @State private var sanitizationProgress = 0
    @State private var selectedSessions: Set<UUID> = []
    @State private var hasAccessibilityPermission = false
    @State private var showPermissionInstructionSheet = false
    @State private var showSavePresetSheet = false
    @State private var newPresetName = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Section: Permission Status
                privacySection(title: "PERMISSIONS") {
                    HStack(spacing: 12) {
                        Rectangle()
                            .fill(hasAccessibilityPermission ? Color.omoiGreen : Color.omoiOrange)
                            .frame(width: 4, height: 32)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(hasAccessibilityPermission ? "AUTO-PASTE ENABLED" : "AUTO-PASTE DISABLED")
                                .font(OmoiFont.label(size: 11))
                                .foregroundStyle(hasAccessibilityPermission ? Color.omoiGreen : Color.omoiOrange)
                            Text(hasAccessibilityPermission ? "Ready to use" : "Permission required")
                                .font(OmoiFont.body(size: 11))
                                .foregroundStyle(Color.omoiMuted)
                        }

                        Spacer()

                        if !hasAccessibilityPermission {
                            Button(action: {
                                AccessibilityPermissions.openAccessibilitySettings()
                                showPermissionInstructionSheet = true
                            }) {
                                Text("FIX")
                                    .font(OmoiFont.label(size: 10))
                                    .foregroundStyle(Color.omoiBlack)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.omoiOrange)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Section: Sanitization Settings
                privacySection(title: "SANITIZATION") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $sanitizationManager.rules.enabled) {
                            Text("ENABLED")
                                .font(OmoiFont.label(size: 11))
                                .foregroundStyle(Color.omoiWhite)
                        }
                        .toggleStyle(.switch)

                        // Preset Picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("PRESET")
                                .font(OmoiFont.label(size: 10))
                                .foregroundStyle(Color.omoiMuted)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(sanitizationManager.presets) { preset in
                                        Button(action: {
                                            sanitizationManager.applyPreset(preset)
                                        }) {
                                            Text(preset.name.uppercased())
                                                .font(OmoiFont.label(size: 10))
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(
                                                    sanitizationManager.rules.activePresetId == preset.id
                                                        ? Color.omoiTeal
                                                        : Color.omoiGray
                                                )
                                                .foregroundStyle(
                                                    sanitizationManager.rules.activePresetId == preset.id
                                                        ? Color.omoiBlack
                                                        : Color.omoiWhite
                                                )
                                        }
                                        .buttonStyle(.plain)
                                        .contextMenu {
                                            if !preset.isBuiltIn {
                                                Button(role: .destructive) {
                                                    sanitizationManager.deletePreset(preset)
                                                } label: {
                                                    Label("Delete Preset", systemImage: "trash")
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .disabled(!sanitizationManager.rules.enabled)
                        .opacity(sanitizationManager.rules.enabled ? 1 : 0.5)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("INSTRUCTIONS")
                                .font(OmoiFont.label(size: 10))
                                .foregroundStyle(Color.omoiMuted)

                            TextEditor(text: $sanitizationManager.rules.instructions)
                                .font(OmoiFont.body(size: 12))
                                .scrollContentBackground(.hidden)
                                .background(Color.omoiGray)
                                .foregroundStyle(Color.omoiWhite)
                                .frame(height: 80)
                                .disabled(!sanitizationManager.rules.enabled)
                                .opacity(sanitizationManager.rules.enabled ? 1 : 0.5)
                        }

                        Text("e.g., Remove email addresses, phone numbers, and names")
                            .font(OmoiFont.caption)
                            .foregroundStyle(Color.omoiMuted)

                        // Save current as preset button
                        if !sanitizationManager.rules.instructions.isEmpty {
                            Button(action: {
                                showSavePresetSheet = true
                            }) {
                                HStack {
                                    Image(systemName: "plus")
                                        .font(.system(size: 10, weight: .bold))
                                    Text("SAVE AS PRESET")
                                        .font(OmoiFont.label(size: 10))
                                }
                                .foregroundStyle(Color.omoiTeal)
                            }
                            .buttonStyle(.plain)
                            .disabled(!sanitizationManager.rules.enabled)
                            .opacity(sanitizationManager.rules.enabled ? 1 : 0.5)
                        }

                        // Auto-sanitize toggle
                        Toggle(isOn: $sanitizationManager.rules.autoSanitizeBeforePaste) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("AUTO-SANITIZE BEFORE PASTE")
                                    .font(OmoiFont.label(size: 11))
                                    .foregroundStyle(Color.omoiWhite)
                                Text("Apply sanitization automatically when auto-paste is enabled")
                                    .font(OmoiFont.caption)
                                    .foregroundStyle(Color.omoiMuted)
                            }
                        }
                        .toggleStyle(.switch)
                        .disabled(!sanitizationManager.rules.enabled)
                        .opacity(sanitizationManager.rules.enabled ? 1 : 0.5)
                    }
                }

                // Section: Preview
                privacySection(title: "PREVIEW") {
                    if let mostRecent = statsManager.sessions.first {
                        VStack(alignment: .leading, spacing: 12) {
                            // Original
                            VStack(alignment: .leading, spacing: 4) {
                                Text("ORIGINAL")
                                    .font(OmoiFont.label(size: 10))
                                    .foregroundStyle(Color.omoiMuted)

                                Text(mostRecent.text)
                                    .font(OmoiFont.body(size: 12))
                                    .foregroundStyle(Color.omoiOffWhite)
                                    .lineLimit(3)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.omoiGray)
                            }

                            // Sanitized
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("SANITIZED")
                                        .font(OmoiFont.label(size: 10))
                                        .foregroundStyle(Color.omoiMuted)
                                    Spacer()
                                    if isPreviewLoading {
                                        ProgressView()
                                            .scaleEffect(0.6)
                                    }
                                }

                                if let sanitized = previewSanitized {
                                    Text(sanitized)
                                        .font(OmoiFont.body(size: 12))
                                        .foregroundStyle(Color.omoiTeal)
                                        .lineLimit(3)
                                        .padding(12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.omoiTeal.opacity(0.1))
                                } else if let error = previewError {
                                    Text(error)
                                        .font(OmoiFont.body(size: 11))
                                        .foregroundStyle(Color.omoiOrange)
                                        .padding(12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.omoiOrange.opacity(0.1))
                                } else {
                                    Text("Click preview to test")
                                        .font(OmoiFont.body(size: 11))
                                        .foregroundStyle(Color.omoiMuted)
                                        .padding(12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.omoiGray)
                                }
                            }

                            Button(action: previewSanitization) {
                                Text("PREVIEW")
                                    .font(OmoiFont.label(size: 11))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(sanitizationManager.rules.enabled && !isPreviewLoading ? Color.omoiTeal : Color.omoiGray)
                                    .foregroundStyle(sanitizationManager.rules.enabled && !isPreviewLoading ? Color.omoiBlack : Color.omoiMuted)
                            }
                            .buttonStyle(.plain)
                            .disabled(!sanitizationManager.rules.enabled || isPreviewLoading)
                        }
                    } else {
                        Text("No transcriptions yet")
                            .font(OmoiFont.body(size: 12))
                            .foregroundStyle(Color.omoiMuted)
                    }
                }

                // Section: Batch Operations
                if !statsManager.sessions.isEmpty {
                    privacySection(title: "BATCH (\(selectedSessions.count) SELECTED)") {
                        VStack(alignment: .leading, spacing: 12) {
                            Button(action: { selectedSessions = Set(statsManager.sessions.map { $0.id }) }) {
                                Text("SELECT ALL")
                                    .font(OmoiFont.label(size: 10))
                                    .foregroundStyle(Color.omoiTeal)
                            }
                            .buttonStyle(.plain)

                            ScrollView {
                                VStack(spacing: 0) {
                                    ForEach(statsManager.sessions) { session in
                                        HStack(spacing: 12) {
                                            Rectangle()
                                                .fill(selectedSessions.contains(session.id) ? Color.omoiTeal : Color.omoiGray)
                                                .frame(width: 16, height: 16)
                                                .overlay(
                                                    selectedSessions.contains(session.id) ?
                                                        Image(systemName: "checkmark")
                                                            .font(.system(size: 10, weight: .bold))
                                                            .foregroundStyle(Color.omoiBlack)
                                                        : nil
                                                )

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(session.targetAppName?.uppercased() ?? "UNKNOWN")
                                                    .font(OmoiFont.label(size: 9))
                                                    .foregroundStyle(Color.omoiMuted)
                                                Text(session.text)
                                                    .font(OmoiFont.body(size: 11))
                                                    .foregroundStyle(Color.omoiOffWhite)
                                                    .lineLimit(1)
                                            }

                                            Spacer()

                                            if session.sanitizedText != nil {
                                                Rectangle()
                                                    .fill(Color.omoiGreen)
                                                    .frame(width: 8, height: 8)
                                            }
                                        }
                                        .padding(.vertical, 8)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            if selectedSessions.contains(session.id) {
                                                selectedSessions.remove(session.id)
                                            } else {
                                                selectedSessions.insert(session.id)
                                            }
                                        }
                                    }
                                }
                            }
                            .frame(maxHeight: 160)

                            Button(action: sanitizeSelected) {
                                HStack {
                                    Text("SANITIZE SELECTED")
                                        .font(OmoiFont.label(size: 11))
                                    if isSanitizingAll {
                                        Spacer()
                                        ProgressView()
                                            .scaleEffect(0.6)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(selectedSessions.isEmpty || isSanitizingAll || !sanitizationManager.rules.enabled ? Color.omoiGray : Color.omoiTeal)
                                .foregroundStyle(selectedSessions.isEmpty || isSanitizingAll || !sanitizationManager.rules.enabled ? Color.omoiMuted : Color.omoiBlack)
                            }
                            .buttonStyle(.plain)
                            .disabled(selectedSessions.isEmpty || isSanitizingAll || !sanitizationManager.rules.enabled)

                            if isSanitizingAll {
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        Rectangle()
                                            .fill(Color.omoiGray)
                                        Rectangle()
                                            .fill(Color.omoiTeal)
                                            .frame(width: geometry.size.width * (Double(sanitizationProgress) / Double(selectedSessions.count)))
                                    }
                                }
                                .frame(height: 4)
                            }
                        }
                    }
                }
            }
        }
        .omoiBackground()
        .onAppear {
            hasAccessibilityPermission = AccessibilityPermissions.hasAccessibilityPermission()
        }
        .sheet(isPresented: $showPermissionInstructionSheet) {
            PermissionInstructionSheet()
        }
        .sheet(isPresented: $showSavePresetSheet) {
            VStack(spacing: 20) {
                Text("SAVE PRESET")
                    .font(OmoiFont.heading(size: 16))
                    .foregroundStyle(Color.omoiWhite)

                TextField("Preset name", text: $newPresetName)
                    .textFieldStyle(.plain)
                    .font(OmoiFont.body(size: 14))
                    .padding(12)
                    .background(Color.omoiGray)
                    .foregroundStyle(Color.omoiWhite)

                HStack(spacing: 12) {
                    Button("Cancel") {
                        newPresetName = ""
                        showSavePresetSheet = false
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.omoiMuted)

                    Button("Save") {
                        if !newPresetName.isEmpty {
                            sanitizationManager.addPreset(
                                name: newPresetName,
                                instructions: sanitizationManager.rules.instructions
                            )
                            newPresetName = ""
                            showSavePresetSheet = false
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(newPresetName.isEmpty ? Color.omoiGray : Color.omoiTeal)
                    .foregroundStyle(newPresetName.isEmpty ? Color.omoiMuted : Color.omoiBlack)
                    .disabled(newPresetName.isEmpty)
                }
            }
            .padding(24)
            .background(Color.omoiDarkGray)
            .presentationDetents([.height(200)])
        }
        .alert("Preview Error", isPresented: $showPreviewError) {
            Button("OK") { showPreviewError = false }
        } message: {
            Text(previewError ?? "Unknown error")
        }
    }

    // MARK: - Helper

    @ViewBuilder
    private func privacySection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(OmoiFont.label(size: 10))
                .foregroundStyle(Color.omoiMuted)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.omoiDarkGray)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(Color.omoiGray),
                    alignment: .top
                )

            VStack(alignment: .leading) {
                content()
            }
            .padding(20)
            .background(Color.omoiDarkGray)
        }
    }

    // MARK: - Private Methods

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
        let sessionsToSanitize = statsManager.sessions.filter { selectedSessions.contains($0.id) }
        isSanitizingAll = true
        sanitizationProgress = 0

        Task {
            let apiService = APIService()

            for session in sessionsToSanitize {
                do {
                    let sanitized = try await apiService.sanitizeText(
                        text: session.text,
                        instructions: sanitizationManager.rules.instructions
                    )
                    await MainActor.run {
                        statsManager.updateSessionSanitized(session.id, sanitizedText: sanitized)
                        sanitizationProgress += 1
                    }
                } catch {
                    print("Error sanitizing session \(session.id): \(error)")
                    await MainActor.run {
                        sanitizationProgress += 1
                    }
                }
            }

            await MainActor.run {
                isSanitizingAll = false
                selectedSessions.removeAll()
            }
        }
    }
}
