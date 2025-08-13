承知いたしました。ご提示いただいた動画のUIをiOSアプリで実装するための、開発者向け詳細資料を作成します。

このUIは非常に洗練されており、SwiftUIを使用することで、宣言的かつ効率的に構築することが可能です。ここではSwiftUIをベースに、各コンポーネントの実装方法を詳細に解説します。

---

### **インタラクティブな録音UI実装ガイド**

この資料は、以下の3つの主要パートに分かれています。

1.  **録音モーダルUIの実装**: アプリの中核となる、リアルタイム波形表示を備えた録音画面。
2.  **メインコンテンツボードの実装**: 録音データを含む様々なカードを配置するメイン画面。
3.  **インタラクションとアニメーション**: UIの質感を高めるための詳細なTIPS。

---

### **Part 1: 録音モーダルUIの実装**

このUIの最も特徴的な部分です。リアルタイムの音声波形がユーザーにフィードバックを与え、録音体験を向上させます。

#### **1.1. 技術要素の概要**

*   **音声録音**: `AVFoundation`フレームワークの`AVAudioRecorder`を使用します。
*   **UI構築**: `SwiftUI`を使用します。
*   **モーダル表示**: SwiftUIの`.sheet()`モディファイアを利用します。
*   **リアルタイム波形描画**: 録音中の音声レベルを`AVAudioRecorder`から取得し、SwiftUIの`Canvas`または`Shape`で描画します。

#### **1.2. 音声録音機能のセットアップ**

まず、音声を録音し、そのレベル（音の大きさ）を監視するクラスを作成します。

1.  **`Info.plist`の設定**:
    マイクの使用許可をユーザーに求めるため、`Info.plist`に「**Privacy - Microphone Usage Description**」を追加し、説明文を記述してください。

2.  **`AudioRecorder`クラスの作成**:
    `AVFoundation`をインポートし、`AVAudioRecorder`を管理するクラスを作成します。このクラスは`ObservableObject`に準拠させ、UIに状態変化を通知できるようにします。

    ```swift
    import AVFoundation
    import SwiftUI

    class AudioRecorder: NSObject, ObservableObject, AVAudioPlayerDelegate {
        var audioRecorder: AVAudioRecorder?
        @Published var isRecording = false
        // 録音レベルをUIに公開するためのプロパティ
        @Published var power: CGFloat = 0.0

        private var timer: Timer?

        func startRecording() {
            let recordingSession = AVAudioSession.sharedInstance()
            do {
                try recordingSession.setCategory(.playAndRecord, mode: .default)
                try recordingSession.setActive(true)
            } catch {
                print("Failed to set up recording session")
            }

            let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioFilename = documentPath.appendingPathComponent("\(Date().toString(dateFormat: "dd-MM-YY_'at'_HH:mm:ss")).m4a")

            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 12000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            do {
                audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
                audioRecorder?.isMeteringEnabled = true // 音声レベルの監視を有効にする
                audioRecorder?.record()
                isRecording = true

                // 0.05秒ごとに音声レベルを取得するタイマーを開始
                timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                    self?.updatePower()
                }
            } catch {
                stopRecording()
            }
        }

        func stopRecording() {
            audioRecorder?.stop()
            isRecording = false
            timer?.invalidate()
            timer = nil
        }

        private func updatePower() {
            guard let recorder = audioRecorder else { return }
            recorder.updateMeters()
            // デシベル値を0から1の範囲に正規化する
            let averagePower = recorder.averagePower(forChannel: 0)
            let normalizedPower = pow(10, averagePower / 20)
            
            // UI更新をメインスレッドで行う
            DispatchQueue.main.async {
                self.power = CGFloat(normalizedPower)
            }
        }
    }
    ```

#### **1.3. リアルタイム音声波形ビューの作成**

`AudioRecorder`から受け取った`power`の値を使って、リアルタイムに変化する波形ビューを作成します。

