import 'package:ohhell_engine/ohhell_engine.dart';

void main() {
  const engine = GameEngine();
  final players = [
    const Player(id: 'p1', name: 'Alice'),
    const Player(id: 'p2', name: 'Bob'),
    const Player(id: 'p3', name: 'Charlie'),
  ];
  final config = GameConfig.defaultFor(3);
  final state = engine.startGame(players, config);
  print('Game started with ${state.players.length} players');
  print('Round schedule: ${config.roundSchedule}');
}
