import 'package:flutter/material.dart';
import 'board_theme.dart';

/// The grid's heading row, shared by every board: same height, fill and bottom line.
class BoardHeaderRow extends StatelessWidget {
  BoardHeaderRow({required this.children, super.key});

  /// [BoardTheme.cell]s, with the same widths as the board's rows.
  final List<Widget> children;

  static const height = 66.0;

  static TextStyle get style => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: BoardTheme.textPrimary,
        letterSpacing: 1.6,
      );

  /// One heading; shrinks rather than overflow a narrow column.
  static Widget label(String text, {Alignment align = Alignment.center}) => Align(
        alignment: align,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: FittedBox(fit: BoxFit.scaleDown, child: Text(text, style: style)),
        ),
      );

  /// A short code over its meaning, e.g. ETA / ARRIVAL.
  static Widget twoLine(String code, String meaning) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(code, style: style.copyWith(fontSize: 13)),
                Text(meaning,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: BoardTheme.textSecondary,
                        letterSpacing: 1.4)),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: BoardTheme.headerFill,
        border: Border(bottom: BorderSide(color: BoardTheme.accent, width: 2)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

/// Vessel Planning headings: # / VESSEL / PORT / JOB NO. / EMPLOYEE / STATUS, then ETA / ETB / ETD
/// under LOADING VESSEL and OFF VESSEL.
class VesselColumnHeaders extends StatelessWidget {
  const VesselColumnHeaders({super.key});

  @override
  Widget build(BuildContext context) {
    final cell = BoardTheme.cell;
    final label = BoardHeaderRow.label;
    Widget group(String title, Color color, {bool last = false}) => cell(
          flex: BoardTheme.timeGroup,
          divider: !last,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  border: Border(bottom: BorderSide(color: BoardTheme.gridLine)),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.directions_boat_filled_rounded, size: 15, color: color),
                      const SizedBox(width: 8),
                      Text(title, style: BoardHeaderRow.style.copyWith(fontSize: 11, color: color)),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    cell(child: BoardHeaderRow.twoLine('ETA', 'ARRIVAL')),
                    cell(child: BoardHeaderRow.twoLine('ETB', 'BERTHING')),
                    cell(child: BoardHeaderRow.twoLine('ETD', 'DEPARTURE'), divider: false),
                  ],
                ),
              ),
            ],
          ),
        );
    return BoardHeaderRow(children: [
      cell(width: BoardTheme.snoWidth, child: label('#')),
      cell(flex: BoardTheme.vessel, child: label('VESSEL', align: Alignment.centerLeft)),
      cell(flex: BoardTheme.port, child: label('PORT', align: Alignment.centerLeft)),
      cell(flex: BoardTheme.jobNo, child: label('JOB NO.')),
      cell(flex: BoardTheme.employee, child: label('EMPLOYEE', align: Alignment.centerLeft)),
      cell(flex: BoardTheme.status, child: label('STATUS')),
      group('LOADING VESSEL', BoardTheme.accent),
      group('OFF VESSEL', BoardTheme.offVessel, last: true),
    ]);
  }
}