```swift
import SwiftUI

struct RealtimeWaveformView: View {
    @Binding var power: CGFloat // AudioRecorderのpowerをバインドする

    var body: some View {
        HStack(spacing: 4) {
            // ここでは簡易的に、高さを変えるバーで表現
            // 実際には過去のpower値を配列で保持し、複数のバーを描画すると動画のようになる
            Rectangle()
                .frame(width: 20, height: 100 * power) // powerに応じて高さを変える
                .foregroundColor(.blue)

            // 中央のライン
            Rectangle()
                .frame(width: 2, height: 120)
                .foregroundColor(.blue)

            // TODO: 左右対称に波形を描画するロジックを追加
        }
        .animation(.easeOut(duration: 0.05), value: power)
    }
}
```
**高度な実装**: 動画のような滑らかな波形にするには、`power`の値を配列に保持し、`Canvas`を使って過去のデータも含めて線や長方形として描画する手法が一般的です。

#### **1.4. 録音モーダルビューの組み立て**

これらのコンポーネントを組み合わせて、モーダル全体を構築します。

```swift
struct RecordingView: View {
    @StateObject private var audioRecorder = AudioRecorder()
    @Binding var isShowing: Bool // このビューの表示状態を管理

    var body: some View {
        VStack {
            Spacer()
            // UI全体を黒い角丸のコンテナに入れる
            VStack(spacing: 20) {
                Text("00:00") // TODO: タイマー実装
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("New Audio from you")
                    .foregroundColor(.gray)

                // リアルタイム波形ビュー
                RealtimeWaveformView(power: $audioRecorder.power)
                    .frame(height: 150)
                
                // コントロールボタン
                HStack(spacing: 40) {
                    Button(action: {}) {
                        Image(systemName: "stop.fill")
                    }
                    
                    Button(action: {
                        if audioRecorder.isRecording {
                            audioRecorder.stopRecording()
                        } else {
                            audioRecorder.startRecording()
                        }
                    }) {
                        // 録音状態によってアイコンとエフェクトを切り替え
                        ZStack {
                            Image(systemName: audioRecorder.isRecording ? "pause.fill" : "play.fill")
                                .font(.system(size: 40))
                            if audioRecorder.isRecording {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 10, height: 10)
                                    .offset(x: 15, y: 15)
                            }
                        }
                    }
                    
                    Button(action: {
                        // 削除処理とビューを閉じる
                        audioRecorder.stopRecording()
                        isShowing = false
                    }) {
                        Image(systemName: "trash.fill")
                    }
                }
                .font(.title)
                .foregroundColor(.white)
            }
            .padding(30)
            .background(Color.black.opacity(0.9))
            .cornerRadius(30)
            .shadow(radius: 20)
            
            Spacer()
        }
        .padding()
        .background(Color.black.opacity(0.4).edgesIgnoringSafeArea(.all)) // 半透明の背景
    }
}
```

---

### **Part 2: メインコンテンツボードの実装**

様々な種類の情報をカードとして表示する画面です。

#### **2.1. データモデルの設計**

まず、表示するコンテンツのデータ構造を定義します。

```swift
import SwiftUI

// カード一つ一つを表すモデル
struct CardItem: Identifiable {
    let id = UUID()
    let type: CardType
}

// カードの種類を定義
enum CardType {
    case audio(AudioData)
    case product(ProductData)
    case note(NoteData)
    // 他のタイプも追加可能
}

// 各カードタイプの詳細データ
struct AudioData {
    let fileURL: URL
    let duration: TimeInterval
    let userAvatar: String
}
// ProductData, NoteDataなども同様に定義
```

#### **2.2. カード型レイアウトの実装**

動画のような異なる高さのカードが並ぶレイアウトは「Masonryレイアウト」や「Pinterest風レイアウト」と呼ばれます。SwiftUIの標準では`LazyVGrid`がありますが、これだけでは高さの異なる要素をうまく詰めることができません。

