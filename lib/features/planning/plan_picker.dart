import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maleva_tv/core/network/api_exception.dart';
import 'package:maleva_tv/core/providers.dart';
import 'package:maleva_tv/features/board/board_theme.dart';
import 'package:maleva_tv/features/home/presentation/home_controller.dart';
import 'planning_controller.dart';
import 'planning_job.dart';

/// What the plan list returns: a plan number, or "all plans of the day".
sealed class PlanPick {
  const PlanPick();
}

class AllPlansOfDay extends PlanPick {
  const AllPlansOfDay();
}

class OnePlan extends PlanPick {
  const OnePlan(this.number);
  final int number;
}

/// Choose the plan the Planning board shows: type its number with the number keys (as the web's
/// PLAN NO field), or pick one of the day's plans. Up/down move, OK opens, Back clears / closes.
class PlanPicker extends ConsumerStatefulWidget {
  const PlanPicker({required this.current, super.key});

  /// The plan shown now (null = all plans of the day).
  final int? current;

  @override
  ConsumerState<PlanPicker> createState() => _PlanPickerState();
}

class _PlanPickerState extends ConsumerState<PlanPicker> {
  final _scroll = ScrollController();
  String _typed = '';
  int _index = 0;
  bool _placed = false;
  bool _checking = false;
  String? _error;

