import SwiftUI

struct RecordingModeSelectionView: View {
    @StateObject private var settings = RecordingSettings.shared
    @State private var selectedMode: RecordingStartMode = .manual
    @State private var showingInstantRecordingConsent = false
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // ヘッダー
                VStack(spacing: 16) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.blue)
                    
                    Text("InstantRec")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("録音開始方式を選択してください")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 32)
                
                // 方式選択リスト
                VStack(spacing: 16) {
                    ForEach(RecordingStartMode.allCases) { mode in
                        RecordingModeCard(
                            mode: mode,
                            isSelected: selectedMode == mode
                        ) {
                            selectedMode = mode
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // 決定ボタン
                Button(action: {
                    if selectedMode == .instantStart {
                        showingInstantRecordingConsent = true
                    } else {
                        confirmModeSelection()
                    }
                }) {
                    Text("この方式で開始")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .navigationBarHidden(true)
        }
        .alert("即録音方式の確認", isPresented: $showingInstantRecordingConsent) {
            Button("キャンセル", role: .cancel) { }
            Button("同意して続行") {
                settings.userConsentForInstantRecording = true
                confirmModeSelection()
            }
        } message: {
            Text("即録音方式では、アプリを開くと同時に録音が開始されます。この動作に同意しますか？設定画面でいつでも変更できます。")
        }
    }
    
    private func confirmModeSelection() {
        settings.recordingStartMode = selectedMode
        settings.isFirstLaunch = false
        
        print("✅ Recording mode selected: \(selectedMode.displayName)")
        print("✅ User consent for instant recording: \(settings.userConsentForInstantRecording)")
        
        isPresented = false
    }
}

struct RecordingModeCard: View {
    let mode: RecordingStartMode
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // アイコン
                Image(systemName: mode.icon)
                    .font(.system(size: 28))
                    .foregroundColor(isSelected ? .white : .blue)
                    .frame(width: 44, height: 44)
                
                // テキスト情報
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.displayName)
                        .font(.headline)
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Text(mode.description)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                        .multilineTextAlignment(.leading)
                    
                    // 警告文言（即録音方式のみ）
                    if let warningText = mode.warningText {
                        Text(warningText)
                            .font(.caption2)
                            .foregroundColor(isSelected ? .yellow.opacity(0.9) : .orange)
                            .multilineTextAlignment(.leading)
                            .padding(.top, 4)
                    }
                }
                
                Spacer()
                
                // 選択インジケーター
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    RecordingModeSelectionView(isPresented: .constant(true))
}