*   **簡易的な実装**: `LazyVGrid`を使い、各カードの高さをある程度揃える。
*   **高度な実装**:
    1.  **自作する**: カラム数分の配列を用意し、合計の高さが最も低いカラムに次のアイテムを追加していくロジックを組む。
    2.  **ライブラリを利用する**: `SwiftUI-Masonry`のようなサードパーティライブラリを検討するのが現実的です。

#### **2.3. 各種カードビューの作成**

`CardType`に応じて表示を切り替えるビューを作成します。

```swift
struct CardView: View {
    let item: CardItem

    var body: some View {
        switch item.type {
        case .audio(let audioData):
            AudioCardView(data: audioData)
        case .product(let productData):
            ProductCardView(data: productData)
        case .note(let noteData):
            NoteCardView(data: noteData)
        }
    }
}

// 音声カードの例
struct AudioCardView: View {
    let data: AudioData
    var body: some View {
        HStack {
            Image(systemName: data.userAvatar) // アバター
            // TODO: 録音済み音声の波形を描画
            Text(String(format: "%.2f", data.duration))
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
```
**録音済み波形の描画**: 録音済みファイルの波形を描画するには、音声ファイルを読み込み、その振幅データを抽出・正規化してから描画する必要があります。これはリアルタイム描画よりも複雑で、ライブラリ（例: `WaveformView`）の利用も一案です。

---

### **Part 3: インタラクションとアニメーション**

#### **3.1. 「+」ボタンとポップアップメニュー**

`ZStack`を使って、コンテンツリストの上にフローティングボタンを配置します。ボタンをタップすると、複数のアイコンが展開されるアニメーションを実装します。

```swift
struct MainView: View {
    @State private var showMenu = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // Part 2で作成したコンテンツボード
            // ScrollView { ... }
            
            // フローティングボタンとメニュー
            VStack {
                if showMenu {
                    // 展開されるメニュー項目
                    HStack {
                        // バーコード、画像、音声などのアイコンボタン
                        Button(action: {}) { Image(systemName: "barcode.viewfinder") }
                        Button(action: {}) { Image(systemName: "photo.on.rectangle") }
                        Button(action: {}) { Image(systemName: "mic.fill.badge.plus") }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(radius: 10)
                    .transition(.scale.combined(with: .opacity)) // 表示/非表示時のアニメーション
                }
                
                Button(action: {
                    withAnimation(.spring()) {
                        showMenu.toggle()
                    }
                }) {
                    Image(systemName: "plus")
                        .font(.title)
                        .padding()
                        .background(Color.white)
                        .foregroundColor(.black)
                        .clipShape(Circle())
                        .shadow(radius: 10)
                        .rotationEffect(.degrees(showMenu ? 45 : 0)) // +が×に回転するアニメーション
                }
            }
            .padding()
        }
    }
}
```

#### **3.2. スムーズな画面遷移**

*   **モーダル表示**: 録音ボタンがタップされたら、`.sheet()`モディファイアを使って録音ビューを表示します。SwiftUI 16以降では`.presentationDetents()`を使って高さをカスタマイズできます。
*   **アニメーション**: SwiftUIの`withAnimation { ... }`ブロックや`.animation()`モディファイアを積極的に使用し、状態変化に伴うUIの動きを滑らかにしましょう。

---

### **推奨サードパーティライブラリ**

*   **波形描画**:
    *   **`WaveformView` (SwiftUI用/UIKit用あり)**: 音声ファイルの波形を簡単に表示できます。
    *   **`FDSoundActivatedRecorder`**: リアルタイムの波形表示機能を持つ録音ライブラリ。
*   **Masonryレイアウト**:
    *   **`SwiftUI-Masonry`**: SwiftUIでMasonryレイアウトを実装するためのライブラリ。

この資料が、あなたのアプリ開発の助けとなることを願っています。