import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';

import 'package:server/src/room_manager.dart';

void main() async {
  final manager = RoomManager();

  final router = Router()
    ..get('/ws', webSocketHandler(manager.handleNewConnection))
    ..get('/health', (Request req) => Response.ok('ok\n'));

  final handler =
      Pipeline().addMiddleware(logRequests()).addHandler(router.call);

  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await io.serve(handler, InternetAddress.anyIPv4, port);
  print('Server listening on port ${server.port}');
}
