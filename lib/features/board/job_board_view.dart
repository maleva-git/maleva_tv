import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maleva_tv/core/network/api_exception.dart';
import 'package:maleva_tv/features/home/domain/entities/job_model.dart';
import 'package:maleva_tv/features/home/presentation/widgets/job_board_item.dart';
import 'board_header.dart';
import 'board_theme.dart';

/// Builds one row of a board: the item, its position, whether the remote picked it, and the clock.
typedef BoardRowBuilder<T> = Widget Function(T item, int index, bool selected, DateTime now);

/// One full-screen TV board: title bar (title, search, date, clock), a bordered grid with the
/// board's own [columnHeaders] and rows ([rowBuilder]) that scrolls by itself, and a legend footer.
/// Vessel Planning ([JobBoardView]) and Planning use it, so both look and behave the same.
class BoardView<T> extends StatefulWidget {
  const BoardView({
    required this.title,
    required this.subtitle,
    required this.date,
    required this.onChangeDate,
    required this.jobs,
    this.scrollStep = 1.5,
    this.autoPlay = true,
    this.selectedIndex,
    this.controls,
    this.search = '',
    this.searchBar,
    required this.columnHeaders,
    required this.rowBuilder,
    this.titleWidget,
    this.noMatchTitle = 'Nothing matches',
    this.belowTitle,
    this.edgePause = const Duration(seconds: 4),
    this.rowHeight = 68,
    super.key,
  });

  final String title;
  final String subtitle;
  final DateTime date;
  final ValueChanged<int> onChangeDate;
  final AsyncValue<List<T>> jobs;
  final double scrollStep;

  /// Scrolls by itself. Off while someone drives the board with the remote.
  final bool autoPlay;

  /// The row picked with the remote, or null for none.
  final int? selectedIndex;

  /// Shown at the left of the footer: the mode badge and remote help.
  final Widget? controls;

  /// The search on the board ('' for none).
  final String search;

  /// The search field, in the title bar between the title and the date.
  final Widget? searchBar;

  /// The grid's heading row, laid out with [BoardTheme.cell] like the rows.
  final Widget columnHeaders;

  final BoardRowBuilder<T> rowBuilder;

  /// Replaces the plain [title] text, e.g. with the board tabs.
  final Widget? titleWidget;

  /// The empty-list heading while searching, e.g. 'No vessel matches'.
  final String noMatchTitle;

  /// A bar between the title bar and the grid, e.g. Planning's truck summary.
  final Widget? belowTitle;

  /// How long auto-scroll holds at the top and at the bottom of the list.
  final Duration edgePause;

  /// The height of one row (its grid line included); the rows must draw at this height.
  final double rowHeight;

  @override
  State<BoardView<T>> createState() => _BoardViewState<T>();
}

class _BoardViewState<T> extends State<BoardView<T>> {
  final ScrollController _scrollController = ScrollController();
  Timer? _autoScrollTimer;
  Timer? _clockTimer;
  DateTime _now = DateTime.now();
  DateTime? _updatedAt;
  DateTime? _pauseUntil;

  Duration get _edgePause => widget.edgePause;

  /// One row of [JobBoardItem], grid line included.
  double get _rowHeight => widget.rowHeight;

  /// The narrowest width the board is laid out at; smaller screens scale it down.
  static const _designWidth = 1440.0;

  /// The widest layout; a larger screen (a 4K / 8K TV at 1x) shows the board scaled up.
  static const _maxDesignWidth = 1920.0;

