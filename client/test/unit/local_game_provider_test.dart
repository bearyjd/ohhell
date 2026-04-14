import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohhell_engine/ohhell_engine.dart';
import 'package:ohhell_client/src/providers/local_game_provider.dart';
import 'package:ohhell_client/src/models/local_game_state.dart';

void main() {
  group('LocalGameNotifier', () {
    ProviderContainer makeContainer() {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      return c;
    }

    test('initial state is idle', () {
      final c = makeContainer();
      final s = c.read(localGameProvider);
      expect(s.phase, LocalGamePhase.idle);
      expect(s.gameState, isNull);
    });

    test('startGame transitions to bidding phase', () {
      final c = makeContainer();
      c.read(localGameProvider.notifier).startGame(
            humanName: 'Alice',
            botCount: 2,
            difficulty: BotDifficulty.easy,
            strictScoring: false,
          );
      final s = c.read(localGameProvider);
      expect(s.phase, isNot(LocalGamePhase.idle));
      expect(s.gameState, isNotNull);
      expect(s.gameState!.players.length, 3);
    });

    test('humanIndex identifies human player', () {
      final c = makeContainer();
      c.read(localGameProvider.notifier).startGame(
            humanName: 'Bob',
            botCount: 3,
            difficulty: BotDifficulty.medium,
            strictScoring: false,
          );
      final s = c.read(localGameProvider);
      final humanId = s.humanPlayerId;
      expect(humanId, isNotNull);
      final human = s.gameState!.players.firstWhere((p) => p.id == humanId);
      expect(human.name, 'Bob');
    });

    test('reset returns to idle', () {
      final c = makeContainer();
      c.read(localGameProvider.notifier).startGame(
            humanName: 'Alice',
            botCount: 2,
            difficulty: BotDifficulty.easy,
            strictScoring: false,
          );
      c.read(localGameProvider.notifier).reset();
      final s = c.read(localGameProvider);
      expect(s.phase, LocalGamePhase.idle);
      expect(s.gameState, isNull);
    });

    test('strictScoring sets strict scoring variant', () {
      final c = makeContainer();
      c.read(localGameProvider.notifier).startGame(
            humanName: 'Alice',
            botCount: 2,
            difficulty: BotDifficulty.easy,
            strictScoring: true,
          );
      final s = c.read(localGameProvider);
      expect(
        s.gameState!.config.scoringVariant,
        ScoringVariant.strict,
      );
    });

    test('botPlayerIds length matches botCount', () {
      final c = makeContainer();
      c.read(localGameProvider.notifier).startGame(
            humanName: 'Alice',
            botCount: 3,
            difficulty: BotDifficulty.hard,
            strictScoring: false,
          );
      final s = c.read(localGameProvider);
      expect(s.botPlayerIds.length, 3);
    });
  });
}
