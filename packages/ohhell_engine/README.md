# ohhell_engine

Pure Dart game logic for Oh Hell — no Flutter, no network dependencies. Used by both the server and (optionally) the client for local bots.

## Features

- Immutable `GameState` with sealed `GamePhase` hierarchy
- Full Oh Hell rules: follow-suit enforcement, trump suit, trick evaluation
- Standard and strict scoring variants
- Bot players: `RandomBot` and `HeuristicBot`
- 67 unit tests

## Usage

```dart
import 'package:ohhell_engine/ohhell_engine.dart';

// Configure a 4-player game
final config = GameConfig.defaultFor(playerCount: 4);
final players = [
  Player(id: 'p1', name: 'Alice'),
  Player(id: 'p2', name: 'Bob'),
  Player(id: 'p3', name: 'Charlie'),
  Player(id: 'p4', name: 'Diana'),
];

// Start → deal → bid → play
var state = GameEngine.startGame(players: players, config: config);
state = GameEngine.dealRound(state);

// Each player bids
for (final player in state.players) {
  state = GameEngine.placeBid(state, playerId: player.id, bid: 1);
}

// Play cards
final legal = CardValidator.legalCards(state, playerId: 'p1');
state = GameEngine.playCard(state, playerId: 'p1', card: legal.first);
// ...after all players play:
state = GameEngine.evaluateTrick(state);
```

## Game phases

```
Lobby → Dealing → Bidding → Playing ⟲ → RoundEnd → GameEnd
```

All phase transitions are validated — `IllegalMoveException` is thrown for out-of-turn or invalid actions.

## Scoring

| Variant | Exact bid | Over/under |
|---------|-----------|------------|
| `standard` | +10 + bid | +tricksWon |
| `strict` | +10 + bid | -tricksWon |

```dart
final config = GameConfig.defaultFor(
  playerCount: 4,
  scoringVariant: ScoringVariant.strict,
);
```

## Bots

```dart
final bot = HeuristicBot();
final bid = bot.chooseBid(state, playerId: 'bot1');
final card = bot.chooseCard(state, playerId: 'bot1');
```

## Running tests

```bash
dart test packages/ohhell_engine
```
