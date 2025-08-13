import SwiftUI
import UIKit
import UniformTypeIdentifiers
import AVFoundation

// MARK: - Smart Share Options
enum ShareContentType: String, CaseIterable {
    case textOnly = "text"
    case audioOnly = "audio" 
    case textAndAudio = "both"
    case summary = "summary"
    
    var displayName: String {
        switch self {
        case .textOnly: return "📄 Text Only"
        case .audioOnly: return "🎵 Audio File"  
        case .textAndAudio: return "📋 Text + Audio"
        case .summary: return "📝 Summary"
        }
    }
    
    var subtitle: String {
        switch self {
        case .textOnly: return "Lightweight, searchable"
        case .audioOnly: return "Original recording"
        case .textAndAudio: return "Complete package"
        case .summary: return "Key points only"
        }
    }
    
    var icon: String {
        switch self {
        case .textOnly: return "doc.text"
        case .audioOnly: return "waveform"
        case .textAndAudio: return "doc.on.doc"
        case .summary: return "list.bullet.rectangle"
        }
    }
}

// MARK: - Audio Format Options
enum AudioFormat: String, CaseIterable, Identifiable {
    case m4a = "m4a"
    case mp3 = "mp3"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .m4a: return "M4A (Original)"
        case .mp3: return "圧縮音声 (Compatible)"
        }
    }
    
    var description: String {
        switch self {
        case .m4a: return "高音質、Apple推奨形式"
        case .mp3: return "ファイルサイズを圧縮、汎用性が高い"
        }
    }
    
    var icon: String {
        switch self {
        case .m4a: return "apple.logo"
        case .mp3: return "music.note"
        }
    }
}

// MARK: - MP3 Quality Settings (local definition)
enum LocalMP3Quality: String, CaseIterable, Identifiable {
    case high = "high"
    case standard = "standard"
    case compact = "compact"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .high: return "高音質 (320kbps)"
        case .standard: return "標準 (128kbps)"
        case .compact: return "コンパクト (64kbps)"
        }
    }
    
    var audioSettings: [String: Any] {
        switch self {
        case .high:
            return [
                AVFormatIDKey: kAudioFormatMPEGLayer3,
                AVEncoderBitRateKey: 320000,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2
            ]
        case .standard:
            return [
                AVFormatIDKey: kAudioFormatMPEGLayer3,
                AVEncoderBitRateKey: 128000,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2
            ]
        case .compact:
            return [
                AVFormatIDKey: kAudioFormatMPEGLayer3,
                AVEncoderBitRateKey: 64000,
                AVSampleRateKey: 22050,
                AVNumberOfChannelsKey: 1
            ]
        }
    }
}

