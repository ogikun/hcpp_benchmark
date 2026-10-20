# hcpp_benchmark

Android の PlatformView について、Hybrid Composition++（HCPP）と従来方式（TLHC / HC）の性能を比べるためのデモアプリです。

## 必要なもの

- Flutter 3.44 以降（HCPP は実験的機能）。記事の計測には Flutter 3.47.7 を使用
- Android 14（API 34）以上で、Vulkan に対応した実機（HCPP の計測に必要）

## デモアプリの考え方

比べたいのは「同じ画面・同じ操作で、HCPP を有効にしたときと無効にしたとき」です。

HCPP はアプリ全体の設定なので、1 つのアプリの中で切り替えることができません。そこで **Android の「フレーバー」** という仕組みを使いました。フレーバーは、1 つのプロジェクトから設定違いのアプリを複数ビルドする仕組みで、Flutter では `flutter run --flavor <名前>` で切り替えられます。

`legacy`（HCPP 無効）と `hcpp`（HCPP 有効）の 2 つのフレーバーを用意しました。アプリの ID も別にしているので、**同じ端末に 2 つ並べてインストール** して比べられます。

| フレーバー | applicationId | `io.flutter.embedding.android.EnableHcpp` |
| --- | --- | --- |
| `legacy` | `dev.example.hcpp_benchmark.legacy` | `false` |
| `hcpp` | `dev.example.hcpp_benchmark.hcpp` | `true` |

画面には、Android の View と Flutter のカードが交互に並ぶリストがあります。これを一定時間自動でスクロールさせ、その間の描画時間を記録します。計測するときは、次の条件を組み合わせられます。

| 条件 | 選択肢 | 何を確かめるためか |
| --- | --- | --- |
| フレーバー | `legacy` / `hcpp` | HCPP の有効・無効 |
| PlatformView を作る API | `AndroidView`（TLHC） / `initExpensiveAndroidView`（HC） / `initHybridAndroidView`（HCPP） | 従来の方式どうしの比較 |
| Android の View の種類 | 通常の View / SurfaceView | TLHC が苦手な SurfaceView での違い |
| メインスレッドの負荷 | 0 / 4 / 8 / 12 ミリ秒（毎フレーム） | **スレッドのマージの影響** を見えるようにする |
| Flutter の部品を重ねる | オン / オフ | Android の View の上に Flutter を重ねたときのコスト |

## ファイル構成

```
hcpp_benchmark/
├── android/app/
│   ├── build.gradle.kts            # legacy / hcpp の 2 つのフレーバーの定義
│   └── src/main/
│       ├── AndroidManifest.xml     # HCPP の有効・無効をフレーバーごとに切り替え
│       └── kotlin/.../
│           ├── MainActivity.kt         # Android の View の登録など
│           ├── AnimatedNativeView.kt   # 常にアニメーションし続ける通常の View
│           ├── SurfaceNativeView.kt    # 常にアニメーションし続ける SurfaceView
│           └── MainThreadLoad.kt       # メインスレッドにわざと負荷をかける
├── lib/src/
│   ├── bench_platform_view.dart    # 3 つの API で PlatformView を作る
│   ├── benchmark_page.dart         # 自動でスクロールしながら計測する画面
│   ├── frame_stats.dart            # 描画時間の集計
│   └── device_info.dart            # Android のバージョン、HCPP が有効かどうかなど
├── integration_test/scroll_perf_test.dart   # 自動計測用のテスト
├── test_driver/perf_driver.dart             # 計測結果をファイルに書き出す
└── tool/                                    # まとめて計測するスクリプトと集計スクリプト
```

## しくみ

### フレーバーで HCPP を切り替える

`build.gradle.kts` は、Android アプリのビルド設定ファイルです。ここで 2 つのフレーバーを定義し、`AndroidManifest.xml` に書く値（`enableHcpp`）をフレーバーごとに変えています。

