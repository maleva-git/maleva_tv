import 'package:web_socket_channel/web_socket_channel.dart';

/// Browser: the browser always offers frame compression and the page cannot switch it off, so on the
/// live server (behind IIS) the socket fails until the server stops accepting compression; the board
/// then keeps its one-minute refresh.
Future<WebSocketChannel> openPlanningSocket(Uri uri) async {
  final channel = WebSocketChannel.connect(uri);
  await channel.ready.timeout(const Duration(seconds: 15));
  return channel;
}
