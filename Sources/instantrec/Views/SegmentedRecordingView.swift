import SwiftUI

struct SegmentedRecordingView: View {
    @StateObject private var segmentedService = SegmentedRecordingService()
    @Environment(\.dismiss) private var dismiss
    
    @State private var baseName = ""
    @State private var showingMergeProgress = false
    @State private var mergeProgress = 0.0
    @State private var mergedFileURL: URL?
    @State private var errorMessage: String?
    @State private var showingError = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                
                // ヘッダー情報
                VStack(spacing: 12) {
                    Text("🎬 セグメント録音")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("15分ごとに自動分割し、最後に結合します")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // 録音状態表示
                if segmentedService.isRecording {
                    recordingStatusView
                } else {
                    recordingSetupView
                }
                
                // セグメント情報表示
                if !segmentedService.getSegmentInfos().isEmpty {
                    segmentInfoView
                }
                
                Spacer()
                
                // 制御ボタン
                controlButtonsView
                
            }
            .padding()
            .navigationTitle("セグメント録音")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .alert("エラー", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "不明なエラーが発生しました")
            }
            .sheet(isPresented: $showingMergeProgress) {
                mergeProgressView
            }
        }
    }
    
    // MARK: - 録音セットアップビュー
    
    private var recordingSetupView: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("録音ファイル名")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextField("例: meeting-20250127", text: $baseName)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("セグメント録音の特徴")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "timer")
                            .foregroundColor(.blue)
                        Text("15分ごとに自動分割")
                    }
                    .font(.caption)
                    
                    HStack {
                        Image(systemName: "shield.checkered")
                            .foregroundColor(.green)
                        Text("中断からの自動復帰")
                    }
                    .font(.caption)
                    
                    HStack {
                        Image(systemName: "link")
                            .foregroundColor(.orange)
                        Text("録音完了時に自動結合")
                    }
                    .font(.caption)
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(8)
        }
    }
    
    // MARK: - 録音状態ビュー
    
    private var recordingStatusView: some View {
        VStack(spacing: 16) {
            // 録音インジケーター
            HStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                    .opacity(0.8)
                    .scaleEffect(1.2)
                    .animation(.easeInOut(duration: 1).repeatForever(), value: segmentedService.isRecording)
                
                Text("録音中")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            // 時間表示
            VStack(spacing: 8) {
                Text(formatDuration(segmentedService.totalDuration))
                    .font(.title)
                    .fontWeight(.bold)
                    .monospacedDigit()
                
                Text("総録音時間")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // セグメント情報
            HStack(spacing: 32) {
                VStack {
                    Text("\(segmentedService.currentSegmentIndex)")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("現在セグメント")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(segmentedService.segmentCount)")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("総セグメント数")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - セグメント情報ビュー
    
    private var segmentInfoView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("セグメント一覧")
                .font(.headline)
                .fontWeight(.semibold)
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(segmentedService.getSegmentInfos().enumerated()), id: \.offset) { index, segmentInfo in
                        segmentRow(segmentInfo: segmentInfo)
                    }
                }
            }
            .frame(maxHeight: 200)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func segmentRow(segmentInfo: SegmentedRecordingService.SegmentInfo) -> some View {
        HStack {
            Text("Seg \(segmentInfo.index + 1)")
                .font(.caption)
                .fontWeight(.medium)
                .frame(width: 50, alignment: .leading)
            
            Text(formatDuration(segmentInfo.duration))
                .font(.caption)
                .monospacedDigit()
                .frame(width: 60, alignment: .leading)
            
            Text("\(segmentInfo.fileSize / 1024)KB")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            
            Spacer()
            
            Text(formatTime(segmentInfo.startTime))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
    
    // MARK: - 制御ボタン
    
    private var controlButtonsView: some View {
        VStack(spacing: 16) {
            if segmentedService.isRecording {
                // 録音停止ボタン
                Button {
                    stopRecording()
                } label: {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("録音停止")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                
            } else {
                // 録音開始ボタン
                Button {
                    startRecording()
                } label: {
                    HStack {
                        Image(systemName: "record.circle.fill")
                        Text("録音開始")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(baseName.isEmpty ? Color.gray : Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(baseName.isEmpty)
                
                // セグメント結合ボタン（セグメントがある場合）
                if !segmentedService.getSegmentInfos().isEmpty {
                    Button {
                        mergeSegments()
                    } label: {
                        HStack {
                            Image(systemName: "link")
                            Text("セグメント結合")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
    
    // MARK: - 結合進捗ビュー
    
    private var mergeProgressView: some View {
        VStack(spacing: 24) {
            Text("セグメント結合中...")
                .font(.headline)
                .fontWeight(.semibold)
            
            ProgressView(value: mergeProgress)
                .progressViewStyle(LinearProgressViewStyle())
            
            Text("\(Int(mergeProgress * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let mergedURL = mergedFileURL {
                VStack(spacing: 8) {
                    Text("✅ 結合完了")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    Text(mergedURL.lastPathComponent)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }
    
    // MARK: - アクション
    
    private func startRecording() {
        guard !baseName.isEmpty else { return }
        
        // 権限チェック
        Task {
            let audioService = AudioService()
            let granted = await audioService.requestMicrophonePermission()
            
            await MainActor.run {
                if granted {
                    let success = segmentedService.startSegmentedRecording(baseName: baseName)
                    if !success {
                        errorMessage = "録音の開始に失敗しました"
                        showingError = true
                    }
                } else {
                    errorMessage = "マイクの権限が必要です。設定アプリで権限を許可してください。"
                    showingError = true
                }
            }
        }
    }
    
    private func stopRecording() {
        let segmentURLs = segmentedService.stopSegmentedRecording()
        print("🛑 Recording stopped. Segments: \(segmentURLs.count)")
    }
    
    private func mergeSegments() {
        showingMergeProgress = true
        mergeProgress = 0.0
        
        Task {
            do {
                let outputFileName = "\(baseName)-merged-\(formatTimestamp()).m4a"
                
                // 進捗シミュレーション
                for i in 1...10 {
                    try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
                    await MainActor.run {
                        mergeProgress = Double(i) / 10.0
                    }
                }
                
                let mergedURL = try await segmentedService.mergeSegments(outputFileName: outputFileName)
                
                await MainActor.run {
                    mergedFileURL = mergedURL
                    mergeProgress = 1.0
                }
                
                // クリーンアップ
                segmentedService.cleanupSegments()
                
            } catch {
                await MainActor.run {
                    showingMergeProgress = false
                    errorMessage = "セグメント結合に失敗しました: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
    
    // MARK: - ユーティリティ
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}