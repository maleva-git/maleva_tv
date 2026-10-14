import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maleva_tv/core/network/api_exception.dart';
import 'package:maleva_tv/features/board/board_theme.dart';
import 'package:maleva_tv/features/home/presentation/home_controller.dart';

/// The port list: "ALL PORTS" and the company's ports. ▲▼ move, OK picks, Back closes.
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
  int _index = 0;
  bool _placed = false;

  static const _rowHeight = 54.0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _move(int step, int count) {
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

  @override
  Widget build(BuildContext context) {
    final ports = ref.watch(portsProvider);
    final options = ['', ...?ports.valueOrNull];
    // Start on the port the board shows now.
    if (!_placed && ports.hasValue) {
      _placed = true;
      _index = options.indexOf(widget.current).clamp(0, options.length - 1);
      WidgetsBinding.instance.addPostFrameCallback((_) => _keepVisible());
    }

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyUpEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowDown) {
          _move(1, options.length);
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
          Navigator.of(context).pop(options[_index]);
        } else if (event is KeyDownEvent &&
            (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.colorF1Green)) {
          Navigator.of(context).pop();
        } else {
          return KeyEventResult.ignored;
        }
        return KeyEventResult.handled;
      },
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
            width: 520,
            height: 600,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.anchor_rounded, color: BoardTheme.success, size: 26),
                      SizedBox(width: 10),
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
                  Expanded(child: _list(ports, options)),
                  const SizedBox(height: 12),
                  Text('UP / DOWN  MOVE     OK  SHOW THIS PORT     BACK  CLOSE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700, color: BoardTheme.textMuted, letterSpacing: 1)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _list(AsyncValue<List<String>> ports, List<String> options) {
    if (ports.isLoading && !ports.hasValue) {
      return Padding(
        padding: EdgeInsets.all(30),
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
    return ListView.builder(
      controller: _scroll,
      shrinkWrap: true,
      itemExtent: _rowHeight,
      itemCount: options.length,
      itemBuilder: (context, i) {
        final port = options[i];
        final picked = i == _index;
        final current = port == widget.current;
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
                  child: Text(
                    port.isEmpty ? 'ALL PORTS' : port.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: picked ? BoardTheme.textPrimary : BoardTheme.textSecondary),
                  ),
                ),
                if (current)
                  Row(
                    children: [
                      Icon(Icons.check_circle_rounded, size: 18, color: BoardTheme.success),
                      SizedBox(width: 6),
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
