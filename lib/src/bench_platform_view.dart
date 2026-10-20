import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'composition_mode.dart';

/// [mode] に応じた API でネイティブ View を埋め込むウィジェット。
class BenchPlatformView extends StatelessWidget {
  const BenchPlatformView({super.key, required this.mode, required this.kind});

  final CompositionMode mode;
  final NativeViewKind kind;

  @override
  Widget build(BuildContext context) {
    return switch (mode) {
      CompositionMode.textureLayer => AndroidView(
        viewType: kind.viewType,
        layoutDirection: TextDirection.ltr,
        creationParamsCodec: const StandardMessageCodec(),
      ),
      CompositionMode.hybrid => _buildLink(PlatformViewsService.initExpensiveAndroidView),
      CompositionMode.hcpp => _buildLink(PlatformViewsService.initHybridAndroidView),
    };
  }

  Widget _buildLink(_ControllerFactory factory) {
    return PlatformViewLink(
      viewType: kind.viewType,
      surfaceFactory: (context, controller) {
        return AndroidViewSurface(
          controller: controller as AndroidViewController,
          gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
          hitTestBehavior: PlatformViewHitTestBehavior.opaque,
        );
      },
      onCreatePlatformView: (params) {
        return factory(
            id: params.id,
            viewType: kind.viewType,
            layoutDirection: TextDirection.ltr,
            creationParamsCodec: const StandardMessageCodec(),
            onFocus: () => params.onFocusChanged(true),
          )
          ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
          ..create();
      },
    );
  }
}

typedef _ControllerFactory =
    AndroidViewController Function({
      required int id,
      required String viewType,
      required TextDirection layoutDirection,
      dynamic creationParams,
      MessageCodec<dynamic>? creationParamsCodec,
      VoidCallback? onFocus,
    });
