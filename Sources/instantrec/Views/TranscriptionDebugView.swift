import SwiftUI
import SwiftData

/// 文字起こし機能のデバッグ・検証画面
struct TranscriptionDebugView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Transcription Debug View")
                    .font(.headline)
                
                Text("Debug functionality temporarily simplified for build stability")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Spacer()
            }
            .navigationTitle("Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .padding()
        }
    }
}