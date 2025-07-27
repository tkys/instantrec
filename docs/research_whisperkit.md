---
以下は、iOSアプリでの文字起こしアプリ開発にWhisperKitを使用するためのMarkdown形式の資料です。精度、実装面、技術情報、具体的なコード例、参考リンクを含め、開発者がすぐに着手できるように構成しています。
---

# iOS文字起こしアプリ開発ガイド: WhisperKitを活用

## 1. 概要
WhisperKitは、OpenAIの音声認識モデル「Whisper」をAppleのCoreMLフレームワークに最適化したSwiftパッケージです。iOSアプリでの高精度な文字起こしを、オフラインかつ高速に実現します。このガイドでは、WhisperKitを使った開発手順、精度の特徴、実装のポイントを解説します。

---

## 2. WhisperKitの特徴

### 2.1 精度
- **日本語対応**: Whisperのbaseモデルで実用的な精度、large-v3モデルでほぼ完璧な文字起こし（句読点も正確）。
- **WER（Word Error Rate）**: baseモデルで15分の音声を51秒で処理（iPhone 15 Pro）。largeモデルはさらに高精度。
- **文脈理解**: 専門用語や複雑な会話でも高い認識精度。
- **ノイズ耐性**: 生活騒音下でも安定したパフォーマンス。

### 2.2 実装の利点
- **簡単な統合**: Swift Package Manager（SPM）で簡単に導s入可能。
- **オフライン動作**: 完全ローカル処理でプライバシー保護。
- **高速処理**: Neural EngineとGPUを活用し、エネルギー効率が高い。
- **モデル選択**: tiny（43MB）、base（145MB）、small、medium、largeなど用途に応じたモデルを選択可能。
- **リアルタイム対応**: ストリーム入力でリアルタイム文字起こしが可能。

---

## 3. 開発環境の準備

### 3.1 必要条件
- **OS**: macOS 14.0以降
- **Xcode**: 15.0以降
- **デバイス**: iPhone 12以降推奨（Neural Engine搭載で最適パフォーマンス）
- **Swift**: 5.7以降
- **依存ライブラリ**: CoreML、AVFoundation

### 3.2 リポジトリのクローン
```bash
git clone https://github.com/argmaxinc/whisperkit.git
cd whisperkit
```

### 3.3 モデルのダウンロード
- WhisperKitのモデルはCoreML形式で提供。例: baseモデル（145MB）は以下で取得：
  ```bash
  git clone https://huggingface.co/argmaxinc/whisperkit-coreml
  ```
- モデルサイズの選択：
  - tiny: 43MB（軽量、リアルタイム向け）
  - base: 145MB（バランス型）
  - large-v3: 1.5GB（最高精度）

---

## 4. 実装手順

### 4.1 プロジェクトへの統合
1. **SPMでWhisperKitを追加**:
   - Xcodeでプロジェクトを開き、`File > Add Package Dependencies`を選択。
   - URL: `https://github.com/argmaxinc/whisperkit`
   - 依存関係をプロジェクトに追加。

2. **CoreMLモデルのインポート**:
   - ダウンロードしたモデル（例: `openai_whisper-base`）をプロジェクトにドラッグ＆ドロップ。
   - 必要に応じてモデルをコンパイル：
     ```swift
     import CoreML
     let compiledModelURL = try MLModel.compileModel(at: modelURL)
     ```

### 4.2 基本的な文字起こしコード
以下は、音声ファイルから文字起こしを行うサンプルコードです：
```swift
import WhisperKit
import AVFoundation

@MainActor
func transcribeAudio(fileURL: URL) async throws -> String? {
    // WhisperKitの初期化
    let whisperKit = try await WhisperKit()
    
    // 言語設定（日本語の場合）
    let options = TranscribeOptions(language: "ja")
    
    // 音声ファイルの文字起こし
    let transcription = try await whisperKit.transcribe(audioPath: fileURL.path, options: options)
    
    // 結果を返す
    return transcription?.text
}

// 使用例
Task {
    guard let audioURL = Bundle.main.url(forResource: "sample", withExtension: "mp3") else {
        print("音声ファイルが見つかりません")
        return
    }
    
    do {
        let result = try await transcribeAudio(fileURL: audioURL)
        print("文字起こし結果: \(result ?? "失敗")")
    } catch {
        print("エラー: \(error)")
    }
}
```

