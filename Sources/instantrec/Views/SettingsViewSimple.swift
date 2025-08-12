import SwiftUI

struct SettingsViewSimple: View {
    @StateObject private var recordingSettings = RecordingSettings.shared
    
    var body: some View {
        NavigationView {
            Form {
                Section("Recording Behavior") {
                    Text("Start Mode: \(recordingSettings.recordingStartMode.displayName)")
                    Text("Recording Mode: Balance") // Placeholder
                }
                
                Section("Audio & AI") {
                    Text("Noise Reduction: Medium") // Placeholder
                    Text("Auto Transcription: Enabled") // Placeholder
                }
                
                Section("Cloud & Sync") {
                    Text("Google Drive: Not Connected") // Placeholder
                }
            }
            .navigationTitle("Settings")
        }
    }
}