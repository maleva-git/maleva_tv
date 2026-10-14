import 'dart:io';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Android TV, Mac and Windows: the socket is opened WITHOUT permessage-deflate. The IIS/ARR proxy in
/// front of the server breaks compressed WebSocket frames (the backend's WebSocketConfig explains it);
/// uncompressed, the STOMP connection works (checked against the live server on 2026-10-14).
Future<WebSocketChannel> openPlanningSocket(Uri uri) async {
  final socket = await WebSocket.connect(uri.toString(), compression: CompressionOptions.compressionOff)
      .timeout(const Duration(seconds: 15));
  return IOWebSocketChannel(socket);
}
