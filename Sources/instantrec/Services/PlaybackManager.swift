import Foundation
import AVFoundation
import SwiftUI

class PlaybackManager: ObservableObject {
    static let shared = PlaybackManager()
    
    @Published var currentPlayingRecording: Recording?
    @Published var isPlaying: Bool = false
    @Published var playbackProgress: Double = 0.0
    @Published var currentPlaybackTime: String = "00:00"
    @Published var totalPlaybackTime: String = "00:00"
    @Published var playbackRate: Float = 1.0
    
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    
    // 再生速度オプション
    let availablePlaybackRates: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
    
    private init() {}
    
    func play(recording: Recording) {
        print("🎵 PlaybackManager: Starting playback for \(recording.fileName)")
        
        // 別の録音が再生中の場合は停止
        if let currentRecording = currentPlayingRecording, 
           currentRecording.id != recording.id {
            stop()
        }
        
        // 同じ録音の場合は一時停止/再開
        if currentPlayingRecording?.id == recording.id {
            if isPlaying {
                pause()
            } else {
                resume()
            }
            return
        }
        
        // 新しい録音の再生開始
        setupPlayer(for: recording)
        audioPlayer?.play()
        startTimer()
        
        currentPlayingRecording = recording
        isPlaying = true
        
        print("✅ Playback started for: \(recording.fileName)")
    }
    
    func pause() {
        print("⏸️ Pausing playback")
        audioPlayer?.pause()
        timer?.invalidate()
        isPlaying = false
    }
    
    func resume() {
        print("▶️ Resuming playback")
        audioPlayer?.play()
        startTimer()
        isPlaying = true
    }
    
    func stop() {
        print("⏹️ Stopping playback")
        audioPlayer?.stop()
        timer?.invalidate()
        isPlaying = false
        currentPlayingRecording = nil
        playbackProgress = 0.0
        currentPlaybackTime = "00:00"
        totalPlaybackTime = "00:00"
        playbackRate = 1.0
    }
    
    func seek(to progress: Double) {
        guard let player = audioPlayer else { return }
        
        let targetTime = progress * player.duration
        player.currentTime = targetTime
        playbackProgress = progress
        currentPlaybackTime = formatTime(targetTime)
        
        print("⏯️ Seeking to: \(formatTime(targetTime))")
    }
    
    func setPlaybackRate(_ rate: Float) {
        guard availablePlaybackRates.contains(rate) else { 
            print("⚠️ Invalid playback rate: \(rate)")
            return 
        }
        
        playbackRate = rate
        audioPlayer?.rate = rate
        
        print("🎵 Playback rate set to: \(rate)x")
    }
    
    private func setupPlayer(for recording: Recording) {
        let audioService = AudioService()
        let url = audioService.getDocumentsDirectory().appendingPathComponent(recording.fileName)
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.enableRate = true  // 再生速度変更を有効化
            audioPlayer?.rate = playbackRate  // 現在の再生速度を適用
            totalPlaybackTime = formatTime(audioPlayer?.duration ?? 0)
            currentPlaybackTime = "00:00"
            playbackProgress = 0.0
        } catch {
            print("❌ Error setting up player: \(error.localizedDescription)")
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateProgress()
        }
    }
    
    private func updateProgress() {
        guard let player = audioPlayer else { return }
        
        if player.duration > 0 {
            playbackProgress = player.currentTime / player.duration
            currentPlaybackTime = formatTime(player.currentTime)
        }
        
        // 再生終了の検出
        if !player.isPlaying && playbackProgress < 1.0 {
            // 一時停止状態
        } else if playbackProgress >= 1.0 || !player.isPlaying {
            // 再生完了
            stop()
        }
    }
    
    func isPlayingRecording(_ recording: Recording) -> Bool {
        return currentPlayingRecording?.id == recording.id && isPlaying
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}