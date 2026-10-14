import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maleva_tv/features/board/board_cells.dart';
import 'package:maleva_tv/features/board/board_header.dart';
import 'package:maleva_tv/features/board/board_theme.dart';
import 'package:maleva_tv/features/board/job_board_view.dart';
import 'planning_job.dart';

/// Planning column widths (flex), in display order after the fixed # column.
class PlanningColumns {
  PlanningColumns._();

  static const truck = 5;
  static const jobNo = 3;
  static const customer = 4;
  static const route = 6;
  static const vessel = 4;
  static const time = 2; // PICKUP and DELIVERY
  static const status = 4;
}

/// The Planning board: [BoardView] with the day's plans, one row per job, grouped by truck.
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

/// # / TRUCK & DRIVER / JOB NO. / CUSTOMER / FROM → TO / VESSEL / PICKUP / DELIVERY / STATUS.
class PlanningColumnHeaders extends StatelessWidget {
  const PlanningColumnHeaders({super.key});

  @override
  Widget build(BuildContext context) {
    final cell = BoardTheme.cell;
    const label = BoardHeaderRow.label;
    return BoardHeaderRow(children: [
      cell(width: BoardTheme.snoWidth, child: label('#')),
      cell(flex: PlanningColumns.truck, child: label('TRUCK  ·  DRIVER', align: Alignment.centerLeft)),
      cell(flex: PlanningColumns.jobNo, child: label('JOB NO.')),
      cell(flex: PlanningColumns.customer, child: label('CUSTOMER', align: Alignment.centerLeft)),
      cell(flex: PlanningColumns.route, child: label('FROM  →  TO', align: Alignment.centerLeft)),
      cell(flex: PlanningColumns.vessel, child: label('VESSEL', align: Alignment.centerLeft)),
      cell(flex: PlanningColumns.time, child: BoardHeaderRow.twoLine('PICKUP', 'TIME')),
      cell(flex: PlanningColumns.time, child: BoardHeaderRow.twoLine('DELIVERY', 'TIME')),
      cell(flex: PlanningColumns.status, child: label('STATUS'), divider: false),
    ]);
  }
}

/// One planned job. The first job of a truck shows the truck in full; the truck's next jobs show it
/// dimmed, so each truck's day reads as one block.
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
      height: 68,
      foregroundDecoration: selected ? BoxDecoration(border: Border.all(color: BoardTheme.selection, width: 3)) : null,
      decoration: BoxDecoration(
        color: selected
            ? BoardTheme.selection.withValues(alpha: 0.22)
            : (index.isEven ? BoardTheme.rowEven : BoardTheme.rowOdd),
        border: Border(
          // a brighter line where a new truck's jobs start
          top: job.firstOfTruck && index > 0 ? BorderSide(color: BoardTheme.accent, width: 2) : BorderSide.none,
          bottom: BorderSide(color: BoardTheme.gridLine),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          cell(
            width: BoardTheme.snoWidth,
            child: Row(
              children: [
                Container(width: 6, color: BoardTheme.statusColor(job.jobStatus)),
                Expanded(
                  child: Center(
                    child: Text('${index + 1}',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: BoardTheme.textMuted)),
                  ),
                ),
              ],
            ),
          ),
          cell(flex: PlanningColumns.truck, child: _truckCell()),
          cell(flex: PlanningColumns.jobNo, child: _jobNoCell()),
          cell(flex: PlanningColumns.customer, child: _textCell(job.customer, size: 15)),
          cell(flex: PlanningColumns.route, child: _routeCell()),
          cell(flex: PlanningColumns.vessel, child: _textCell(job.vessel, size: 15, weight: FontWeight.w800)),
          cell(flex: PlanningColumns.time, child: BoardCells.time(job.pickup, now)),
          cell(flex: PlanningColumns.time, child: BoardCells.time(job.delivery, now)),
          cell(flex: PlanningColumns.status, child: BoardCells.statusChip(job.jobStatus), divider: false),
        ],
      ),
    );
  }

  TextSpan _marked(String text, TextStyle style) => BoardCells.marked(text, style, highlight);

  Widget _truckCell() {
    final noTruck = job.truck.isEmpty;
    final truckStyle = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.5,
      height: 1.05,
      color: noTruck ? BoardTheme.textMuted : (job.firstOfTruck ? BoardTheme.textPrimary : BoardTheme.textMuted),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_shipping_rounded,
                  size: 18, color: job.firstOfTruck && !noTruck ? BoardTheme.accent : BoardTheme.textMuted),
              const SizedBox(width: 8),
              Flexible(
                child: Text.rich(
                  _marked(noTruck ? 'NO TRUCK YET' : job.truck.toUpperCase(), truckStyle),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Icon(Icons.person_rounded, size: 15, color: BoardTheme.textSecondary),
              const SizedBox(width: 8),
              Flexible(
                child: Text.rich(
                  _marked(
                    job.driver.isEmpty ? 'NO DRIVER YET' : job.driver.toUpperCase(),
                    TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: job.driver.isEmpty ? BoardTheme.textMuted : BoardTheme.textSecondary,
                    ),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _jobNoCell() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: BoardTheme.background.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: BoardTheme.border),
            ),
            child: Text.rich(
              _marked(
                job.jobNo.isEmpty ? '—' : job.jobNo,
                TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: BoardTheme.textPrimary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              maxLines: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _textCell(String text, {double size = 15, FontWeight weight = FontWeight.w600}) {
    if (text.isEmpty) {
      return Center(child: Text('—', style: TextStyle(fontSize: 18, color: BoardTheme.textMuted)));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text.rich(
          _marked(
            text.toUpperCase(),
            TextStyle(fontSize: size, fontWeight: weight, color: BoardTheme.textPrimary, height: 1.15),
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  /// FROM over TO, each with a small coloured mark.
  Widget _routeCell() {
    Widget line(String mark, Color color, String place) => Row(
          children: [
            Container(
              width: 40,
              padding: const EdgeInsets.symmetric(vertical: 1),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(mark,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color, letterSpacing: 1)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                place.isEmpty ? '—' : place.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: place.isEmpty ? BoardTheme.textMuted : BoardTheme.textPrimary,
                ),
              ),
            ),
          ],
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          line('FROM', BoardTheme.accent, job.origin),
          const SizedBox(height: 5),
          line('TO', BoardTheme.offVessel, job.destination),
        ],
      ),
    );
  }
}
