import 'package:ohhell_engine/ohhell_engine.dart';

class AppSettings {
  const AppSettings({
    required this.botDifficulty,
    required this.botCount,
    required this.strictScoring,
  });

  factory AppSettings.defaults() => const AppSettings(
        botDifficulty: BotDifficulty.medium,
        botCount: 2,
        strictScoring: false,
      );

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        botDifficulty: BotDifficulty.values.firstWhere(
          (d) => d.name == (json['botDifficulty'] as String),
          orElse: () => BotDifficulty.medium,
        ),
        botCount: (json['botCount'] as int?) ?? 2,
        strictScoring: (json['strictScoring'] as bool?) ?? false,
      );

  final BotDifficulty botDifficulty;
  final int botCount;
  final bool strictScoring;

  Map<String, dynamic> toJson() => {
        'botDifficulty': botDifficulty.name,
        'botCount': botCount,
        'strictScoring': strictScoring,
      };

  AppSettings copyWith({
    BotDifficulty? botDifficulty,
    int? botCount,
    bool? strictScoring,
  }) =>
      AppSettings(
        botDifficulty: botDifficulty ?? this.botDifficulty,
        botCount: botCount ?? this.botCount,
        strictScoring: strictScoring ?? this.strictScoring,
      );
}
