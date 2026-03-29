import SwiftUI

struct RetroView: View {
    @ObservedObject var statsManager: StatsManager
    @Binding var selectedTab: Int

    @State private var selectedDate = Date()
    @State private var analysisText: String = ""
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var showSaveSuccess = false
    @State private var showPipelineConfig = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("RETROSPECTIVE")
                    .font(OmoiFont.brand(size: 14))
                    .foregroundStyle(Color.omoiWhite)
                
                Spacer()
                
                CustomDatePicker(selection: $selectedDate)
                    .frame(width: 200)
                
                Button(action: { showPipelineConfig = true }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.omoiMuted)
                        .padding(8)
                        .background(Color.omoiDarkGray)
                        .overlay(Rectangle().stroke(Color.omoiGray, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .help("Configure Analysis Pipeline")
            }
            .padding(16)
            .background(Color.omoiDarkGray)
            
            // Content
            if isGenerating {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Analyzing your day...")
                        .font(OmoiFont.mono(size: 12))
                        .foregroundStyle(Color.omoiMuted)
                }
                .frame(maxHeight: .infinity)
            } else if analysisText.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.omoiTeal.opacity(0.5))
                    
                    Text("Generate a daily synthesis of your voice memos.")
                        .font(OmoiFont.body(size: 13))
                        .foregroundStyle(Color.omoiMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    let count = statsManager.sessions(for: selectedDate).count
                    Text("\(count) memos found for \(selectedDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(OmoiFont.label(size: 10))
                        .foregroundStyle(count > 0 ? Color.omoiGreen : Color.omoiOrange)
                    
                    Button(action: generateAnalysis) {
                        Text("GENERATE ANALYSIS")
                            .font(OmoiFont.label(size: 12))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(count > 0 ? Color.omoiTeal : Color.omoiGray)
                            .foregroundStyle(Color.omoiBlack)
                    }
                    .buttonStyle(.plain)
                    .disabled(count == 0)
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    Text(analysisText)
                        .font(OmoiFont.mono(size: 12))
                        .foregroundStyle(Color.omoiOffWhite)
                        .padding(20)
                        .textSelection(.enabled)
                }
            }
            
            // Footer Action
            if !analysisText.isEmpty {
                HStack {
                    if let error = errorMessage {
                        Text(error)
                            .font(OmoiFont.label(size: 10))
                            .foregroundStyle(Color.omoiOrange)
                    }
                    
                    Spacer()
                    
                    if showSaveSuccess {
                        Text("SAVED")
                            .font(OmoiFont.label(size: 10))
                            .foregroundStyle(Color.omoiGreen)
                            .padding(.trailing, 8)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    showSaveSuccess = false
                                }
                            }
                    }
                    
                    Button(action: { selectedTab = 4 }) {
                        HStack(spacing: 4) {
                            Image(systemName: "slider.horizontal.3")
                            Text("PROMPT")
                        }
                        .font(OmoiFont.label(size: 10))
                        .foregroundStyle(Color.omoiMuted)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(analysisText, forType: .string)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.on.doc")
                            Text("COPY")
                        }
                        .font(OmoiFont.label(size: 10))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.omoiDarkGray)
                        .overlay(
                            Rectangle()
                                .stroke(Color.omoiGray, lineWidth: 1)
                        )
                        .foregroundStyle(Color.omoiWhite)
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .background(Color.omoiBlack)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(Color.omoiGray),
                    alignment: .top
                )
            }
        }
        .background(Color.omoiBlack)
        .onChange(of: selectedDate) { newDate in
            loadSavedAnalysis(for: newDate)
        }
        .onAppear {
            loadSavedAnalysis(for: selectedDate)
        }
        .sheet(isPresented: $showPipelineConfig) {
            VStack(spacing: 0) {
                HStack {
                    Text("CONFIGURE PIPELINE")
                        .font(OmoiFont.label(size: 12))
                        .foregroundStyle(Color.omoiMuted)
                    Spacer()
                    Button("Done") { showPipelineConfig = false }
                        .buttonStyle(.plain)
                        .font(OmoiFont.label(size: 12))
                        .foregroundStyle(Color.omoiTeal)
                }
                .padding(16)
                .background(Color.omoiDarkGray)
                
                PipelinesView(statsManager: statsManager)
            }
            .frame(width: 500, height: 600)
        }
    }
    
    // MARK: - Actions
    
    private func loadSavedAnalysis(for date: Date) {
        if let saved = statsManager.loadRetrospective(for: date) {
            analysisText = saved
        } else {
            analysisText = ""
        }
        errorMessage = nil
    }
    
    private func generateAnalysis() {
        let sessions = statsManager.sessions(for: selectedDate)
        guard !sessions.isEmpty else { return }
        
        isGenerating = true
        errorMessage = nil
        
        // Get custom prompt from manager
        let customPrompt = SanitizationManager.shared.retrospectivePrompt
        
        Task {
            do {
                let result = try await OllamaService.shared.generateRetrospective(
                    sessions: sessions,
                    customPrompt: customPrompt.isEmpty ? nil : customPrompt
                )
                
                await MainActor.run {
                    self.analysisText = result
                    self.isGenerating = false
                    // Auto-save on success
                    self.statsManager.saveRetrospective(result, for: selectedDate)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Analysis failed: \(error.localizedDescription)"
                    self.isGenerating = false
                }
            }
        }
    }
    
    private func saveToOffice() {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        let officeDir = home.appendingPathComponent("Scurving/Office/Daily")
        
        // Ensure directory exists
        do {
            try fileManager.createDirectory(at: officeDir, withIntermediateDirectories: true)
            
            let dateStr = selectedDate.formatted(.iso8601.year().month().day().dateSeparator(.dash))
            let filename = "\(dateStr)-Retro.md"
            let fileURL = officeDir.appendingPathComponent(filename)
            
            let header = "# Daily Retrospective: \(selectedDate.formatted(date: .long, time: .omitted))\n\n"
            let content = header + analysisText
            
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            
            print("Saved retrospective to: \(fileURL.path)")
            showSaveSuccess = true
            
        } catch {
            print("Failed to save retrospective: \(error)")
            errorMessage = "Save failed: check permissions"
        }
    }
}
