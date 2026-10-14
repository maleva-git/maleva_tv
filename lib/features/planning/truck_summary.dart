import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maleva_tv/core/network/api_exception.dart';
import 'package:maleva_tv/features/board/board_theme.dart';
import 'truck_fleet.dart';

/// Green (assigned) and neutral (available) chip tones, from the board's colours.
Color _soft(Color c) => c.withValues(alpha: BoardTheme.palette.isLight ? 0.10 : 0.18);

/// The web Planning page's truck bar: progress, "2/20 TRUCKS", "18 FREE", "9 JOBS WITHOUT TRUCK", the
/// assigned trucks, and DETAILS (the remote's red button, or a click) for the full lists.
class TruckSummaryBar extends ConsumerWidget {
  const TruckSummaryBar({required this.onDetails, super.key});

  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allocation = ref.watch(truckAllocationProvider);
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: BoardTheme.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BoardTheme.border),
        boxShadow: BoardTheme.raised,
      ),
      child: allocation.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => Row(children: [
          Icon(Icons.local_shipping_outlined, size: 20, color: BoardTheme.accent),
          const SizedBox(width: 10),
          Text('LOADING TRUCKS…', style: _label(BoardTheme.textMuted)),
        ]),
        error: (e, _) => Row(children: [
          Icon(Icons.local_shipping_outlined, size: 20, color: BoardTheme.textMuted),
          const SizedBox(width: 10),
          Flexible(
            child: Text('TRUCKS NOT AVAILABLE: ${e is ApiException ? e.message : e}'.toUpperCase(),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: _label(BoardTheme.danger)),
          ),
        ]),
        data: (a) => Row(
          children: [
            Icon(Icons.local_shipping_outlined, size: 20, color: BoardTheme.accent),
            const SizedBox(width: 10),
            // progress: share of the fleet on the plan
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 110,
                height: 8,
                child: LinearProgressIndicator(
                  value: a.share,
                  backgroundColor: BoardTheme.border,
                  color: BoardTheme.success,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text('${a.fleetAssigned}/${a.fleetSize} TRUCKS',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w900, color: BoardTheme.textPrimary, letterSpacing: 0.8)),
            const SizedBox(width: 10),
            _pill('${a.available.length} FREE', BoardTheme.textSecondary),
            if (a.jobsWithoutTruck > 0) ...[
              const SizedBox(width: 8),
              _pill('${a.jobsWithoutTruck} ${a.jobsWithoutTruck == 1 ? 'JOB' : 'JOBS'} WITHOUT TRUCK',
                  BoardTheme.warning),
            ],
            const SizedBox(width: 14),
            Container(width: 1, height: 22, color: BoardTheme.border),
            const SizedBox(width: 14),
            // the assigned trucks, as far as they fit; DETAILS has them all
            Expanded(
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.centerLeft,
                  maxWidth: double.infinity,
                  child: Row(
                    children: [
                      if (a.assigned.isEmpty)
                        Text('NO TRUCK ON THIS PLAN YET', style: _label(BoardTheme.textMuted))
                      else
                        for (final t in a.assigned) ...[TruckChip.assigned(t), const SizedBox(width: 8)],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _detailsButton(),
          ],
        ),
      ),
    );
  }

  Widget _detailsButton() => Material(
        color: Colors.transparent,
        child: InkWell(
          canRequestFocus: false,
          borderRadius: BorderRadius.circular(8),
          onTap: onDetails,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(children: [
              // the remote's red button opens it
              Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('DETAILS',
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: BoardTheme.accent, letterSpacing: 1)),
              Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: BoardTheme.accent),
            ]),
          ),
        ),
      );
}

TextStyle _label(Color color) => TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color, letterSpacing: 1);

Widget _pill(String text, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: _soft(color), borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.8)),
    );

