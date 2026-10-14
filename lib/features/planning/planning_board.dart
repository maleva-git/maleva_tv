import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maleva_tv/features/board/board_cells.dart';
import 'package:maleva_tv/features/board/board_header.dart';
import 'package:maleva_tv/features/board/board_theme.dart';
import 'package:maleva_tv/features/board/job_board_view.dart';
import 'planning_job.dart';

/// Planning column widths (flex), after the fixed S.NO column. maleva_app's tablet planning grid,
/// without its edit-only columns and, as the owner asked, without L ETA, O ETA, STATUS and REMARKS;
/// the room goes to TRUCK and DRIVER, shown large, and to roomier text cells.
class PlanningColumns {
  PlanningColumns._();

  static const jobNo = 3;
  static const truck = 4;
  static const driver = 4;
  static const origin = 3;
  static const dest = 3;
  static const pkg = 3;
  static const customer = 4;
  static const date = 2; // P.DATE, D.DATE
  static const vessel = 3;
  static const pic = 3;
}

/// One row of the Planning grid.
const planningRowHeight = 74.0;

/// The Planning board: [BoardView] with the plan(s), one row per job in the web's order, laid out like
/// maleva_app's tablet planning grid.
class PlanningBoardView extends StatelessWidget {
  const PlanningBoardView({
    required this.date,
    required this.onChangeDate,
    required this.jobs,
    // Very slow (the owner's choice for Planning): about 4.5 px a second, one row every ~15 s,
    // holding 10 s at the top and bottom. Vessel Planning keeps its own speed.
    this.scrollStep = 0.15,
    this.autoPlay = true,
    this.selectedIndex,
    this.controls,
    this.search = '',
    this.searchBar,
    this.titleWidget,
    this.belowTitle,
    super.key,
  });

  final DateTime date;
  final ValueChanged<int> onChangeDate;
  final AsyncValue<List<PlanningJob>> jobs;
  final double scrollStep;
  final bool autoPlay;
  final int? selectedIndex;
  final Widget? controls;
  final String search;
  final Widget? searchBar;
  final Widget? titleWidget;
  final Widget? belowTitle;

  @override
  Widget build(BuildContext context) {
    return BoardView<PlanningJob>(
      title: 'PLANNING',
      subtitle: 'Trucks and drivers planned for this day',
      date: date,
      onChangeDate: onChangeDate,
      jobs: jobs,
      scrollStep: scrollStep,
      edgePause: const Duration(seconds: 10),
      rowHeight: planningRowHeight,
      autoPlay: autoPlay,
      selectedIndex: selectedIndex,
      controls: controls,
      search: search,
      searchBar: searchBar,
      titleWidget: titleWidget,
      belowTitle: belowTitle,
      noMatchTitle: 'No planned job matches',
      columnHeaders: const PlanningColumnHeaders(),
      rowBuilder: (job, index, selected, now) =>
          PlanningRow(job: job, index: index, now: now, selected: selected, highlight: search),
    );
  }
}

/// S.NO / JOB NO / TRUCK / DRIVER / ORIGIN / DEST / PKG / WT / CUSTOMER / P.DATE / D.DATE / VESSEL / PIC.
class PlanningColumnHeaders extends StatelessWidget {
  const PlanningColumnHeaders({super.key});

  @override
  Widget build(BuildContext context) {
    final cell = BoardTheme.cell;
    const label = BoardHeaderRow.label;
    Widget left(String t) => label(t, align: Alignment.centerLeft);
    return BoardHeaderRow(children: [
      cell(width: BoardTheme.snoWidth, child: label('S.NO')),
      cell(flex: PlanningColumns.jobNo, child: label('JOB NO')),
      cell(flex: PlanningColumns.truck, child: left('TRUCK')),
      cell(flex: PlanningColumns.driver, child: left('DRIVER')),
      cell(flex: PlanningColumns.origin, child: left('ORIGIN')),
      cell(flex: PlanningColumns.dest, child: left('DEST')),
      cell(flex: PlanningColumns.pkg, child: left('PKG / WT')),
      cell(flex: PlanningColumns.customer, child: left('CUSTOMER')),
      cell(flex: PlanningColumns.date, child: BoardHeaderRow.twoLine('P.DATE', 'PICKUP')),
      cell(flex: PlanningColumns.date, child: BoardHeaderRow.twoLine('D.DATE', 'DELIVERY')),
      cell(flex: PlanningColumns.vessel, child: left('VESSEL')),
      cell(flex: PlanningColumns.pic, child: left('PIC'), divider: false),
    ]);
  }
}

