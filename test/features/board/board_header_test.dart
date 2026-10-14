import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maleva_tv/features/board/board_header.dart';
import 'package:maleva_tv/features/board/board_theme.dart';

void main() {
  tearDown(() => BoardTheme.palette = BoardPalette.navy);

  for (final (name, palette) in [('Planning (light)', BoardPalette.malevaLight), ('Vessel Planning (navy)', BoardPalette.navy)]) {
    testWidgets('$name: headings are white on the header bar', (tester) async {
      BoardTheme.palette = palette;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: BoardHeaderRow(children: [Expanded(child: BoardHeaderRow.label('TRUCK'))])),
      ));
      final text = tester.widget<Text>(find.text('TRUCK'));
      expect(text.style!.color, Colors.white);
      // and the bar behind them is dark enough for white text
      expect(palette.headerFill.computeLuminance(), lessThan(0.2));
    });
  }
}
