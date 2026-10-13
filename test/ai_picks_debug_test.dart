import 'package:aboutme/screens/widgets_gallery/screens/ai_picks_demo/book_detail_page.dart';
import 'package:aboutme/screens/widgets_gallery/screens/ai_picks_demo/demo_books.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('debug detail overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    await tester.pumpWidget(MaterialApp(home: BookDetailPage(book: demoBooks.first)));
    await tester.pump();
    final e = tester.takeException();
    // ignore: avoid_print
    print(e?.toString() ?? 'no exception');
  });
}