  @override
  void initState() {
    super.initState();
    if (widget.jobs.hasValue) _updatedAt = DateTime.now();
    _pauseUntil = DateTime.now().add(_edgePause);
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 33), (_) => _tickScroll());
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void didUpdateWidget(covariant BoardView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.jobs.hasValue && !identical(widget.jobs.valueOrNull, oldWidget.jobs.valueOrNull)) {
      _updatedAt = DateTime.now();
    }
    if (widget.autoPlay && !oldWidget.autoPlay) _pauseUntil = DateTime.now().add(_edgePause);
    final selected = widget.selectedIndex;
    if (selected != null && selected != oldWidget.selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToRow(selected));
    }
  }

  /// Keeps the remote's row in the middle of the list.
  void _scrollToRow(int index) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final target = index * _rowHeight - (position.viewportDimension - _rowHeight) / 2;
    _scrollController.animateTo(target.clamp(0.0, position.maxScrollExtent),
        duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);
  }

  /// Scrolls slowly, holds at the bottom, jumps to the top and holds again.
  void _tickScroll() {
    if (!widget.autoPlay || !_scrollController.hasClients) return;
    final now = DateTime.now();
    if (_pauseUntil != null && now.isBefore(_pauseUntil!)) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent <= 0) return;
    if (position.pixels >= position.maxScrollExtent) {
      if (_pauseUntil == null) {
        _pauseUntil = now.add(_edgePause);
      } else {
        _scrollController.jumpTo(0);
        _pauseUntil = now.add(_edgePause);
      }
      return;
    }
    _pauseUntil = null;
    _scrollController.jumpTo((position.pixels + widget.scrollStep).clamp(0, position.maxScrollExtent));
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _clockTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.8, -1.2),
          radius: 1.8,
          colors: [BoardTheme.backgroundEnd, BoardTheme.background],
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final board = Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 4),
              child: Column(
                children: [
                  _titleBar(),
                  if (widget.belowTitle != null) ...[const SizedBox(height: 10), widget.belowTitle!],
                  const SizedBox(height: 12),
                  Expanded(child: _table()),
                  const SizedBox(height: 4),
                  _footer(),
                ],
              ),
            );
            // The board is laid out between [_designWidth] and [_maxDesignWidth]. A narrower
            // screen shows it scaled down, a 4K / 8K screen scaled up, so text and columns keep
            // their proportions and stay large enough to read across the room.
            if (!constraints.hasBoundedHeight) return board;
            final width = constraints.maxWidth;
            final design = width < _designWidth ? _designWidth : (width > _maxDesignWidth ? _maxDesignWidth : null);
            if (design == null) return board;
            final scale = width / design;
            return FittedBox(
              fit: BoxFit.fitWidth,
              alignment: Alignment.topCenter,
              child: SizedBox(width: design, height: constraints.maxHeight / scale, child: board),
            );
          },
        ),
      ),
    );
  }

  // ---------- Title bar ----------

  /// One slim row - logo, title, vessel search, date and clock - so the grid gets the screen.
  Widget _titleBar() {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [BoardTheme.panelHigh, BoardTheme.panel],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BoardTheme.border),
        boxShadow: BoardTheme.raised,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: Image.asset('assets/company/logo.png', width: 30, height: 30, fit: BoxFit.contain),
          ),
          const SizedBox(width: 14),
          _titleText(),
          const SizedBox(width: 24),
          Expanded(child: widget.searchBar ?? const SizedBox()),
          const SizedBox(width: 16),
          _dateControl(),
          const SizedBox(width: 20),
          _clock(),
        ],
      ),
    );
  }

  Widget _titleText() {
    if (widget.titleWidget != null) return widget.titleWidget!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          widget.title,
          maxLines: 1,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: BoardTheme.textPrimary,
            letterSpacing: 2,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            _LiveDot(),
            const SizedBox(width: 7),
            Text(widget.subtitle.toUpperCase(),
                maxLines: 1,
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w600, color: BoardTheme.textSecondary, letterSpacing: 1.2)),
          ],
        ),
      ],
    );
  }

  Widget _clock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '${BoardTheme.two(_now.hour)}:${BoardTheme.two(_now.minute)}',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: BoardTheme.textPrimary,
                height: 1,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 3),
            Text(
              BoardTheme.two(_now.second),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: BoardTheme.textMuted,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 1),
        Text('${BoardTheme.weekday(_now)} · ${BoardTheme.dayMonth(_now)}',
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: BoardTheme.textSecondary, letterSpacing: 1.1)),
      ],
    );
  }

  /// Left/right on the remote change the day.
  Widget _dateControl() {
    final d = widget.date;
    Widget arrow(IconData icon, int days) => ExcludeFocus(
          child: IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => widget.onChangeDate(days),
            icon: Icon(icon, color: BoardTheme.textSecondary, size: 22),
          ),
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
      decoration: BoxDecoration(
        color: BoardTheme.background.withValues(alpha: 0.7),
        border: Border.all(color: BoardTheme.border, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          arrow(Icons.chevron_left_rounded, -1),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(BoardTheme.relativeDay(d, _now),
                  style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w800, color: BoardTheme.accent, letterSpacing: 1.4)),
              Text(
                '${BoardTheme.two(d.day)}/${BoardTheme.two(d.month)}/${d.year}',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: BoardTheme.textPrimary),
              ),
            ],
          ),
          arrow(Icons.chevron_right_rounded, 1),
        ],
      ),
    );
  }

  // ---------- Table ----------

  /// Header and rows in one bordered grid.
  Widget _table() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: BoardTheme.rowOdd,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BoardTheme.gridLine, width: 1.5),
        boxShadow: BoardTheme.raised,
      ),
      child: Column(
        children: [
          widget.columnHeaders,
          Expanded(child: _body()),
        ],
      ),
    );
  }

  // ---------- Body ----------

  Widget _body() {
    return widget.jobs.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true, // keep the rows while a new search or day loads
      loading: () => Center(
        child:
            SizedBox(width: 56, height: 56, child: CircularProgressIndicator(color: BoardTheme.accent, strokeWidth: 5)),
      ),
      error: (error, _) => _message(
        icon: Icons.cloud_off_rounded,
        color: BoardTheme.danger,
        title: 'Cannot load the board',
        detail: error is ApiException ? error.message : '$error',
      ),
      data: (list) => list.isEmpty
          ? (widget.search.trim().isNotEmpty
              ? _message(
                  icon: Icons.search_off_rounded,
                  color: BoardTheme.textSecondary,
                  title: '${widget.noMatchTitle} "${widget.search.trim().toUpperCase()}"',
                  detail: 'Check the spelling, or press Back to clear the search.',
                )
              : _message(
                  icon: Icons.event_available_rounded,
                  color: BoardTheme.textSecondary,
                  title: 'No jobs for this date',
                  detail: 'Press left or right on the remote to see another day.',
                ))
          // The scrollbar shows where the list is: top, middle or the last rows.
          : RawScrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              thickness: 8,
              radius: const Radius.circular(4),
              thumbColor: BoardTheme.accent.withValues(alpha: 0.75),
              mainAxisMargin: 6,
              child: ShaderMask(
                // Soft fade at the bottom so rows slide out gently.
                shaderCallback: (rect) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, Colors.white, Colors.transparent],
                  stops: [0, 0.94, 1],
                ).createShader(rect),
                blendMode: BlendMode.dstIn,
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(bottom: 40),
                  itemExtent: _rowHeight,
                  itemCount: list.length,
                  itemBuilder: (context, index) =>
                      widget.rowBuilder(list[index], index, widget.selectedIndex == index, _now),
                ),
              ),
            ),
    );
  }

  Widget _message({required IconData icon, required Color color, required String title, required String detail}) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 760),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
        decoration: BoxDecoration(
          color: BoardTheme.panel,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(icon, size: 52, color: color),
            ),
            const SizedBox(height: 20),
            Text(title, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: BoardTheme.textPrimary)),
            const SizedBox(height: 10),
            Text(detail, textAlign: TextAlign.center, style: TextStyle(fontSize: 19, color: BoardTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  // ---------- Footer ----------

  /// The mode badge and remote help on the left, the colour legend and last update on the right.
  /// Each side shrinks a little rather than run off a narrower screen.
  Widget _footer() {
    Widget legend(Color color, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 7),
            Text(label,
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w600, color: BoardTheme.textSecondary, letterSpacing: 1)),
            const SizedBox(width: 12),
          ],
        );
    final updated = _updatedAt;
    return SizedBox(
      height: 20,
      child: Row(
        children: [
          if (widget.controls != null)
            Expanded(
              flex: 11,
              child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: widget.controls),
            ),
          const SizedBox(width: 16),
          Expanded(
            flex: 9,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(
                children: [
                  legend(BoardTheme.soon, 'WITHIN 2 HOURS'),
                  legend(BoardTheme.textPrimary, 'UPCOMING'),
                  legend(BoardTheme.textMuted, 'PASSED'),
                  if (widget.jobs.isRefreshing)
                    Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: BoardTheme.textMuted)),
                    ),
                  Text(
                    updated == null
                        ? 'REFRESH EVERY MINUTE'
                        : 'UPDATED ${BoardTheme.two(updated.hour)}:${BoardTheme.two(updated.minute)}',
                    style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w600, color: BoardTheme.textMuted, letterSpacing: 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small pulsing green dot that shows the board is live.
class _LiveDot extends StatefulWidget {
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 1.0).animate(_c),
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: BoardTheme.success,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: BoardTheme.success.withValues(alpha: 0.8), blurRadius: 8)],
        ),
      ),
    );
  }
}