/// One planned job on one row. The truck is a truck icon and its full name in large blue letters, the
/// driver a large name, so both read from across the room. A truck's next job straight after its
/// previous one shows the name lighter.
class PlanningRow extends StatelessWidget {
  const PlanningRow({
    required this.job,
    required this.index,
    required this.now,
    this.selected = false,
    this.highlight = '',
    super.key,
  });

  final PlanningJob job;
  final int index;
  final DateTime now;
  final bool selected;
  final String highlight;

  @override
  Widget build(BuildContext context) {
    final cell = BoardTheme.cell;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: planningRowHeight,
      foregroundDecoration: selected ? BoxDecoration(border: Border.all(color: BoardTheme.selection, width: 3)) : null,
      decoration: BoxDecoration(
        color: selected
            ? BoardTheme.selection.withValues(alpha: 0.12)
            : (index.isEven ? BoardTheme.rowEven : BoardTheme.rowOdd),
        border: Border(bottom: BorderSide(color: BoardTheme.gridLine)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          cell(
            width: BoardTheme.snoWidth,
            child: Center(
              child: Text('${index + 1}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: BoardTheme.textMuted)),
            ),
          ),
          cell(flex: PlanningColumns.jobNo, child: _jobNo()),
          cell(flex: PlanningColumns.truck, child: _truck()),
          cell(flex: PlanningColumns.driver, child: _driver()),
          cell(flex: PlanningColumns.origin, child: _text(job.origin)),
          cell(flex: PlanningColumns.dest, child: _text(job.destination)),
          cell(flex: PlanningColumns.pkg, child: _text(job.pkg, upper: false)),
          cell(flex: PlanningColumns.customer, child: _text(job.customer, weight: FontWeight.w700)),
          cell(flex: PlanningColumns.date, child: BoardCells.time(job.pickup, now)),
          cell(flex: PlanningColumns.date, child: BoardCells.time(job.delivery, now)),
          cell(flex: PlanningColumns.vessel, child: _text(job.vessel, weight: FontWeight.w700)),
          cell(flex: PlanningColumns.pic, child: _text(job.pic), divider: false),
        ],
      ),
    );
  }

  TextSpan _marked(String text, TextStyle style) => BoardCells.marked(text, style, highlight);

  Widget _jobNo() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text.rich(
              _marked(
                job.jobNo.isEmpty ? '—' : job.jobNo,
                TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: BoardTheme.accent,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              maxLines: 1,
            ),
          ),
        ),
      );

  /// A truck icon and the truck name: large, full (a long name shrinks to fit, never cut), on the
  /// column's soft blue tint. The truck's next job straight after shows the icon and name lighter.
  Widget _truck() {
    final none = job.truck.isEmpty;
    final repeat = !job.firstOfTruck;
    return Container(
      color: BoardTheme.accent.withValues(alpha: BoardTheme.palette.isLight ? 0.08 : 0.16),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: none
          ? Text('NO TRUCK YET',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: BoardTheme.warning, letterSpacing: 1))
          : Row(children: [
              Icon(Icons.local_shipping_rounded, size: 26, color: repeat ? BoardTheme.textMuted : BoardTheme.accent),
              const SizedBox(width: 10),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text.rich(
                    _marked(
                      job.truck.toUpperCase(),
                      TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        color: repeat ? BoardTheme.textMuted : BoardTheme.accent,
                      ),
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
            ]),
    );
  }

  /// The driver: the full name only, large (no initials badge).
  Widget _driver() {
    final name = job.driver.trim();
    if (name.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text('NO DRIVER YET',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: BoardTheme.warning, letterSpacing: 1)),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text.rich(
          _marked(
            name.toUpperCase(),
            TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: BoardTheme.textPrimary, height: 1.15),
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  /// A plain cell: up to two lines, cut with "…". A single word ("SINGAPORE") never breaks in the
  /// middle: it stays on one line and shrinks a little if it must.
  Widget _text(String value, {FontWeight weight = FontWeight.w600, bool upper = true}) {
    final missing = value.trim().isEmpty;
    final oneWord = !missing && !value.trim().contains(RegExp(r'\s'));
    final style = TextStyle(
      fontSize: 17,
      fontWeight: missing ? FontWeight.w600 : weight,
      color: missing ? BoardTheme.textMuted : BoardTheme.textPrimary,
      height: 1.2,
      letterSpacing: 0.2,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Align(
        alignment: Alignment.centerLeft,
        child: oneWord
            ? FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text.rich(_marked(upper ? value.trim().toUpperCase() : value.trim(), style), maxLines: 1),
              )
            : Text.rich(
                _marked(missing ? '—' : (upper ? value.toUpperCase() : value), style),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
      ),
    );
  }
}
