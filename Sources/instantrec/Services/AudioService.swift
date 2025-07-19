
import Foundation
import AVFoundation

class AudioService: ObservableObject {
    var audioRecorder: AVAudioRecorder?
    var audioPlayer: AVAudioPlayer?
    @Published var permissionGranted = false
    @Published var audioLevel: Float = 0.0
    
    init() {
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error.localizedDescription)")
        }
    }
    
    func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    self.permissionGranted = granted
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func startRecording(fileName: String) -> URL? {
        guard permissionGranted else {
            print("Microphone permission not granted")
            return nil
        }
        
        do {
            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            let url = getDocumentsDirectory().appendingPathComponent(fileName)
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()
            return url
        } catch {
            print("Failed to start recording: \(error.localizedDescription)")
            return nil
        }
    }

    func stopRecording() {
        audioRecorder?.stop()
        audioLevel = 0.0
        audioRecorder = nil
    }
    
    func updateAudioLevel() {
        guard let recorder = audioRecorder, recorder.isRecording else {
            audioLevel = 0.0
            return
        }
        
        recorder.updateMeters()
        let averagePower = recorder.averagePower(forChannel: 0)
        let normalizedLevel = pow(10.0, averagePower / 20.0)
        audioLevel = max(0.0, min(1.0, normalizedLevel))
    }

    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
}
