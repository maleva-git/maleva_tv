import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maleva_tv/features/board/job_board_view.dart';
import 'package:maleva_tv/features/home/domain/entities/job_model.dart';
import 'package:maleva_tv/features/home/presentation/home_controller.dart';
import 'package:maleva_tv/main_navigation_screen.dart';

JobModel _job(int id) =>
    JobModel(id: id, jobNo: 'SO-$id', jobStatus: 'ASSIGNED', picName: 'Ahmad', loadingVesselName: 'MV $id');

void main() {
  late ProviderContainer container;

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    container = ProviderContainer(overrides: [
      jobsProvider.overrideWith((ref) async => [for (var i = 1; i <= 20; i++) _job(i)]),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: MainNavigationScreen()),
    ));
    await tester.pump();
    await tester.pump();
  }

  JobBoardView board(WidgetTester tester) => tester.widget<JobBoardView>(find.byType(JobBoardView));

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> close(WidgetTester tester) => tester.pumpWidget(const SizedBox());

  testWidgets('starts in auto mode on the one vessel planning board', (tester) async {
    await open(tester);
    expect(find.textContaining('AUTO ·'), findsOneWidget);
    expect(find.text('VESSEL PLANNING'), findsOneWidget);
    expect(find.textContaining('WESTPORT'), findsNothing);
    expect(board(tester).autoPlay, isTrue);
    await close(tester);
  });

  testWidgets('down stops auto mode and highlights rows one by one', (tester) async {
    await open(tester);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.arrowDown);

    expect(find.textContaining('PAUSED'), findsOneWidget);
    expect(board(tester).autoPlay, isFalse);
    expect(board(tester).selectedIndex, 1);
    await close(tester);
  });

  testWidgets('left and right change the day', (tester) async {
    await open(tester);
    final day = container.read(dateProvider);
    await press(tester, LogicalKeyboardKey.arrowRight);
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(container.read(dateProvider).difference(day).inDays, 2);

    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(container.read(dateProvider).difference(day).inDays, 1);
    await close(tester);
  });

  testWidgets('OK goes back to auto mode and clears the highlight', (tester) async {
    await open(tester);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.select);

    expect(find.textContaining('AUTO ·'), findsOneWidget);
    expect(board(tester).selectedIndex, isNull);
    await close(tester);
  });

  testWidgets('auto mode comes back by itself after 45 s without a key', (tester) async {
    await open(tester);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(seconds: 46));

    expect(board(tester).autoPlay, isTrue);
    await close(tester);
  });

  testWidgets('up on the first row goes straight to the last row, down on the last back to the first', (tester) async {
    await open(tester);
    await press(tester, LogicalKeyboardKey.arrowDown); // row 1
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(board(tester).selectedIndex, 19);
    expect(find.textContaining('ROW 20 / 20'), findsOneWidget);

    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(board(tester).selectedIndex, 0);
    await close(tester);
  });

  testWidgets('up in auto mode starts at the last row', (tester) async {
    await open(tester);
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(board(tester).selectedIndex, 19);
    await close(tester);
  });

  testWidgets('a held key moves fast and stops at the end instead of wrapping', (tester) async {
    await open(tester);
    await press(tester, LogicalKeyboardKey.arrowDown);
    for (var i = 0; i < 30; i++) {
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowDown);
    }
    await tester.pump(const Duration(milliseconds: 300));
    expect(board(tester).selectedIndex, 19);
    await close(tester);
  });

  testWidgets('channel and fast-forward keys jump a page', (tester) async {
    await open(tester);
    await press(tester, LogicalKeyboardKey.arrowDown); // row 1
    await press(tester, LogicalKeyboardKey.channelDown);
    expect(board(tester).selectedIndex, 6);
    await press(tester, LogicalKeyboardKey.mediaFastForward);
    expect(board(tester).selectedIndex, 12);
    await press(tester, LogicalKeyboardKey.channelUp);
    expect(board(tester).selectedIndex, 6);
    await close(tester);
  });

  testWidgets('Escape (the desktop Back) returns to auto mode', (tester) async {
    await open(tester);
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(board(tester).autoPlay, isFalse);

    await press(tester, LogicalKeyboardKey.escape);
    expect(board(tester).autoPlay, isTrue);
    expect(board(tester).selectedIndex, isNull);
    await close(tester);
  });
}
