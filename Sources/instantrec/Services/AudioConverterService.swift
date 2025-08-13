import Foundation
import AVFoundation

/// 音声ファイル変換サービス
class AudioConverterService {
    
    // MARK: - Singleton
    
    static let shared = AudioConverterService()
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// M4AファイルをMP3に変換（共有用）
    /// - Parameters:
    ///   - sourceURL: 元のM4Aファイル
    ///   - quality: MP3品質設定
    /// - Returns: 変換されたMP3ファイルのURL
    func convertToMP3(sourceURL: URL, quality: MP3Quality = .standard) async throws -> URL {
        print("🎵 AudioConverter: Converting \(sourceURL.lastPathComponent) to MP3")
        
        // 出力ファイルのパスを生成
        let outputURL = generateMP3OutputURL(from: sourceURL)
        
        // 既存のファイルを削除
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            // AVAssetを作成
            let asset = AVURLAsset(url: sourceURL)
            
            // エクスポートセッションを作成
            guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetMediumQuality) else {
                continuation.resume(throwing: AudioConversionError.exportSessionCreationFailed)
                return
            }
            
            // 出力設定
            exportSession.outputURL = outputURL
            exportSession.outputFileType = .mp3
            exportSession.shouldOptimizeForNetworkUse = true
            
            // MP3品質に応じた設定
            exportSession.audioSettings = quality.audioSettings
            
            // 変換実行
            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed:
                    print("✅ AudioConverter: MP3 conversion completed")
                    continuation.resume(returning: outputURL)
                    
                case .failed:
                    let error = exportSession.error ?? AudioConversionError.conversionFailed
                    print("❌ AudioConverter: MP3 conversion failed: \(error)")
                    continuation.resume(throwing: error)
                    
                case .cancelled:
                    print("⏹️ AudioConverter: MP3 conversion cancelled")
                    continuation.resume(throwing: AudioConversionError.conversionCancelled)
                    
                default:
                    print("⚠️ AudioConverter: Unexpected export status: \(exportSession.status)")
                    continuation.resume(throwing: AudioConversionError.unexpectedStatus)
                }
            }
        }
    }
    
    /// 音声ファイル情報を取得
    /// - Parameter fileURL: 音声ファイルのURL
    /// - Returns: ファイル情報
    func getAudioFileInfo(url: URL) async throws -> AudioFileInfo {
        let asset = AVURLAsset(url: url)
        
        // ファイルの基本情報を取得
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        
        // ファイルサイズを取得
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        
        // オーディオトラック情報を取得
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        let format = try await audioTracks.first?.load(.formatDescriptions).first
        
        var bitrate: Int = 0
        var channels: Int = 0
        var sampleRate: Double = 0
        
        if let formatDescription = format {
            let audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
            if let basicDescription = audioStreamBasicDescription {
                sampleRate = basicDescription.pointee.mSampleRate
                channels = Int(basicDescription.pointee.mChannelsPerFrame)
                
                // ビットレートを計算（概算）
                bitrate = Int(Double(fileSize * 8) / durationSeconds)
            }
        }
        
        return AudioFileInfo(
            duration: durationSeconds,
            fileSize: fileSize,
            bitrate: bitrate,
            sampleRate: sampleRate,
            channels: channels,
            format: url.pathExtension.uppercased()
        )
    }
    
    /// 一時変換ファイルをクリーンアップ
    func cleanupTemporaryFiles() {
        let tempDir = FileManager.default.temporaryDirectory
        let mp3TempDir = tempDir.appendingPathComponent("mp3_conversions")
        
        do {
            if FileManager.default.fileExists(atPath: mp3TempDir.path) {
                let files = try FileManager.default.contentsOfDirectory(at: mp3TempDir, includingPropertiesForKeys: nil)
                
                for file in files {
                    try FileManager.default.removeItem(at: file)
                }
                
                print("🧹 AudioConverter: Cleaned up \(files.count) temporary files")
            }
        } catch {
            print("⚠️ AudioConverter: Failed to clean up temporary files: \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    private func generateMP3OutputURL(from sourceURL: URL) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let mp3TempDir = tempDir.appendingPathComponent("mp3_conversions")
        
        // ディレクトリが存在しない場合は作成
        if !FileManager.default.fileExists(atPath: mp3TempDir.path) {
            try? FileManager.default.createDirectory(at: mp3TempDir, withIntermediateDirectories: true)
        }
        
        let fileName = sourceURL.deletingPathExtension().lastPathComponent
        let mp3FileName = "\(fileName).mp3"
        
        return mp3TempDir.appendingPathComponent(mp3FileName)
    }
}

// MARK: - Supporting Types

/// MP3変換品質設定
enum MP3Quality: String, CaseIterable, Identifiable {
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
    
    var estimatedSizeMultiplier: Double {
        switch self {
        case .high: return 1.2  // 高音質は元ファイルより少し大きい
        case .standard: return 0.8  // 標準は約20%小さい
        case .compact: return 0.4   // コンパクトは約60%小さい
        }
    }
}

/// 音声ファイル情報
struct AudioFileInfo {
    let duration: TimeInterval
    let fileSize: Int64
    let bitrate: Int
    let sampleRate: Double
    let channels: Int
    let format: String
    
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var technicalDescription: String {
        return "\(format) • \(formattedFileSize) • \(bitrate/1000)kbps • \(Int(sampleRate/1000))kHz"
    }
}

/// 音声変換エラー
enum AudioConversionError: LocalizedError {
    case exportSessionCreationFailed
    case conversionFailed
    case conversionCancelled
    case unexpectedStatus
    case fileNotFound
    case unsupportedFormat
    
    var errorDescription: String? {
        switch self {
        case .exportSessionCreationFailed:
            return "変換セッションの作成に失敗しました"
        case .conversionFailed:
            return "音声変換に失敗しました"
        case .conversionCancelled:
            return "変換がキャンセルされました"
        case .unexpectedStatus:
            return "予期しないエラーが発生しました"
        case .fileNotFound:
            return "音声ファイルが見つかりません"
        case .unsupportedFormat:
            return "サポートされていない音声形式です"
        }
    }
}