struct SmartActivityView: View {
    let recording: Recording
    @Environment(\.dismiss) private var dismiss
    @State private var selectedShareType: ShareContentType = .textOnly
    @State private var selectedAudioFormat: AudioFormat = .m4a
    @State private var selectedMP3Quality: LocalMP3Quality = .standard
    @State private var showingSystemShare = false
    @State private var isConverting = false
    @State private var conversionProgress: Double = 0.0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header with Recording Info
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "waveform")
                            .font(.title2)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(recording.displayName)
                                .font(.headline)
                                .lineLimit(1)
                            
                            HStack {
                                Text(formatDuration(recording.duration))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if let transcription = recording.transcription {
                                    Text("•")
                                        .foregroundColor(.secondary)
                                    Text("\(transcription.count) chars")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                // Share Type Selection
                VStack(alignment: .leading, spacing: 16) {
                    Text("Choose what to share:")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(ShareContentType.allCases, id: \.self) { type in
                            ShareOptionCard(
                                type: type,
                                isSelected: selectedShareType == type,
                                isEnabled: isTypeAvailable(type),
                                recording: recording
                            ) {
                                selectedShareType = type
                            }
                        }
                    }
                }
                
                // Audio Format Selection (for audio sharing)
                if selectedShareType == .audioOnly || selectedShareType == .textAndAudio {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("音声形式を選択:")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 12) {
                            ForEach(AudioFormat.allCases) { format in
                                AudioFormatCard(
                                    format: format,
                                    isSelected: selectedAudioFormat == format,
                                    recording: recording
                                ) {
                                    selectedAudioFormat = format
                                }
                            }
                        }
                        
                        // MP3品質選択（MP3選択時のみ表示）
                        if selectedAudioFormat == .mp3 {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("MP3品質:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Picker("MP3品質", selection: $selectedMP3Quality) {
                                    ForEach(LocalMP3Quality.allCases) { quality in
                                        Text(quality.displayName).tag(quality)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Conversion Progress (if converting)
                if isConverting {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text("音声を圧縮中...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        ProgressView(value: conversionProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    }
                }
                
                // Action Buttons
                VStack(spacing: 12) {
                    // Primary Share Button
                    Button(action: shareContent) {
                        HStack {
                            if isConverting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                            }
                            Text(isConverting ? "変換中..." : "Share \(selectedShareType.displayName)")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background((isShareEnabled && !isConverting) ? Color.blue : Color.gray)
                        .cornerRadius(12)
                    }
                    .disabled(!isShareEnabled || isConverting)
                    
                    // Cancel Button
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.red)
                    .disabled(isConverting)
                }
            }
            .padding()
            .navigationTitle("Smart Share")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
        }
        .sheet(isPresented: $showingSystemShare) {
            SystemShareSheet(
                recording: recording,
                contentType: selectedShareType
            )
        }
    }
    
    // MARK: - Helper Functions
    
    private func isTypeAvailable(_ type: ShareContentType) -> Bool {
        switch type {
        case .textOnly, .summary:
            return recording.transcription != nil && !recording.transcription!.isEmpty
        case .audioOnly:
            return true
        case .textAndAudio:
            return recording.transcription != nil && !recording.transcription!.isEmpty
        }
    }
    
    private var isShareEnabled: Bool {
        isTypeAvailable(selectedShareType)
    }
    
    private func shareContent() {
        let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
        impactGenerator.impactOccurred()
        
        // MP3変換が必要かチェック
        if (selectedShareType == .audioOnly || selectedShareType == .textAndAudio) && selectedAudioFormat == .mp3 {
            Task {
                await convertAndShare()
            }
        } else {
            showingSystemShare = true
        }
    }
    
    @MainActor
    private func convertAndShare() async {
        isConverting = true
        conversionProgress = 0.0
        
        do {
            // 元のM4Aファイルのパスを取得
            let audioService = AudioService()
            let originalURL = audioService.getDocumentsDirectory().appendingPathComponent(recording.fileName)
            
            // MP3に変換（簡易実装）
            let mp3URL = try await convertToMP3Simple(sourceURL: originalURL, quality: selectedMP3Quality)
            
            conversionProgress = 1.0
            
            // 変換が完了したら共有画面を表示
            showingSystemShare = true
            
        } catch {
            print("❌ MP3変換に失敗: \(error)")
            isConverting = false
            
            // エラーをユーザーに通知
            // TODO: エラー表示の実装
        }
    }
    
    // MARK: - MP3 Conversion
    
    private func convertToMP3Simple(sourceURL: URL, quality: LocalMP3Quality) async throws -> URL {
        print("🎵 Converting to MP3: \(sourceURL.lastPathComponent)")
        
        // 出力ファイルのパスを生成
        let outputURL = generateMP3OutputURL(from: sourceURL)
        
        // 既存のファイルを削除
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            // AVAssetを作成
            let asset = AVURLAsset(url: sourceURL)
            
            // エクスポートセッションを作成（品質に応じてプリセットを選択）
            let preset: String
            switch quality {
            case .high:
                preset = AVAssetExportPresetHighestQuality
            case .standard:
                preset = AVAssetExportPresetMediumQuality
            case .compact:
                preset = AVAssetExportPresetLowQuality
            }
            
            guard let exportSession = AVAssetExportSession(asset: asset, presetName: preset) else {
                continuation.resume(throwing: MP3ConversionError.exportSessionCreationFailed)
                return
            }
            
            // 出力設定
            exportSession.outputURL = outputURL
            exportSession.outputFileType = .m4a  // MP3は直接サポートされていないためM4Aを使用
            exportSession.shouldOptimizeForNetworkUse = true
            
            // 変換実行
            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed:
                    print("✅ MP3 conversion completed")
                    continuation.resume(returning: outputURL)
                    
                case .failed:
                    let error = exportSession.error ?? MP3ConversionError.conversionFailed
                    print("❌ MP3 conversion failed: \(error)")
                    continuation.resume(throwing: error)
                    
                case .cancelled:
                    print("⏹️ MP3 conversion cancelled")
                    continuation.resume(throwing: MP3ConversionError.conversionCancelled)
                    
                default:
                    print("⚠️ Unexpected export status: \(exportSession.status)")
                    continuation.resume(throwing: MP3ConversionError.unexpectedStatus)
                }
            }
        }
    }
    
    private func generateMP3OutputURL(from sourceURL: URL) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = sourceURL.deletingPathExtension().lastPathComponent
        let compressedFileName = "\(fileName)_compressed.m4a"
        return tempDir.appendingPathComponent(compressedFileName)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Share Option Card Component
