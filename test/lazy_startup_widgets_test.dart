import 'dart:async';

import 'package:aboutme/core/widgets/app_bootstrap.dart';
import 'package:aboutme/core/widgets/lazy_indexed_stack.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('bootstrap draws before initialization and gates the app tree', (
    tester,
  ) async {
    final initialization = Completer<void>();
    var started = false;
    var appBuilt = false;
    await tester.pumpWidget(
      AppBootstrap(
        initialize: () {
          started = true;
          expect(find.text('Aboutme'), findsOneWidget);
          return initialization.future;
        },
        builder: (_) {
          appBuilt = true;
          return const Directionality(
            textDirection: TextDirection.ltr,
            child: Text('ready'),
          );
        },
      ),
    );
    expect(started, isTrue);
    expect(appBuilt, isFalse);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    initialization.complete();
    await tester.pump();
    expect(appBuilt, isTrue);
    expect(find.text('ready'), findsOneWidget);
    expect(find.text('Aboutme'), findsNothing);
  });

  testWidgets('bootstrap handles completion after disposal', (tester) async {
    final initialization = Completer<void>();
    await tester.pumpWidget(
      AppBootstrap(
        initialize: () => initialization.future,
        builder: (_) => const SizedBox(),
      ),
    );
    await tester.pumpWidget(const SizedBox());
    initialization.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('bootstrap failure keeps dependent widgets unbuilt', (
    tester,
  ) async {
    final initialization = Completer<void>();
    var appBuilt = false;
    await tester.pumpWidget(
      AppBootstrap(
        initialize: () => initialization.future,
        builder: (_) {
          appBuilt = true;
          return const SizedBox();
        },
      ),
    );
    initialization.completeError(StateError('storage failed'));
    await tester.pump();
    expect(tester.takeException(), isStateError);
    expect(appBuilt, isFalse);
    expect(find.text('启动失败，请重启应用'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('tabs initialize on demand, preserve state and pause tickers', (
    tester,
  ) async {
    var index = 0;
    var label = 'first';
    final initialized = <int>[];
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return LazyIndexedStack(
              index: index,
              builders: [
                for (var i = 0; i < 3; i++)
                  (_) => _TabProbe(
                    id: i,
                    label: label,
                    onInit: () => initialized.add(i),
                  ),
              ],
            );
          },
        ),
      ),
    );
    expect(initialized, [0]);
    await tester.tap(find.text('page 0 first: 0'));
    await tester.pump();

    rebuild(() => index = 1);
    await tester.pump();
    expect(initialized, [0, 1]);
    final first = find.byWidgetPredicate(
      (widget) => widget is _TabProbe && widget.id == 0,
      skipOffstage: false,
    );
    final second = find.byWidgetPredicate(
      (widget) => widget is _TabProbe && widget.id == 1,
    );
    expect(TickerMode.of(tester.element(first)), isFalse);
    expect(TickerMode.of(tester.element(second)), isTrue);
    expect(find.text('page 0 first: 1', skipOffstage: false), findsOneWidget);

    rebuild(() {
      index = 0;
      label = 'updated';
    });
    await tester.pump();
    expect(initialized, [0, 1]);
    expect(find.text('page 0 updated: 1'), findsOneWidget);
    expect(TickerMode.of(tester.element(first)), isTrue);
  });
}

class _TabProbe extends StatefulWidget {
  const _TabProbe({
    required this.id,
    required this.label,
    required this.onInit,
  });

  final int id;
  final String label;
  final VoidCallback onInit;

  @override
  State<_TabProbe> createState() => _TabProbeState();
}

class _TabProbeState extends State<_TabProbe> {
  var count = 0;

  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => setState(() => count++),
    child: Text('page ${widget.id} ${widget.label}: $count'),
  );
}
