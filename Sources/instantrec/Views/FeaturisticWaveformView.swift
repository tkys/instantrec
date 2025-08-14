import SwiftUI
import AVFoundation

// MARK: - Featuristic Design: Enhanced Waveform System
// Canvas-based smooth waveform visualization integrated with existing AudioService

struct FeaturisticWaveformView: View {
    @ObservedObject var audioService: AudioService
    @State private var waveformHistory: [Float] = Array(repeating: 0, count: 50)
    @State private var animationPhase: CGFloat = 0
    
    private let waveformColor = Color.blue
    private let centerLineColor = Color.blue.opacity(0.3)
    private let maxAmplitude: CGFloat = 60 // 最大振幅
    
    var body: some View {
        Canvas { context, size in
            drawFeaturisticWaveform(context: context, size: size)
        }
        .onReceive(audioService.$audioLevel) { level in
            updateWaveformHistory(level)
        }
        .onAppear {
            startAnimation()
        }
        .frame(height: 120)
        .background(Color.black.opacity(0.05))
        .cornerRadius(8)
    }
    
    // MARK: - Waveform Drawing (Canvas-based)
    
    private func drawFeaturisticWaveform(context: GraphicsContext, size: CGSize) {
        let centerY = size.height / 2
        let width = size.width
        let barWidth: CGFloat = width / CGFloat(waveformHistory.count)
        
        // 中央ライン描画
        drawCenterLine(context: context, size: size, centerY: centerY)
        
        // 対称波形描画
        for (index, amplitude) in waveformHistory.enumerated() {
            let x = CGFloat(index) * barWidth + barWidth / 2
            let normalizedAmplitude = CGFloat(amplitude) * maxAmplitude
            
            drawSymmetricalBar(
                context: context,
                x: x,
                centerY: centerY,
                amplitude: normalizedAmplitude,
                barWidth: barWidth * 0.8,
                index: index
            )
        }
        
        // リアルタイム効果のためのグラデーション
        drawRealtimeGradient(context: context, size: size)
    }
    
    private func drawCenterLine(context: GraphicsContext, size: CGSize, centerY: CGFloat) {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: centerY))
        path.addLine(to: CGPoint(x: size.width, y: centerY))
        
        context.stroke(path, with: .color(centerLineColor), lineWidth: 1)
    }
    
    private func drawSymmetricalBar(
        context: GraphicsContext,
        x: CGFloat,
        centerY: CGFloat,
        amplitude: CGFloat,
        barWidth: CGFloat,
        index: Int
    ) {
        // フェード効果（新しいデータほど明るく）
        let fadeMultiplier = CGFloat(index) / CGFloat(waveformHistory.count - 1)
        let alpha = 0.3 + (fadeMultiplier * 0.7)
        
        // 上下対称のバー
        let topHeight = amplitude
        let bottomHeight = amplitude
        
        // 上側バー
        let topRect = CGRect(
            x: x - barWidth / 2,
            y: centerY - topHeight,
            width: barWidth,
            height: topHeight
        )
        
        // 下側バー
        let bottomRect = CGRect(
            x: x - barWidth / 2,
            y: centerY,
            width: barWidth,
            height: bottomHeight
        )
        
        let barColor = waveformColor.opacity(alpha)
        
        context.fill(Path(topRect), with: .color(barColor))
        context.fill(Path(bottomRect), with: .color(barColor))
        
        // リアルタイムの最新バーには特別効果
        if index == waveformHistory.count - 1 && amplitude > 5 {
            addRealtimeEffect(context: context, rect: topRect.union(bottomRect))
        }
    }
    
    private func addRealtimeEffect(context: GraphicsContext, rect: CGRect) {
        // 最新バーにグロー効果（iOS Canvas制限のため簡易実装）
        let glowColor = waveformColor.opacity(0.9)
        
        // 複数の色でグロー効果を模擬
        context.fill(Path(rect.insetBy(dx: -1, dy: -1)), with: .color(glowColor.opacity(0.3)))
        context.fill(Path(rect), with: .color(glowColor))
    }
    
    private func drawRealtimeGradient(context: GraphicsContext, size: CGSize) {
        // 右端に向かってフェードインするグラデーション
        let gradientRect = CGRect(origin: .zero, size: size)
        context.fill(Path(gradientRect), with: .linearGradient(
            Gradient(colors: [Color.clear, waveformColor.opacity(0.05)]),
            startPoint: CGPoint(x: 0, y: size.height / 2),
            endPoint: CGPoint(x: size.width, y: size.height / 2)
        ))
    }
    
    // MARK: - Data Management
    
    private func updateWaveformHistory(_ newLevel: Float) {
        // 新しいデータを追加し、古いデータを削除
        waveformHistory.removeFirst()
        waveformHistory.append(newLevel)
        
        // パフォーマンス最適化: 配列サイズ制限
        if waveformHistory.count > 50 {
            waveformHistory = Array(waveformHistory.suffix(50))
        }
    }
    
    private func startAnimation() {
        // 微細なアニメーション効果
        withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
            animationPhase = 1.0
        }
    }
}

// MARK: - Featuristic Waveform with Recording State Integration

struct AdaptiveFeaturisticWaveform: View {
    @ObservedObject var audioService: AudioService
    @ObservedObject var recordingViewModel: RecordingViewModel
    
    var body: some View {
        VStack(spacing: 8) {
            // 録音状態表示
            HStack {
                Circle()
                    .fill(getStatusColor())
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut(duration: 0.3), value: recordingViewModel.isRecording)
                    .animation(.easeInOut(duration: 0.3), value: recordingViewModel.isPaused)
                
                Text(getStatusText())
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(recordingViewModel.elapsedTime)
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }
            
            // Featuristic波形表示
            FeaturisticWaveformView(audioService: audioService)
                .opacity(recordingViewModel.isRecording && !recordingViewModel.isPaused ? 1.0 : 0.5)
                .animation(.easeInOut(duration: 0.3), value: recordingViewModel.isRecording)
                .animation(.easeInOut(duration: 0.3), value: recordingViewModel.isPaused)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func getStatusColor() -> Color {
        if recordingViewModel.isPaused {
            return Color.orange
        } else if recordingViewModel.isRecording {
            return Color.red
        } else {
            return Color.gray
        }
    }
    
    private func getStatusText() -> String {
        if recordingViewModel.isPaused {
            return "Paused"
        } else if recordingViewModel.isRecording {
            return "Recording"
        } else {
            return "Ready"
        }
    }
}

// MARK: - Preview Helpers

#if DEBUG
class MockAudioService: AudioService {
    override init() {
        super.init()
        startMockAudioLevel()
    }
    
    private func startMockAudioLevel() {
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            self.audioLevel = Float.random(in: 0...1.0)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        Text("Featuristic Waveform Demo")
            .font(.headline)
        
        FeaturisticWaveformView(audioService: MockAudioService())
        
        AdaptiveFeaturisticWaveform(
            audioService: MockAudioService(),
            recordingViewModel: RecordingViewModel()
        )
    }
    .padding()
}
#endif