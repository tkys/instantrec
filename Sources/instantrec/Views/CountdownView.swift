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
                // 統一されたヘッダー
                VStack(spacing: 8) {
                    HStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 12, height: 12)
                            .opacity(0.8)
                            .scaleEffect(1.1)
                            .animation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: true)
                        
                        Text("Starting in...")
                            .foregroundColor(.blue)
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                }
                
                // 統一されたアイコンセクション
                VStack(spacing: 15) {
                    Image(systemName: "timer")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Get ready to record")
                        .foregroundColor(Color(UIColor.secondaryLabel))
                        .font(.subheadline)
                }
                
                // カウントダウン時間
                Text("\(remainingTime)")
                    .font(.system(.largeTitle, design: .monospaced, weight: .light))
                    .foregroundColor(Color(UIColor.label))
                    .scaleEffect(scale)
                    .animation(.easeInOut(duration: 0.1), value: scale)
                
                // 統一されたキャンセルボタン
                Button(action: {
                    stopTimer()
                    onCancel()
                }) {
                    HStack {
                        Image(systemName: "xmark")
                        Text("Cancel")
                    }
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(width: 200, height: 80)
                    .background(Color.red)
                    .cornerRadius(40)
                }
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
            if remainingTime > 0 {
                // アニメーション効果
                withAnimation(.easeInOut(duration: 0.1)) {
                    scale = 1.2
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        scale = 1.0
                    }
                }
                
                remainingTime -= 1
                
                // カウントダウンが0になったら完了処理
                if remainingTime == 0 {
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