import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixora/src/widget/pixiv_image.dart';

void main() {
  testWidgets('renders the supplied fallback for a missing image URL', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PixivImage(
          url: null,
          width: 84,
          height: 84,
          errorWidget: Icon(Icons.person),
        ),
      ),
    );

    expect(find.byIcon(Icons.person), findsOneWidget);
  });
}
