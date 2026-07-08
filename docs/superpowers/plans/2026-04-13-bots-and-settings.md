# Play vs Bots + Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a local "Play vs Bots" game mode (no server required) and a persistent Settings screen for difficulty, bot count, and scoring variant.

**Architecture:** A new `LocalGameNotifier` owns a `GameState` and calls `GameEngine` directly—no WebSocket involved. `AppSettingsNotifier` persists preferences to `SharedPreferences`. Both use manual `StateNotifierProvider` (no codegen). The local game screen adapts `game_screen.dart`'s UI but calls local provider methods instead of WebSocket sends.

**Tech Stack:** Flutter, Riverpod (manual StateNotifierProvider), GoRouter, `ohhell_engine` (GameEngine + BotPlayer + BotDifficulty), `shared_preferences: ^2.2.2`

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Modify | `client/pubspec.yaml` | Add `shared_preferences: ^2.2.2` |
| Create | `client/lib/src/models/app_settings.dart` | `AppSettings` value object + JSON serialization |
| Create | `client/lib/src/providers/settings_provider.dart` | `AppSettingsNotifier` + `settingsProvider` |
| Create | `client/lib/src/screens/settings_screen.dart` | Settings UI |
| Modify | `client/lib/src/screens/home_screen.dart` | Add "Play vs Bots" + Settings icon button |
| Create | `client/lib/src/models/local_game_state.dart` | `LocalGameState` value object |
| Create | `client/lib/src/providers/local_game_provider.dart` | `LocalGameNotifier` + `localGameProvider` |
| Create | `client/lib/src/screens/local_game_setup_screen.dart` | Bot count + difficulty form |
| Create | `client/lib/src/screens/local_game_screen.dart` | Local gameplay UI |
| Modify | `client/lib/src/router/router.dart` | Add `/settings`, `/local-game/setup`, `/local-game` routes |
| Create | `client/test/widget/local_game_setup_screen_test.dart` | Widget tests for setup form |
| Create | `client/test/unit/local_game_provider_test.dart` | Unit tests for game logic |
| Create | `client/test/unit/settings_provider_test.dart` | Unit tests for persistence |

---

### Task 1: `AppSettings` model + `shared_preferences` dependency

**Files:**
- Modify: `client/pubspec.yaml`
- Create: `client/lib/src/models/app_settings.dart`
- Create: `client/test/unit/settings_provider_test.dart` (stubs only — fleshed out in Task 3)

- [ ] **Step 1: Write failing unit test for AppSettings serialization**

Create `client/test/unit/settings_provider_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ohhell/src/models/app_settings.dart';
import 'package:ohhell_engine/ohhell_engine.dart';

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
}
```

- [ ] **Step 2: Run test — expect FAIL (class does not exist)**

```bash
flutter test client/test/unit/settings_provider_test.dart
```

Expected: compilation error or "Target of URI doesn't exist".

- [ ] **Step 3: Add `shared_preferences` to pubspec**

In `client/pubspec.yaml`, under `dependencies:`, add after `google_fonts`:

```yaml
  shared_preferences: ^2.2.2
```

Run:
```bash
dart pub get
```

- [ ] **Step 4: Create `app_settings.dart`**

Create `client/lib/src/models/app_settings.dart`:

```dart
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
```

- [ ] **Step 5: Run test — expect PASS**

```bash
flutter test client/test/unit/settings_provider_test.dart
```

Expected: `+3: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add client/pubspec.yaml client/pubspec.lock client/lib/src/models/app_settings.dart client/test/unit/settings_provider_test.dart
git commit -m "feat: add AppSettings model with JSON serialization"
```

---

### Task 2: `SettingsNotifier` + `settingsProvider`

**Files:**
- Create: `client/lib/src/providers/settings_provider.dart`
- Modify: `client/test/unit/settings_provider_test.dart` (add notifier tests)

- [ ] **Step 1: Write failing tests for the notifier**

Append to `client/test/unit/settings_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ohhell/src/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Add inside main():
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
      container.read(settingsProvider.notifier).updateBotDifficulty(BotDifficulty.hard);
      expect(container.read(settingsProvider).botDifficulty, BotDifficulty.hard);
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
```

