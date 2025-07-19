
import SwiftUI
import AVFoundation

class PlaybackViewModel: ObservableObject {
    @Published var isPlaying = false
    @Published var playbackProgress: Double = 0.0
    @Published var currentPlaybackTime: String = "00:00"
    @Published var totalPlaybackTime: String = "00:00"

    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    var recording: Recording

    init(recording: Recording) {
        self.recording = recording
    }

    func setupPlayer() {
        let audioService = AudioService()
        let url = audioService.getDocumentsDirectory().appendingPathComponent(recording.fileName)
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            totalPlaybackTime = formatTime(audioPlayer?.duration ?? 0)
        } catch {
            print("Error setting up player: \(error.localizedDescription)")
        }
    }

    func togglePlayback() {
        if isPlaying {
            audioPlayer?.pause()
            timer?.invalidate()
        } else {
            audioPlayer?.play()
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                self?.updatePlaybackProgress()
            }
        }
        isPlaying.toggle()
    }

    func updatePlaybackProgress() {
        guard let player = audioPlayer else { return }
        playbackProgress = player.currentTime / player.duration
        currentPlaybackTime = formatTime(player.currentTime)
        if !player.isPlaying {
            isPlaying = false
            timer?.invalidate()
        }
    }

    func sliderEditingChanged(editingStarted: Bool) {
        if !editingStarted {
            guard let player = audioPlayer else { return }
            player.currentTime = playbackProgress * player.duration
            currentPlaybackTime = formatTime(player.currentTime)
        }
    }

    func stopPlayer() {
        audioPlayer?.stop()
        timer?.invalidate()
        isPlaying = false
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct PlaybackView: View {
    @StateObject private var viewModel: PlaybackViewModel

    init(recording: Recording) {
        _viewModel = StateObject(wrappedValue: PlaybackViewModel(recording: recording))
    }

    var body: some View {
        VStack {
            Text(viewModel.recording.fileName)
                .font(.headline)
                .padding()

            HStack {
                Text(viewModel.currentPlaybackTime)
                Slider(value: $viewModel.playbackProgress, in: 0...1, onEditingChanged: viewModel.sliderEditingChanged)
                    .accentColor(.accentColor)
                Text(viewModel.totalPlaybackTime)
            }
            .padding(.horizontal)

            Button(action: viewModel.togglePlayback) {
                Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .resizable()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.accentColor)
            }
        }
        .onAppear(perform: viewModel.setupPlayer)
        .onDisappear(perform: viewModel.stopPlayer)
    }
}
