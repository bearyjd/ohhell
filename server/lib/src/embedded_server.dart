import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';

import 'room_manager.dart';

/// Starts an in-process WebSocket game server bound to all IPv4 interfaces.
///
/// [port] defaults to 0, which lets the OS assign a free port. The actual
/// bound port is available via the returned [HttpServer.port].
///
/// Caller is responsible for calling [HttpServer.close] when done.
///
/// Throws [SocketException] if the port is already in use or the address
/// cannot be bound (e.g. insufficient permissions).
Future<HttpServer> startEmbeddedServer({int port = 0}) async {
  final manager = RoomManager();
  final router = Router()
    ..get('/ws', webSocketHandler(manager.handleNewConnection));
  final handler = Pipeline().addHandler(router.call);
  return io.serve(handler, InternetAddress.anyIPv4, port);
}