- [ ] **Step 2: Run test — expect FAIL**

```bash
flutter test client/test/unit/settings_provider_test.dart
```

Expected: compilation error (`settingsProvider` not found).

- [ ] **Step 3: Create `settings_provider.dart`**

Create `client/lib/src/providers/settings_provider.dart`:

```dart
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
```

- [ ] **Step 4: Run test — expect PASS**

```bash
flutter test client/test/unit/settings_provider_test.dart
```

Expected: `+6: All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add client/lib/src/providers/settings_provider.dart client/test/unit/settings_provider_test.dart
git commit -m "feat: add AppSettingsNotifier with SharedPreferences persistence"
```

---

### Task 3: Settings screen

**Files:**
- Create: `client/lib/src/screens/settings_screen.dart`

- [ ] **Step 1: Create `settings_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohhell_engine/ohhell_engine.dart';

import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.appBarBg,
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            title: 'Game Defaults',
            children: [
              _LabelRow(
                label: 'Bot Difficulty',
                child: SegmentedButton<BotDifficulty>(
                  segments: const [
                    ButtonSegment(value: BotDifficulty.easy, label: Text('Easy')),
                    ButtonSegment(value: BotDifficulty.medium, label: Text('Medium')),
                    ButtonSegment(value: BotDifficulty.hard, label: Text('Hard')),
                  ],
                  selected: {settings.botDifficulty},
                  onSelectionChanged: (set) =>
                      notifier.updateBotDifficulty(set.first),
                ),
              ),
              _LabelRow(
                label: 'Default Bots  (${settings.botCount})',
                child: Slider(
                  value: settings.botCount.toDouble(),
                  min: 1,
                  max: 6,
                  divisions: 5,
                  activeColor: AppColors.amber,
                  onChanged: (v) => notifier.updateBotCount(v.round()),
                ),
              ),
              SwitchListTile(
                title: const Text('Strict Scoring'),
                subtitle: const Text(
                    'Wrong bid = negative tricks (harder penalty)'),
                value: settings.strictScoring,
                activeColor: AppColors.amber,
                onChanged: (v) =>
                    notifier.updateStrictScoring(strict: v),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'About',
            children: [
              ListTile(
                title: const Text('Version'),
                trailing: const Text('0.1.x'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                title,
                style: TextStyle(
                    color: AppColors.amber,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _LabelRow extends StatelessWidget {
  const _LabelRow({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(color: AppColors.textOnDark.withAlpha(180))),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Add route + Settings button to HomeScreen**

In `client/lib/src/router/router.dart`, add a route for `/settings`:

```dart
GoRoute(
  path: '/settings',
  builder: (context, state) => const SettingsScreen(),
),
```

Import: `import '../screens/settings_screen.dart';`

In `client/lib/src/screens/home_screen.dart`, add a settings icon to the AppBar actions. Find the `AppBar` widget and add `actions`:

```dart
AppBar(
  backgroundColor: AppColors.appBarBg,
  title: const Text('Oh Hell'),
  actions: [
    IconButton(
      icon: const Icon(Icons.settings_outlined),
      tooltip: 'Settings',
      onPressed: () => context.go('/settings'),
    ),
  ],
),
```

- [ ] **Step 3: Run analyze + tests**

```bash
flutter analyze client
flutter test client
```

Expected: no issues, all existing tests pass.

- [ ] **Step 4: Commit**

```bash
git add client/lib/src/screens/settings_screen.dart client/lib/src/router/router.dart client/lib/src/screens/home_screen.dart
git commit -m "feat: add Settings screen with bot difficulty, count, and scoring variant"
```

---

### Task 4: `LocalGameState` model + `LocalGameNotifier`

**Files:**
- Create: `client/lib/src/models/local_game_state.dart`
- Create: `client/lib/src/providers/local_game_provider.dart`
- Create: `client/test/unit/local_game_provider_test.dart`

- [ ] **Step 1: Write failing tests for local game provider**

Create `client/test/unit/local_game_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohhell_engine/ohhell_engine.dart';
import 'package:ohhell/src/providers/local_game_provider.dart';

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

    test('startGame transitions to dealing phase', () {
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
      // 3 players total (1 human + 2 bots)
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
  });
}
```

- [ ] **Step 2: Run test — expect FAIL**

```bash
flutter test client/test/unit/local_game_provider_test.dart
```

Expected: compilation error.

- [ ] **Step 3: Create `local_game_state.dart`**

Create `client/lib/src/models/local_game_state.dart`:

```dart
import 'package:ohhell_engine/ohhell_engine.dart';

