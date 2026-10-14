import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maleva_tv/features/home/domain/entities/job_model.dart';
import 'package:maleva_tv/features/home/presentation/home_controller.dart';
import 'package:maleva_tv/features/home/presentation/widgets/port_picker.dart';
import 'package:maleva_tv/main_navigation_screen.dart';

void main() {
  late ProviderContainer container;

  Future<void> open(WidgetTester tester, {Map<String, String> saved = const {}}) async {
    FlutterSecureStorage.setMockInitialValues(Map.of(saved));
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    container = ProviderContainer(overrides: [
      jobsProvider.overrideWith((ref) async => [const JobModel(id: 1, jobNo: 'MY1', jobStatus: 'ASSIGNED')]),
      portsProvider.overrideWith((ref) async => ['SOUTHPORT-B11', 'WESTPORT-B18']),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: MainNavigationScreen()),
    ));
    await settle(tester);
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await settle(tester);
  }

  testWidgets('the board starts on all ports', (tester) async {
    await open(tester);
    expect(container.read(portFilterProvider), '');
    expect(find.text('ALL PORTS'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  // The test keyboard has no key code for the remote's green button; a click on the PORT chip runs
  // the same code (_openPortPicker).
  testWidgets('the PORT chip opens the port list; down and OK pick a port for the board', (tester) async {
    await open(tester);
    await tester.tap(find.text('ALL PORTS'));
    await settle(tester);
    expect(find.byType(PortPicker), findsOneWidget);

    await press(tester, LogicalKeyboardKey.arrowDown); // SOUTHPORT-B11
    await press(tester, LogicalKeyboardKey.arrowDown); // WESTPORT-B18
    await press(tester, LogicalKeyboardKey.select);

    expect(find.byType(PortPicker), findsNothing);
    expect(container.read(portFilterProvider), 'WESTPORT-B18');
    expect(find.text('WESTPORT-B18'), findsOneWidget); // the PORT chip in the title bar
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Back closes the list without changing the port', (tester) async {
    await open(tester);
    await tester.tap(find.text('ALL PORTS'));
    await settle(tester);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.escape);

    expect(find.byType(PortPicker), findsNothing);
    expect(container.read(portFilterProvider), '');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a port picked before is remembered after a restart', (tester) async {
    await open(tester, saved: {'tv.port': 'SOUTHPORT-B11'});
    expect(container.read(portFilterProvider), 'SOUTHPORT-B11');
    await tester.pumpWidget(const SizedBox());
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
