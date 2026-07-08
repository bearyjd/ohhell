import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:test/test.dart';

import 'package:server/src/room_manager.dart';

class WsClient {
  WsClient(this._ws) : _iter = StreamIterator(_ws.cast<String>());

  final WebSocket _ws;
  final StreamIterator<String> _iter;

  void sendJson(Map<String, dynamic> msg) => _ws.add(jsonEncode(msg));

  Future<Map<String, dynamic>> nextMessage() async {
    final hasNext = await _iter.moveNext();
    if (!hasNext) throw StateError('WebSocket stream ended unexpectedly');
    return jsonDecode(_iter.current) as Map<String, dynamic>;
  }

  Future<void> close() async {
    await _iter.cancel();
    await _ws.close();
  }
}

void main() {
  group('RoomManager.rooms empties out (grace-period path)', () {
    late HttpServer server;
    late RoomManager manager;
    late int port;

    const testGrace = Duration(milliseconds: 200);

    setUp(() async {
      manager = RoomManager(gracePeriod: testGrace);
      final router = Router()
        ..get('/ws', webSocketHandler(manager.handleNewConnection));
      server = await io.serve(
        Pipeline().addHandler(router.call),
        InternetAddress.loopbackIPv4,
        0,
      );
      port = server.port;
    });

    tearDown(() async {
      manager.dispose();
      await server.close(force: true);
    });

    Future<WsClient> connect() async {
      final ws = await WebSocket.connect('ws://localhost:$port/ws');
      return WsClient(ws);
    }

    Future<(WsClient, String)> createRoom(String name) async {
      final c = await connect();
      c.sendJson({
        'type': 'join_room',
        'payload': {'playerName': name, 'roomCode': null},
      });
      final msg = await c.nextMessage();
      expect(msg['type'], 'room_joined');
      return (c, msg['payload']['roomCode'] as String);
    }

    test(
      'a host-only room is removed from rooms once its connection drops '
      'and the grace period elapses',
      () async {
        final (host, code) = await createRoom('Alice');

        expect(manager.rooms.keys, contains(code));
        expect(manager.rooms[code]!.connections, hasLength(1));

        await host.close();
        await Future<void>.delayed(
          testGrace + const Duration(milliseconds: 150),
        );

        expect(manager.rooms, isEmpty);
      },
    );

    test(
      'a room with a remaining connected player is not removed when '
      'another player disconnects',
      () async {
        final (host, code) = await createRoom('Alice');

        final bob = await connect();
        bob.sendJson({
          'type': 'join_room',
          'payload': {'playerName': 'Bob', 'roomCode': code},
        });
        await bob.nextMessage();
        await host.nextMessage(); // player_joined notification

        await bob.close();
        await Future<void>.delayed(
          testGrace + const Duration(milliseconds: 150),
        );
        await host.nextMessage(); // player_left

        expect(manager.rooms.keys, contains(code));

        await host.close();
      },
    );
  });

  group('RoomManager idle-room reaper', () {
    // `Room._handleLeaveRoom` (server/lib/src/room.dart) removes the
    // connection directly and closes the socket itself. When that
    // triggers RoomManager's `onDone` handler, `_onDisconnect` finds the
    // connection already gone (`room.connections.remove(playerId)`
    // returns null) and returns early — so a room whose only player
    // leaves via `leave_room` (rather than just dropping the socket)
    // never goes through the grace-period removal path and lingers in
    // `_rooms` forever. This is exactly the gap the reaper exists to
    // catch, and it's now a live path since the client sends
    // `leave_room` on every leave (see leave_session.dart).
    late HttpServer server;
    late int port;

    setUp(() async {});

    Future<RoomManager> startServer({
      required Duration reapInterval,
      required Duration staleRoomAge,
    }) async {
      final manager = RoomManager(
        reapInterval: reapInterval,
        staleRoomAge: staleRoomAge,
      );
      final router = Router()
        ..get('/ws', webSocketHandler(manager.handleNewConnection));
      server = await io.serve(
        Pipeline().addHandler(router.call),
        InternetAddress.loopbackIPv4,
        0,
      );
      port = server.port;
      return manager;
    }

    tearDown(() async {
      await server.close(force: true);
    });

    Future<WsClient> connect() async {
      final ws = await WebSocket.connect('ws://localhost:$port/ws');
      return WsClient(ws);
    }

    test(
      'a room left via leave_room lingers without the reaper, and is '
      'force-removed once the reaper is started',
      () async {
        final manager = await startServer(
          reapInterval: const Duration(milliseconds: 20),
          staleRoomAge: const Duration(milliseconds: 60),
        );
        addTearDown(manager.dispose);

        final host = await connect();
        host.sendJson({
          'type': 'join_room',
          'payload': {'playerName': 'Alice', 'roomCode': null},
        });
        final joined = await host.nextMessage();
        final code = joined['payload']['roomCode'] as String;

        host.sendJson({'type': 'leave_room', 'payload': {}});
        await host.close();
        // Let the socket teardown (and RoomManager's onDone handler,
        // which no-ops since the connection is already gone) settle.
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Confirms the latent gap: the room is still tracked even
        // though it has zero connections and zero pending reconnects.
        expect(manager.rooms.keys, contains(code));

        manager.startReaper();
        await Future<void>.delayed(const Duration(milliseconds: 150));

        expect(manager.rooms, isEmpty);
      },
    );

    test(
      'a room that regains a connection before going stale is not '
      'force-removed',
      () async {
        final manager = await startServer(
          reapInterval: const Duration(milliseconds: 20),
          staleRoomAge: const Duration(milliseconds: 200),
        );
        addTearDown(manager.dispose);
        manager.startReaper();

        final host = await connect();
        host.sendJson({
          'type': 'join_room',
          'payload': {'playerName': 'Alice', 'roomCode': null},
        });
        final joined = await host.nextMessage();
        final code = joined['payload']['roomCode'] as String;

        host.sendJson({'type': 'leave_room', 'payload': {}});
        await host.close();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(manager.rooms.keys, contains(code));

        // A new player joins the same room before staleRoomAge elapses.
        final bob = await connect();
        bob.sendJson({
          'type': 'join_room',
          'payload': {'playerName': 'Bob', 'roomCode': code},
        });
        await bob.nextMessage();

        await Future<void>.delayed(const Duration(milliseconds: 250));
        expect(manager.rooms.keys, contains(code));

        await bob.close();
      },
    );
  });
}
