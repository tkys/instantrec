import SwiftUI

struct CountdownView: View {
    let duration: CountdownDuration
    let onCountdownComplete: () -> Void
    let onCancel: () -> Void
    
    @State private var remainingTime: Int
    @State private var timer: Timer?
    @State private var scale: CGFloat = 1.0
    
    init(duration: CountdownDuration, onCountdownComplete: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.duration = duration
        self.onCountdownComplete = onCountdownComplete
        self.onCancel = onCancel
        self._remainingTime = State(initialValue: duration.rawValue)
    }
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 30) {
                // 上部のカウントダウン状態表示
                VStack(spacing: 8) {
                    HStack {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 12, height: 12)
                            .opacity(0.8)
                        
                        Text("録音開始まで")
                            .foregroundColor(.orange)
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                }
                
                // 中央のカウントダウンアイコン
                VStack(spacing: 15) {
                    Image(systemName: "timer")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("準備してください")
                        .foregroundColor(Color(UIColor.secondaryLabel))
                        .font(.subheadline)
                }
                
                // カウントダウン時間（シンプルな数字のみ）
                Text("\(remainingTime)")
                    .font(.system(.largeTitle, design: .monospaced, weight: .light))
                    .foregroundColor(Color(UIColor.label))
                    .scaleEffect(scale)
                    .animation(.easeInOut(duration: 0.1), value: scale)
                
                // キャンセルボタン
                Button("キャンセル") {
                    stopTimer()
                    onCancel()
                }
                .font(.title)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 200, height: 80)
                .background(Color.red)
                .cornerRadius(40)
            }
        }
        .onAppear {
            startCountdown()
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    private func startCountdown() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if remainingTime > 1 {
                withAnimation(.easeInOut(duration: 0.1)) {
                    scale = 1.2
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        scale = 1.0
                    }
                }
                
                remainingTime -= 1
            } else {
                stopTimer()
                
                // 最後のアニメーション
                withAnimation(.easeInOut(duration: 0.3)) {
                    scale = 1.5
                }
                
                // 完了時の振動フィードバック
                let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                impactFeedback.impactOccurred()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onCountdownComplete()
                }
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

#Preview {
    CountdownView(
        duration: .three,
        onCountdownComplete: {
            print("Countdown completed!")
        },
        onCancel: {
            print("Countdown cancelled!")
        }
    )
}