import Foundation
import AVFoundation

/// セグメント録音サービス - 長時間録音の安定性向上
class SegmentedRecordingService: ObservableObject {
    
    // MARK: - 設定
    
    /// セグメント最大時間（秒）
    private let maxSegmentDuration: TimeInterval = 900 // 15分
    
    /// 最小セグメント時間（秒）- 短すぎるセグメントを防ぐ
    private let minSegmentDuration: TimeInterval = 60 // 1分
    
    // MARK: - 状態管理
    
    @Published var isRecording = false
    @Published var currentSegmentIndex = 0
    @Published var totalDuration: TimeInterval = 0
    @Published var segmentCount = 0
    
    private var currentAudioService: AudioService?
    private var segmentURLs: [URL] = []
    private var segmentTimer: Timer?
    private var totalStartTime: Date?
    private var currentSegmentStartTime: Date?
    
    // MARK: - メタデータ
    
    struct SegmentInfo {
        let index: Int
        let url: URL
        let duration: TimeInterval
        let startTime: Date
        let endTime: Date
        let fileSize: Int64
    }
    
    private var segmentInfos: [SegmentInfo] = []
    
    // MARK: - 録音制御
    
    /// セグメント録音開始
    func startSegmentedRecording(baseName: String) -> Bool {
        guard !isRecording else {
            print("⚠️ Segmented recording already in progress")
            return false
        }
        
        print("🎬 Starting segmented recording: \(baseName)")
        
        // 初期化
        reset()
        totalStartTime = Date()
        
        // 最初のセグメント開始
        let success = startNewSegment(baseName: baseName)
        
        if success {
            isRecording = true
            setupSegmentTimer(baseName: baseName)
            print("✅ Segmented recording started successfully")
        } else {
            print("❌ Failed to start segmented recording")
        }
        
        return success
    }
    
    /// セグメント録音停止
    func stopSegmentedRecording() -> [URL] {
        guard isRecording else {
            print("⚠️ No segmented recording in progress")
            return []
        }
        
        print("🛑 Stopping segmented recording...")
        
        // タイマー停止
        segmentTimer?.invalidate()
        segmentTimer = nil
        
        // 現在のセグメント停止
        stopCurrentSegment()
        
        isRecording = false
        
        print("✅ Segmented recording stopped. Total segments: \(segmentURLs.count)")
        
        return segmentURLs
    }
    
    // MARK: - セグメント管理
    
    /// 新しいセグメント開始
    private func startNewSegment(baseName: String) -> Bool {
        // 前のセグメントを停止
        if currentAudioService != nil {
            stopCurrentSegment()
        }
        
        // 新しいAudioService作成と権限設定
        currentAudioService = AudioService()
        currentAudioService?.permissionGranted = true // セグメント録音では事前に権限が確認済み
        
        // セグメントファイル名生成
        let segmentFileName = generateSegmentFileName(baseName: baseName, index: currentSegmentIndex)
        
        print("🎵 Starting segment \(currentSegmentIndex): \(segmentFileName)")
        
        // 録音開始
        currentSegmentStartTime = Date()
        
        if let segmentURL = currentAudioService?.startRecording(fileName: segmentFileName) {
            segmentURLs.append(segmentURL)
            currentSegmentIndex += 1
            segmentCount = currentSegmentIndex
            
            print("✅ Segment \(currentSegmentIndex - 1) started: \(segmentURL.lastPathComponent)")
            return true
        } else {
            print("❌ Failed to start segment \(currentSegmentIndex)")
            return false
        }
    }
    
