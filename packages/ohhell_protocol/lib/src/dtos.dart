import 'package:ohhell_engine/ohhell_engine.dart';

/// DTO for a playing card (suit + rank as strings).
class CardDto {
  const CardDto({required this.suit, required this.rank});

  final String suit;
  final String rank;

  factory CardDto.fromJson(Map<String, dynamic> json) {
    return CardDto(
      suit: json['suit'] as String,
      rank: json['rank'] as String,
    );
  }

  factory CardDto.fromCard(PlayingCard card) {
    return CardDto(suit: card.suit.name, rank: card.rank.name);
  }

  Map<String, dynamic> toJson() => {'suit': suit, 'rank': rank};

  PlayingCard toCard() {
    final s = Suit.values.firstWhere((v) => v.name == suit);
    final r = Rank.values.firstWhere((v) => v.name == rank);
    return PlayingCard(suit: s, rank: r);
  }
}

/// DTO for a player (no hand field — hands are sent separately).
class PlayerDto {
  const PlayerDto({
    required this.id,
    required this.name,
    this.bid,
    required this.tricksWon,
    required this.totalScore,
  });

  final String id;
  final String name;
  final int? bid;
  final int tricksWon;
  final int totalScore;

  factory PlayerDto.fromJson(Map<String, dynamic> json) {
    return PlayerDto(
      id: json['id'] as String,
      name: json['name'] as String,
      bid: json['bid'] as int?,
      tricksWon: json['tricksWon'] as int,
      totalScore: json['totalScore'] as int,
    );
  }

  factory PlayerDto.fromPlayer(Player player) {
    return PlayerDto(
      id: player.id,
      name: player.name,
      bid: player.bid,
      tricksWon: player.tricksWon,
      totalScore: player.totalScore,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'bid': bid,
    'tricksWon': tricksWon,
    'totalScore': totalScore,
  };
}

/// DTO for a single play within a trick.
class TrickPlayDto {
  const TrickPlayDto({required this.playerId, required this.card});

  final String playerId;
  final CardDto card;

  factory TrickPlayDto.fromJson(Map<String, dynamic> json) {
    return TrickPlayDto(
      playerId: json['playerId'] as String,
      card: CardDto.fromJson(json['card'] as Map<String, dynamic>),
    );
  }

  factory TrickPlayDto.fromTrickPlay(TrickPlay play) {
    return TrickPlayDto(
      playerId: play.playerId,
      card: CardDto.fromCard(play.card),
    );
  }

  Map<String, dynamic> toJson() => {
    'playerId': playerId,
    'card': card.toJson(),
  };
}

/// DTO for a trick.
class TrickDto {
  const TrickDto({
    required this.plays,
    this.leadSuit,
    this.trumpSuit,
  });

  final List<TrickPlayDto> plays;
  final String? leadSuit;
  final String? trumpSuit;

  factory TrickDto.fromJson(Map<String, dynamic> json) {
    final playsList = (json['plays'] as List<dynamic>)
        .map((e) => TrickPlayDto.fromJson(e as Map<String, dynamic>))
        .toList();
    return TrickDto(
      plays: playsList,
      leadSuit: json['leadSuit'] as String?,
      trumpSuit: json['trumpSuit'] as String?,
    );
  }

  factory TrickDto.fromTrick(Trick trick) {
    return TrickDto(
      plays: trick.plays.map(TrickPlayDto.fromTrickPlay).toList(),
      leadSuit: trick.leadSuit?.name,
      trumpSuit: trick.trumpSuit?.name,
    );
  }

  Map<String, dynamic> toJson() => {
    'plays': plays.map((p) => p.toJson()).toList(),
    'leadSuit': leadSuit,
    'trumpSuit': trumpSuit,
  };
}

/// DTO for the state of a single round.
class RoundStateDto {
  const RoundStateDto({
    required this.roundNumber,
    required this.cardsPerHand,
    this.trumpSuit,
    required this.bids,
    required this.completedTricks,
    this.currentTrick,
  });

  final int roundNumber;
  final int cardsPerHand;
  final String? trumpSuit;
  final Map<String, int> bids;
  final int completedTricks;
  final TrickDto? currentTrick;

  factory RoundStateDto.fromJson(Map<String, dynamic> json) {
    final bidsRaw = json['bids'] as Map<String, dynamic>;
    return RoundStateDto(
      roundNumber: json['roundNumber'] as int,
      cardsPerHand: json['cardsPerHand'] as int,
      trumpSuit: json['trumpSuit'] as String?,
      bids: bidsRaw.map((k, v) => MapEntry(k, v as int)),
      completedTricks: json['completedTricks'] as int,
      currentTrick: json['currentTrick'] != null
          ? TrickDto.fromJson(
              json['currentTrick'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  factory RoundStateDto.fromRoundState(RoundState round) {
    return RoundStateDto(
      roundNumber: round.roundNumber,
      cardsPerHand: round.cardsPerHand,
      trumpSuit: round.trumpSuit?.name,
      bids: Map<String, int>.of(round.bids),
      completedTricks: round.tricks.length,
      currentTrick: TrickDto.fromTrick(round.currentTrick),
    );
  }

  Map<String, dynamic> toJson() => {
    'roundNumber': roundNumber,
    'cardsPerHand': cardsPerHand,
    'trumpSuit': trumpSuit,
    'bids': bids,
    'completedTricks': completedTricks,
    'currentTrick': currentTrick?.toJson(),
  };
}

/// DTO for the complete game state (without player hands).
class GameStateDto {
  const GameStateDto({
    required this.phase,
    required this.players,
    this.currentRound,
    this.winnerId,
  });

  final String phase;
  final List<PlayerDto> players;
  final RoundStateDto? currentRound;
  final String? winnerId;

  factory GameStateDto.fromJson(Map<String, dynamic> json) {
    final playersList = (json['players'] as List<dynamic>)
        .map((e) => PlayerDto.fromJson(e as Map<String, dynamic>))
        .toList();
    return GameStateDto(
      phase: json['phase'] as String,
      players: playersList,
      currentRound: json['currentRound'] != null
          ? RoundStateDto.fromJson(
              json['currentRound'] as Map<String, dynamic>,
            )
          : null,
      winnerId: json['winnerId'] as String?,
    );
  }

  factory GameStateDto.fromGameState(GameState state) {
    final phase = switch (state.phase) {
      Lobby() => 'lobby',
      Dealing() => 'dealing',
      Bidding() => 'bidding',
      Playing() => 'playing',
      RoundEnd() => 'round_end',
      GameEnd() => 'game_end',
    };
    return GameStateDto(
      phase: phase,
      players: state.players.map(PlayerDto.fromPlayer).toList(),
      currentRound: state.currentRound != null
          ? RoundStateDto.fromRoundState(state.currentRound!)
          : null,
      winnerId: state.winnerId,
    );
  }

  Map<String, dynamic> toJson() => {
    'phase': phase,
    'players': players.map((p) => p.toJson()).toList(),
    'currentRound': currentRound?.toJson(),
    'winnerId': winnerId,
  };
}