/// One truck as a chip: green with "· N JOBS" when on the plan, outlined when free.
class TruckChip extends StatelessWidget {
  const TruckChip.assigned(AssignedTruck this.truck, {super.key}) : free = null;
  const TruckChip.free(FleetTruck this.free, {super.key}) : truck = null;

  final AssignedTruck? truck;
  final FleetTruck? free;

  @override
  Widget build(BuildContext context) {
    final t = truck;
    final onPlan = t != null;
    final color = onPlan ? (t.outsideFleet ? BoardTheme.textSecondary : BoardTheme.success) : BoardTheme.textPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: onPlan ? _soft(color) : BoardTheme.panel,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: onPlan ? color.withValues(alpha: 0.45) : BoardTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(onPlan ? Icons.check_rounded : Icons.add_rounded,
              size: 14, color: onPlan ? color : BoardTheme.textMuted),
          const SizedBox(width: 4),
          Text((onPlan ? t.name : free!.name).toUpperCase(),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.6)),
          if (onPlan)
            Text('  ·  ${t.jobs} ${t.jobs == 1 ? 'JOB' : 'JOBS'}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

/// The web's truck Details: ASSIGNED (trucks on the plan) and AVAILABLE (free fleet trucks), view only.
/// OK, Back or the red button close it.
class TruckDetailsDialog extends ConsumerWidget {
  const TruckDetailsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(truckAllocationProvider).valueOrNull;
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final k = event.logicalKey;
        if (k == LogicalKeyboardKey.escape ||
            k == LogicalKeyboardKey.colorF0Red ||
            k == LogicalKeyboardKey.select ||
            k == LogicalKeyboardKey.enter) {
          Navigator.of(context).pop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Dialog(
        backgroundColor: BoardTheme.panel,
        insetPadding: const EdgeInsets.all(40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: BoardTheme.border, width: 1.5),
        ),
        // fixed layout, scaled down evenly in a small window like the board
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: 820,
            height: 560,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: a == null
                  ? Center(child: CircularProgressIndicator(color: BoardTheme.accent))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.local_shipping_outlined, size: 26, color: BoardTheme.accent),
                          const SizedBox(width: 10),
                          Text('TRUCKS  ·  ${a.fleetAssigned}/${a.fleetSize} ON THIS PLAN',
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: BoardTheme.textPrimary,
                                  letterSpacing: 1.5)),
                        ]),
                        const SizedBox(height: 18),
                        _section(
                          icon: Icons.check_circle_outline_rounded,
                          color: BoardTheme.success,
                          title: 'ASSIGNED (${a.assigned.length})',
                          empty: 'No truck on this plan yet',
                          chips: [for (final t in a.assigned) TruckChip.assigned(t)],
                        ),
                        const SizedBox(height: 18),
                        Expanded(
                          child: _section(
                            icon: Icons.radio_button_unchecked_rounded,
                            color: BoardTheme.textSecondary,
                            title: 'AVAILABLE (${a.available.length})',
                            hint: 'View only',
                            empty: 'Every planning truck is in use',
                            chips: [for (final t in a.available) TruckChip.free(t)],
                            expand: true,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: Text('OK  /  BACK  /  RED  CLOSE',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: BoardTheme.textMuted,
                                  letterSpacing: 1)),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _section({
    required IconData icon,
    required Color color,
    required String title,
    required String empty,
    required List<Widget> chips,
    String? hint,
    bool expand = false,
  }) {
    final body = chips.isEmpty
        ? Text(empty, style: TextStyle(fontSize: 15, color: BoardTheme.textMuted))
        : Wrap(spacing: 8, runSpacing: 8, children: chips);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color, letterSpacing: 1.2)),
          if (hint != null) ...[
            const SizedBox(width: 8),
            Text('·  $hint', style: TextStyle(fontSize: 13, color: BoardTheme.textMuted)),
          ],
        ]),
        const SizedBox(height: 10),
        if (expand) Expanded(child: SingleChildScrollView(child: body)) else body,
      ],
    );
  }
}
