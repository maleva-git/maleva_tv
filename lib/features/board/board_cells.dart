import 'package:flutter/material.dart';
import 'board_theme.dart';

/// Pieces every board's rows share, so Vessel Planning and Planning look the same.
class BoardCells {
  BoardCells._();

  /// [text] with every word of [highlight] (the search) shown in amber on a soft amber background.
  static TextSpan marked(String text, TextStyle style, String highlight) {
    final words = highlight.toUpperCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return TextSpan(text: text, style: style);
    final upper = text.toUpperCase();
    if (upper.length != text.length) return TextSpan(text: text, style: style);
    final hit = List<bool>.filled(text.length, false);
    for (final w in words) {
      for (var i = upper.indexOf(w); i >= 0; i = upper.indexOf(w, i + 1)) {
        hit.fillRange(i, i + w.length, true);
      }
    }
    final marked = style.copyWith(
      color: BoardTheme.soon,
      backgroundColor: BoardTheme.soon.withValues(alpha: 0.18),
    );
    final spans = <TextSpan>[];
    var start = 0;
    for (var i = 1; i <= text.length; i++) {
      if (i == text.length || hit[i] != hit[start]) {
        spans.add(TextSpan(text: text.substring(start, i), style: hit[start] ? marked : style));
        start = i;
      }
    }
    return TextSpan(children: spans);
  }

  /// The status as a coloured chip; a long status wraps to two lines instead of being cut.
  static Widget statusChip(String jobStatus) {
    final color = BoardTheme.statusColor(jobStatus);
    final status = jobStatus.trim().isEmpty ? 'UNKNOWN' : jobStatus.trim().toUpperCase();
    return Padding(
      // keeps the chip clear of the grid lines
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              border: Border.all(color: color.withValues(alpha: 0.8), width: 1.5),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 6)],
                  ),
                ),
                const SizedBox(width: 8),
                // At most ~two words a line, so "WAITING FOR L-VESSEL" shows whole on two lines.
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 104),
                  child: Text(
                    status,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.6, height: 1.15),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Time over day. Within the next 2 hours it turns amber; once passed it dims.
  static Widget time(String? value, DateTime now) {
    final at = BoardTheme.parseDateTime(value);
    if (at == null) {
      return const Center(child: Text('—', style: TextStyle(fontSize: 18, color: BoardTheme.textMuted)));
    }
    final passed = at.isBefore(now);
    final soon = !passed && at.difference(now) <= const Duration(hours: 2);
    final timeColor = soon ? BoardTheme.soon : (passed ? BoardTheme.textMuted : BoardTheme.textPrimary);
    final day = BoardTheme.relativeDay(at, now);

    // Scales down rather than spilling out of a narrow column.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${BoardTheme.two(at.hour)}:${BoardTheme.two(at.minute)}',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: timeColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            soon ? 'SOON' : day,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: soon ? BoardTheme.soon : (day == 'TODAY' ? BoardTheme.accent : BoardTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
