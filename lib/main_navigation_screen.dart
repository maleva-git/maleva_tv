import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/board/board_theme.dart';
import 'features/board/job_board_view.dart';
import 'features/home/presentation/home_controller.dart';
import 'features/home/presentation/widgets/port_picker.dart';
import 'features/planning/planning_board.dart';
import 'features/planning/plan_picker.dart';
import 'features/planning/planning_controller.dart';
import 'features/planning/planning_live.dart';
import 'features/planning/truck_summary.dart';

/// The vessel planning board and the remote control.
///
/// Auto mode: the board scrolls through its list again and again.
/// Remote: ▲▼ stops auto mode and moves a highlight over the rows (▲ on the first row jumps to the
/// last); CH± / ⏪⏩ / Page Up/Down jump a page; ◀▶ change the day;
/// OK, Back or ⏯ go back to auto mode, which also comes back by itself after [_idleResume]
/// without a key press.
/// Search: typing a letter (or the search / menu key) opens the vessel search; results show live,
/// ▼ moves into them, Back clears the search, and it closes by itself after [_searchIdle].
class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  final FocusNode _focus = FocusNode(debugLabel: 'remote');
  bool _auto = true;
  int? _selected;
  Timer? _apiRefreshTimer;
  Timer? _idleTimer;
  Timer? _tick;
  DateTime _lastKey = DateTime.now();

  PlanningLiveUpdates? _live;
  bool _searching = false;
  final TextEditingController _query = TextEditingController();
  final FocusNode _queryFocus = FocusNode(debugLabel: 'search');
  Timer? _debounce;

  static const _idleResume = Duration(seconds: 45);

  /// A forgotten search closes by itself, so the wall board goes back to today's vessels.
  static const _searchIdle = Duration(minutes: 2);

  @override
  void initState() {
    super.initState();
    // Live plan saves, only while the Planning board is on screen (see PlanningLiveUpdates)
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncLive());
    ref.listenManual(boardProvider, (_, __) => _syncLive());
    // Repaint the search bar's border when the field gains or loses focus
    _queryFocus.addListener(() {
      if (!mounted) return;
      setState(() {});
      // A focused field can select its whole text a moment later (the web does), so the next letter
      // would replace the one that opened the search; keep the cursor at the end instead.
      if (_queryFocus.hasFocus && !_searching) {
        // tapped straight into the field
        _searching = true;
        _takeControl();
      }
      if (_queryFocus.hasFocus) {
        Future<void>.delayed(const Duration(milliseconds: 80), () {
          if (mounted && _queryFocus.hasFocus && !_query.selection.isCollapsed) {
            _query.selection = TextSelection.collapsed(offset: _query.text.length);
          }
        });
      }
    });
    // Refresh the board every minute
    _apiRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      ref.invalidate(jobsProvider);
      ref.invalidate(shownPlanningProvider);
      ref.invalidate(dayPlansProvider);
    });
    // Drives the "auto in 30 s" countdown while paused
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_auto && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _apiRefreshTimer?.cancel();
    _idleTimer?.cancel();
    _tick?.cancel();
    _debounce?.cancel();
    _live?.stop();
    _query.dispose();
    _queryFocus.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _syncLive() {
    if (!mounted) return;
    final onPlanning = ref.read(boardProvider) == BoardKind.planning;
    if (onPlanning && _live == null) {
      _live = ref.read(planningLiveProvider);
      _live!.start();
    } else if (!onPlanning && _live != null) {
      _live!.stop();
      _live = null;
    }
  }

  /// On Planning, another day means that day's plans: a chosen plan belongs to its own date.
  void _changeDate(int days) {
    if (ref.read(boardProvider) == BoardKind.planning && ref.read(planChoiceProvider) != null) {
      ref.read(planChoiceProvider.notifier).show(null);
    }
    ref.read(dateProvider.notifier).changeDate(days);
  }

  /// A key from the remote: leave auto mode and restart the idle countdown.
  void _takeControl() {
    _lastKey = DateTime.now();
    _idleTimer?.cancel();
    _idleTimer = Timer(_searching ? _searchIdle : _idleResume, _resumeAuto);
    if (_auto) setState(() => _auto = false);
  }

  void _resumeAuto() {
    _idleTimer?.cancel();
    if (!mounted) return;
    if (_searching) _closeSearch();
    setState(() {
      _auto = true;
      _selected = null;
    });
  }

  // ---------- Vessel search ----------

  /// Opens the search field, starting with [seed] (the letter that was typed).
  void _openSearch({String seed = ''}) {
    _takeControl();
    setState(() {
      _searching = true;
      _selected = null;
    });
    if (seed.isNotEmpty) {
      _query.text = _query.text + seed;
      _query.selection = TextSelection.collapsed(offset: _query.text.length);
      _onQueryChanged(_query.text);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queryFocus.requestFocus();
      // Focusing can select the whole text; put the cursor after the typed letter so the next one adds to it.
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _query.selection = TextSelection.collapsed(offset: _query.text.length));
    });
  }

  void _onQueryChanged(String text) {
    _takeControl();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      ref.read(searchProvider.notifier).state = text.trim();
      setState(() => _selected = null);
    });
  }

  /// From the field down into the results (▼ or Enter).
  void _leaveField() {
    _debounce?.cancel();
    ref.read(searchProvider.notifier).state = _query.text.trim();
    _focus.requestFocus();
    if (_rowCount > 0) setState(() => _selected = 0);
  }

  void _closeSearch() {
    _debounce?.cancel();
    _query.clear();
    ref.read(searchProvider.notifier).state = '';
    setState(() {
      _searching = false;
      _selected = null;
    });
    _focus.requestFocus();
  }

  /// Back while searching: first clears what was typed, then closes the search.
  void _backInSearch() {
    _takeControl();
    if (_query.text.isNotEmpty) {
      _query.clear();
      _onQueryChanged('');
      _queryFocus.requestFocus();
    } else {
      _closeSearch();
    }
  }

  /// Keys that open the search. On the office TV remote: MENU (Android 82) and the blue button (186);
  /// its number keys open it too, with the digit typed (see [_typedKey]).
  static final _searchKeys = {
    LogicalKeyboardKey.find,
    LogicalKeyboardKey.browserSearch,
    LogicalKeyboardKey.contextMenu,
    LogicalKeyboardKey.colorF3Blue,
    LogicalKeyboardKey.slash,
  };
  static final _typedKey = RegExp(r'^[A-Za-z0-9]$');

  /// The rows of the board on screen.
  AsyncValue<List<Object>> _rows(WidgetRef ref, {bool watch = false}) {
    final planning = (watch ? ref.watch(boardProvider) : ref.read(boardProvider)) == BoardKind.planning;
    return planning
        ? (watch ? ref.watch(planningJobsProvider) : ref.read(planningJobsProvider))
        : (watch ? ref.watch(jobsProvider) : ref.read(jobsProvider));
  }

  int get _rowCount => _rows(ref).valueOrNull?.length ?? 0;

  /// The yellow button (or Tab) switches between Vessel Planning and Planning.
  /// Each board is its own: switching closes the other board's search.
  void _switchBoard([BoardKind? to]) {
    final notifier = ref.read(boardProvider.notifier);
    final before = ref.read(boardProvider);
    to == null ? notifier.toggle() : notifier.show(to);
    if (ref.read(boardProvider) == before) return;
    if (_searching || ref.read(searchProvider).isNotEmpty) _closeSearch();
    _resumeAuto();
  }

  /// Moves the highlight by [step] rows. A single press past either end [wrap]s round, so ▲ on the
  /// first row goes straight to the last; a held key stops at the end instead of spinning round.
  /// ▲ in auto mode starts at the last row, ▼ at the first.
  void _moveSelection(int step, {bool wrap = false}) {
    final count = _rowCount;
    if (count == 0) return;
    final current = _selected;
    int next;
    if (current == null) {
      next = step > 0 ? 0 : count - 1;
    } else if (wrap && current + step < 0) {
      next = count - 1;
    } else if (wrap && current + step >= count) {
      next = 0;
    } else {
      next = (current + step).clamp(0, count - 1);
    }
    setState(() => _selected = next);
  }

  /// Rows one page key (CH+/CH−, ⏪/⏩, Page Up/Down) jumps.
  static const _pageRows = 6;

  static final _pageDownKeys = {
    LogicalKeyboardKey.pageDown,
    LogicalKeyboardKey.channelDown,
    LogicalKeyboardKey.mediaFastForward,
    LogicalKeyboardKey.mediaTrackNext,
  };
  static final _pageUpKeys = {
    LogicalKeyboardKey.pageUp,
    LogicalKeyboardKey.channelUp,
    LogicalKeyboardKey.mediaRewind,
    LogicalKeyboardKey.mediaTrackPrevious,
  };

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (event is KeyDownEvent && (key == LogicalKeyboardKey.colorF2Yellow || key == LogicalKeyboardKey.tab)) {
      _switchBoard();
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent &&
        key == LogicalKeyboardKey.colorF0Red &&
        ref.read(boardProvider) == BoardKind.planning) {
      _openTruckDetails();
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent && key == LogicalKeyboardKey.colorF1Green) {
      // the port filter belongs to Vessel Planning only
      // green picks each board's own filter: the port on Vessel Planning, the plan on Planning
      ref.read(boardProvider) == BoardKind.vesselPlanning ? _openPortPicker() : _openPlanPicker();
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent && _searchKeys.contains(key)) {
      _openSearch();
      return KeyEventResult.handled;
    }
    final typed = event.character;
    if (event is KeyDownEvent && typed != null && _typedKey.hasMatch(typed)) {
      _openSearch(seed: typed);
      return KeyEventResult.handled;
    }
    // Escape is the desktop's Back: clears the search, then returns to auto mode.
    if (event is KeyDownEvent && key == LogicalKeyboardKey.escape) {
      _searching ? _backInSearch() : _resumeAuto();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowUp) {
      _takeControl();
      _moveSelection(key == LogicalKeyboardKey.arrowDown ? 1 : -1, wrap: event is KeyDownEvent);
      return KeyEventResult.handled;
    }
    if (_pageDownKeys.contains(key) || _pageUpKeys.contains(key)) {
      _takeControl();
      _moveSelection(_pageDownKeys.contains(key) ? _pageRows : -_pageRows);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home || key == LogicalKeyboardKey.end) {
      _takeControl();
      if (_rowCount > 0) setState(() => _selected = key == LogicalKeyboardKey.home ? 0 : _rowCount - 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight) {
      _takeControl();
      setState(() => _selected = null);
      _changeDate(key == LogicalKeyboardKey.arrowRight ? 1 : -1);
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent &&
        (key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter ||
            key == LogicalKeyboardKey.gameButtonA ||
            key == LogicalKeyboardKey.mediaPlayPause ||
            key == LogicalKeyboardKey.mediaPlay)) {
      _auto ? _takeControl() : _resumeAuto();
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent && (key == LogicalKeyboardKey.mediaPause || key == LogicalKeyboardKey.mediaStop)) {
      _takeControl();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(searchProvider);
    final board = ref.watch(boardProvider);
    // Each board's own colours: Planning follows maleva_app's Planning screens, Vessel Planning stays navy.
    BoardTheme.palette = board == BoardKind.planning ? BoardPalette.malevaLight : BoardPalette.navy;
    final controls = Row(children: [
      _modePill(),
      if (board == BoardKind.planning) ...[const SizedBox(width: 10), _livePill()],
      ..._keyHelp(),
    ]);
    final searchBar = Row(
      children: [
        Expanded(child: _searchBar(search)),
        // Vessel Planning only: Planning has no port filter
        // each board's own filter: the port on Vessel Planning, the plan on Planning
        const SizedBox(width: 10),
        board == BoardKind.vesselPlanning ? _portChip() : _planChip(),
      ],
    );
    return PopScope(
      // Back on the remote clears the search, then returns to auto mode; only then does it leave the app.
      canPop: _auto && !_searching,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _searching ? _backInSearch() : _resumeAuto();
      },
      child: Scaffold(
        backgroundColor: BoardTheme.background,
        body: Focus(
          focusNode: _focus,
          autofocus: true,
          onKeyEvent: _onKey,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => _focus.requestFocus(),
            child: board == BoardKind.planning
                ? PlanningBoardView(
                    // a new board gets its own state (scroll position), not the other board's
                    key: const ValueKey(BoardKind.planning),
                    date: ref.watch(dateProvider),
                    onChangeDate: _changeDate,
                    jobs: ref.watch(planningJobsProvider),
                    autoPlay: _auto,
                    selectedIndex: _selected,
                    controls: controls,
                    search: search,
                    searchBar: searchBar,
                    titleWidget: _boardTabs(board, _planningSubtitle()),
                    belowTitle: TruckSummaryBar(onDetails: _openTruckDetails),
                  )
                : JobBoardView(
                    key: const ValueKey(BoardKind.vesselPlanning),
                    title: 'VESSEL PLANNING',
                    subtitle: '',
                    date: ref.watch(dateProvider),
                    onChangeDate: _changeDate,
                    jobs: ref.watch(jobsProvider),
                    scrollStep: 0.5, // about 15 px a second: one row every 6 s, slow enough to read
                    autoPlay: _auto,
                    selectedIndex: _selected,
                    controls: controls,
                    search: search,
                    searchBar: searchBar,
                    titleWidget: _boardTabs(
                        board,
                        search.isEmpty
                            ? 'Arriving on this day · finished hidden'
                            : 'Search · $searchDaysBack days back to $searchDaysAhead days ahead'),
                  ),
          ),
        ),
      ),
    );
  }

  // ---------- Board tabs (in the title bar) ----------

  Widget _boardTabs(BoardKind board, String subtitle) {
    Widget tab(BoardKind kind, String label, IconData icon) {
      final on = kind == board;
      return Material(
        color: Colors.transparent,
        child: InkWell(
          canRequestFocus: false,
          borderRadius: BorderRadius.circular(10),
          onTap: () => _switchBoard(kind),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: on ? BoardTheme.accent.withValues(alpha: 0.22) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: on ? BoardTheme.accent : BoardTheme.border, width: on ? 2 : 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: on ? BoardTheme.textPrimary : BoardTheme.textMuted),
                const SizedBox(width: 8),
                Text(label,
                    style: TextStyle(
                        fontSize: on ? 17 : 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: on ? BoardTheme.textPrimary : BoardTheme.textMuted)),
              ],
            ),
          ),
        ),
      );
    }

    // Shrinks rather than overflow the slim title bar.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              tab(BoardKind.vesselPlanning, 'VESSEL PLANNING', Icons.directions_boat_filled_rounded),
              const SizedBox(width: 8),
              tab(BoardKind.planning, 'PLANNING', Icons.local_shipping_rounded),
            ],
          ),
          const SizedBox(height: 3),
          // A plan's remarks can be very long: the line stops under the tabs and ends with "…".
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Text(subtitle.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w600, color: BoardTheme.textSecondary, letterSpacing: 1.2)),
          ),
        ],
      ),
    );
  }

  // ---------- Search bar ----------

  /// Always in the title bar. Idle it shows how many vessels the board has; while searching,
  /// how many match.
  Widget _searchBar(String search) {
    final jobs = _rows(ref, watch: true);
    final planning = ref.watch(boardProvider) == BoardKind.planning;
    final focused = _queryFocus.hasFocus;
    final active = focused || search.isNotEmpty;
    final n = jobs.valueOrNull?.length;
    final String info;
    if (search.isNotEmpty && jobs.isLoading) {
      info = 'SEARCHING…';
    } else if (n == null) {
      info = '';
    } else if (search.isNotEmpty) {
      info = n == 1 ? '1 FOUND' : '$n FOUND';
    } else {
      info = planning ? (n == 1 ? '1 JOB' : '$n JOBS') : (n == 1 ? '1 VESSEL' : '$n VESSELS');
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 42,
      padding: const EdgeInsets.only(left: 12, right: 4),
      decoration: BoxDecoration(
        color: BoardTheme.background.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: focused ? BoardTheme.selection : (active ? BoardTheme.soon : BoardTheme.border),
          width: focused ? 2.5 : 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 22, color: focused ? BoardTheme.selection : BoardTheme.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Focus(
              // ▼ from the field goes into the results; the rest goes to the text field.
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  _leaveField();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: TextField(
                controller: _query,
                focusNode: _queryFocus,
                onChanged: _onQueryChanged,
                onSubmitted: (_) => _leaveField(),
                textInputAction: TextInputAction.search,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                enableSuggestions: false,
                cursorColor: BoardTheme.selection,
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800, color: BoardTheme.textPrimary, letterSpacing: 1),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: planning
                      ? 'PRESS MENU TO SEARCH TRUCK, DRIVER, VESSEL OR JOB NO.'
                      : 'PRESS MENU TO SEARCH VESSEL OR JOB NO.',
                  hintStyle: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700, color: BoardTheme.textMuted, letterSpacing: 1),
                ),
              ),
            ),
          ),
          if (search.isNotEmpty && jobs.isLoading)
            Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(
                  width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: BoardTheme.accent)),
            ),
          if (info.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: (search.isNotEmpty ? BoardTheme.soon : BoardTheme.accent).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(info,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: search.isNotEmpty ? BoardTheme.soon : BoardTheme.accent)),
            ),
          if (_searching)
            IconButton(
              tooltip: 'Close search',
              visualDensity: VisualDensity.compact,
              onPressed: _closeSearch,
              icon: Icon(Icons.close_rounded, size: 20, color: BoardTheme.textSecondary),
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }

  // ---------- Truck details (Planning) ----------

  Future<void> _openTruckDetails() async {
    _takeControl();
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => const TruckDetailsDialog(),
    );
    if (mounted) _focus.requestFocus();
  }

  // ---------- Plan choice (Planning) ----------

  Future<void> _openPlanPicker() async {
    _takeControl();
    final current = ref.read(planChoiceProvider);
    final picked = await showDialog<PlanPick>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => PlanPicker(current: current),
    );
    if (!mounted) return;
    _focus.requestFocus();
    if (picked == null) return;
    ref.read(planChoiceProvider.notifier).show(picked is OnePlan ? picked.number : null);
    setState(() => _selected = null);
    if (!_searching) _resumeAuto();
  }

  String _planningSubtitle() {
    final shown = ref.watch(shownPlanningProvider).valueOrNull;
    final plan = shown?.plan;
    if (plan != null) {
      return ['Plan #${plan.label}', if (plan.date.isNotEmpty) plan.date, if (plan.remarks.isNotEmpty) plan.remarks]
          .join(' · ');
    }
    final n = ref.watch(dayPlansProvider).valueOrNull?.length;
    return n == null ? 'All plans of the day' : 'All plans of the day · $n ${n == 1 ? 'plan' : 'plans'}';
  }

  Widget _planChip() {
    final number = ref.watch(planChoiceProvider);
    final plan = ref.watch(shownPlanningProvider).valueOrNull?.plan;
    final one = number != null;
    final text = one ? '#${plan?.label ?? number}' : 'ALL OF THE DAY';
    return _filterChip(
      icon: Icons.assignment_rounded,
      label: 'PLAN',
      value: text,
      active: one,
      onTap: _openPlanPicker,
    );
  }

  /// LIVE: plan saves reload the board at once. Otherwise it still refreshes every minute.
  Widget _livePill() {
    final status = ref.watch(liveStatusProvider);
    final (Color color, String text) = switch (status) {
      LiveStatus.live => (BoardTheme.success, 'LIVE · PLAN SAVES SHOW AT ONCE'),
      LiveStatus.connecting => (BoardTheme.soon, 'CONNECTING LIVE…'),
      LiveStatus.offline => (BoardTheme.danger, 'LIVE OFF · RETRYING · REFRESH EVERY MIN'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Icon(status == LiveStatus.live ? Icons.sensors_rounded : Icons.sensors_off_rounded, size: 13, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: color)),
        ],
      ),
    );
  }

  // ---------- Port filter ----------

  /// The green button (or a click) opens the port list; the board then shows only that port.
  Future<void> _openPortPicker() async {
    _takeControl();
    final current = ref.read(portFilterProvider);
    final picked = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => PortPicker(current: current),
    );
    if (!mounted) return;
    _focus.requestFocus();
    if (picked == null || picked == current) return;
    ref.read(portFilterProvider.notifier).select(picked);
    setState(() => _selected = null);
    if (!_searching) _resumeAuto();
  }

  Widget _portChip() {
    final port = ref.watch(portFilterProvider);
    return _filterChip(
      icon: Icons.anchor_rounded,
      label: 'PORT',
      value: port.isNotEmpty ? port.toUpperCase() : 'ALL PORTS',
      active: port.isNotEmpty,
      onTap: _openPortPicker,
    );
  }

  /// The title bar's filter chip (PORT on Vessel Planning, PLAN on Planning): green while it limits
  /// the board; the green dot says the remote's green button opens it.
  Widget _filterChip({
    required IconData icon,
    required String label,
    required String value,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        canRequestFocus: false,
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 42,
          constraints: const BoxConstraints(maxWidth: 300),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color:
                active ? const Color(0xFF22C55E).withValues(alpha: 0.16) : BoardTheme.background.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? BoardTheme.success : BoardTheme.border, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: active ? BoardTheme.success : BoardTheme.textSecondary),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontSize: 9, fontWeight: FontWeight.w800, color: BoardTheme.textMuted, letterSpacing: 1.4)),
                    Flexible(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: BoardTheme.textPrimary,
                            letterSpacing: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
              ),
              Icon(Icons.arrow_drop_down_rounded, size: 22, color: BoardTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Mode and remote help (shown in the board's footer) ----------

  Widget _modePill() {
    final Color color;
    final IconData icon;
    final String text;
    if (_auto) {
      color = BoardTheme.success;
      icon = Icons.play_circle_rounded;
      text = 'AUTO · SCROLLING';
    } else {
      final idle = _searching ? _searchIdle : _idleResume;
      final left = idle - DateTime.now().difference(_lastKey);
      color = BoardTheme.soon;
      icon = Icons.pause_circle_rounded;
      final row = _selected == null ? '' : 'ROW ${_selected! + 1} / $_rowCount · ';
      text = 'PAUSED · ${row}AUTO IN ${left.inSeconds.clamp(0, idle.inSeconds)} S';
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.7), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: color)),
        ],
      ),
    );
  }

  List<Widget> _keyHelp() {
    // Key caps use icons: the TV font has no arrow glyphs.
    Widget key(Widget cap, String label) => Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Row(
            children: [
              Container(
                height: 16,
                padding: const EdgeInsets.symmetric(horizontal: 3),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: BoardTheme.panel,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: BoardTheme.border),
                ),
                child: cap,
              ),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700, color: BoardTheme.textSecondary, letterSpacing: 1)),
            ],
          ),
        );
    Widget icons(IconData a, IconData b) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(a, size: 13, color: BoardTheme.textPrimary),
            Icon(b, size: 13, color: BoardTheme.textPrimary)
          ],
        );
    return [
      key(icons(Icons.keyboard_arrow_up_rounded, Icons.keyboard_arrow_down_rounded), 'ROWS · HOLD = FAST'),
      key(Text('CH ±', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: BoardTheme.textPrimary)),
          'PAGE'),
      key(icons(Icons.keyboard_arrow_left_rounded, Icons.keyboard_arrow_right_rounded), 'CHANGE DATE'),
      key(Icon(Icons.search_rounded, size: 13, color: BoardTheme.textPrimary), 'MENU / BLUE: SEARCH'),
      key(const Icon(Icons.circle, size: 10, color: Color(0xFF22C55E)),
          ref.watch(boardProvider) == BoardKind.vesselPlanning ? 'GREEN: PORT' : 'GREEN: PLAN'),
      if (ref.watch(boardProvider) == BoardKind.planning)
        key(const Icon(Icons.circle, size: 10, color: Color(0xFFEF4444)), 'RED: TRUCKS'),
      key(const Icon(Icons.circle, size: 10, color: Color(0xFFFACC15)), 'YELLOW: BOARD'),
      key(Text('OK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: BoardTheme.textPrimary)),
          _auto ? 'PAUSE' : 'BACK TO AUTO'),
    ];
  }
}
