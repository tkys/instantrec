# 進捗表示機能の現状分析と改善提案

## 📊 現在の問題点

### 1. **モデルダウンロード進捗がダミー**

#### 現在の実装（確認済み）
```swift
/// ダウンロード進捗のシミュレーション（実際のWhisperKitでは進捗コールバックを使用）
private func simulateDownloadProgress(for model: WhisperKitModel) async {
    let steps = 10
    let stepDuration: UInt64 = 200_000_000 // 0.2秒 in nanoseconds
    
    for step in 1...steps {
        let progress = Float(step) / Float(steps)
        
        await MainActor.run {
            self.downloadProgress[model] = progress * 0.8 // 80%まで進捗表示
        }
        
        try? await Task.sleep(nanoseconds: stepDuration)
    }
}
```

**問題**:
- ✅ ダミーの進捗表示（2秒間で80%まで）
- ❌ 実際のダウンロード状況と無関係
- ❌ ユーザーを誤解させる可能性

### 2. **文字起こし進捗表示の欠如**

#### 現在の実装状況
- ✅ 開始・終了ログはあり
- ❌ 進行中の進捗表示なし
- ❌ ユーザーは完了まで待機するしかない

実際のログから見る処理時間:
```
🎵 Audio file info: duration=59.99s, format=16000
🎯 Starting WhisperKit transcription...
[2.8秒後]
✅ WhisperKit transcription completed in 2.80s
```

## 🎯 改善提案

### 1. **リアルモデルダウンロード進捗**

#### WhisperKitの実際の進捗取得方法
```swift
// WhisperKitConfig with progress callback
let config = WhisperKitConfig(
    model: selectedModel.rawValue,
    verbose: true,
    logLevel: .info,
    prewarm: false,
    load: true,
    download: true,
    // 進捗コールバックの実装が必要
    progressCallback: { progress in
        DispatchQueue.main.async {
            self.downloadProgress[model] = progress
        }
    }
)
```

**課題**: WhisperKitの進捗APIの詳細確認が必要

#### 代替アプローチ
1. **ファイルサイズベース**: ダウンロードファイルのサイズ監視
2. **時間ベース**: 平均ダウンロード時間からの推定
3. **段階表示**: "初期化中" → "ダウンロード中" → "完了"

### 2. **文字起こし進捗表示**

#### WhisperKitの内部処理段階
```
Audio Load:             14.58 ms    (0.53%)
Audio Processing:        1.01 ms    (0.04%)
Mels:                    6.77 ms    (0.25%)
Encoding:              251.70 ms    (9.19%)
Decoding:             2113.04 ms   (77.14%) ← メイン処理
```

#### 実装アプローチ
```swift
// 進捗状態の追加
enum TranscriptionProgress {
    case preparing      // 0-5%: ファイル読み込み
    case processing     // 5-15%: 音声前処理
    case encoding       // 15-25%: エンコーディング
    case decoding(Float) // 25-95%: デコーディング（メイン）
    case finalizing     // 95-100%: 後処理
}

@Published var transcriptionProgress: TranscriptionProgress = .preparing
```

#### 進捗推定方法
1. **時間ベース**: 音声長から処理時間を推定
2. **段階ベース**: 処理フェーズごとの進捗表示
3. **リアルタイム**: WhisperKitの内部コールバック活用

### 3. **UI表示の改善**

#### 進捗表示コンポーネント
```swift
struct TranscriptionProgressView: View {
    let progress: Float
    let stage: String
    let estimatedTimeRemaining: TimeInterval?
    
    var body: some View {
        VStack(spacing: 8) {
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle())
            
            HStack {
                Text(stage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let timeRemaining = estimatedTimeRemaining {
                    Text("約\(Int(timeRemaining))秒")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
```

## 🛠️ 実装優先度

### 高優先（ユーザー体験直結）
1. **文字起こし進捗表示**: 段階ベース進捗
2. **推定時間表示**: "約30秒で完了予定"
3. **視覚的フィードバック**: プログレスバー + 説明

### 中優先（技術的改善）
1. **リアルモデルダウンロード進捗**: WhisperKit API調査
2. **処理時間の学習**: 過去データからの予測精度向上
3. **エラー時の進捗表示**: 失敗時の適切なフィードバック

### 低優先（付加機能）
1. **詳細統計**: 各処理段階の詳細時間
2. **パフォーマンス最適化**: 進捗更新頻度の調整
3. **A/Bテスト**: 進捗表示方法の効果測定

## 📋 具体的な実装ステップ

### Step 1: 文字起こし進捗基盤（1-2時間）
1. `TranscriptionProgress` enum の追加
2. 段階ベース進捗の実装
3. UI コンポーネントの作成

### Step 2: 時間推定機能（1時間）
1. 音声長からの処理時間予測
2. 過去データの蓄積・活用
3. 動的な時間更新

### Step 3: モデルダウンロード改善（2-3時間）
1. WhisperKit進捗APIの調査
2. 実際の進捗取得実装
3. ダミー進捗の置き換え

## 🎯 期待効果

### ユーザー体験
- ✅ 待機時間の不安解消
- ✅ 処理状況の透明性
- ✅ 完了予定時間の把握

### 技術的価値
- ✅ デバッグ情報の充実
- ✅ パフォーマンス監視
- ✅ エラー発生箇所の特定

---

**結論**: ダミー進捗は確認済み。リアル進捗表示の実装が次回の重要課題です。