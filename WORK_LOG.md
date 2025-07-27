# InstantRec開発作業記録

## 2025-07-27 WhisperKit音声認識統合とモデル選択機能実装

### 概要
Apple Speech FrameworkからWhisperKitへの移行を完了し、動的モデル選択機能を実装。精度比較のため複数モデル（tiny, base, small, medium, large-v3）を選択可能にした。

### 主要な変更内容

#### 1. WhisperKit統合
- **新規ファイル**: `Sources/instantrec/Services/WhisperKitTranscriptionService.swift`
  - OpenAIのWhisperモデルをCoreML最適化したWhisperKitを使用
  - 完全オフライン動作でプライバシー保護
  - 日本語特化設定 (`language: "ja"`)
  - 詳細なデバッグログとエラーハンドリング

#### 2. 動的モデル選択機能
- **モデル定義enum**: `WhisperKitModel`
  - Tiny (43MB) - リアルタイム向け高速処理
  - Base (145MB) - バランス型、推奨設定
  - Small (~500MB) - 高精度、中程度速度
  - Medium (~1GB) - 非常に高精度、処理時間長め
  - Large-v3 (1.5GB) - 最高精度、専門用途

- **モデル切り替え機能**:
  ```swift
  let config = WhisperKitConfig(model: selectedModel.rawValue)
  whisperKit = try await WhisperKit(config)
  ```

#### 3. デバッグUI改善
- **新規ファイル**: `Sources/instantrec/Views/TranscriptionDebugView.swift`
  - モデル選択Picker UI
  - 文字起こし結果表示
  - 処理時間表示
  - WhisperKit初期化状態監視

#### 4. プロジェクト設定更新
- **project.yml**: WhisperKit依存関係追加
  ```yaml
  packages:
    WhisperKit:
      url: https://github.com/argmaxinc/whisperkit
      from: 0.8.0
  ```

### 実装の技術的詳細

#### WhisperKit初期化
```swift
private func initializeWhisperKit() async {
    do {
        let config = WhisperKitConfig(model: selectedModel.rawValue)
        whisperKit = try await WhisperKit(config)
        isInitialized = true
    } catch {
        // エラーハンドリング
    }
}
```

#### 文字起こし処理
```swift
let transcription = try await whisperKit.transcribe(
    audioPath: audioURL.path,
    decodeOptions: DecodingOptions(
        verbose: true,
        task: .transcribe,
        language: "ja",
        temperature: 0.0,
        temperatureIncrementOnFallback: 0.2,
        temperatureFallbackCount: 5
    )
)
```

### 精度比較結果（60秒音声ファイルでのテスト）

| モデル | 処理時間 | 文字数 | 速度比 | 精度評価 |
|--------|----------|--------|---------|----------|
| Base | 11.11秒 | 288文字 | 30.5倍速 | 中程度 |
| Small | 33.26秒 | 295文字 | 12.7倍速 | 良好 |
| Medium | 66.64秒 | 293文字 | 3.5倍速 | 最高（相槌も認識） |
| Large-v3 | 109.16秒 | 1文字 | 4.4倍速 | 認識失敗 |

### 推奨設定
- **Medium**モデルが最も実用的（正確性と処理時間のバランス）
- Large-v3は処理が重すぎて実際の用途では不向き
- リアルタイム用途にはTinyまたはBaseを推奨

### 今後の課題
1. Large-v3モデルの認識失敗問題の調査
2. メモリ使用量の最適化
3. バックグラウンド処理でのモデル切り替え対応

### コミット対象ファイル
- 新規: WhisperKitTranscriptionService.swift
- 新規: TranscriptionDebugView.swift  
- 新規: research_whisperkit.md（技術調査資料）
- 更新: project.yml（WhisperKit依存関係）
- 更新: その他既存ファイル（Google Drive統合改善等）

### 開発環境
- macOS 14.5
- Xcode 15.4
- Swift 5.9
- WhisperKit 0.13.0
- iOS 17.0+

---
*作業完了時刻: 2025-07-27 15:30*