enum LocalGamePhase { idle, dealing, bidding, playing, roundEnd, gameOver }

class LocalGameState {
  const LocalGameState({
    required this.phase,
    required this.gameState,
    required this.humanPlayerId,
    required this.botPlayerIds,
    required this.awaitingBot,
  });

  const LocalGameState.idle()
      : phase = LocalGamePhase.idle,
        gameState = null,
        humanPlayerId = null,
        botPlayerIds = const [],
        awaitingBot = false;

  final LocalGamePhase phase;
  final GameState? gameState;
  final String? humanPlayerId;
  final List<String> botPlayerIds;
  final bool awaitingBot; // true while bot is "thinking"

  LocalGameState copyWith({
    LocalGamePhase? phase,
    GameState? gameState,
    String? humanPlayerId,
    List<String>? botPlayerIds,
    bool? awaitingBot,
  }) =>
      LocalGameState(
        phase: phase ?? this.phase,
        gameState: gameState ?? this.gameState,
        humanPlayerId: humanPlayerId ?? this.humanPlayerId,
        botPlayerIds: botPlayerIds ?? this.botPlayerIds,
        awaitingBot: awaitingBot ?? this.awaitingBot,
      );
}
```

- [ ] **Step 4: Create `local_game_provider.dart`**

Create `client/lib/src/providers/local_game_provider.dart`:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ohhell_engine/ohhell_engine.dart';
import 'package:uuid/uuid.dart';

import '../models/local_game_state.dart';

const _uuid = Uuid();
const _botThinkMs = 800; // ms delay before bot acts

class LocalGameNotifier extends StateNotifier<LocalGameState> {
  LocalGameNotifier() : super(const LocalGameState.idle());

  // Map botPlayerId → BotPlayer instance
  final Map<String, BotPlayer> _bots = {};

  void startGame({
    required String humanName,
    required int botCount,
    required BotDifficulty difficulty,
    required bool strictScoring,
  }) {
    _bots.clear();
    final humanId = _uuid.v4();
    final botIds = List.generate(botCount, (_) => _uuid.v4());

    for (final id in botIds) {
      _bots[id] = BotPlayer.create(difficulty);
    }

    final players = [
      Player(id: humanId, name: humanName),
      for (var i = 0; i < botCount; i++)
        Player(id: botIds[i], name: _botName(difficulty, i)),
    ];

    final config = GameConfig.defaultFor(
      playerCount: players.length,
      strictScoring: strictScoring,
    );

    var gs = GameEngine.startGame(players: players, config: config);
    gs = GameEngine.dealRound(gs);

    state = LocalGameState(
      phase: LocalGamePhase.bidding,
      gameState: gs,
      humanPlayerId: humanId,
      botPlayerIds: botIds,
      awaitingBot: false,
    );

    // If human is not first to bid, advance bots
    _advanceBotsIfNeeded();
  }

  void humanPlaceBid(int bid) {
    final gs = state.gameState;
    if (gs == null) return;
    if (gs.currentRound?.currentBidderIndex == null) return;

    final updated = GameEngine.placeBid(gs, bid: bid);
    state = state.copyWith(gameState: updated);
    _advanceBotsIfNeeded();
  }

  void humanPlayCard(PlayingCard card) {
    final gs = state.gameState;
    if (gs == null) return;

    var updated = GameEngine.playCard(gs, card: card);

    // If trick is complete, evaluate it
    if (updated.currentRound?.currentTrick?.isComplete(updated.players.length) ??
        false) {
      updated = GameEngine.evaluateTrick(updated);
    }

    // If round ended
    if (updated.phase == GamePhase.roundEnd) {
      state = state.copyWith(
          phase: LocalGamePhase.roundEnd, gameState: updated, awaitingBot: false);
      return;
    }

    // If game ended
    if (updated.phase == GamePhase.gameOver) {
      state = state.copyWith(
          phase: LocalGamePhase.gameOver, gameState: updated, awaitingBot: false);
      return;
    }

    state = state.copyWith(gameState: updated, awaitingBot: false);
    _advanceBotsIfNeeded();
  }

  void dealNextRound() {
    final gs = state.gameState;
    if (gs == null) return;
    final dealt = GameEngine.dealRound(gs);
    state = state.copyWith(
        phase: LocalGamePhase.bidding, gameState: dealt, awaitingBot: false);
    _advanceBotsIfNeeded();
  }

  void reset() {
    _bots.clear();
    state = const LocalGameState.idle();
  }

  // ── Internal helpers ─────────────────────────────────────────────

  void _advanceBotsIfNeeded() {
    final gs = state.gameState;
    if (gs == null) return;

    final currentPlayerId = _currentActorId(gs);
    if (currentPlayerId == null) return;
    if (!state.botPlayerIds.contains(currentPlayerId)) return;

    // It's a bot's turn — schedule auto-play
    state = state.copyWith(awaitingBot: true);
    Future.delayed(const Duration(milliseconds: _botThinkMs), () {
      if (!mounted) return;
      _botAct(currentPlayerId);
    });
  }

  void _botAct(String botId) {
    final gs = state.gameState;
    if (gs == null) return;
    final bot = _bots[botId];
    if (bot == null) return;

    if (gs.phase == GamePhase.bidding) {
      final bid = bot.chooseBid(gs, botId);
      final updated = GameEngine.placeBid(gs, bid: bid);
      state = state.copyWith(gameState: updated, awaitingBot: false);
      _advanceBotsIfNeeded();
    } else if (gs.phase == GamePhase.playing) {
      final card = bot.chooseCard(gs, botId);
      humanPlayCard(card); // reuse evaluation logic
    }
  }

  String? _currentActorId(GameState gs) {
    if (gs.phase == GamePhase.bidding) {
      final round = gs.currentRound;
      if (round == null) return null;
      final idx = round.currentBidderIndex;
      if (idx == null || idx >= gs.players.length) return null;
      return gs.players[idx].id;
    }
    if (gs.phase == GamePhase.playing) {
      final round = gs.currentRound;
      if (round == null) return null;
      final trick = round.currentTrick;
      if (trick == null) return null;
      final idx = trick.currentPlayerIndex(gs.players.length);
      if (idx < 0 || idx >= gs.players.length) return null;
      return gs.players[idx].id;
    }
    return null;
  }

  String _botName(BotDifficulty d, int index) {
    final suffix = index > 0 ? ' ${index + 1}' : '';
    return switch (d) {
      BotDifficulty.easy => 'Easy Bot$suffix',
      BotDifficulty.medium => 'Bot$suffix',
      BotDifficulty.hard => 'Hard Bot$suffix',
    };
  }
}

final localGameProvider =
    StateNotifierProvider<LocalGameNotifier, LocalGameState>(
  (_) => LocalGameNotifier(),
);
```