  static const _rowHeight = 62.0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _move(int step, int count) {
    setState(() => _index = (_index + step).clamp(0, count - 1));
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    final target = _index * _rowHeight - (p.viewportDimension - _rowHeight) / 2;
    _scroll.animateTo(target.clamp(0.0, p.maxScrollExtent),
        duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
  }

  /// Checks a typed plan number exists before the board switches to it.
  Future<void> _openTyped() async {
    final number = int.tryParse(_typed);
    if (number == null || _checking) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      await ref.read(planningApiProvider).plan(companyId: ref.read(companyIdProvider), planningNo: number);
      if (mounted) Navigator.of(context).pop(OnePlan(number));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = 'Plan $number cannot be opened: ${e.message}');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  KeyEventResult _onKey(KeyEvent event, List<PlanPick> options) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final digit = event.character;
    if (event is KeyDownEvent && digit != null && RegExp(r'^[0-9]$').hasMatch(digit)) {
      setState(() {
        if (_typed.length < 9) _typed += digit;
        _error = null;
      });
    } else if (key == LogicalKeyboardKey.backspace || key == LogicalKeyboardKey.delete) {
      setState(() => _typed = _typed.isEmpty ? '' : _typed.substring(0, _typed.length - 1));
    } else if (key == LogicalKeyboardKey.arrowDown) {
      _move(1, options.length);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _move(-1, options.length);
    } else if (event is KeyDownEvent &&
        (key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter ||
            key == LogicalKeyboardKey.gameButtonA)) {
      if (_typed.isNotEmpty) {
        _openTyped();
      } else {
        Navigator.of(context).pop(options[_index]);
      }
    } else if (event is KeyDownEvent && (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.colorF1Green)) {
      if (_typed.isNotEmpty) {
        setState(() {
          _typed = '';
          _error = null;
        });
      } else {
        Navigator.of(context).pop();
      }
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final plans = ref.watch(dayPlansProvider);
    final day = ref.watch(dateProvider);
    final options = <PlanPick>[
      const AllPlansOfDay(),
      for (final p in plans.valueOrNull ?? const <PlanSummary>[]) OnePlan(p.number),
    ];
    if (!_placed && plans.hasValue) {
      _placed = true;
      final at = options.indexWhere((o) => o is OnePlan && o.number == widget.current);
      _index = at < 0 ? 0 : at;
    }

    return PopScope(
      // Back first clears a typed number, then closes.
      canPop: _typed.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _typed = '');
      },
      child: Focus(
        autofocus: true,
        onKeyEvent: (node, event) => _onKey(event, options),
        child: Dialog(
          backgroundColor: BoardTheme.panel,
          insetPadding: const EdgeInsets.all(40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: BoardTheme.border, width: 1.5),
          ),
          // Laid out at a fixed size and scaled down evenly in a small window, like the board.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: 620,
              height: 640,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.assignment_rounded, color: Color(0xFF4ADE80), size: 26),
                        SizedBox(width: 10),
                        Text('SHOW PLAN',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: BoardTheme.textPrimary,
                                letterSpacing: 2)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text('Type a plan number with the number keys, or pick a plan of the day.',
                        style: TextStyle(fontSize: 13, color: BoardTheme.textSecondary)),
                    const SizedBox(height: 14),
                    _numberBox(),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(fontSize: 14, color: Color(0xFFFCA5A5))),
                    ],
                    const SizedBox(height: 14),
                    Text('PLANS OF ${BoardTheme.relativeDay(day, DateTime.now())} · ${BoardTheme.dayMonth(day)}',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: BoardTheme.textMuted,
                            letterSpacing: 1.4)),
                    const SizedBox(height: 8),
                    Expanded(child: _list(plans, options)),
                    const SizedBox(height: 10),
                    const Text('0-9  PLAN NO.     UP / DOWN  MOVE     OK  OPEN     BACK  CLEAR / CLOSE',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700, color: BoardTheme.textMuted, letterSpacing: 1)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _numberBox() {
    final typing = _typed.isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: BoardTheme.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: typing ? BoardTheme.selection : BoardTheme.border, width: typing ? 2.5 : 1.5),
      ),
      child: Row(
        children: [
          const Text('PLAN NO.',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: BoardTheme.textMuted, letterSpacing: 1.4)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              typing ? _typed : 'type the number…',
              style: TextStyle(
                fontSize: typing ? 28 : 18,
                fontWeight: FontWeight.w900,
                color: typing ? BoardTheme.textPrimary : BoardTheme.textMuted,
                letterSpacing: 2,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (_checking)
            const SizedBox(
                width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3, color: BoardTheme.accent))
          else if (typing)
            const Text('OK = OPEN',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800, color: BoardTheme.selection, letterSpacing: 1.2)),
        ],
      ),
    );
  }

  Widget _list(AsyncValue<List<PlanSummary>> plans, List<PlanPick> options) {
    if (plans.isLoading && !plans.hasValue) {
      return const Center(child: CircularProgressIndicator(color: BoardTheme.accent));
    }
    if (plans.hasError && !plans.hasValue) {
      final e = plans.error;
      return Center(
        child: Text('Cannot load the plans: ${e is ApiException ? e.message : e}',
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Color(0xFFFCA5A5))),
      );
    }
    final byNumber = {for (final p in plans.valueOrNull ?? const <PlanSummary>[]) p.number: p};
    return ListView.builder(
      controller: _scroll,
      itemExtent: _rowHeight,
      itemCount: options.length,
      itemBuilder: (context, i) {
        final option = options[i];
        final picked = i == _index && _typed.isEmpty;
        final plan = option is OnePlan ? byNumber[option.number] : null;
        final current = option is OnePlan ? option.number == widget.current : widget.current == null;
        return GestureDetector(
          onTap: () => Navigator.of(context).pop(option),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: picked ? BoardTheme.selection.withValues(alpha: 0.22) : BoardTheme.rowOdd,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: picked ? BoardTheme.selection : BoardTheme.gridLine, width: picked ? 2.5 : 1),
            ),
            child: Row(
              children: [
                Icon(plan == null ? Icons.view_list_rounded : Icons.assignment_rounded,
                    size: 20, color: picked ? BoardTheme.selection : BoardTheme.textMuted),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan == null ? 'ALL PLANS OF THE DAY' : 'PLAN #${plan.label}',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                            color: picked ? BoardTheme.textPrimary : BoardTheme.textSecondary),
                      ),
                      if (plan != null)
                        Text(
                          [
                            if (plan.employee.isNotEmpty) plan.employee.toUpperCase(),
                            '${plan.totalOrders} ${plan.totalOrders == 1 ? 'JOB' : 'JOBS'}',
                            if (plan.remarks.isNotEmpty) plan.remarks.toUpperCase(),
                          ].join('  ·  '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: BoardTheme.textMuted,
                              letterSpacing: 0.8),
                        ),
                    ],
                  ),
                ),
                if (current)
                  const Row(children: [
                    Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF4ADE80)),
                    SizedBox(width: 6),
                    Text('SHOWING',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF4ADE80), letterSpacing: 1)),
                  ]),
              ],
            ),
          ),
        );
      },
    );
  }
}
