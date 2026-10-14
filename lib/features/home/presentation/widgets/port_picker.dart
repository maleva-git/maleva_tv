import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maleva_tv/core/network/api_exception.dart';
import 'package:maleva_tv/features/board/board_cells.dart';
import 'package:maleva_tv/features/board/board_theme.dart';
import 'package:maleva_tv/features/home/presentation/home_controller.dart';

/// The port list: "ALL PORTS" and the company's ports, with a search box on top.
/// Typing (or MENU / blue on the TV remote, which opens the on-screen keyboard) filters the ports;
/// ▲▼ move, OK picks, Back clears the search and then closes.
/// Pops the picked port ('' for all ports), or null when closed without a pick.
class PortPicker extends ConsumerStatefulWidget {
  const PortPicker({required this.current, super.key});

  /// The port the board shows now ('' = all).
  final String current;

  @override
  ConsumerState<PortPicker> createState() => _PortPickerState();
}

class _PortPickerState extends ConsumerState<PortPicker> {
  final _scroll = ScrollController();
  final _query = TextEditingController();
  final _searchFocus = FocusNode(debugLabel: 'port search');
  final _listFocus = FocusNode(debugLabel: 'port list');
  int _index = 0;
  bool _placed = false;

  static const _rowHeight = 54.0;
  static final _typedKey = RegExp(r'^[A-Za-z0-9\-]$');
  static final _searchKeys = {
    LogicalKeyboardKey.contextMenu,
    LogicalKeyboardKey.colorF3Blue,
    LogicalKeyboardKey.find,
    LogicalKeyboardKey.browserSearch,
  };

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() => _index = 0));
    _searchFocus.addListener(() {
      if (!mounted) return;
      setState(() {});
      // A focused field can select its whole text a moment later (the web does), so the next letter
      // would replace the one that started the search; keep the cursor at the end instead.
      if (_searchFocus.hasFocus) {
        Future<void>.delayed(const Duration(milliseconds: 80), () {
          if (mounted && _searchFocus.hasFocus && !_query.selection.isCollapsed) {
            _query.selection = TextSelection.collapsed(offset: _query.text.length);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _query.dispose();
    _searchFocus.dispose();
    _listFocus.dispose();
    super.dispose();
  }

  /// "ALL PORTS" and every port while nothing is typed; otherwise the ports containing every word typed.
  List<String> _options(List<String> ports) {
    final words = _query.text.toUpperCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return ['', ...ports];
    return ports.where((p) => words.every(p.toUpperCase().contains)).toList();
  }

  void _move(int step, int count) {
    if (count == 0) return;
    setState(() => _index = (_index + step).clamp(0, count - 1));
    _keepVisible();
  }

  void _keepVisible() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    final target = _index * _rowHeight - (position.viewportDimension - _rowHeight) / 2;
    _scroll.animateTo(target.clamp(0.0, position.maxScrollExtent),
        duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
  }

  void _pick(List<String> options) {
    if (options.isEmpty) return;
    Navigator.of(context).pop(options[_index.clamp(0, options.length - 1)]);
  }

  /// Opens the search box; [seed] is a letter typed while the list had the focus.
  void _startSearch({String seed = ''}) {
    if (seed.isNotEmpty) {
      _query.text = _query.text + seed;
      _query.selection = TextSelection.collapsed(offset: _query.text.length);
    }
    _searchFocus.requestFocus();
  }

  /// Back: first clears the search, then closes.
  void _back() {
    if (_query.text.isNotEmpty) {
      _query.clear();
      _listFocus.requestFocus();
    } else {
      Navigator.of(context).pop();
    }
  }

  KeyEventResult _onKey(KeyEvent event, List<String> options) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final typing = _searchFocus.hasFocus;
    final typed = event.character;
    if (!typing && event is KeyDownEvent && _searchKeys.contains(key)) {
      _startSearch();
    } else if (!typing && event is KeyDownEvent && typed != null && _typedKey.hasMatch(typed)) {
      _startSearch(seed: typed);
    } else if (!typing && key == LogicalKeyboardKey.backspace && _query.text.isNotEmpty) {
      _query.text = _query.text.substring(0, _query.text.length - 1);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      // from the search box, ▼ goes back to the list
      if (typing) _listFocus.requestFocus();
      _move(typing ? 0 : 1, options.length);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _move(-1, options.length);
    } else if (key == LogicalKeyboardKey.pageDown || key == LogicalKeyboardKey.channelDown) {
      _move(6, options.length);
    } else if (key == LogicalKeyboardKey.pageUp || key == LogicalKeyboardKey.channelUp) {
      _move(-6, options.length);
    } else if (event is KeyDownEvent &&
        (key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter ||
            key == LogicalKeyboardKey.gameButtonA)) {
      _pick(options);
    } else if (event is KeyDownEvent &&
        (key == LogicalKeyboardKey.escape || (!typing && key == LogicalKeyboardKey.colorF1Green))) {
      _back();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final ports = ref.watch(portsProvider);
    final options = _options(ports.valueOrNull ?? const []);
    // Start on the port the board shows now.
    if (!_placed && ports.hasValue) {
      _placed = true;
      _index = options.indexOf(widget.current).clamp(0, options.length - 1);
      WidgetsBinding.instance.addPostFrameCallback((_) => _keepVisible());
    }

    return PopScope(
      // The TV's Back first clears the search, then closes.
      canPop: _query.text.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Focus(
        focusNode: _listFocus,
        autofocus: true,
        onKeyEvent: (node, event) => _onKey(event, options),
        child: Dialog(
          backgroundColor: BoardTheme.panel,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: BoardTheme.border, width: 1.5),
          ),
          // Laid out at a fixed size and scaled down evenly in a small window, like the board.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: 560,
              height: 660,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.anchor_rounded, color: BoardTheme.success, size: 26),
                        const SizedBox(width: 10),
                        Text('SHOW PORT',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: BoardTheme.textPrimary,
                                letterSpacing: 2)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('The board shows only vessels at the port you pick (loading or off-vessel port).',
                        style: TextStyle(fontSize: 13, color: BoardTheme.textSecondary)),
                    const SizedBox(height: 14),
                    _searchBox(ports.valueOrNull?.length, options.length),
                    const SizedBox(height: 12),
                    Expanded(child: _list(ports, options)),
                    const SizedBox(height: 12),
                    Text('TYPE / MENU  SEARCH     UP / DOWN  MOVE     OK  SHOW     BACK  CLEAR / CLOSE',
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

  Widget _searchBox(int? total, int shown) {
    final focused = _searchFocus.hasFocus;
    final searching = _query.text.trim().isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 52,
      padding: const EdgeInsets.only(left: 14, right: 6),
      decoration: BoxDecoration(
        color: BoardTheme.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: focused ? BoardTheme.selection : (searching ? BoardTheme.soon : BoardTheme.border),
          width: focused ? 2.5 : 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 22, color: focused ? BoardTheme.selection : BoardTheme.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _query,
              focusNode: _searchFocus,
              onSubmitted: (_) => _listFocus.requestFocus(),
              textInputAction: TextInputAction.search,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              enableSuggestions: false,
              cursorColor: BoardTheme.selection,
              style:
                  TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: BoardTheme.textPrimary, letterSpacing: 1),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'TYPE OR PRESS MENU TO SEARCH A PORT',
                hintStyle:
                    TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: BoardTheme.textMuted, letterSpacing: 1),
              ),
            ),
          ),
          if (searching) ...[
            Text(shown == 1 ? '1 PORT' : '$shown PORTS',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: BoardTheme.soon, letterSpacing: 1)),
            IconButton(
              tooltip: 'Clear',
              visualDensity: VisualDensity.compact,
              onPressed: () {
                _query.clear();
                _listFocus.requestFocus();
              },
              icon: Icon(Icons.close_rounded, size: 20, color: BoardTheme.textSecondary),
            ),
          ] else if (total != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text('$total PORTS',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800, color: BoardTheme.textMuted, letterSpacing: 1)),
            ),
        ],
      ),
    );
  }

  Widget _list(AsyncValue<List<String>> ports, List<String> options) {
    if (ports.isLoading && !ports.hasValue) {
      return Padding(
        padding: const EdgeInsets.all(30),
        child: Center(child: CircularProgressIndicator(color: BoardTheme.accent)),
      );
    }
    if (ports.hasError && !ports.hasValue) {
      final error = ports.error;
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'Cannot load the ports: ${error is ApiException ? error.message : error}',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: BoardTheme.danger),
        ),
      );
    }
    if (options.isEmpty) {
      return Center(
        child: Text('No port matches "${_query.text.trim().toUpperCase()}"',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: BoardTheme.textMuted)),
      );
    }
    final highlight = _query.text;
    return ListView.builder(
      controller: _scroll,
      itemExtent: _rowHeight,
      itemCount: options.length,
      itemBuilder: (context, i) {
        final port = options[i];
        final picked = i == _index;
        final current = port == widget.current;
        final style = TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: picked ? BoardTheme.textPrimary : BoardTheme.textSecondary);
        return GestureDetector(
          onTap: () => Navigator.of(context).pop(port),
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
                Icon(port.isEmpty ? Icons.public_rounded : Icons.anchor_rounded,
                    size: 20, color: picked ? BoardTheme.selection : BoardTheme.textMuted),
                const SizedBox(width: 12),
                Expanded(
                  child: Text.rich(
                    // the letters searched for are lit up
                    port.isEmpty
                        ? TextSpan(text: 'ALL PORTS', style: style)
                        : BoardCells.marked(port.toUpperCase(), style, highlight),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (current)
                  Row(
                    children: [
                      Icon(Icons.check_circle_rounded, size: 18, color: BoardTheme.success),
                      const SizedBox(width: 6),
                      Text('SHOWING',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w800, color: BoardTheme.success, letterSpacing: 1)),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