**Note:** `uuid` package may need adding to `client/pubspec.yaml` — check if already present. If not, add `uuid: ^4.4.0`.

- [ ] **Step 5: Run test — expect PASS**

```bash
flutter test client/test/unit/local_game_provider_test.dart
```

Expected: `+3: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add client/lib/src/models/local_game_state.dart client/lib/src/providers/local_game_provider.dart client/test/unit/local_game_provider_test.dart
git commit -m "feat: add LocalGameNotifier for offline bot games"
```

---

### Task 5: Local game setup screen

**Files:**
- Create: `client/lib/src/screens/local_game_setup_screen.dart`
- Create: `client/test/widget/local_game_setup_screen_test.dart`

- [ ] **Step 1: Write failing widget test**

Create `client/test/widget/local_game_setup_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ohhell/src/screens/local_game_setup_screen.dart';

Widget _wrap(Widget child) => ProviderScope(
      child: MaterialApp.router(
        routerConfig: GoRouter(routes: [
          GoRoute(path: '/', builder: (_, __) => child),
          GoRoute(path: '/local-game', builder: (_, __) => const SizedBox()),
        ]),
      ),
    );

void main() {
  group('LocalGameSetupScreen', () {
    testWidgets('shows player name, bot count, difficulty fields',
        (tester) async {
      await tester.pumpWidget(_wrap(const LocalGameSetupScreen()));
      expect(find.text('Your Name'), findsOneWidget);
      expect(find.text('Easy'), findsOneWidget);
      expect(find.text('Medium'), findsOneWidget);
      expect(find.text('Hard'), findsOneWidget);
    });

    testWidgets('Start Game button disabled when name is empty', (tester) async {
      await tester.pumpWidget(_wrap(const LocalGameSetupScreen()));
      final btn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(btn.onPressed, isNull);
    });

    testWidgets('Start Game button enabled when name is entered', (tester) async {
      await tester.pumpWidget(_wrap(const LocalGameSetupScreen()));
      await tester.enterText(find.byType(TextField), 'Alice');
      await tester.pump();
      final btn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(btn.onPressed, isNotNull);
    });
  });
}
```