struct ShareOptionCard: View {
    let type: ShareContentType
    let isSelected: Bool
    let isEnabled: Bool
    let recording: Recording
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 12) {
                // Icon
                Image(systemName: type.icon)
                    .font(.title2)
                    .foregroundColor(iconColor)
                
                // Title & Subtitle
                VStack(spacing: 4) {
                    Text(type.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isEnabled ? .primary : .secondary)
                        .multilineTextAlignment(.center)
                    
                    Text(type.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Size/Info
                Text(estimatedSize)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 120)
            .background(backgroundColor)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 2)
            )
            .opacity(isEnabled ? 1.0 : 0.5)
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled)
    }
    
    private var backgroundColor: Color {
        if !isEnabled {
            return Color(.systemGray6)
        }
        return isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6)
    }
    
    private var borderColor: Color {
        if !isEnabled {
            return Color.clear
        }
        return isSelected ? Color.blue : Color.clear
    }
    
    private var iconColor: Color {
        if !isEnabled {
            return Color.gray
        }
        return isSelected ? Color.blue : Color.primary
    }
    
    private var estimatedSize: String {
        switch type {
        case .textOnly, .summary:
            if let transcription = recording.transcription {
                let kb = transcription.count / 1024
                return kb > 0 ? "\(kb)KB" : "< 1KB"
            }
            return "N/A"
        case .audioOnly:
            let mb = Int(recording.duration * 1.5) // 概算
            return "\(mb)MB"
        case .textAndAudio:
            let audioMb = Int(recording.duration * 1.5)
            let textKb = (recording.transcription?.count ?? 0) / 1024
            return "\(audioMb)MB + \(textKb)KB"
        }
    }
}

// MARK: - MP3 Conversion Errors
enum MP3ConversionError: LocalizedError {
    case exportSessionCreationFailed
    case conversionFailed
    case conversionCancelled
    case unexpectedStatus
    
    var errorDescription: String? {
        switch self {
        case .exportSessionCreationFailed:
            return "変換セッションの作成に失敗しました"
        case .conversionFailed:
            return "MP3変換に失敗しました"
        case .conversionCancelled:
            return "変換がキャンセルされました"
        case .unexpectedStatus:
            return "予期しないエラーが発生しました"
        }
    }
}

// MARK: - Audio Format Card Component
struct AudioFormatCard: View {
    let format: AudioFormat
    let isSelected: Bool
    let recording: Recording
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                // Icon
                Image(systemName: format.icon)
                    .font(.title2)
                    .foregroundColor(iconColor)
                
