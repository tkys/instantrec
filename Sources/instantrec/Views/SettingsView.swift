import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = RecordingSettings.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingModeChangeAlert = false
    @State private var pendingMode: RecordingStartMode?
    
    var body: some View {
        NavigationView {
            Form {
                // 録音方式設定セクション
                Section(header: Text("録音開始方式")) {
                    ForEach(RecordingStartMode.allCases) { mode in
                        Button(action: {
                            if mode == .instantStart && !settings.userConsentForInstantRecording {
                                pendingMode = mode
                                showingModeChangeAlert = true
                            } else {
                                settings.recordingStartMode = mode
                            }
                        }) {
                            HStack {
                                Image(systemName: mode.icon)
                                    .foregroundColor(.blue)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(mode.displayName)
                                        .foregroundColor(.primary)
                                        .fontWeight(.medium)
                                    
                                    Text(mode.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.leading)
                                }
                                
                                Spacer()
                                
                                if settings.recordingStartMode == mode {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                // カウントダウン設定（カウントダウン方式選択時のみ表示）
                if settings.recordingStartMode == .countdown {
                    Section(header: Text("カウントダウン時間")) {
                        Picker("カウントダウン時間", selection: $settings.countdownDuration) {
                            ForEach(CountdownDuration.allCases) { duration in
                                Text(duration.displayName)
                                    .tag(duration)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                }
                
                // その他設定
                Section(header: Text("その他")) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        
                        Text("バージョン")
                        
                        Spacer()
                        
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: {
                        // リセット機能（デバッグ用）
                        settings.recordingStartMode = .manual
                        settings.userConsentForInstantRecording = false
                        settings.countdownDuration = .three
                        settings.isFirstLaunch = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.orange)
                            
                            Text("設定をリセット")
                                .foregroundColor(.primary)
                        }
                    }
                }
                
                // Apple審査対策の説明
                Section(footer: Text("録音開始方式は、Appleストアポリシーに準拠するため選択可能になっています。いつでも変更できます。")) {
                    EmptyView()
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
        .alert("即録音方式の確認", isPresented: $showingModeChangeAlert) {
            Button("キャンセル", role: .cancel) { 
                pendingMode = nil
            }
            Button("同意して変更") {
                if let mode = pendingMode {
                    settings.userConsentForInstantRecording = true
                    settings.recordingStartMode = mode
                    pendingMode = nil
                }
            }
        } message: {
            Text("即録音方式では、アプリを開くと同時に録音が開始されます。この動作に同意しますか？")
        }
    }
}

#Preview {
    SettingsView()
}