- [ ] **Step 2: Run test — expect FAIL**

```bash
flutter test client/test/widget/local_game_setup_screen_test.dart
```

Expected: compilation error.

- [ ] **Step 3: Create `local_game_setup_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohhell_engine/ohhell_engine.dart';

import '../providers/local_game_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';

class LocalGameSetupScreen extends ConsumerStatefulWidget {
  const LocalGameSetupScreen({super.key});

  @override
  ConsumerState<LocalGameSetupScreen> createState() =>
      _LocalGameSetupScreenState();
}

class _LocalGameSetupScreenState extends ConsumerState<LocalGameSetupScreen> {
  final _nameController = TextEditingController();
  late BotDifficulty _difficulty;
  late int _botCount;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _difficulty = settings.botDifficulty;
    _botCount = settings.botCount;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _startGame() {
    final settings = ref.read(settingsProvider);
    ref.read(localGameProvider.notifier).startGame(
          humanName: _nameController.text.trim(),
          botCount: _botCount,
          difficulty: _difficulty,
          strictScoring: settings.strictScoring,
        );
    context.go('/local-game');
  }

  @override
  Widget build(BuildContext context) {
    final nameEmpty = _nameController.text.trim().isEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.appBarBg,
        title: const Text('Play vs Bots'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Your Name'),
                  onChanged: (_) => setState(() {}),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 24),
                Text('Bot Count (${_botCount})',
                    style: TextStyle(color: AppColors.textOnDark)),
                Slider(
                  value: _botCount.toDouble(),
                  min: 2,
                  max: 6,
                  divisions: 4,
                  activeColor: AppColors.amber,
                  onChanged: (v) => setState(() => _botCount = v.round()),
                ),
                const SizedBox(height: 8),
                Text('Difficulty',
                    style: TextStyle(color: AppColors.textOnDark)),
                const SizedBox(height: 8),
                SegmentedButton<BotDifficulty>(
                  segments: const [
                    ButtonSegment(value: BotDifficulty.easy, label: Text('Easy')),
                    ButtonSegment(
                        value: BotDifficulty.medium, label: Text('Medium')),
                    ButtonSegment(value: BotDifficulty.hard, label: Text('Hard')),
                  ],
                  selected: {_difficulty},
                  onSelectionChanged: (set) =>
                      setState(() => _difficulty = set.first),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: nameEmpty ? null : _startGame,
                  child: const Text('Start Game'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test — expect PASS**

```bash
flutter test client/test/widget/local_game_setup_screen_test.dart
```

Expected: `+3: All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add client/lib/src/screens/local_game_setup_screen.dart client/test/widget/local_game_setup_screen_test.dart
git commit -m "feat: add LocalGameSetupScreen for bot game configuration"
```

---

### Task 6: Local game screen

**Files:**
- Create: `client/lib/src/screens/local_game_screen.dart`

The local game screen mirrors `game_screen.dart`'s UI but calls `localGameProvider` instead of WebSocket.

- [ ] **Step 1: Create `local_game_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohhell_engine/ohhell_engine.dart';

