import 'package:flutter/material.dart';

/// Colours, column layout and small formatting helpers shared by every TV board,
/// so headers and rows always line up.
class BoardTheme {
  BoardTheme._();

  // Royal-blue palette on a darker navy base: white text stands out and the TV shows less glare.
  // Alternate rows differ clearly so the eye can follow one job across the grid.
  static const background = Color(0xFF020B24);
  static const backgroundEnd = Color(0xFF07194A);
  static const panel = Color(0xFF0A1F52);
  static const panelHigh = Color(0xFF1746B0);
  static const rowEven = Color(0xFF0E2A66);
  static const rowOdd = Color(0xFF061536);
  static const border = Color(0xFF2456C2);
  static const accent = Color(0xFF5AB0FF);
  static const soon = Color(0xFFFBBF24);
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFFC6D7F7);
  static const textMuted = Color(0xFF8AA3D6);

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
  static const gridLine = Color(0xFF1F4BA8);
  static const headerFill = Color(0xFF123A8F);
  static const offVessel = Color(0xFFC4B5FD);

  /// The row or control picked with the remote: bright, so it is seen from across the room.
  static const selection = Color(0xFF22D3EE);

  /// One table cell with a grid line on its right; the last cell of a row has none.
  /// Header and rows both use it, so their columns line up to the pixel.
  static Widget cell({int? flex, double? width, required Widget child, bool divider = true}) {
    final box = Container(
      width: width,
      decoration: divider ? const BoxDecoration(border: Border(right: BorderSide(color: gridLine))) : null,
      child: child,
    );
    return width != null ? box : Expanded(flex: flex ?? 1, child: box);
  }

  static Color statusColor(String status) {
    switch (status.trim().toUpperCase()) {
      case 'ASSIGNED':
        return const Color(0xFF60A5FA);
      case 'IN TRANSIT':
      case 'STARTED':
      case 'ONGOING':
        return const Color(0xFFFB923C);
      case 'COMPLETED':
      case 'DELIVERED':
      case 'CLOSED':
        return const Color(0xFF4ADE80);
      case 'PENDING':
      case 'OPEN':
        return const Color(0xFFFACC15);
      case 'CANCELLED':
      case 'CANCELED':
        return const Color(0xFFF87171);
      default:
        return const Color(0xFFA78BFA);
    }
  }

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
