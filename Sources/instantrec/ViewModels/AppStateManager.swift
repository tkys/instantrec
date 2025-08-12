import SwiftUI
import SwiftData
import AVFoundation

/// Tab enumeration for navigation
enum Tab: String, CaseIterable {
    case recording = "recording"
    case list = "list"
    case settings = "settings"
    
    var displayName: String {
        switch self {
        case .recording: return "Record"
        case .list: return "List"
        case .settings: return "Settings"
        }
    }
    
    var systemImageName: String {
        switch self {
        case .recording: return "mic"
        case .list: return "list.bullet"
        case .settings: return "gear"
        }
    }
}

/// Global State Manager with centralized lifecycle management
@MainActor
class AppStateManager: ObservableObject {
    @Published var currentTab: Tab = .recording
    @Published var isRecording = false
    @Published var currentRecording: Recording?
    @Published var audioLevel: Float = 0.0
    @Published var recordingDuration: TimeInterval = 0.0
    @Published var appState: AppLifecycleState = .background
    
    // Shared service instances
    let recordingViewModel = RecordingViewModel()
    let settings = RecordingSettings.shared
    let playbackManager = PlaybackManager.shared
    let whisperService = WhisperKitTranscriptionService.shared
    
    // Background task management
    private var backgroundTasks: [String: Task<Void, Error>] = [:]
    private var lifecycleTimer: Timer?
    
    init() {
        setupLifecycleObservers()
    }
    
    deinit {
        lifecycleTimer?.invalidate()
        Task { @MainActor in
            self.cancelAllBackgroundTasks()
        }
    }
    
    // MARK: - Lifecycle Management
    
    private func setupLifecycleObservers() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { await self.handleAppWillEnterForeground() }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { await self.handleAppDidEnterBackground() }
        }
    }
    
    private func handleAppWillEnterForeground() async {
        appState = .foreground
        await refreshRecordingState()
        await resumeBackgroundTasks()
    }
    
    private func handleAppDidEnterBackground() async {
        appState = .background
        await pauseNonCriticalTasks()
        await saveCurrentState()
    }
    
    // MARK: - Background Task Management
    
    func startBackgroundTask(_ name: String, task: @escaping () async throws -> Void) {
        backgroundTasks[name] = Task {
            do {
                try await task()
            } catch {
                print("❌ Background task '\(name)' failed: \(error)")
            }
            backgroundTasks.removeValue(forKey: name)
        }
    }
    
    func cancelBackgroundTask(_ name: String) {
        backgroundTasks[name]?.cancel()
        backgroundTasks.removeValue(forKey: name)
    }
    
    @MainActor
    private func cancelAllBackgroundTasks() {
        for task in backgroundTasks.values {
            task.cancel()
        }
        backgroundTasks.removeAll()
    }
    
    // MARK: - State Management
    
    private func refreshRecordingState() async {
        isRecording = recordingViewModel.isRecording
        // Note: RecordingViewModel doesn't have currentRecording property
        // currentRecording is managed directly in AppStateManager
    }
    
    private func pauseNonCriticalTasks() async {
        // Pause transcription if not critical
        cancelBackgroundTask("transcription")
        // Keep recording and cloud sync active
    }
    
    private func resumeBackgroundTasks() async {
        // Resume any paused background operations
        if appState == .foreground {
            // Resume transcription processing
            await processQueuedTranscriptions()
        }
    }
    
    private func saveCurrentState() async {
        // Save any pending state changes
        settings.save()
    }
    
    // MARK: - Async Operations
    
    private func processQueuedTranscriptions() async {
        startBackgroundTask("transcription") {
            // Process any queued transcriptions
            // TODO: Implement queue-based transcription processing
            print("🔄 Processing queued transcriptions...")
        }
    }
    
    // MARK: - Transcription Management
    
    func transcribeRecording(_ recording: Recording, at audioURL: URL) async {
        guard !whisperService.isTranscribing else {
            print("🚫 Transcription already in progress, skipping")
            return
        }
        
        startBackgroundTask("transcription_\(recording.id)") {
            do {
                try await self.whisperService.transcribeAudioFile(at: audioURL)
                
                await MainActor.run {
                    if !self.whisperService.transcriptionText.isEmpty {
                        recording.transcription = self.whisperService.transcriptionText
                        recording.transcriptionDate = Date()
                        print("✅ Transcription completed: \(self.whisperService.transcriptionText.prefix(100))...")
                    }
                }
            } catch {
                print("❌ Transcription failed: \(error)")
                await MainActor.run {
                    recording.transcription = "Failed to transcribe: \(error.localizedDescription)"
                    recording.transcriptionDate = Date()
                }
            }
        }
    }
    
    // MARK: - Cloud Sync Management
    
    func syncRecordingToCloud(_ recording: Recording, at audioURL: URL) async {
        startBackgroundTask("cloud_sync_\(recording.id)") {
            recording.cloudSyncStatus = .uploading
            
            do {
                // Simulate cloud upload - replace with actual GoogleDriveService call
                try await Task.sleep(for: .seconds(2))
                
                await MainActor.run {
                    recording.cloudSyncStatus = .synced
                    print("☁️ Recording synced to cloud: \(recording.fileName)")
                }
            } catch {
                await MainActor.run {
                    recording.cloudSyncStatus = .error
                    recording.syncErrorMessage = error.localizedDescription
                    print("❌ Cloud sync failed: \(error)")
                }
            }
        }
    }
}

// MARK: - App Lifecycle State

enum AppLifecycleState {
    case foreground
    case background
    case inactive
}