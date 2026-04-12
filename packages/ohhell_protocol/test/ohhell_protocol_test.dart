import 'dart:convert';

import 'package:ohhell_engine/ohhell_engine.dart';
import 'package:ohhell_protocol/ohhell_protocol.dart';
import 'package:test/test.dart';

void main() {
  group('ClientMessage roundtrip', () {
    test('JoinRoomMessage with roomCode', () {
      final msg = const JoinRoomMessage(
        playerName: 'Alice',
        roomCode: 'ABC123',
      );
      final json = msg.toJson();
      final decoded = ClientMessage.fromJson(json);
      expect(decoded, isA<JoinRoomMessage>());
      final joined = decoded as JoinRoomMessage;
      expect(joined.playerName, 'Alice');
      expect(joined.roomCode, 'ABC123');
    });

    test('JoinRoomMessage without roomCode creates room', () {
      final msg = const JoinRoomMessage(playerName: 'Bob');
      final json = msg.toJson();
      final decoded = ClientMessage.fromJson(json) as JoinRoomMessage;
      expect(decoded.playerName, 'Bob');
      expect(decoded.roomCode, isNull);
    });

    test('StartGameMessage', () {
      final msg = const StartGameMessage();
      final json = msg.toJson();
      final decoded = ClientMessage.fromJson(json);
      expect(decoded, isA<StartGameMessage>());
    });

    test('PlaceBidMessage', () {
      final msg = const PlaceBidMessage(bid: 3);
      final json = msg.toJson();
      final decoded = ClientMessage.fromJson(json) as PlaceBidMessage;
      expect(decoded.bid, 3);
    });

    test('PlayCardMessage', () {
      final msg = const PlayCardMessage(suit: 'hearts', rank: 'ace');
      final json = msg.toJson();
      final decoded = ClientMessage.fromJson(json) as PlayCardMessage;
      expect(decoded.suit, 'hearts');
      expect(decoded.rank, 'ace');
    });

    test('LeaveRoomMessage', () {
      final msg = const LeaveRoomMessage();
      final json = msg.toJson();
      final decoded = ClientMessage.fromJson(json);
      expect(decoded, isA<LeaveRoomMessage>());
    });

    test('roundtrip through JSON string encoding', () {
      final msg = const PlaceBidMessage(bid: 5);
      final jsonString = jsonEncode(msg.toJson());
      final decoded = ClientMessage.fromJson(
        jsonDecode(jsonString) as Map<String, dynamic>,
      );
      expect(decoded, isA<PlaceBidMessage>());
      expect((decoded as PlaceBidMessage).bid, 5);
    });

    test('unknown type throws FormatException', () {
      expect(
        () => ClientMessage.fromJson({
          'type': 'unknown',
          'payload': <String, dynamic>{},
        }),
        throwsFormatException,
      );
    });
  });

  group('ServerMessage roundtrip', () {
    test('RoomJoinedMessage', () {
      final msg = const RoomJoinedMessage(
        roomCode: 'XYZ789',
        playerId: 'p1',
        isHost: true,
      );
      final json = msg.toJson();
      final decoded = ServerMessage.fromJson(json) as RoomJoinedMessage;
      expect(decoded.roomCode, 'XYZ789');
      expect(decoded.playerId, 'p1');
      expect(decoded.isHost, isTrue);
    });

    test('PlayerJoinedMessage', () {
      final msg = const PlayerJoinedMessage(
        playerId: 'p2',
        playerName: 'Charlie',
      );
      final json = msg.toJson();
      final decoded = ServerMessage.fromJson(json) as PlayerJoinedMessage;
      expect(decoded.playerId, 'p2');
      expect(decoded.playerName, 'Charlie');
    });

    test('PlayerLeftMessage', () {
      final msg = const PlayerLeftMessage(playerId: 'p3');
      final json = msg.toJson();
      final decoded = ServerMessage.fromJson(json) as PlayerLeftMessage;
      expect(decoded.playerId, 'p3');
    });

    test('GameStateMessage', () {
      final dto = GameStateDto(
        phase: 'bidding',
        players: [
          const PlayerDto(
            id: 'p1',
            name: 'Alice',
            bid: 2,
            tricksWon: 0,
            totalScore: 10,
          ),
        ],
        currentRound: const RoundStateDto(
          roundNumber: 1,
          cardsPerHand: 5,
          trumpSuit: 'hearts',
          bids: {'p1': 2},
          completedTricks: 0,
          currentTrick: TrickDto(plays: [], leadSuit: null, trumpSuit: 'hearts'),
        ),
      );
      final msg = GameStateMessage(state: dto);
      final json = msg.toJson();
      final decoded = ServerMessage.fromJson(json) as GameStateMessage;
      expect(decoded.state.phase, 'bidding');
      expect(decoded.state.players.length, 1);
      expect(decoded.state.players.first.name, 'Alice');
      expect(decoded.state.currentRound?.trumpSuit, 'hearts');
    });

    test('YourHandMessage', () {
      final msg = YourHandMessage(
        cards: [
          const CardDto(suit: 'spades', rank: 'ace'),
          const CardDto(suit: 'hearts', rank: 'king'),
        ],
      );
      final json = msg.toJson();
      final decoded = ServerMessage.fromJson(json) as YourHandMessage;
      expect(decoded.cards.length, 2);
      expect(decoded.cards.first.suit, 'spades');
      expect(decoded.cards.first.rank, 'ace');
    });

    test('ErrorMessage', () {
      final msg = const ErrorMessage(message: 'Something went wrong');
      final json = msg.toJson();
      final decoded = ServerMessage.fromJson(json) as ErrorMessage;
      expect(decoded.message, 'Something went wrong');
    });

    test('unknown type throws FormatException', () {
      expect(
        () => ServerMessage.fromJson({
          'type': 'unknown',
          'payload': <String, dynamic>{},
        }),
        throwsFormatException,
      );
    });
  });

  group('GameStateDto from engine types', () {
    test('serializes GameState without hands', () {
      final gameState = GameState(
        phase: const Bidding(),
        players: [
          const Player(
            id: 'p1',
            name: 'Alice',
            hand: [PlayingCard(suit: Suit.spades, rank: Rank.ace)],
            bid: 1,
            tricksWon: 0,
            totalScore: 0,
          ),
          const Player(
            id: 'p2',
            name: 'Bob',
            hand: [PlayingCard(suit: Suit.hearts, rank: Rank.king)],
            tricksWon: 0,
            totalScore: 5,
          ),
        ],
        config: GameConfig.defaultFor(3),
        currentRound: const RoundState(
          roundNumber: 1,
          cardsPerHand: 1,
          trumpSuit: Suit.diamonds,
        ),
      );

      final dto = GameStateDto.fromGameState(gameState);
      expect(dto.phase, 'bidding');
      expect(dto.players.length, 2);
      expect(dto.currentRound?.trumpSuit, 'diamonds');

      // Verify no hand data in JSON
      final json = dto.toJson();
      final playersJson = json['players'] as List<dynamic>;
      for (final pJson in playersJson) {
        final playerMap = pJson as Map<String, dynamic>;
        expect(playerMap.containsKey('hand'), isFalse);
      }

      // Roundtrip
      final restored = GameStateDto.fromJson(json);
      expect(restored.phase, 'bidding');
      expect(restored.players.first.id, 'p1');
      expect(restored.players.first.bid, 1);
      expect(restored.players.last.bid, isNull);
    });
  });

  group('CardDto', () {
    test('fromCard and toCard roundtrip', () {
      const card = PlayingCard(suit: Suit.clubs, rank: Rank.queen);
      final dto = CardDto.fromCard(card);
      expect(dto.suit, 'clubs');
      expect(dto.rank, 'queen');
      final restored = dto.toCard();
      expect(restored, card);
    });
  });
}
