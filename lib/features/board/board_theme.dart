import 'package:flutter/material.dart';

/// Colours, column layout and small formatting helpers shared by every TV board,
/// so headers and rows always line up.
class BoardTheme {
  BoardTheme._();

  /// The colours in use. Each board sets its own before it builds (see [BoardPalette]); the
  /// sign-in screen and Vessel Planning use [BoardPalette.navy], Planning [BoardPalette.malevaLight].
  static BoardPalette palette = BoardPalette.navy;

  static Color get background => palette.background;
  static Color get backgroundEnd => palette.backgroundEnd;
  static Color get panel => palette.panel;
  static Color get panelHigh => palette.panelHigh;
  static Color get rowEven => palette.rowEven;
  static Color get rowOdd => palette.rowOdd;
  static Color get border => palette.border;
  static Color get accent => palette.accent;
  static Color get soon => palette.soon;
  static Color get textPrimary => palette.textPrimary;
  static Color get textSecondary => palette.textSecondary;
  static Color get textMuted => palette.textMuted;
  static Color get success => palette.success;
  static Color get danger => palette.danger;
  static Color get warning => palette.warning;

  /// Column layout, in display order. `snoWidth` is fixed; the rest are flex values.
  static const snoWidth = 64.0;
  static const vessel = 5;
  static const port = 5;
  static const jobNo = 3;
  static const employee = 4;
  static const status = 4;
  static const time = 2; // each of the six ETA / ETB / ETD columns
  static const timeGroup = time * 3; // ETA + ETB + ETD of one vessel

  /// Grid lines between columns and rows, and the header row's fill.
  static Color get gridLine => palette.gridLine;
  static Color get headerFill => palette.headerFill;
  static Color get offVessel => palette.offVessel;

  /// The row or control picked with the remote: bright, so it is seen from across the room.
  static Color get selection => palette.selection;

  /// One table cell with a grid line on its right; the last cell of a row has none.
  /// Header and rows both use it, so their columns line up to the pixel.
  static Widget cell({int? flex, double? width, required Widget child, bool divider = true}) {
    final box = Container(
      width: width,
      decoration: divider ? BoxDecoration(border: Border(right: BorderSide(color: gridLine))) : null,
      child: child,
    );
    return width != null ? box : Expanded(flex: flex ?? 1, child: box);
  }

  static Color statusColor(String status) => palette.status(status);

  static String two(int v) => v.toString().padLeft(2, '0');

  static const _months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
  static const _weekdays = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];

  static String dayMonth(DateTime d) => '${two(d.day)} ${_months[d.month - 1]}';
  static String weekday(DateTime d) => _weekdays[d.weekday - 1];

  /// "TODAY", "TOMORROW", "YESTERDAY" or "14 OCT".
  static String relativeDay(DateTime d, DateTime now) {
    final diff = DateTime(d.year, d.month, d.day).difference(DateTime(now.year, now.month, now.day)).inDays;
    return switch (diff) { 0 => 'TODAY', 1 => 'TOMORROW', -1 => 'YESTERDAY', _ => dayMonth(d) };
  }

  /// Reads the server's `yyyy-MM-dd HH:mm:ss` (or `dd/MM/yyyy HH:mm`); null when empty, unreadable or
  /// the legacy "no date" 1900-01-01.
  static DateTime? parseDateTime(String? value) {
    final parsed = _parse(value);
    return parsed == null || parsed.year <= 1900 ? null : parsed;
  }

  static DateTime? _parse(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    try {
      if (value.contains('/')) {
        final parts = value.trim().split(' ');
        final date = parts[0].split('/');
        final time = parts.length > 1 ? parts[1] : '00:00';
        return DateTime.parse('${date[2]}-${date[1].padLeft(2, '0')}-${date[0].padLeft(2, '0')} $time');
      }
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }
}

/// One set of board colours.
class BoardPalette {
  const BoardPalette({
    required this.background,
    required this.backgroundEnd,
    required this.panel,
    required this.panelHigh,
    required this.rowEven,
    required this.rowOdd,
    required this.border,
    required this.accent,
    required this.soon,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.gridLine,
    required this.headerFill,
    required this.offVessel,
    required this.selection,
    required this.success,
    required this.danger,
    required this.warning,
    required this.info,
    required this.violet,
    required this.isLight,
  });

  final Color background, backgroundEnd, panel, panelHigh, rowEven, rowOdd, border, accent, soon;
  final Color textPrimary, textSecondary, textMuted, gridLine, headerFill, offVessel, selection;
  final Color success, danger, warning, info, violet;
  final bool isLight;

  /// Status colour: blue assigned, orange on the road, green done, amber waiting, red cancelled.
  Color status(String status) {
    switch (status.trim().toUpperCase()) {
      case 'ASSIGNED':
        return accent;
      case 'IN TRANSIT':
      case 'STARTED':
      case 'ONGOING':
        return info;
      case 'COMPLETED':
      case 'DELIVERED':
      case 'CLOSED':
        return success;
      case 'PENDING':
      case 'OPEN':
        return warning;
      case 'CANCELLED':
      case 'CANCELED':
        return danger;
      default:
        return violet;
    }
  }

  /// Royal blue on a dark navy base: white text stands out and the TV shows less glare.
  /// Alternate rows differ clearly so the eye can follow one job across the grid.
  static const navy = BoardPalette(
    background: Color(0xFF020B24),
    backgroundEnd: Color(0xFF07194A),
    panel: Color(0xFF0A1F52),
    panelHigh: Color(0xFF1746B0),
    rowEven: Color(0xFF0E2A66),
    rowOdd: Color(0xFF061536),
    border: Color(0xFF2456C2),
    accent: Color(0xFF5AB0FF),
    soon: Color(0xFFFBBF24),
    textPrimary: Colors.white,
    textSecondary: Color(0xFFC6D7F7),
    textMuted: Color(0xFF8AA3D6),
    gridLine: Color(0xFF1F4BA8),
    headerFill: Color(0xFF123A8F),
    offVessel: Color(0xFFC4B5FD),
    selection: Color(0xFF22D3EE),
    success: Color(0xFF4ADE80),
    danger: Color(0xFFF87171),
    warning: Color(0xFFFACC15),
    info: Color(0xFFFB923C),
    violet: Color(0xFFA78BFA),
    isLight: false,
  );

  /// maleva_app's Planning screens (core/theme/app_theme.dart, light): #F3F5FA page, white cards,
  /// #F6F8FC second surface, #DDE3EE outlines, blue #1555F3, ink #121826, and its status tones.
  static const malevaLight = BoardPalette(
    background: Color(0xFFF3F5FA),
    backgroundEnd: Color(0xFFE9EEF8),
    panel: Color(0xFFFFFFFF),
    panelHigh: Color(0xFFFFFFFF),
    rowEven: Color(0xFFFFFFFF),
    rowOdd: Color(0xFFF6F8FC),
    border: Color(0xFFDDE3EE),
    accent: Color(0xFF1555F3),
    soon: Color(0xFFB45309),
    textPrimary: Color(0xFF121826),
    textSecondary: Color(0xFF535D74),
    textMuted: Color(0xFF7C86A2),
    gridLine: Color(0xFFDDE3EE),
    headerFill: Color(0xFFF6F8FC),
    offVessel: Color(0xFF5B2EB0),
    selection: Color(0xFF1555F3),
    success: Color(0xFF0B6B45),
    danger: Color(0xFFB42318),
    warning: Color(0xFF8A4B00),
    info: Color(0xFF075985),
    violet: Color(0xFF5B2EB0),
    isLight: true,
  );
}
