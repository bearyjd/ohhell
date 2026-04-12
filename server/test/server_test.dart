import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:test/test.dart';

import 'package:server/src/room_manager.dart';

/// Helper to read messages from a WebSocket as parsed JSON maps.
class WsClient {
  WsClient(this._ws) : _iter = StreamIterator(_ws.cast<String>());

  final WebSocket _ws;
  final StreamIterator<String> _iter;

  void sendJson(Map<String, dynamic> msg) {
    _ws.add(jsonEncode(msg));
  }

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

  setUp(() async {
    final manager = RoomManager();
    final router = Router()
      ..get('/ws', webSocketHandler(manager.handleNewConnection))
      ..get('/health', (Request req) => Response.ok('ok\n'));

    final handler =
        Pipeline().addMiddleware(logRequests()).addHandler(router.call);

    server = await io.serve(handler, InternetAddress.loopbackIPv4, 0);
    port = server.port;
  });

  tearDown(() async {
    await server.close(force: true);
  });

  Future<WsClient> connect() async {
    final ws = await WebSocket.connect('ws://localhost:$port/ws');
    return WsClient(ws);
  }

  /// Helper: creates a room, returns (client, roomCode).
  Future<(WsClient, String)> createRoom(String name) async {
    final client = await connect();
    client.sendJson({
      'type': 'join_room',
      'payload': {'playerName': name, 'roomCode': null},
    });
    final msg = await client.nextMessage();
    expect(msg['type'], 'room_joined');
    return (client, msg['payload']['roomCode'] as String);
  }

  /// Helper: joins an existing room, returns client.
  /// The host client will receive a player_joined notification.
  Future<WsClient> joinRoom(String name, String roomCode) async {
    final client = await connect();
    client.sendJson({
      'type': 'join_room',
      'payload': {'playerName': name, 'roomCode': roomCode},
    });
    final msg = await client.nextMessage();
    expect(msg['type'], 'room_joined');
    expect(msg['payload']['roomCode'], roomCode);
    expect(msg['payload']['isHost'], isFalse);
    return client;
  }

  test('health endpoint returns 200', () async {
    final response = await http.get(
      Uri.parse('http://localhost:$port/health'),
    );
    expect(response.statusCode, 200);
    expect(response.body, 'ok\n');
  });

  test('two clients can join a room', () async {
    final (host, roomCode) = await createRoom('Alice');

    final guest = await joinRoom('Bob', roomCode);

    // Host should receive player_joined for Bob
    final notif = await host.nextMessage();
    expect(notif['type'], 'player_joined');
    expect(notif['payload']['playerName'], 'Bob');

    await host.close();
    await guest.close();
  });

  test('client can start game and receives game_state + your_hand', () async {
    final (host, roomCode) = await createRoom('Alice');
    final p2 = await joinRoom('Bob', roomCode);
    await host.nextMessage(); // player_joined Bob
    final p3 = await joinRoom('Charlie', roomCode);
    await host.nextMessage(); // player_joined Charlie
    await p2.nextMessage(); // player_joined Charlie

    // Host starts game
    host.sendJson({
      'type': 'start_game',
      'payload': <String, dynamic>{},
    });

    // Each player should receive game_state then your_hand
    for (final client in [host, p2, p3]) {
      final gs = await client.nextMessage();
      expect(gs['type'], 'game_state');
      expect(gs['payload']['phase'], 'bidding');
      expect((gs['payload']['players'] as List).length, 3);

      // Verify no hand data in game_state players
      for (final p in gs['payload']['players'] as List) {
        expect((p as Map<String, dynamic>).containsKey('hand'), isFalse);
      }

      final hand = await client.nextMessage();
      expect(hand['type'], 'your_hand');
      // Round 1 has 1 card per hand
      expect((hand['payload']['cards'] as List).length, 1);
    }

    await host.close();
    await p2.close();
    await p3.close();
  });

  test('place_bid and play_card flow through one round', () async {
    final (host, roomCode) = await createRoom('Alice');
    final p2 = await joinRoom('Bob', roomCode);
    await host.nextMessage(); // player_joined
    final p3 = await joinRoom('Charlie', roomCode);
    await host.nextMessage(); // player_joined
    await p2.nextMessage(); // player_joined

    final clients = [host, p2, p3];

    // Start game
    host.sendJson({
      'type': 'start_game',
      'payload': <String, dynamic>{},
    });

    // Collect each player's hand (round 1 = 1 card each)
    final hands = <int, Map<String, dynamic>>{};
    for (var i = 0; i < 3; i++) {
      await clients[i].nextMessage(); // game_state
      final hand = await clients[i].nextMessage(); // your_hand
      final cards = hand['payload']['cards'] as List;
      hands[i] = cards.first as Map<String, dynamic>;
    }

    // Helper to consume game_state + your_hand from all clients
    Future<Map<String, dynamic>> consumeStateFromAll() async {
      late Map<String, dynamic> lastGs;
      for (final client in clients) {
        lastGs = await client.nextMessage(); // game_state
        await client.nextMessage(); // your_hand
      }
      return lastGs;
    }

    // Players bid in order (0, 0, 1)
    host.sendJson({
      'type': 'place_bid',
      'payload': {'bid': 0},
    });
    await consumeStateFromAll();

    p2.sendJson({
      'type': 'place_bid',
      'payload': {'bid': 0},
    });
    await consumeStateFromAll();

    p3.sendJson({
      'type': 'place_bid',
      'payload': {'bid': 1},
    });
    final gsAfterBids = await consumeStateFromAll();
    expect(gsAfterBids['payload']['phase'], 'playing');

    // Players play their single card in order
    host.sendJson({
      'type': 'play_card',
      'payload': hands[0],
    });
    await consumeStateFromAll();

    p2.sendJson({
      'type': 'play_card',
      'payload': hands[1],
    });
    await consumeStateFromAll();

    p3.sendJson({
      'type': 'play_card',
      'payload': hands[2],
    });
    // After trick + round ends, transitions to dealing for next round
    final gsAfterRound = await consumeStateFromAll();
    expect(gsAfterRound['payload']['phase'], 'dealing');

    await host.close();
    await p2.close();
    await p3.close();
  });
}