/// The Vessel Planning board: [BoardView] with the vessel grid (port, ETA / ETB / ETD of both vessels).
class JobBoardView extends StatelessWidget {
  const JobBoardView({
    required this.title,
    required this.subtitle,
    required this.date,
    required this.onChangeDate,
    required this.jobs,
    this.scrollStep = 1.5,
    this.autoPlay = true,
    this.selectedIndex,
    this.controls,
    this.search = '',
    this.searchBar,
    this.titleWidget,
    super.key,
  });

  final String title;
  final String subtitle;
  final DateTime date;
  final ValueChanged<int> onChangeDate;
  final AsyncValue<List<JobModel>> jobs;
  final double scrollStep;
  final bool autoPlay;
  final int? selectedIndex;
  final Widget? controls;
  final String search;
  final Widget? searchBar;
  final Widget? titleWidget;

  @override
  Widget build(BuildContext context) {
    return BoardView<JobModel>(
      title: title,
      subtitle: subtitle,
      date: date,
      onChangeDate: onChangeDate,
      jobs: jobs,
      scrollStep: scrollStep,
      autoPlay: autoPlay,
      selectedIndex: selectedIndex,
      controls: controls,
      search: search,
      searchBar: searchBar,
      titleWidget: titleWidget,
      noMatchTitle: 'No vessel matches',
      columnHeaders: const VesselColumnHeaders(),
      rowBuilder: (job, index, selected, now) =>
          JobBoardItem(job: job, index: index, now: now, selected: selected, highlight: search),
    );
  }
}
