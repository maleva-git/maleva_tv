import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maleva_tv/core/config/app_config.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'planning_controller.dart';
import 'ws_connect.dart';

/// Whether the board hears plan saves live.
enum LiveStatus { connecting, live, offline }

/// Listens to the server's planning channel - STOMP over the raw WebSocket `/api/ws`, topic
/// `/topic/planning`, the one React's planning page uses. The server sends "UPDATE" there after a
/// plan is saved (`POST /api/planing/save`); the board then reloads.
///
/// The TV only listens: it sends nothing but the STOMP CONNECT / SUBSCRIBE frames and keep-alive
/// newlines, so it cannot affect anyone's work. If the connection drops it reconnects, waiting a
/// little longer each time (up to a minute); the board's one-minute refresh still runs meanwhile.
class PlanningLiveUpdates {
  PlanningLiveUpdates({
    required this.onPlanSaved,
    required this.onStatus,
    Future<WebSocketChannel> Function(Uri uri)? connect,
    Uri? uri,
  })  : _connect = connect ?? openPlanningSocket,
        _uri = uri ?? wsUri(AppConfig.javaBaseUrl);

  /// `https://host` → `wss://host/api/ws`.
  static Uri wsUri(String httpBase) {
    final base = Uri.parse(httpBase);
    return base.replace(scheme: base.scheme == 'https' ? 'wss' : 'ws', path: '/api/ws');
  }

  final VoidCallback onPlanSaved;
  final ValueChanged<LiveStatus> onStatus;
  final Future<WebSocketChannel> Function(Uri uri) _connect;
  final Uri _uri;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _keepAlive;
  Timer? _retry;
  Timer? _debounce;
  int _attempt = 0;
  bool _stopped = false;
  String _buffer = '';

  void start() {
    _stopped = false;
    _open();
  }

  Future<void> _open() async {
    if (_stopped) return;
    onStatus(LiveStatus.connecting);
    try {
      final channel = await _connect(_uri);
      if (_stopped) {
        channel.sink.close();
        return;
      }
      _channel = channel;
      _sub = channel.stream.listen(_onData, onError: (_) => _lost(), onDone: _lost, cancelOnError: true);
      channel.sink.add('CONNECT\naccept-version:1.2,1.1\nheart-beat:0,0\n\n\x00');
      // Keep-alive newlines: the proxy in front of the server closes sockets that stay silent.
      _keepAlive = Timer.periodic(const Duration(seconds: 20), (_) {
        try {
          _channel?.sink.add('\n');
        } catch (_) {}
      });
    } catch (_) {
      _lost();
    }
  }

  void _onData(dynamic data) {
    _buffer += data is String ? data : String.fromCharCodes(data as List<int>);
    // STOMP frames end with a NUL; between frames the server may send bare newlines.
    while (true) {
      final end = _buffer.indexOf('\x00');
      if (end < 0) break;
      final frame = _buffer.substring(0, end).replaceFirst(RegExp(r'^[\r\n]+'), '');
      _buffer = _buffer.substring(end + 1);
      _onFrame(frame);
    }
  }

  void _onFrame(String frame) {
    final command = frame.split('\n').first.trim();
    if (command == 'CONNECTED') {
      _attempt = 0;
      _channel?.sink.add('SUBSCRIBE\nid:tv-planning\ndestination:/topic/planning\nack:auto\n\n\x00');
      onStatus(LiveStatus.live);
    } else if (command == 'MESSAGE') {
      // One save can come with several messages; reload once.
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 800), onPlanSaved);
    } else if (command == 'ERROR') {
      _lost();
    }
  }

  void _lost() {
    _closeSocket();
    if (_stopped) return;
    onStatus(LiveStatus.offline);
    _attempt++;
    final wait = Duration(seconds: (2 << (_attempt.clamp(1, 5) - 1)).clamp(2, 60));
    _retry?.cancel();
    _retry = Timer(wait, _open);
  }

  void _closeSocket() {
    _keepAlive?.cancel();
    _sub?.cancel();
    _sub = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _buffer = '';
  }

  void stop() {
    _stopped = true;
    _retry?.cancel();
    _debounce?.cancel();
    _closeSocket();
  }
}

/// The live connection's state, for the board's LIVE badge.
final liveStatusProvider = StateProvider<LiveStatus>((ref) => LiveStatus.connecting);

/// Started once the board is on screen; reloads the Planning board when a plan is saved.
final planningLiveProvider = Provider<PlanningLiveUpdates>((ref) {
  final live = PlanningLiveUpdates(
    onPlanSaved: () {
      ref.invalidate(shownPlanningProvider);
      ref.invalidate(dayPlansProvider);
    },
    onStatus: (status) => ref.read(liveStatusProvider.notifier).state = status,
  );
  ref.onDispose(live.stop);
  return live;
});