    /// 現在のセグメント停止
    private func stopCurrentSegment() {
        guard let audioService = currentAudioService,
              let startTime = currentSegmentStartTime else {
            return
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        let durationStr = String(format: "%.1f", duration)
        print("🛑 Stopping current segment. Duration: \(durationStr)s")
        
        // 短すぎるセグメントのチェック
        if duration < minSegmentDuration {
            let durationStr = String(format: "%.1f", duration)
            print("⚠️ Segment too short (\(durationStr)s), minimum is \(minSegmentDuration)s")
        }
        
        audioService.stopRecording()
        
        // セグメント情報を記録
        if let lastURL = segmentURLs.last {
            let segmentInfo = SegmentInfo(
                index: segmentURLs.count - 1,
                url: lastURL,
                duration: duration,
                startTime: startTime,
                endTime: endTime,
                fileSize: getFileSize(url: lastURL)
            )
            segmentInfos.append(segmentInfo)
            
            // 総録音時間更新
            updateTotalDuration()
            
            let durationStr = String(format: "%.1f", duration)
            print("📊 Segment \(segmentInfo.index) info: \(durationStr)s, \(segmentInfo.fileSize / 1024)KB")
        }
        
        currentAudioService = nil
        currentSegmentStartTime = nil
    }
    
    /// セグメント自動切り替えタイマー設定
    private func setupSegmentTimer(baseName: String) {
        segmentTimer = Timer.scheduledTimer(withTimeInterval: maxSegmentDuration, repeats: true) { [weak self] _ in
            self?.rotateSegment(baseName: baseName)
        }
        
        print("⏰ Segment timer set for \(maxSegmentDuration)s intervals")
    }
    
    /// セグメント切り替え実行
    private func rotateSegment(baseName: String) {
        guard isRecording else { return }
        
        print("🔄 Rotating to next segment...")
        
        let success = startNewSegment(baseName: baseName)
        if !success {
            print("❌ Failed to rotate segment, stopping recording")
            _ = stopSegmentedRecording()
        }
    }
    
    // MARK: - ユーティリティ
    
    /// セグメントファイル名生成
    private func generateSegmentFileName(baseName: String, index: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestamp = formatter.string(from: Date())
        
        // baseName-timestamp-seg001.m4a
        return "\(baseName)-\(timestamp)-seg\(String(format: "%03d", index + 1)).m4a"
    }
    
    /// ファイルサイズ取得
    private func getFileSize(url: URL) -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            print("❌ Failed to get file size: \(error)")
            return 0
        }
    }
    
    /// 総録音時間更新
    private func updateTotalDuration() {
        guard let startTime = totalStartTime else { return }
        totalDuration = Date().timeIntervalSince(startTime)
    }
    
    /// リセット
    private func reset() {
        currentSegmentIndex = 0
        segmentCount = 0
        totalDuration = 0
        segmentURLs.removeAll()
        segmentInfos.removeAll()
        totalStartTime = nil
        currentSegmentStartTime = nil
    }
    
    // MARK: - セグメント結合
    
    /// セグメントを結合して単一ファイルに
    func mergeSegments(outputFileName: String) async throws -> URL {
        guard !segmentURLs.isEmpty else {
            throw RecordingError.noSegments
        }
        
        print("🔗 Merging \(segmentURLs.count) segments into: \(outputFileName)")
        
        let composition = AVMutableComposition()
        var currentTime = CMTime.zero
        
        for (index, segmentURL) in segmentURLs.enumerated() {
            let asset = AVURLAsset(url: segmentURL)
            
            do {
                let duration = try await asset.load(.duration)
                let range = CMTimeRange(start: .zero, duration: duration)
                
                try await composition.insertTimeRange(range, of: asset, at: currentTime)
                currentTime = CMTimeAdd(currentTime, duration)
                
                print("✅ Merged segment \(index + 1)/\(segmentURLs.count)")
                
            } catch {
                print("❌ Failed to merge segment \(index): \(error)")
                throw error
            }
        }
        
        // 出力URL生成
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let outputURL = documentsDirectory.appendingPathComponent(outputFileName)
        
        // 既存ファイル削除
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }
        
        // エクスポート
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
            throw RecordingError.exportFailed
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        
        await exportSession.export()
        
        if let error = exportSession.error {
            throw error
        }
        
        print("✅ Segments merged successfully: \(outputURL.lastPathComponent)")
        print("📊 Final file size: \(getFileSize(url: outputURL) / 1024)KB")
        
        return outputURL
    }
    
    /// セグメントファイル削除（結合後のクリーンアップ）
    func cleanupSegments() {
        print("🗑️ Cleaning up \(segmentURLs.count) segment files...")
        
        for segmentURL in segmentURLs {
            do {
                try FileManager.default.removeItem(at: segmentURL)
                print("🗑️ Deleted: \(segmentURL.lastPathComponent)")
            } catch {
                print("❌ Failed to delete segment: \(error)")
            }
        }
        
        segmentURLs.removeAll()
        segmentInfos.removeAll()
        print("✅ Segment cleanup completed")
    }
    
    // MARK: - 状態取得
    
    /// セグメント情報取得
    func getSegmentInfos() -> [SegmentInfo] {
        return segmentInfos
    }
    
    /// 録音統計取得
    func getRecordingStats() -> (totalDuration: TimeInterval, segmentCount: Int, totalSize: Int64) {
        let totalSize = segmentInfos.reduce(0) { $0 + $1.fileSize }
        return (totalDuration, segmentCount, totalSize)
    }
}

// MARK: - エラー定義

enum RecordingError: LocalizedError {
    case noSegments
    case exportFailed
    
    var errorDescription: String? {
        switch self {
        case .noSegments:
            return "No segments to merge"
        case .exportFailed:
            return "Failed to create export session"
        }
    }
}