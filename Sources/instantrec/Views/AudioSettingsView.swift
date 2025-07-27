import SwiftUI

struct AudioSettingsView: View {
    @StateObject private var audioSettings = AudioProcessingSettings()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // 録音シナリオ選択
                    VStack(alignment: .leading, spacing: 12) {
                        Text("🎯 録音シナリオ")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Text("録音する内容に最適化された設定を選択してください")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        recordingScenarioSection
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    // 音声処理設定
                    VStack(alignment: .leading, spacing: 12) {
                        Text("🎛️ 音声処理")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        audioProcessingSection
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    // ノイズ制御
                    VStack(alignment: .leading, spacing: 12) {
                        Text("🔇 ノイズ制御")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        noiseControlSection
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    // リアルタイム処理
                    VStack(alignment: .leading, spacing: 12) {
                        Text("⚡ リアルタイム処理")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        realTimeProcessingSection
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("🎙️ 音声設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        audioSettings.saveSettings()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            audioSettings.loadSettings()
        }
    }
    
    // MARK: - Recording Scenario Section
    
    private var recordingScenarioSection: some View {
        VStack(spacing: 16) {
            recordingScenarioCard(
                title: "🗣️ 会話・対話",
                description: "人の声を明瞭に録音\n背景ノイズを抑制",
                mode: .voiceEnhancement,
                recommended: "インタビュー、電話、打ち合わせに最適"
            )
            
            recordingScenarioCard(
                title: "🌍 環境音・自然音",
                description: "すべての音を忠実に録音\n自然な音響環境を保持",
                mode: .ambientPreservation,
                recommended: "鳥の鳴き声、街の音、楽器演奏に最適"
            )
            
            recordingScenarioCard(
                title: "⚖️ バランス型",
                description: "音声と環境音の両立\n適度なノイズ抑制",
                mode: .balanced,
                recommended: "一般的な録音、メモ録音に最適"
            )
        }
    }
    
    private func recordingScenarioCard(title: String, description: String, mode: AudioProcessingService.AudioEnhancementMode, recommended: String) -> some View {
        Button {
            audioSettings.recordingMode = mode
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    if audioSettings.recordingMode == mode {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                    } else {
                        Image(systemName: "circle")
                            .foregroundColor(.gray)
                    }
                }
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                Text(recommended)
                    .font(.caption2)
                    .foregroundColor(.blue)
                    .italic()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(audioSettings.recordingMode == mode ? Color.blue.opacity(0.1) : Color.clear)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(audioSettings.recordingMode == mode ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Audio Processing Section
    
    private var audioProcessingSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("処理モード")
                    .font(.subheadline)
                Spacer()
                Picker("処理モード", selection: $audioSettings.recordingMode) {
                    ForEach(AudioProcessingService.AudioEnhancementMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.menu)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("リアルタイム処理")
                        .font(.subheadline)
                    Text("録音中に音声を最適化")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $audioSettings.enableRealTimeProcessing)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("後処理")
                        .font(.subheadline)
                    Text("録音完了後にファイルを最適化")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $audioSettings.enablePostProcessing)
            }
        }
    }
    
    // MARK: - Noise Control Section
    
    private var noiseControlSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("ノイズ低減レベル")
                    .font(.subheadline)
                Spacer()
                Picker("ノイズ低減", selection: $audioSettings.noiseReductionLevel) {
                    ForEach(AudioProcessingService.NoiseReductionLevel.allCases, id: \.self) { level in
                        Text(level.displayName).tag(level)
                    }
                }
                .pickerStyle(.menu)
            }
            
            // ノイズレベル説明
            VStack(alignment: .leading, spacing: 4) {
                Text("設定ガイド")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text("• なし: 自然な音響環境を保持")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("• 軽微: わずかなノイズ除去")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("• 標準: バランスの取れたノイズ除去")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("• 強力: 積極的なノイズ除去（音質劣化の可能性）")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
        }
    }
    
    // MARK: - Real-time Processing Section
    
    private var realTimeProcessingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("自動ゲイン制御", isOn: .constant(true))
            
            Toggle("ノイズゲート", isOn: .constant(false))
            
            Toggle("音声強調", isOn: .constant(audioSettings.recordingMode == .voiceEnhancement))
                .disabled(true)
            
            Text("リアルタイム処理を有効にすると、録音中に音声が最適化されます。バッテリー消費が増加する場合があります。")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
    }
}