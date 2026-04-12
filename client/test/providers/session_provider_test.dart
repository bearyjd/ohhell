import 'package:flutter_test/flutter_test.dart';
import 'package:ohhell_client/src/providers/session_provider.dart';
import 'package:ohhell_protocol/ohhell_protocol.dart';

void main() {
  group('SessionState', () {
    test('has correct default values', () {
      const state = SessionState();

      expect(state.serverHost, 'localhost:8080');
      expect(state.playerName, '');
      expect(state.playerId, isNull);
      expect(state.roomCode, isNull);
      expect(state.isHost, isFalse);
      expect(state.hand, isEmpty);
      expect(state.error, isNull);
    });

    test('copyWith preserves unchanged fields', () {
      const state = SessionState(
        serverHost: 'example.com:9090',
        playerName: 'Alice',
      );

      final updated = state.copyWith(playerName: 'Bob');

      expect(updated.serverHost, 'example.com:9090');
      expect(updated.playerName, 'Bob');
    });

    test('copyWith updates all fields', () {
      const state = SessionState();
      final hand = [
        const CardDto(suit: 'spades', rank: 'ace'),
      ];

      final updated = state.copyWith(
        serverHost: 'host',
        playerName: 'Alice',
        playerId: 'p1',
        roomCode: 'ROOM1',
        isHost: true,
        hand: hand,
        error: 'some error',
      );

      expect(updated.serverHost, 'host');
      expect(updated.playerName, 'Alice');
      expect(updated.playerId, 'p1');
      expect(updated.roomCode, 'ROOM1');
      expect(updated.isHost, isTrue);
      expect(updated.hand, hand);
      expect(updated.error, 'some error');
    });

    test('copyWith clearError sets error to null', () {
      const state = SessionState(error: 'oops');

      final updated = state.copyWith(clearError: true);

      expect(updated.error, isNull);
    });

    test('copyWith clearPlayerId sets playerId to null', () {
      const state = SessionState(playerId: 'p1');

      final updated = state.copyWith(clearPlayerId: true);

      expect(updated.playerId, isNull);
    });

    test('copyWith clearRoomCode sets roomCode to null', () {
      const state = SessionState(roomCode: 'R1');

      final updated = state.copyWith(clearRoomCode: true);

      expect(updated.roomCode, isNull);
    });
  });

  group('SessionNotifier', () {
    late SessionNotifier notifier;

    setUp(() {
      notifier = SessionNotifier();
    });

    test('initial state has defaults', () {
      expect(notifier.state.serverHost, 'localhost:8080');
      expect(notifier.state.playerName, '');
      expect(notifier.state.playerId, isNull);
    });

    test('setServerHost updates serverHost', () {
      notifier.setServerHost('192.168.1.1:3000');

      expect(notifier.state.serverHost, '192.168.1.1:3000');
    });

    test('setPlayerName updates playerName', () {
      notifier.setPlayerName('Alice');

      expect(notifier.state.playerName, 'Alice');
    });

    test('onRoomJoined updates session fields', () {
      notifier.setError('old error');

      notifier.onRoomJoined(
        playerId: 'p1',
        roomCode: 'ABCD',
        isHost: true,
      );

      expect(notifier.state.playerId, 'p1');
      expect(notifier.state.roomCode, 'ABCD');
      expect(notifier.state.isHost, isTrue);
      expect(notifier.state.error, isNull);
    });

    test('onHand updates hand', () {
      final cards = [
        const CardDto(suit: 'hearts', rank: 'king'),
        const CardDto(suit: 'clubs', rank: 'two'),
      ];

      notifier.onHand(cards);

      expect(notifier.state.hand.length, 2);
      expect(notifier.state.hand[0].suit, 'hearts');
    });

    test('onError sets error', () {
      notifier.setError('connection lost');

      expect(notifier.state.error, 'connection lost');
    });

    test('clearError removes error', () {
      notifier.setError('bad');
      notifier.clearError();

      expect(notifier.state.error, isNull);
    });

    test('reset preserves host and name', () {
      notifier.setServerHost('myhost:8080');
      notifier.setPlayerName('Bob');
      notifier.onRoomJoined(
        playerId: 'p1',
        roomCode: 'XYZ',
        isHost: true,
      );

      notifier.reset();

      expect(notifier.state.serverHost, 'myhost:8080');
      expect(notifier.state.playerName, 'Bob');
      expect(notifier.state.playerId, isNull);
      expect(notifier.state.roomCode, isNull);
      expect(notifier.state.isHost, isFalse);
      expect(notifier.state.hand, isEmpty);
    });
  });
}
