import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ohhell_engine/ohhell_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

const _kSettingsKey = 'app_settings';

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  AppSettingsNotifier() : super(AppSettings.defaults()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSettingsKey);
    if (raw != null) {
      try {
        state = AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // Corrupted prefs — fall back to defaults
      }
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSettingsKey, jsonEncode(state.toJson()));
  }

  void updateBotDifficulty(BotDifficulty difficulty) {
    state = state.copyWith(botDifficulty: difficulty);
    _persist();
  }

  void updateBotCount(int count) {
    state = state.copyWith(botCount: count.clamp(1, 6));
    _persist();
  }

  void updateStrictScoring({required bool strict}) {
    state = state.copyWith(strictScoring: strict);
    _persist();
  }
}

final settingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>(
  (_) => AppSettingsNotifier(),
);