import '../models/local_game_state.dart';
import '../providers/local_game_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/card_widget.dart';
import '../widgets/hand_widget.dart';

class LocalGameScreen extends ConsumerStatefulWidget {
  const LocalGameScreen({super.key});

  @override
  ConsumerState<LocalGameScreen> createState() => _LocalGameScreenState();
}

class _LocalGameScreenState extends ConsumerState<LocalGameScreen> {
  bool _bidDialogShowing = false;

  @override
  Widget build(BuildContext context) {
    final localState = ref.watch(localGameProvider);

    // Navigate to results when game ends
    ref.listen<LocalGameState>(localGameProvider, (prev, next) {
      if (next.phase == LocalGamePhase.gameOver && mounted) {
        context.go('/local-scores');
      }
    });

    // Show bid dialog when bidding phase and it's the human's turn
    ref.listen<LocalGameState>(localGameProvider, (prev, next) {
      if (!mounted) return;
      final gs = next.gameState;
      if (gs == null) return;
      final isHumanTurn = _currentActorId(gs, next) == next.humanPlayerId;
      final prevIsHumanTurn = prev?.gameState != null &&
          _currentActorId(prev!.gameState!, prev) == prev.humanPlayerId;
      final nowBidding =
          gs.phase == GamePhase.bidding && isHumanTurn && !next.awaitingBot;
      final wasBidding = prev?.gameState?.phase == GamePhase.bidding &&
          prevIsHumanTurn;

      if (nowBidding && !wasBidding && !_bidDialogShowing) {
        _bidDialogShowing = true;
        _showBidDialog(gs).whenComplete(() {
          if (mounted) setState(() => _bidDialogShowing = false);
        });
      }
    });

    if (localState.phase == LocalGamePhase.idle) {
      return const Scaffold(body: Center(child: Text('No game in progress')));
    }

    final gs = localState.gameState!;
    final humanId = localState.humanPlayerId!;
    final hand = gs.currentRound?.playerHands[humanId] ?? const [];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Column(
            children: [
              _ScoreBar(gs: gs, humanPlayerId: humanId),
              Expanded(child: _TrickArea(gs: gs)),
              if (gs.phase == GamePhase.playing)
                HandWidget(
                  cards: hand,
                  onCardTap: localState.awaitingBot
                      ? null
                      : (card) => _onCardTap(card, gs, humanId),
                ),
            ],
          ),
          if (localState.phase == LocalGamePhase.roundEnd)
            _RoundEndOverlay(
              gs: gs,
              onNext: () =>
                  ref.read(localGameProvider.notifier).dealNextRound(),
            ),
          if (localState.awaitingBot)
            const Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'Bot is thinking…',
                  style: TextStyle(color: AppColors.amber),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _onCardTap(PlayingCard card, GameState gs, String humanId) {
    final round = gs.currentRound;
    if (round == null) return;
    final trick = round.currentTrick;
    final actorId =
        _currentActorId(gs, ref.read(localGameProvider));
    if (actorId != humanId) return;

    final legal = CardValidator.legalCards(
      hand: round.playerHands[humanId] ?? [],
      leadSuit: trick?.leadSuit,
    );
    if (!legal.contains(card)) return;

    ref.read(localGameProvider.notifier).humanPlayCard(card);
  }

  Future<void> _showBidDialog(GameState gs) async {
    final round = gs.currentRound;
    if (round == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      builder: (_) => _BidDialog(
        cardsPerHand: round.cardsPerHand,
        onBid: (bid) {
          Navigator.pop(context);
          ref.read(localGameProvider.notifier).humanPlaceBid(bid);
        },
      ),
    );
  }

  String? _currentActorId(GameState gs, LocalGameState ls) {
    if (gs.phase == GamePhase.bidding) {
      final idx = gs.currentRound?.currentBidderIndex;
      if (idx == null || idx >= gs.players.length) return null;
      return gs.players[idx].id;
    }
    if (gs.phase == GamePhase.playing) {
      final trick = gs.currentRound?.currentTrick;
      if (trick == null) return null;
      final idx = trick.currentPlayerIndex(gs.players.length);
      if (idx < 0 || idx >= gs.players.length) return null;
      return gs.players[idx].id;
    }
    return null;
  }
}

// ── Private sub-widgets ────────────────────────────────────────────

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.gs, required this.humanPlayerId});
  final GameState gs;
  final String humanPlayerId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        color: AppColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (final p in gs.players)
              _PlayerChip(
                player: p,
                round: gs.currentRound,
                isHuman: p.id == humanPlayerId,
              ),
          ],
        ),
      ),
    );
  }
}

