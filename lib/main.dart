import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app/app.dart';
import 'src/app/bootstrap.dart';

Future<void> main() async {
  final result = await bootstrap();

  runApp(
    UncontrolledProviderScope(
      container: result.container,
      child: PixivApp(protocolRegistered: result.protocolRegistered),
    ),
  );
}
