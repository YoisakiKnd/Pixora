import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app/app.dart';
import 'src/app/bootstrap.dart';
import 'src/app/diagnostics.dart';

Future<void> main() async {
  // 必须包在最外层：zone 内的同步/异步错误都能落到诊断日志，
  // 而 PlatformDispatcher.onError 只覆盖后者。
  runZonedGuarded(
    () async {
      final result = await bootstrap();
      installGlobalErrorHandlers();

      runApp(
        UncontrolledProviderScope(
          container: result.container,
          child: PixivApp(protocolRegistered: result.protocolRegistered),
        ),
      );
    },
    (error, stack) => DiagnosticLog.record(
      'Uncaught zone error',
      error: error,
      stackTrace: stack,
      tag: 'zone',
    ),
  );
}