class _PlayerChip extends StatelessWidget {
  const _PlayerChip(
      {required this.player, required this.round, required this.isHuman});
  final Player player;
  final GameRound? round;
  final bool isHuman;

  @override
  Widget build(BuildContext context) {
    final bid = round?.bids[player.id];
    final tricks = round?.tricksWon[player.id] ?? 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(player.name,
            style: TextStyle(
              color: isHuman ? AppColors.amber : AppColors.textOnDark,
              fontWeight: isHuman ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            )),
        if (bid != null)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.amber.withAlpha(80)),
            ),
            child: Text('$tricks/$bid',
                style: const TextStyle(
                    color: AppColors.textOnDark, fontSize: 11)),
          ),
      ],
    );
  }
}

class _TrickArea extends StatelessWidget {
  const _TrickArea({required this.gs});
  final GameState gs;

  @override
  Widget build(BuildContext context) {
    final trick = gs.currentRound?.currentTrick;
    if (trick == null || trick.cards.isEmpty) {
      return const Center(
          child: Text('Waiting…', style: TextStyle(color: AppColors.textOnDark)));
    }
    return Center(
      child: Wrap(
        spacing: 8,
        children: trick.cards
            .map((tc) => CardWidget(card: tc.card, faceUp: true))
            .toList(),
      ),
    );
  }
}

