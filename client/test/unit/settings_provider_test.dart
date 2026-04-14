import 'package:flutter_test/flutter_test.dart';
import 'package:ohhell_client/src/models/app_settings.dart';
import 'package:ohhell_engine/ohhell_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ohhell_client/src/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AppSettings', () {
    test('defaults are sane', () {
      final s = AppSettings.defaults();
      expect(s.botDifficulty, BotDifficulty.medium);
      expect(s.botCount, 2);
      expect(s.strictScoring, isFalse);
    });

    test('round-trips through JSON', () {
      final s = AppSettings(
        botDifficulty: BotDifficulty.hard,
        botCount: 4,
        strictScoring: true,
      );
      final json = s.toJson();
      final restored = AppSettings.fromJson(json);
      expect(restored.botDifficulty, BotDifficulty.hard);
      expect(restored.botCount, 4);
      expect(restored.strictScoring, isTrue);
    });

    test('copyWith changes only specified fields', () {
      final s = AppSettings.defaults();
      final updated = s.copyWith(botCount: 5);
      expect(updated.botCount, 5);
      expect(updated.botDifficulty, s.botDifficulty);
    });
  });

  group('AppSettingsNotifier', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loads defaults when no stored value', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final settings = container.read(settingsProvider);
      expect(settings.botDifficulty, BotDifficulty.medium);
      expect(settings.botCount, 2);
    });

    test('updateBotDifficulty changes state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(settingsProvider.notifier)
          .updateBotDifficulty(BotDifficulty.hard);
      expect(
        container.read(settingsProvider).botDifficulty,
        BotDifficulty.hard,
      );
    });

    test('updateBotCount clamps to 1–6', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(settingsProvider.notifier).updateBotCount(10);
      expect(container.read(settingsProvider).botCount, 6);
      container.read(settingsProvider.notifier).updateBotCount(0);
      expect(container.read(settingsProvider).botCount, 1);
    });
  });
}
