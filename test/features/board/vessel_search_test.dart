import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maleva_tv/features/board/job_board_view.dart';
import 'package:maleva_tv/features/home/domain/entities/job_model.dart';
import 'package:maleva_tv/features/home/presentation/home_controller.dart';
import 'package:maleva_tv/main_navigation_screen.dart';

JobModel _job(String vessel, {String off = '', String jobNo = 'MY001'}) =>
    JobModel(id: 1, jobNo: jobNo, jobStatus: 'ASSIGNED', loadingVesselName: vessel, offVesselName: off);

void main() {
  group('matchesSearch', () {
    test('finds the loading vessel, ignoring case', () {
      expect(matchesSearch(_job('EVER MAGNA'), 'ever'), isTrue);
    });
    test('finds the off vessel and the job number', () {
      expect(matchesSearch(_job('SHIJING', off: 'EVER BREED'), 'breed'), isTrue);
      expect(matchesSearch(_job('SHIJING', jobNo: 'MY002605899'), '605899'), isTrue);
    });
    test('every word must match, in any order', () {
      expect(matchesSearch(_job('EVER MAGNA'), 'magna ever'), isTrue);
      expect(matchesSearch(_job('EVER MAGNA'), 'ever pacific'), isFalse);
    });
  });

  group('on the TV', () {
    late ProviderContainer container;

    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      container = ProviderContainer(overrides: [
        jobsProvider.overrideWith((ref) async => [_job('EVER MAGNA'), _job('SHIJING')]),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MainNavigationScreen()),
      ));
      await tester.pump();
      await tester.pump();
    }

    bool fieldFocused(WidgetTester tester) => tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus;

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('the search field sits in the title bar, with the vessel count instead of status tiles',
        (tester) async {
      await open(tester);
      expect(find.byType(TextField), findsOneWidget);
      expect(fieldFocused(tester), isFalse);
      expect(find.text('2 VESSELS'), findsOneWidget);
      expect(find.text('TOTAL'), findsNothing); // no status count tiles any more
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('typing a letter starts the search with that letter', (tester) async {
      await open(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyE, character: 'e');
      await settle(tester);

      expect(fieldFocused(tester), isTrue);
      expect(container.read(searchProvider), 'e');
      // the cursor sits after the typed letter, so the next letter adds to it
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.selection, const TextSelection.collapsed(offset: 1));
      expect(tester.widget<JobBoardView>(find.byType(JobBoardView)).search, 'e');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the search key (here /) opens an empty search; Escape closes it', (tester) async {
      await open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.slash);
      await settle(tester);
      expect(fieldFocused(tester), isTrue);

      await tester.enterText(find.byType(TextField), 'SHI');
      await settle(tester);
      expect(container.read(searchProvider), 'SHI');

      // first Escape clears the text, the second closes the search
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(container.read(searchProvider), '');
      expect(fieldFocused(tester), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(fieldFocused(tester), isFalse);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('down from the field moves into the results', (tester) async {
      await open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyE, character: 'e');
      await settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await settle(tester);

      expect(tester.widget<JobBoardView>(find.byType(JobBoardView)).selectedIndex, 0);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a forgotten search closes by itself after 2 minutes', (tester) async {
      await open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyE, character: 'e');
      await settle(tester);
      await tester.pump(const Duration(minutes: 2, seconds: 1));
      await settle(tester);

      expect(fieldFocused(tester), isFalse);
      expect(container.read(searchProvider), '');
      await tester.pumpWidget(const SizedBox());
    });
  });
}