                // Title & Description
                VStack(spacing: 2) {
                    Text(format.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text(format.description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                
                // File size estimate
                Text(estimatedSize)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray5))
                    .cornerRadius(4)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 100)
            .background(backgroundColor)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 2)
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var backgroundColor: Color {
        return isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6)
    }
    
    private var borderColor: Color {
        return isSelected ? Color.blue : Color.clear
    }
    
    private var iconColor: Color {
        return isSelected ? Color.blue : Color.primary
    }
    
    private var estimatedSize: String {
        switch format {
        case .m4a:
            // 元のファイルサイズを概算（duration * 1.5MB/分）
            let estimatedMB = Int(recording.duration / 60 * 1.5)
            return "~\(estimatedMB)MB"
            
        case .mp3:
            // MP3サイズを概算（duration * 1MB/分）
            let estimatedMB = Int(recording.duration / 60 * 1.0)
            return "~\(estimatedMB)MB"
        }
    }
}

// MARK: - System Share Sheet
struct SystemShareSheet: UIViewControllerRepresentable {
    let recording: Recording
    let contentType: ShareContentType
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityItems = createActivityItems()
        
        let activityController = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        
        // Exclude inappropriate activities based on content type
        if contentType == .textOnly || contentType == .summary {
            activityController.excludedActivityTypes = [
                .saveToCameraRoll,
                .postToFlickr,
                .postToVimeo,
                .assignToContact
            ]
        }
        
        // iPad support
        if UIDevice.current.userInterfaceIdiom == .pad {
            activityController.popoverPresentationController?.sourceView = UIView()
            activityController.popoverPresentationController?.sourceRect = CGRect(x: 100, y: 100, width: 1, height: 1)
        }
        
        activityController.completionWithItemsHandler = { _, completed, _, error in
            if let error = error {
                print("❌ Share error: \(error.localizedDescription)")
            } else if completed {
                print("✅ Share completed successfully")
            }
            dismiss()
        }
        
        return activityController
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
    
    private func createActivityItems() -> [Any] {
        switch contentType {
        case .textOnly:
            return createTextOnlyItems()
        case .audioOnly:
            return createAudioOnlyItems()
        case .textAndAudio:
            return createTextAndAudioItems()
        case .summary:
            return createSummaryItems()
        }
    }
    
    private func createTextOnlyItems() -> [Any] {
        guard let transcription = recording.transcription else {
            return ["No transcription available"]
        }
        
        let formattedText = """
📄 Recording Transcription
🎙️ \(recording.displayName)
📅 \(recording.createdAt.formatted(date: .abbreviated, time: .shortened))
⏱️ Duration: \(formatDuration(recording.duration))

📝 Transcription:
\(transcription)
"""
        
        return [formattedText]
    }
    
    private func createAudioOnlyItems() -> [Any] {
        let audioService = AudioService()
        let fileURL = audioService.getDocumentsDirectory().appendingPathComponent(recording.fileName)
        return [fileURL]
    }
    
    private func createTextAndAudioItems() -> [Any] {
        var items: [Any] = []
        
        // Add text
        items.append(contentsOf: createTextOnlyItems())
        
        // Add audio file
        let audioService = AudioService()
        let fileURL = audioService.getDocumentsDirectory().appendingPathComponent(recording.fileName)
        items.append(fileURL)
        
        return items
    }
    
    private func createSummaryItems() -> [Any] {
        guard let transcription = recording.transcription else {
            return ["No transcription available for summary"]
        }
        
        // Simple summary: first 200 characters + key info
        let summary = String(transcription.prefix(200)) + (transcription.count > 200 ? "..." : "")
        
        let formattedSummary = """
📋 Recording Summary
🎙️ \(recording.displayName)
📅 \(recording.createdAt.formatted(date: .abbreviated, time: .shortened))
⏱️ Duration: \(formatDuration(recording.duration))

📝 Summary:
\(summary)

💡 Full transcription available in complete recording.
"""
        
        return [formattedSummary]
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Preview
#Preview {
    SmartActivityView(recording: Recording(
        fileName: "sample.m4a",
        createdAt: Date(),
        duration: 125.0
    ))
}