```kotlin
// android/app/build.gradle.kts
android {
    // ...
    flavorDimensions += "composition"
    productFlavors {
        create("legacy") {
            dimension = "composition"
            applicationIdSuffix = ".legacy"   // アプリの ID を分けて、両方インストールできるようにする
            resValue("string", "app_name", "PV Bench (legacy)")
            manifestPlaceholders["enableHcpp"] = "false"
        }
        create("hcpp") {
            dimension = "composition"
            applicationIdSuffix = ".hcpp"
            resValue("string", "app_name", "PV Bench (HCPP)")
            manifestPlaceholders["enableHcpp"] = "true"
        }
    }
}
```

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<!-- ${enableHcpp} の部分に、フレーバーごとの値が入る -->
<meta-data
    android:name="io.flutter.embedding.android.EnableHcpp"
    android:value="${enableHcpp}" />
```

### 3 つの API で PlatformView を作る

Dart 側では、選んだ方式に応じて PlatformView の作り方を切り替えています。

```dart
// lib/src/bench_platform_view.dart
@override
Widget build(BuildContext context) {
  return switch (mode) {
    // TLHC（標準の方式）
    CompositionMode.textureLayer => AndroidView(
      viewType: kind.viewType,
      layoutDirection: TextDirection.ltr,
      creationParamsCodec: const StandardMessageCodec(),
    ),
    // HC
    CompositionMode.hybrid => _buildLink(PlatformViewsService.initExpensiveAndroidView),
    // HCPP
    CompositionMode.hcpp => _buildLink(PlatformViewsService.initHybridAndroidView),
  };
}
```

HCPP が有効なアプリ（`hcpp` フレーバー）では、TLHC や HC を選んでもエンジンが自動的に HCPP に切り替えます。取り違えを防ぐため、アプリのホーム画面には「選んだ API → 実際に使われる方式」を表示しています。

### スレッドのマージの影響を見えるようにする

HC と HCPP のいちばん大きな違いは、スレッドのマージがあるかどうかです。ただ、メインスレッドが暇なときは差が出にくくなります。

そこで、地図や広告の SDK がメインスレッドで重い処理をしている状況を再現するため、**毎フレーム、メインスレッドをわざと指定した時間だけ忙しくする** 仕組みを入れました。

```kotlin
// MainThreadLoad.kt
// Choreographer は、画面が更新されるタイミングごとに処理を呼び出してくれる Android の仕組み
class MainThreadLoad : Choreographer.FrameCallback {
    private var loadMillis = 0

    fun setLoadMillis(millis: Int) { /* ... */ }

