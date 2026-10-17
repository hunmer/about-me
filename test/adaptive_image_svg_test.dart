import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aboutme/widgets/adaptive_image.dart';

void main() {
  testWidgets('svg accepts infinite preview width with finite height', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 482,
            child: AdaptiveImage(
              imagePath: 'assets/svg/items/clothes_bear-hoodie.svg',
              width: double.infinity,
              height: 150,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(AdaptiveImage)), const Size(482, 150));
  });
}
