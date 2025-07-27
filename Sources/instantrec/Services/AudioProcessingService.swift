import Foundation
import AVFoundation

/// 音声処理とフィルタリングを担当するサービス
class AudioProcessingService {
    
    enum NoiseReductionLevel: Float, CaseIterable {
        case none = 0.0
        case light = 0.3
        case medium = 0.6
        case aggressive = 0.9
        
        var displayName: String {
            switch self {
            case .none: return "なし"
            case .light: return "軽微"
            case .medium: return "標準"
            case .aggressive: return "強力"
            }
        }
    }
    
    enum AudioEnhancementMode: CaseIterable {
        case voiceEnhancement    // 音声強調
        case ambientPreservation // 環境音保持
        case balanced           // バランス型
        
        var displayName: String {
            switch self {
            case .voiceEnhancement: return "音声強調"
            case .ambientPreservation: return "環境音保持"
            case .balanced: return "バランス"
            }
        }
    }
    
    // MARK: - リアルタイム音声処理
    
    /// AGC（自動ゲイン制御）を適用 - 簡略版
    func applyAutomaticGainControl(buffer: AVAudioPCMBuffer, targetLevel: Float = -12.0) -> AVAudioPCMBuffer? {
        guard let floatChannelData = buffer.floatChannelData else { return nil }
        
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        
        for channel in 0..<channelCount {
            let channelData = floatChannelData[channel]
            
            // 簡単なRMS計算
            var sumOfSquares: Float = 0.0
            for frame in 0..<frameLength {
                let sample = channelData[frame]
                sumOfSquares += sample * sample
            }
            let rms = sqrt(sumOfSquares / Float(frameLength))
            
            // ゲイン計算
            let currentLevel = 20 * log10(rms + 1e-10)
            let gainNeeded = targetLevel - currentLevel
            let linearGain = pow(10, gainNeeded / 20)
            
            // ゲイン制限
            let limitedGain = min(max(linearGain, 0.1), 10.0)
            
            // ゲイン適用
            for frame in 0..<frameLength {
                channelData[frame] *= limitedGain
            }
        }
        
        return buffer
    }
    
    /// ノイズゲート（低音量部分のカット）
    func applyNoiseGate(buffer: AVAudioPCMBuffer, threshold: Float = -40.0, ratio: Float = 10.0) -> AVAudioPCMBuffer? {
        guard let floatChannelData = buffer.floatChannelData else { return nil }
        
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        let thresholdLinear = pow(10, threshold / 20)
        
        for channel in 0..<channelCount {
            let channelData = floatChannelData[channel]
            
            for frame in 0..<frameLength {
                let sample = abs(channelData[frame])
                
                if sample < thresholdLinear {
                    // 閾値以下の音声を減衰
                    channelData[frame] *= (1.0 / ratio)
                }
            }
        }
        
        return buffer
    }
    
    /// ハイパスフィルタ（低周波ノイズ除去）
    func applyHighPassFilter(buffer: AVAudioPCMBuffer, cutoffFrequency: Float = 80.0) -> AVAudioPCMBuffer? {
        guard let floatChannelData = buffer.floatChannelData else { return nil }
        
        let sampleRate = buffer.format.sampleRate
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        
        // 簡易ハイパスフィルタ（1次）
        let rc = 1.0 / (2.0 * Float.pi * cutoffFrequency)
        let dt = 1.0 / Float(sampleRate)
        let alpha = rc / (rc + dt)
        
        for channel in 0..<channelCount {
            let channelData = floatChannelData[channel]
            var previousInput: Float = 0.0
            var previousOutput: Float = 0.0
            
            for frame in 0..<frameLength {
                let currentInput = channelData[frame]
                let output = alpha * (previousOutput + currentInput - previousInput)
                
                channelData[frame] = output
                previousInput = currentInput
                previousOutput = output
            }
        }
        
        return buffer
    }
    
    /// 音声強調フィルタ（会話帯域の強調）
    func applyVoiceEnhancement(buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        // 300Hz-3400Hzの音声帯域を強調
        guard let highPassFiltered = applyHighPassFilter(buffer: buffer, cutoffFrequency: 300.0) else {
            return nil
        }
        
        // さらなる音声強調処理をここに追加可能
        return highPassFiltered
    }
    
    // MARK: - 後処理（録音完了後の処理）
    
    /// 録音完了後のファイル処理 - 簡略版
    func processRecordedFile(at url: URL, mode: AudioEnhancementMode, noiseReduction: NoiseReductionLevel) async throws -> URL {
        // 現在は単純にオリジナルファイルを返す
        // 将来的に音声処理を実装予定
        print("🎛️ Audio processing requested: mode=\(mode.displayName), noise=\(noiseReduction.displayName)")
        return url
    }
}

// MARK: - 設定クラス

class AudioProcessingSettings: ObservableObject {
    @Published var recordingMode: AudioProcessingService.AudioEnhancementMode = .balanced
    @Published var noiseReductionLevel: AudioProcessingService.NoiseReductionLevel = .medium
    @Published var enableRealTimeProcessing: Bool = true
    @Published var enablePostProcessing: Bool = false
    
    // ユーザー設定保存
    func saveSettings() {
        UserDefaults.standard.set(recordingMode.displayName, forKey: "audioProcessingMode")
        UserDefaults.standard.set(noiseReductionLevel.rawValue, forKey: "noiseReductionLevel")
        UserDefaults.standard.set(enableRealTimeProcessing, forKey: "enableRealTimeProcessing")
        UserDefaults.standard.set(enablePostProcessing, forKey: "enablePostProcessing")
    }
    
    func loadSettings() {
        // UserDefaultsから設定を読み込み
        // 実装詳細省略
    }
}