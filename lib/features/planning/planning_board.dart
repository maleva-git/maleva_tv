import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maleva_tv/features/board/board_cells.dart';
import 'package:maleva_tv/features/board/board_header.dart';
import 'package:maleva_tv/features/board/board_theme.dart';
import 'package:maleva_tv/features/board/job_board_view.dart';
import 'planning_job.dart';

/// Planning column widths (flex), after the fixed S.NO column - the columns of maleva_app's tablet
/// planning grid ("All": job no, truck, driver, origin, dest, pkg/wt, customer, p.date, d.date, vessel,
/// PIC, L ETA, O ETA, status, remarks), without its edit-only columns (tick, RTI, sort).
class PlanningColumns {
  PlanningColumns._();

  static const jobNo = 3;
  static const truck = 3;
  static const driver = 3;
  static const origin = 3;
  static const dest = 3;
  static const pkg = 3;
  static const customer = 4;
  static const date = 2; // P.DATE, D.DATE, L ETA, O ETA
  static const vessel = 3;
  static const pic = 3;
  static const status = 3;
  static const remarks = 3;
}

/// One row of the Planning grid.
const planningRowHeight = 58.0;

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
/// L ETA / O ETA / STATUS / REMARKS - maleva_app's tablet grid headings.
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
      cell(flex: PlanningColumns.date, child: BoardHeaderRow.twoLine('L ETA', 'LOADING')),
      cell(flex: PlanningColumns.date, child: BoardHeaderRow.twoLine('O ETA', 'OFF VESSEL')),
      cell(flex: PlanningColumns.status, child: label('STATUS')),
      cell(flex: PlanningColumns.remarks, child: left('REMARKS'), divider: false),
    ]);
  }
}

/// One planned job, one line, as a row of maleva_app's tablet grid: job no in blue, truck and driver
/// bold. A truck's next job straight after its previous one shows the truck dimmed.
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
            ? BoardTheme.selection.withValues(alpha: 0.14)
            : (index.isEven ? BoardTheme.rowEven : BoardTheme.rowOdd),
        border: Border(bottom: BorderSide(color: BoardTheme.gridLine)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          cell(
            width: BoardTheme.snoWidth,
            child: Row(children: [
              Container(width: 5, color: BoardTheme.statusColor(job.jobStatus)),
              Expanded(
                child: Center(
                  child: Text('${index + 1}',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: BoardTheme.textMuted)),
                ),
              ),
            ]),
          ),
          cell(flex: PlanningColumns.jobNo, child: _jobNo()),
          cell(flex: PlanningColumns.truck, child: _truck()),
          cell(
            flex: PlanningColumns.driver,
            child: _text(job.driver, weight: FontWeight.w700, empty: 'NO DRIVER', icon: Icons.person_outline),
          ),
          cell(flex: PlanningColumns.origin, child: _text(job.origin)),
          cell(flex: PlanningColumns.dest, child: _text(job.destination)),
          cell(flex: PlanningColumns.pkg, child: _text(job.pkg, upper: false)),
          cell(flex: PlanningColumns.customer, child: _text(job.customer, weight: FontWeight.w700)),
          cell(flex: PlanningColumns.date, child: BoardCells.time(job.pickup, now)),
          cell(flex: PlanningColumns.date, child: BoardCells.time(job.delivery, now)),
          cell(flex: PlanningColumns.vessel, child: _text(job.vessel, weight: FontWeight.w700)),
          cell(flex: PlanningColumns.pic, child: _text(job.pic)),
          cell(flex: PlanningColumns.date, child: BoardCells.time(job.leta, now)),
          cell(flex: PlanningColumns.date, child: BoardCells.time(job.oeta, now)),
          cell(flex: PlanningColumns.status, child: BoardCells.statusChip(job.jobStatus)),
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

  Widget _truck() {
    final none = job.truck.isEmpty;
    final dim = none || !job.firstOfTruck;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(children: [
        Icon(Icons.local_shipping_outlined, size: 17, color: dim ? BoardTheme.textMuted : BoardTheme.accent),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                _marked(
                  none ? 'NO TRUCK' : job.truck.toUpperCase(),
                  TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: dim ? BoardTheme.textMuted : BoardTheme.textPrimary,
                  ),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (job.truckSize.isNotEmpty)
                Text(job.truckSize.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: BoardTheme.textMuted)),
            ],
          ),
        ),
      ]),
    );
  }

  /// A plain cell: up to two lines, cut with "…".
  Widget _text(String value,
      {FontWeight weight = FontWeight.w500, bool upper = true, String empty = '—', IconData? icon}) {
    final missing = value.trim().isEmpty;
    final style = TextStyle(
      fontSize: 14,
      fontWeight: missing ? FontWeight.w600 : weight,
      color: missing ? BoardTheme.textMuted : BoardTheme.textPrimary,
      height: 1.15,
    );
    final text = missing ? empty : (upper ? value.toUpperCase() : value);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(children: [
        if (icon != null && !missing) ...[
          Icon(icon, size: 15, color: BoardTheme.textSecondary),
          const SizedBox(width: 5)
        ],
        Expanded(
          child: Text.rich(_marked(text, style), maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }
}
