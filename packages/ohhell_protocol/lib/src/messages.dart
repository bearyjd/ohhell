import 'package:ohhell_protocol/src/dtos.dart';

// ---------------------------------------------------------------------------
// Client → Server messages
// ---------------------------------------------------------------------------

/// Messages sent from the client to the server.
sealed class ClientMessage {
  const ClientMessage();

  factory ClientMessage.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    final payload = json['payload'] as Map<String, dynamic>;
    return switch (type) {
      'join_room' => JoinRoomMessage.fromJson(payload),
      'start_game' => const StartGameMessage(),
      'place_bid' => PlaceBidMessage.fromJson(payload),
      'play_card' => PlayCardMessage.fromJson(payload),
      'leave_room' => const LeaveRoomMessage(),
      'reconnect_player' => ReconnectPlayerMessage.fromJson(payload),
      _ => throw FormatException('Unknown client message type: $type'),
    };
  }

  Map<String, dynamic> toJson();
}

final class JoinRoomMessage extends ClientMessage {
  const JoinRoomMessage({required this.playerName, this.roomCode});

  final String playerName;
  final String? roomCode;

  factory JoinRoomMessage.fromJson(Map<String, dynamic> json) {
    return JoinRoomMessage(
      playerName: json['playerName'] as String,
      roomCode: json['roomCode'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'join_room',
    'payload': {'playerName': playerName, 'roomCode': roomCode},
  };
}

final class StartGameMessage extends ClientMessage {
  const StartGameMessage();

  @override
  Map<String, dynamic> toJson() => {
    'type': 'start_game',
    'payload': <String, dynamic>{},
  };
}

final class PlaceBidMessage extends ClientMessage {
  const PlaceBidMessage({required this.bid});

  final int bid;

  factory PlaceBidMessage.fromJson(Map<String, dynamic> json) {
    return PlaceBidMessage(bid: json['bid'] as int);
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'place_bid',
    'payload': {'bid': bid},
  };
}

final class PlayCardMessage extends ClientMessage {
  const PlayCardMessage({required this.suit, required this.rank});

  final String suit;
  final String rank;

  factory PlayCardMessage.fromJson(Map<String, dynamic> json) {
    return PlayCardMessage(
      suit: json['suit'] as String,
      rank: json['rank'] as String,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'play_card',
    'payload': {'suit': suit, 'rank': rank},
  };
}

final class LeaveRoomMessage extends ClientMessage {
  const LeaveRoomMessage();

  @override
  Map<String, dynamic> toJson() => {
    'type': 'leave_room',
    'payload': <String, dynamic>{},
  };
}

final class ReconnectPlayerMessage extends ClientMessage {
  const ReconnectPlayerMessage({
    required this.playerId,
    required this.roomCode,
  });

  final String playerId;
  final String roomCode;

  factory ReconnectPlayerMessage.fromJson(Map<String, dynamic> json) {
    return ReconnectPlayerMessage(
      playerId: json['playerId'] as String,
      roomCode: json['roomCode'] as String,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'reconnect_player',
    'payload': {'playerId': playerId, 'roomCode': roomCode},
  };
}

// ---------------------------------------------------------------------------
// Server → Client messages
// ---------------------------------------------------------------------------

/// Messages sent from the server to the client.
sealed class ServerMessage {
  const ServerMessage();

  factory ServerMessage.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    final payload = json['payload'] as Map<String, dynamic>;
    return switch (type) {
      'room_joined' => RoomJoinedMessage.fromJson(payload),
      'player_joined' => PlayerJoinedMessage.fromJson(payload),
      'player_left' => PlayerLeftMessage.fromJson(payload),
      'game_state' => GameStateMessage.fromJson(payload),
      'your_hand' => YourHandMessage.fromJson(payload),
      'error' => ErrorMessage.fromJson(payload),
      'player_reconnected' => PlayerReconnectedMessage.fromJson(payload),
      _ => throw FormatException('Unknown server message type: $type'),
    };
  }

  Map<String, dynamic> toJson();
}

final class RoomJoinedMessage extends ServerMessage {
  const RoomJoinedMessage({
    required this.roomCode,
    required this.playerId,
    required this.isHost,
  });

  final String roomCode;
  final String playerId;
  final bool isHost;

  factory RoomJoinedMessage.fromJson(Map<String, dynamic> json) {
    return RoomJoinedMessage(
      roomCode: json['roomCode'] as String,
      playerId: json['playerId'] as String,
      isHost: json['isHost'] as bool,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'room_joined',
    'payload': {
      'roomCode': roomCode,
      'playerId': playerId,
      'isHost': isHost,
    },
  };
}

final class PlayerJoinedMessage extends ServerMessage {
  const PlayerJoinedMessage({
    required this.playerId,
    required this.playerName,
  });

  final String playerId;
  final String playerName;

  factory PlayerJoinedMessage.fromJson(Map<String, dynamic> json) {
    return PlayerJoinedMessage(
      playerId: json['playerId'] as String,
      playerName: json['playerName'] as String,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'player_joined',
    'payload': {'playerId': playerId, 'playerName': playerName},
  };
}

final class PlayerLeftMessage extends ServerMessage {
  const PlayerLeftMessage({required this.playerId});

  final String playerId;

  factory PlayerLeftMessage.fromJson(Map<String, dynamic> json) {
    return PlayerLeftMessage(playerId: json['playerId'] as String);
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'player_left',
    'payload': {'playerId': playerId},
  };
}

final class GameStateMessage extends ServerMessage {
  const GameStateMessage({required this.state});

  final GameStateDto state;

  factory GameStateMessage.fromJson(Map<String, dynamic> json) {
    return GameStateMessage(
      state: GameStateDto.fromJson(json),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'game_state',
    'payload': state.toJson(),
  };
}

final class YourHandMessage extends ServerMessage {
  const YourHandMessage({required this.cards});

  final List<CardDto> cards;

  factory YourHandMessage.fromJson(Map<String, dynamic> json) {
    final cardsList = (json['cards'] as List<dynamic>)
        .map((e) => CardDto.fromJson(e as Map<String, dynamic>))
        .toList();
    return YourHandMessage(cards: cardsList);
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'your_hand',
    'payload': {
      'cards': cards.map((c) => c.toJson()).toList(),
    },
  };
}

final class ErrorMessage extends ServerMessage {
  const ErrorMessage({required this.message});

  final String message;

  factory ErrorMessage.fromJson(Map<String, dynamic> json) {
    return ErrorMessage(message: json['message'] as String);
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'error',
    'payload': {'message': message},
  };
}

final class PlayerReconnectedMessage extends ServerMessage {
  const PlayerReconnectedMessage({required this.playerId});

  final String playerId;

  factory PlayerReconnectedMessage.fromJson(Map<String, dynamic> json) {
    return PlayerReconnectedMessage(
      playerId: json['playerId'] as String,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'player_reconnected',
    'payload': {'playerId': playerId},
  };
}