    override fun doFrame(frameTimeNanos: Long) {
        if (loadMillis <= 0) return
        // 指定した時間が過ぎるまで、何もせずにメインスレッドを占有する
        val end = SystemClock.uptimeMillis() + loadMillis
        while (SystemClock.uptimeMillis() < end) {
            // busy wait
        }
        // 次のフレームでもまた呼んでもらう
        Choreographer.getInstance().postFrameCallback(this)
    }
}
```

### 計測する値

Flutter には、各フレームの描画にかかった時間を受け取る `SchedulerBinding.addTimingsCallback` という API があります。デモアプリはこれで各フレームの時間を集め、次の値を計算しています。

```dart
// lib/src/frame_stats.dart
// build にかかった時間（Dart のコード）
final build = timings.map((t) => ms(t.buildDuration)).toList();
// ラスタライズにかかった時間
final raster = timings.map((t) => ms(t.rasterDuration)).toList()..sort();
// フレームの開始からラスタライズの完了までの時間。ユーザーが感じる遅れに最も近い
final total = timings.map((t) => ms(t.totalSpan)).toList()..sort();
```

| 値 | 意味 |
| --- | --- |
| FPS | 1 秒あたりに描けたフレーム数 |
| build 平均 | Dart の `build` やレイアウトにかかった時間の平均 |
| ラスタライズ平均 / p90 | Raster スレッドが絵を描くのにかかった時間。描き始めるまでの待ち時間は含まない |
| 合計時間 p50 / p90 / p99 / 最大 | フレームの開始から描き終わるまでの時間。待ち時間も含むので、**スレッドのマージやメインスレッドの負荷の影響はここに出る** |
| ジャンク率 | 合計時間が 1 フレームの持ち時間（60Hz の画面なら約 16.6 ミリ秒、120Hz なら約 8.3 ミリ秒）を超えたフレームの割合 |

p50 / p90 / p99 は「全フレームを時間の短い順に並べたとき、50% / 90% / 99% の位置にあるフレームの時間」です。p99 が大きいほど、ときどき大きくカクつくことを意味します。

1 フレームの持ち時間は、端末が対応する最大のリフレッシュレートから計算します。可変リフレッシュレートの端末で計測ごとに条件が変わらないよう、アプリは起動時に最大のリフレッシュレートを要求しています。

また、Android の View の左上には、Android 側で数えた描画回数（1 秒あたり）を表示しています。Flutter 側だけでなく、Android の View が滑らかに動いているかも目で確認できます。

## 計測の手順

> [!IMPORTANT]
> 計測は必ず **実機** で、**profile モード** で行ってください。debug モードは開発用の余計な処理が入るので、数値が参考になりません。エミュレータでは Vulkan の条件を満たさず、HCPP にならないことがあります。

### 画面を操作して計測する

```bash
# 2 つのアプリを同じ端末にインストールして起動する
flutter run --profile --flavor legacy
flutter run --profile --flavor hcpp
```

1. ホーム画面の「HCPP: 有効 / 無効」が想定どおりになっているか確認する
2. API・View の種類・負荷・重ね表示を選び、「計測開始」をタップする
3. 15 秒間の自動スクロールが終わると、結果が表示される

結果はログにも 1 行の JSON で出力されるので、次のコマンドで集められます。

```bash
adb logcat -s flutter | grep HCPP_BENCH
```

### コマンドで自動計測する

Flutter の `integration_test`（実機で動かす結合テスト）を使って、同じ条件で繰り返し計測できます。条件は `--dart-define` で渡します。

```bash
# HC（legacy フレーバー）、メインスレッドの負荷 8 ミリ秒
SUMMARY_NAME=hc_load8 flutter drive --no-dds --profile --flavor legacy \
  --driver=test_driver/perf_driver.dart \
  --target=integration_test/scroll_perf_test.dart \
  --dart-define=PV_MODE=hybrid --dart-define=MAIN_THREAD_LOAD_MS=8

# 同じ条件で HCPP（hcpp フレーバー）
# HCPP が有効なアプリでは、PV_MODE=hybrid もエンジンが自動で HCPP に切り替える
SUMMARY_NAME=hcpp_load8 flutter drive --no-dds --profile --flavor hcpp \
  --driver=test_driver/perf_driver.dart \
  --target=integration_test/scroll_perf_test.dart \
  --dart-define=PV_MODE=hybrid --dart-define=MAIN_THREAD_LOAD_MS=8
```

`--no-dds` は必須です。付けないと、タイムラインの記録（`traceAction`）が VM Service に接続できずにテストが失敗します。

| `--dart-define` | 値 |
| --- | --- |
| `PV_MODE` | `textureLayer` / `hybrid` / `hcpp` |
| `PV_KIND` | `animated` / `surface` |
| `MAIN_THREAD_LOAD_MS` | 毎フレーム、メインスレッドを忙しくする時間（ミリ秒） |
| `OVERLAY` | Android の View の上に Flutter の部品を重ねるか（既定 `true`） |
| `DURATION_SEC` | 自動スクロールの時間（既定 15 秒） |

`PV_MODE=hcpp` は HCPP が有効なとき（`hcpp` フレーバーで、端末が条件を満たすとき）だけ使ってください。

出力されるファイル：

- `build/$SUMMARY_NAME.timeline_summary.json`
- `build/$SUMMARY_NAME.frame_stats.json`

`timeline_summary.json` には、ラスタライズ時間の平均（`average_frame_rasterizer_time_millis`）や 90% の位置の値（`90th_percentile_frame_rasterizer_time_millis`）などが入ります。Flutter 本体の性能テストと同じ形式なので、ほかの計測結果とも比べやすくなっています。

### 記事の表と同じ条件をまとめて計測する

記事の表と同じ 13 の条件をまとめて計測し、結果を Markdown の表で出力するスクリプトも用意しています。

```bash
tool/run_all.sh 3              # 13 の条件をそれぞれ 3 回計測する
dart run tool/summarize.dart   # 条件ごとの中央値を Markdown の表で出力する
```
