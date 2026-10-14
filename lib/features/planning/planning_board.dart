import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maleva_tv/features/board/board_cells.dart';
import 'package:maleva_tv/features/board/board_header.dart';
import 'package:maleva_tv/features/board/board_theme.dart';
import 'package:maleva_tv/features/board/job_board_view.dart';
import 'planning_job.dart';

/// Planning column widths (flex), after the fixed S.NO column. maleva_app's tablet planning grid,
/// without its edit-only columns and, as the owner asked, without L ETA, O ETA and STATUS; the room
/// goes to TRUCK and DRIVER, shown large.
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
  static const remarks = 3;
}

/// One row of the Planning grid.
const planningRowHeight = 66.0;

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

/// S.NO / JOB NO / TRUCK / DRIVER / ORIGIN / DEST / PKG / WT / CUSTOMER / P.DATE / D.DATE / VESSEL / PIC /
/// REMARKS.
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
      cell(flex: PlanningColumns.pic, child: left('PIC')),
      cell(flex: PlanningColumns.remarks, child: left('REMARKS'), divider: false),
    ]);
  }
}

/// One planned job on one row. The truck is a number-plate badge with its full name, the driver a
/// large name with initials, so both read from across the room. A truck's next job straight after
/// its previous one shows the plate outlined only.
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: BoardTheme.textMuted)),
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
          cell(flex: PlanningColumns.pic, child: _text(job.pic)),
          cell(flex: PlanningColumns.remarks, child: _text(job.remarks, upper: false), divider: false),
        ],
      ),
    );
  }

  TextSpan _marked(String text, TextStyle style) => BoardCells.marked(text, style, highlight);

  Widget _jobNo() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text.rich(
              _marked(
                job.jobNo.isEmpty ? '—' : job.jobNo,
                TextStyle(
                  fontSize: 15,
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

  /// The number plate: the full truck name, never cut - a long one shrinks to fit instead.
  Widget _truck() {
    if (job.truck.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: BoardTheme.warning.withValues(alpha: 0.6), width: 1.5),
              color: BoardTheme.warning.withValues(alpha: 0.08),
            ),
            child: Text('NO TRUCK YET',
                style:
                    TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: BoardTheme.warning, letterSpacing: 1)),
          ),
        ),
      );
    }
    final repeat = !job.firstOfTruck;
    final ink = repeat ? BoardTheme.textSecondary : Colors.white;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: repeat
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: BoardTheme.border, width: 2),
                      )
                    : BoxDecoration(
                        // a raised plate: light from the top, a soft shadow under it
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color.lerp(BoardTheme.accent, Colors.white, 0.18)!, BoardTheme.accent],
                        ),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: Color.lerp(BoardTheme.accent, Colors.black, 0.25)!, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                              color: BoardTheme.accent.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3)),
                        ],
                      ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_shipping_rounded, size: 20, color: repeat ? BoardTheme.textMuted : Colors.white),
                    const SizedBox(width: 8),
                    Text.rich(
                      _marked(
                        job.truck.toUpperCase(),
                        TextStyle(
                            fontSize: 21, fontWeight: FontWeight.w900, color: ink, letterSpacing: 1.2, height: 1.1),
                      ),
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (job.truckSize.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(job.truckSize.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800, color: BoardTheme.textMuted, letterSpacing: 1)),
          ],
        ],
      ),
    );
  }

  /// The driver: initials and the full name, large.
  Widget _driver() {
    final name = job.driver.trim();
    if (name.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text('NO DRIVER YET',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: BoardTheme.warning, letterSpacing: 1)),
        ),
      );
    }
    final initials =
        name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2).map((p) => p[0]).join().toUpperCase();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [
        CircleAvatar(
          radius: 17,
          backgroundColor: BoardTheme.accent.withValues(alpha: 0.12),
          child: Text(initials, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: BoardTheme.accent)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            _marked(
              name.toUpperCase(),
              TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: BoardTheme.textPrimary, height: 1.1),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),
    );
  }

  /// A plain cell: up to two lines, cut with "…". A single word ("SINGAPORE") never breaks in the
  /// middle: it stays on one line and shrinks a little if it must.
  Widget _text(String value, {FontWeight weight = FontWeight.w600, bool upper = true}) {
    final missing = value.trim().isEmpty;
    final oneWord = !missing && !value.trim().contains(RegExp(r'\s'));
    final style = TextStyle(
      fontSize: 15,
      fontWeight: missing ? FontWeight.w600 : weight,
      color: missing ? BoardTheme.textMuted : BoardTheme.textPrimary,
      height: 1.15,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
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
