import 'package:flutter/material.dart';
import 'package:maleva_tv/features/board/board_cells.dart';
import 'package:maleva_tv/features/board/board_theme.dart';
import 'package:maleva_tv/features/home/domain/entities/job_model.dart';

/// One job row of the board grid. [selected] is the row picked with the remote.
class JobBoardItem extends StatelessWidget {
  final JobModel job;
  final int index;
  final DateTime now;
  final bool selected;

  /// The vessel search; its words are highlighted in the vessel names and job number.
  final String highlight;

  const JobBoardItem({
    required this.job,
    required this.index,
    required this.now,
    this.selected = false,
    this.highlight = '',
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = BoardTheme.statusColor(job.jobStatus);

    final cell = BoardTheme.cell;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 68,
      foregroundDecoration: selected ? BoxDecoration(border: Border.all(color: BoardTheme.selection, width: 3)) : null,
      decoration: BoxDecoration(
        color: selected
            ? BoardTheme.selection.withValues(alpha: 0.22)
            : (index.isEven ? BoardTheme.rowEven : BoardTheme.rowOdd),
        border: const Border(bottom: BorderSide(color: BoardTheme.gridLine)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          cell(
            width: BoardTheme.snoWidth,
            child: Row(
              children: [
                // Status colour stripe
                Container(width: 6, color: statusColor),
                Expanded(
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: BoardTheme.textMuted),
                    ),
                  ),
                ),
              ],
            ),
          ),
          cell(flex: BoardTheme.vessel, child: _vesselCell()),
          cell(flex: BoardTheme.port, child: _portCell()),
          cell(flex: BoardTheme.jobNo, child: _jobNoCell()),
          cell(flex: BoardTheme.employee, child: _employeeCell()),
          cell(flex: BoardTheme.status, child: _statusChip(statusColor)),
          cell(flex: BoardTheme.time, child: _timeCell(job.seta)),
          cell(flex: BoardTheme.time, child: _timeCell(job.setb)),
          cell(flex: BoardTheme.time, child: _timeCell(job.setd)),
          cell(flex: BoardTheme.time, child: _timeCell(job.soeta)),
          cell(flex: BoardTheme.time, child: _timeCell(job.soetb)),
          cell(flex: BoardTheme.time, child: _timeCell(job.soetd), divider: false),
        ],
      ),
    );
  }

  TextSpan _marked(String text, TextStyle style) => BoardCells.marked(text, style, highlight);

  Widget _vesselCell() {
    final loading = job.loadingVesselName?.trim() ?? '';
    final off = job.offVesselName?.trim() ?? '';
    final main = loading.isNotEmpty ? loading : off;
    // Second line: the off vessel when both exist, or which side the only vessel is on.
    final String? second = loading.isNotEmpty && off.isNotEmpty && off != loading
        ? 'OFF  ›  ${off.toUpperCase()}'
        : loading.isEmpty && off.isNotEmpty
            ? 'OFF VESSEL'
            : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  _marked(
                    main.isEmpty ? 'NO VESSEL' : main.toUpperCase(),
                    TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: main.isEmpty ? BoardTheme.textMuted : BoardTheme.textPrimary,
                      letterSpacing: 0.3,
                      height: 1.0,
                    ),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (second != null) ...[
                  const SizedBox(height: 3),
                  Text.rich(
                    _marked(
                      second,
                      const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: BoardTheme.textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The loading port, and the off-vessel port under it when that one is different.
  Widget _portCell() {
    final load = job.port?.trim() ?? '';
    final off = job.offPort?.trim() ?? '';
    final lines = <(String, String)>[
      if (load.isNotEmpty) ('L', load),
      if (off.isNotEmpty && off != load) ('O', off),
    ];
    if (lines.isEmpty) {
      return const Center(child: Text('—', style: TextStyle(fontSize: 18, color: BoardTheme.textMuted)));
    }
    Widget line(String side, String name) => Row(
          children: [
            if (lines.length > 1) ...[
              Text(side,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: side == 'L' ? BoardTheme.accent : BoardTheme.offVessel)),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                name.toUpperCase(),
                maxLines: lines.length > 1 ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700, color: BoardTheme.textPrimary, height: 1.05),
              ),
            ),
          ],
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < lines.length; i++) ...[
            if (i > 0) const SizedBox(height: 2),
            line(lines[i].$1, lines[i].$2),
          ],
        ],
      ),
    );
  }

  Widget _jobNoCell() {
    final text = job.jobNo;
    // The whole job number always shows: a long one shrinks a little instead of ending in "…".
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
                text.isEmpty ? '—' : text,
                const TextStyle(
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

  Widget _employeeCell() {
    // The person in charge (PICName, from EmployeeRefId), as the owner chose (2026-10-14).
    final name = job.picName.trim();
    if (name.isEmpty) {
      return const Center(
        child: Text('UNASSIGNED',
            style:
                TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: BoardTheme.textMuted, letterSpacing: 1.2)),
      );
    }
    final initials =
        name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2).map((p) => p[0]).join().toUpperCase();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: BoardTheme.panelHigh,
            child: Text(initials,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: BoardTheme.textSecondary)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: BoardTheme.textPrimary, height: 1.15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(Color color) => BoardCells.statusChip(job.jobStatus);

  Widget _timeCell(String? value) => BoardCells.time(value, now);
}
