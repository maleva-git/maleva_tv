// Opens the planning socket: without frame compression where the platform allows it (see ws_connect_io.dart).
export 'ws_connect_web.dart' if (dart.library.io) 'ws_connect_io.dart';