### 4.3 リアルタイム文字起こし
リアルタイム処理には、AVFoundationでマイク入力をキャプチャし、WhisperKitにストリームを渡します：
```swift
import AVFoundation
import WhisperKit

class RealTimeTranscriber {
    private var whisperKit: WhisperKit?
    private let audioEngine = AVAudioEngine()
    
    func startTranscription() async throws {
        whisperKit = try await WhisperKit()
        let options = TranscribeOptions(language: "ja", stream: true)
        
        // マイク入力の設定
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        
        // 音声バッファをWhisperKitに渡す
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, time in
            Task {
                let transcription = try await self.whisperKit?.transcribe(audioBuffer: buffer, options: options)
                print("リアルタイム文字起こし: \(transcription?.text ?? "")")
            }
        }
        
        // 音声エンジン開始
        try audioEngine.start()
    }
    
    func stopTranscription() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
    }
}
```

---

## 5. 技術的な注意点

### 5.1 言語設定
- 日本語音声を正確に認識するには、`language: "ja"`を明示的に指定。
- 未指定の場合、英語として誤認識される可能性あり。

### 5.2 ハードウェア依存
- iPhone 15 ProやApple Silicon Macで最適パフォーマンス。
- 古いデバイス（例: iPhone 8）では処理速度が低下する可能性。

### 5.3 話者分離
- WhisperKit単体では話者識別が不可。複数話者の場合は、Pyannote（例: `pyannote-audio`）と統合を検討。

### 5.4 モデルサイズのトレードオフ
| モデル | サイズ | 処理速度（15分音声） | 精度 | 用途 |
|--------|--------|---------------------|-------|------|
| tiny   | 43MB   | 10秒                | 中    | リアルタイム |
| base   | 145MB  | 51秒                | 高    | バランス |
| large-v3 | 1.5GB | 数分                | 最高  | 高精度用途 |

---

## 6. ユースケース
- **会議の文字起こし**: オフラインで機密性の高い議事録作成。
- **リアルタイム翻訳**: 日本語→英語の同時翻訳アプリ。
- **音声メモアプリ**: 音声入力の即時テキスト化。

---

## 7. 代替案との比較
| ツール | メリット | デメリット |
|--------|----------|------------|
| WhisperKit | オフライン、高精度、簡単実装 | 話者分離なし |
| Whisper API | クラウドベース、安価（1分約1円） | インターネット必須、プライバシー懸念 |
| kotoba-whisper-v2.0 | 日本語特化、句読点処理優れる | 柔軟性低い |
| Google Speech-to-Text | クラウドで高精度 | コスト高、オフライン不可 |

---

## 8. 参考リンク
- **WhisperKit公式リポジトリ**: [https://github.com/argmaxinc/whisperkit](https://github.com/argmaxinc/whisperkit)
- **モデルダウンロード**: [https://huggingface.co/argmaxinc/whisperkit-coreml](https://huggingface.co/argmaxinc/whisperkit-coreml)
- **CoreMLドキュメント**: [https://developer.apple.com/documentation/coreml](https://developer.apple.com/documentation/coreml)
- **AVFoundation（音声キャプチャ）**: [https://developer.apple.com/documentation/avfoundation](https://developer.apple.com/documentation/avfoundation)
- **サンプルアプリ（WhisperAX）**: [https://testflight.apple.com/join/whisperax](https://testflight.apple.com/join/whisperax)

---

## 9. トラブルシューティング
- **モデル読み込みエラー**: モデルファイルの破損やパスを確認。Xcodeでモデルを再コンパイル。
- **日本語認識精度が低い**: `language: "ja"`を指定。large-v3モデルを試す。
- **処理速度が遅い**: モデルサイズを小さく（例: tiny）、または高性能デバイスを使用。

---

## 10. 次のステップ
1. **プロトタイプ作成**: 上記のサンプルコードで基本的な文字起こしを実装。
2. **UI設計**: SwiftUIやUIKitで結果表示用のインターフェースを構築。
3. **テスト**: 異なる音声（ノイズあり/なし、複数話者）で精度を評価。
4. **最適化**: リアルタイム処理や話者分離の追加を検討。

---

**質問や追加のコード例が必要な場合、開発者に連絡してください！**
```

この資料は、WhisperKitを使ったiOSアプリ開発の全体像をカバーし、具体的なコード例やリンクを提供しています。必要に応じて、特定の部分（例: リアルタイム処理の詳細、UI設計のサンプル）をさらに深掘りできますので、お知らせください！