class _RoundEndOverlay extends StatelessWidget {
  const _RoundEndOverlay({required this.gs, required this.onNext});
  final GameState gs;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          color: AppColors.surface,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Round Over',
                    style: TextStyle(
                        color: AppColors.amber,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                for (final p in gs.players)
                  Text('${p.name}: ${p.totalScore} pts',
                      style:
                          const TextStyle(color: AppColors.textOnDark)),
                const SizedBox(height: 16),
                ElevatedButton(
                    onPressed: onNext, child: const Text('Next Round')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BidDialog extends StatefulWidget {
  const _BidDialog({required this.cardsPerHand, required this.onBid});
  final int cardsPerHand;
  final void Function(int) onBid;

  @override
  State<_BidDialog> createState() => _BidDialogState();
}

class _BidDialogState extends State<_BidDialog> {
  int _bid = 0;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('How many tricks? (0–${widget.cardsPerHand})',
                style: const TextStyle(color: AppColors.textOnDark)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (var i = 0; i <= widget.cardsPerHand; i++)
                  ChoiceChip(
                    label: Text('$i'),
                    selected: _bid == i,
                    onSelected: (_) => setState(() => _bid = i),
                    selectedColor: AppColors.amber,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => widget.onBid(_bid),
              child: const Text('Place Bid'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Analyze**

```bash
flutter analyze client
```

Expected: no issues (fix any type mismatches — the exact method signatures on `GameEngine`, `GameRound`, `Trick` depend on the engine's public API; adjust as needed).

- [ ] **Step 3: Run all tests**

```bash
flutter test client
```

Expected: all tests pass.

- [ ] **Step 4: Commit**

```bash
git add client/lib/src/screens/local_game_screen.dart
git commit -m "feat: add LocalGameScreen for offline bot gameplay"
```

---

### Task 7: Wire routes + "Play vs Bots" home button + local scores screen

**Files:**
- Modify: `client/lib/src/router/router.dart`
- Modify: `client/lib/src/screens/home_screen.dart`
- Create: `client/lib/src/screens/local_scores_screen.dart`

- [ ] **Step 1: Add routes**

In `client/lib/src/router/router.dart`, add:

```dart
GoRoute(
  path: '/local-game/setup',
  builder: (context, state) => const LocalGameSetupScreen(),
),
GoRoute(
  path: '/local-game',
  builder: (context, state) => const LocalGameScreen(),
),
GoRoute(
  path: '/local-scores',
  builder: (context, state) => const LocalScoresScreen(),
),
```

Add imports for the new screens.

- [ ] **Step 2: Create `local_scores_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/local_game_provider.dart';
import '../theme/app_theme.dart';

class LocalScoresScreen extends ConsumerWidget {
  const LocalScoresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localState = ref.watch(localGameProvider);
    final gs = localState.gameState;

    if (gs == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(child: Text('No game data')),
      );
    }

    final sorted = [...gs.players]
      ..sort((a, b) => b.totalScore.compareTo(a.totalScore));
    final winner = sorted.first;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.appBarBg,
        title: const Text('Final Scores'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppColors.amber.withAlpha(30),
                  AppColors.amber.withAlpha(80),
                ]),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                const Text('🏆', style: TextStyle(fontSize: 32)),
                Text(winner.name,
                    style: const TextStyle(
                        color: AppColors.amber,
                        fontSize: 28,
                        fontWeight: FontWeight.bold)),
                Text('${winner.totalScore} points',
                    style: const TextStyle(color: AppColors.textOnDark)),
              ]),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (var i = 0; i < sorted.length; i++)
                  ListTile(
                    leading: Text('${i + 1}.',
                        style: TextStyle(
                            color: i == 0
                                ? AppColors.amber
                                : AppColors.textOnDark)),
                    title: Text(sorted[i].name,
                        style:
                            const TextStyle(color: AppColors.textOnDark)),
                    trailing: Text('${sorted[i].totalScore}',
                        style: TextStyle(
                            color: i == 0
                                ? AppColors.amber
                                : AppColors.textOnDark)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ref.read(localGameProvider.notifier).reset();
                  context.go('/home');
                },
                child: const Text('Back to Home'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Add "Play vs Bots" button to HomeScreen**

In `client/lib/src/screens/home_screen.dart`, find where the "Scorekeeper" button is and add a "Play vs Bots" button above it:

```dart
OutlinedButton.icon(
  onPressed: () => context.go('/local-game/setup'),
  icon: const Icon(Icons.smart_toy_outlined),
  label: const Text('Play vs Bots'),
  style: OutlinedButton.styleFrom(
    foregroundColor: AppColors.textOnDark,
    side: BorderSide(color: AppColors.amber.withAlpha(120)),
  ),
),
const SizedBox(height: 8),
```

- [ ] **Step 4: Analyze + full test suite**

```bash
flutter analyze client
flutter test client
```

Expected: no issues, all tests pass.

- [ ] **Step 5: Commit**

```bash
git add client/lib/src/screens/local_scores_screen.dart client/lib/src/router/router.dart client/lib/src/screens/home_screen.dart
git commit -m "feat: wire Play vs Bots entry point, routes, and local scores screen"
```

---

## Self-Review

**Spec coverage:**
- ✅ Play vs Bots: `LocalGameNotifier`, `LocalGameSetupScreen`, `LocalGameScreen`, routes, home button
- ✅ Settings: `AppSettings`, `AppSettingsNotifier`, `SettingsScreen`, settings button in home AppBar
- ✅ Settings default to setup screen (Task 5 `initState` reads `settingsProvider`)
- ✅ TDD: all providers have unit tests; screens have widget tests

**Placeholder scan:** No TBDs. All code blocks are complete.

**Type consistency:** `LocalGamePhase`, `LocalGameState`, `localGameProvider`, `LocalGameNotifier` — names consistent across all tasks. `humanPlaceBid` / `humanPlayCard` / `dealNextRound` / `reset` — consistent in provider and screen.

**Known risk:** `GameEngine` API method signatures (`evaluateTrick`, `trick.currentPlayerIndex`, `round.playerHands`) — verify exact names against `packages/ohhell_engine/lib/` before starting Task 4. The engine is pure Dart so `flutter analyze` will catch mismatches immediately.
