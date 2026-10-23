import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/calendar_album/controllers/calendar_controller.dart';
import 'package:aboutme/plugins/calendar_album/models/calendar_entry.dart';
import 'package:aboutme/plugins/calendar_album/screens/album_map_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _MapController extends ChangeNotifier implements CalendarController {
  @override
  final entries = {
    DateTime(2026): [
      CalendarEntry.create(
        title: 'Map photo',
        content: '',
        createdAt: DateTime(2026),
        latLng: '31.23,121.47',
        imageUrls: ['https://example.com/photo.png'],
      ),
    ],
  };

  @override
  List<String> getAllTags() => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Uri _mapUri(WidgetTester tester) {
  final image = tester
      .widgetList<Image>(find.byType(Image))
      .firstWhere(
        (image) =>
            image.image is NetworkImage &&
            (image.image as NetworkImage).url.contains('/v3/staticmap'),
      );
  return Uri.parse((image.image as NetworkImage).url);
}

Future<void> _openMap(WidgetTester tester) async {
  final controller = _MapController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: AppTheme(
        data: AppThemeData.light(),
        child: AlbumMapScreen(controller: controller),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('refreshes a stale empty key cache before showing the map', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('location_api_key'), isNull);
    // 模拟其他引擎/原生端写入，当前 SharedPreferences 缓存仍为空。
    await SharedPreferencesStorePlatform.instance.setValue(
      'String',
      'flutter.location_api_key',
      ' saved-key ',
    );
    await _openMap(tester);
    expect(_mapUri(tester).queryParameters['key'], 'saved-key');
    expect(find.text('calendar_album_map_key_missing'), findsNothing);
  });

  testWidgets('a fast drag commits once and stops moving after release', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'location_api_key': 'test-key'});
    await _openMap(tester);
    final before = _mapUri(tester);
    final map = find.byWidgetPredicate(
      (widget) => widget is GestureDetector && widget.onScaleEnd != null,
    );
    await tester.fling(map, const Offset(160, 0), 2000);
    await tester.pump();
    final after = _mapUri(tester);
    expect(
      after.queryParameters['location'],
      isNot(before.queryParameters['location']),
    );
    expect(after.queryParameters['zoom'], before.queryParameters['zoom']);
    await tester.pump(const Duration(milliseconds: 500));
    expect(_mapUri(tester), after);
    final transform = tester.widget<Transform>(
      find.descendant(of: map, matching: find.byType(Transform)).first,
    );
    expect(transform.transform, Matrix4.identity());
  });
}
