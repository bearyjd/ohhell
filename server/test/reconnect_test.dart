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
  late HttpServer server;
  late int port;

  const testGrace = Duration(milliseconds: 200);

  setUp(() async {
    final manager = RoomManager(gracePeriod: testGrace);
    final router = Router()
      ..get('/ws', webSocketHandler(manager.handleNewConnection));
    server = await io.serve(
      Pipeline().addHandler(router.call),
      InternetAddress.loopbackIPv4,
      0,
    );
    port = server.port;
  });

  tearDown(() => server.close(force: true));

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
    'reconnect within grace period sends player_reconnected and game state',
    () async {
      final (host, code) = await createRoom('Alice');

      final bobWs = await connect();
      bobWs.sendJson({
        'type': 'join_room',
        'payload': {'playerName': 'Bob', 'roomCode': code},
      });
      final bobJoined = await bobWs.nextMessage();
      expect(bobJoined['type'], 'room_joined');
      final bobId = bobJoined['payload']['playerId'] as String;

      await host.nextMessage(); // player_joined notification

      await bobWs.close();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final bobBack = await connect();
      bobBack.sendJson({
        'type': 'reconnect_player',
        'payload': {'playerId': bobId, 'roomCode': code},
      });

      final reconnectMsg = await bobBack.nextMessage();
      expect(reconnectMsg['type'], 'player_reconnected');
      expect(reconnectMsg['payload']['playerId'], bobId);

      final stateMsg = await bobBack.nextMessage();
      expect(stateMsg['type'], 'game_state');

      await host.close();
      await bobBack.close();
    },
  );

  test(
    'grace period expiry broadcasts player_left to remaining players',
    () async {
      final (host, code) = await createRoom('Alice');

      final bobWs = await connect();
      bobWs.sendJson({
        'type': 'join_room',
        'payload': {'playerName': 'Bob', 'roomCode': code},
      });
      await bobWs.nextMessage();
      await host.nextMessage();

      await bobWs.close();
      await Future<void>.delayed(testGrace + const Duration(milliseconds: 100));

      final leftMsg = await host.nextMessage();
      expect(leftMsg['type'], 'player_left');

      await host.close();
    },
  );

  test(
    'reconnect after grace period expiry returns an error message',
    () async {
      final (host, code) = await createRoom('Alice');

      final bobWs = await connect();
      bobWs.sendJson({
        'type': 'join_room',
        'payload': {'playerName': 'Bob', 'roomCode': code},
      });
      final bobJoined = await bobWs.nextMessage();
      final bobId = bobJoined['payload']['playerId'] as String;
      await host.nextMessage();

      await bobWs.close();
      await Future<void>.delayed(testGrace + const Duration(milliseconds: 100));
      await host.nextMessage(); // player_left

      final lateClient = await connect();
      lateClient.sendJson({
        'type': 'reconnect_player',
        'payload': {'playerId': bobId, 'roomCode': code},
      });

      final errorMsg = await lateClient.nextMessage();
      expect(errorMsg['type'], 'error');

      await host.close();
    },
  );
}
