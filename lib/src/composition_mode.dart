/// Dart 側でどの API を使って PlatformView を生成するか。
///
/// 注意: HCPP が有効なアプリ（hcpp フレーバー）では、エンジンが
/// [textureLayer] / [hybrid] の生成リクエストも HCPP にアップグレードする。
enum CompositionMode {
  /// `AndroidView`（内部的には `initAndroidView`）。TLHC、条件次第で VD にフォールバック。
  textureLayer('TLHC', 'AndroidView'),

  /// `initExpensiveAndroidView`。常に従来の Hybrid Composition。
  hybrid('HC', 'initExpensiveAndroidView'),

  /// `initHybridAndroidView`。常に Hybrid Composition++。
  hcpp('HCPP', 'initHybridAndroidView');

  const CompositionMode(this.shortName, this.apiName);

  final String shortName;
  final String apiName;
}

/// 埋め込むネイティブ View の種類。
enum NativeViewKind {
  /// Choreographer 駆動で毎フレーム再描画する通常の View。
  animated('hcpp-bench/animated-view', 'View (Canvas)'),

  /// 専用スレッドから描画する SurfaceView。動画や地図 SDK を想定。
  surface('hcpp-bench/surface-view', 'SurfaceView');

  const NativeViewKind(this.viewType, this.label);

  final String viewType;
  final String label;
}
