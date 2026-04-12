# Blueprint: Oh Hell — Multiplayer Card Game

**Objective:** Build a full-featured multiplayer "Oh Hell" card game with Flutter clients (Android, iOS, Windows, Linux, Web) and a Dart WebSocket game server deployable in Docker.

**Created:** 2026-04-11  
**Status:** READY  
**Total Steps:** 10  
**Parallelism:** Steps 3a/3b run in parallel; Steps 6/7 run in parallel  

---

## Architecture Overview

```
ohhell/                          ← git root
├── packages/
│   └── ohhell_engine/           ← Pure Dart game-logic library (no UI, no network)
├── client/                      ← Flutter app (Android, iOS, Windows, Linux, Web)
├── server/                      ← Dart shelf WebSocket game server
├── docker/                      ← Dockerfiles + nginx config
│   ├── Dockerfile.server
│   ├── Dockerfile.client
│   └── nginx.conf
├── docker-compose.yml
├── .github/workflows/
│   ├── ci.yml
│   └── release.yml
└── plans/                       ← this file lives here
```

**Tech Stack:**
- **Client:** Flutter 3.x (Dart) — single codebase for all 5 targets
- **State management:** Riverpod
- **Server:** Dart `shelf` + `shelf_web_socket` — WebSocket game server
- **Protocol:** JSON over WebSocket (defined in Step 2)
- **Web delivery:** Flutter web compiled to static files, served by nginx
- **Container:** Docker Compose — `server` container + `client` (nginx) container
- **CI/CD:** GitHub Actions

**Oh Hell Rules Summary:**
- 3–7 players; standard 52-card deck
- Rounds: deal N cards (N starts at max, increments/decrements per variant)
- Trump suit: flip top card after deal
- Bidding: each player bids tricks they'll win; total bids need NOT equal cards dealt
- Trick-taking: must follow suit if possible; trump beats non-trump
- Scoring: +10 + bid if exact; +1 per trick taken otherwise (variant: penalty if wrong)
- Game ends after all rounds; highest score wins

---

## Dependency Graph

```
Step 1 (scaffold)
  └─→ Step 2 (engine)
        ├─→ Step 3a (server)      ─┐
        └─→ Step 3b* (client UI)  ─┤ both feed Step 4
  └─→ Step 3b* (parallel with 3a)─┘
Step 4 (integration) → Step 5 (gameplay screens)
  ├─→ Step 6 (Android/iOS)    ─┐
  ├─→ Step 7 (Windows/Linux)  ─┤ parallel
  └─→ Step 8 (Web+Docker)     ─┘
Step 6 + Step 7 + Step 8 → Step 9 (testing)
Step 9 → Step 10 (CI/CD release)
```

*Step 3b depends only on Step 1; it can start in parallel with Step 3a once Step 1 is done.

---

## Step 1 — Repository, GitHub, and Monorepo Scaffold

**Model tier:** default (sonnet)  
**Depends on:** nothing  
**Parallel with:** nothing  

### Context Brief

Fresh directory at `/var/home/user/Documents/vibe-code/games/ohhell`. Git and GitHub CLI available. User authenticated as `bearyjd`. This step creates the entire repository skeleton so all subsequent steps have a stable foundation to build on.

### Tasks

1. Init git repo: `git init && git checkout -b main`
2. Create GitHub repo: `gh repo create ohhell --public --description "Multiplayer Oh Hell card game — Flutter + Dart"`
3. Create Flutter project in `client/`: `flutter create --project-name ohhell_client --platforms android,ios,windows,linux,web client`
4. Create Dart package stubs:
   - `dart create -t package packages/ohhell_engine`
   - `dart create -t server-shelf server`
5. Write root `pubspec.yaml` (workspace / melos config) — or use melos for monorepo management
6. Create `.github/workflows/ci.yml` skeleton (placeholder, expanded in Step 10)
7. Write root `README.md` with architecture diagram and setup instructions
8. Write `.gitignore` covering Flutter, Dart, build artifacts, Docker, IDE files
9. Write `melos.yaml` defining the three packages (`ohhell_engine`, `client`, `server`)
10. Initial commit and push: `git add . && git commit -m "chore: scaffold monorepo" && git push -u origin main`

### Verification

```bash
flutter doctor -v              # Flutter toolchain healthy
dart --version                 # Dart SDK available
gh repo view ohhell            # GitHub repo exists
cd client && flutter pub get   # Dependencies resolve
cd server && dart pub get
cd packages/ohhell_engine && dart pub get
```

### Exit Criteria

- GitHub repo exists at `github.com/bearyjd/ohhell`
- `flutter pub get` and `dart pub get` succeed in all three packages
- `flutter run -d <any>` compiles without error (empty app is fine)
- CI skeleton workflow visible on GitHub

### Rollback

Delete the GitHub repo (`gh repo delete ohhell --yes`) and `rm -rf .git` to reset.

---

## Step 2 — Oh Hell Engine Package

**Model tier:** strongest (opus) — game logic correctness is critical  
**Depends on:** Step 1  
**Parallel with:** nothing  

### Context Brief

`packages/ohhell_engine` is a pure Dart library with zero Flutter/network dependencies. It implements the complete Oh Hell rules engine that both the server and (optionally) the client can import. All business logic lives here; nothing game-rule-related belongs anywhere else.

### Tasks

1. Define card models in `lib/src/models/`:
   - `Suit` enum: spades, hearts, diamonds, clubs
   - `Rank` enum: two through ace (with numeric value)
   - `Card` (immutable value class: suit + rank)
   - `Deck` (creates/shuffles a standard 52-card deck)
2. Define game state models in `lib/src/models/`:
   - `Player` (id, name, hand, bid, tricksWon)
   - `Trick` (cards played so far, leader, winner)
   - `RoundState` (round number, trump suit, bids, tricks, scores)
   - `GameState` (phase enum, players, currentRound, allRoundResults)
   - `GamePhase` enum: lobby, dealing, bidding, playing, roundEnd, gameEnd
3. Implement `GameEngine` class in `lib/src/engine.dart`:
   - `startGame(List<Player> players, GameConfig config) → GameState`
   - `dealRound(GameState) → GameState` — shuffles and deals correct card count
   - `placeBid(GameState, playerId, int bid) → GameState`
   - `playCard(GameState, playerId, Card) → GameState`
   - `evaluateTrick(GameState) → GameState` — determine trick winner
   - `endRound(GameState) → GameState` — compute scores
4. Implement `GameConfig` value class: `roundCounts` (list of card counts per round), `scoringVariant` enum
5. Implement `ScoreCalculator` service: exact-bid bonus logic
6. Implement `CardValidator`: `canPlay(hand, Card, leadSuit, trumpSuit) → bool`
7. Export all public API from `lib/ohhell_engine.dart`
8. Write exhaustive unit tests in `test/`:
   - `card_test.dart` — ordering, equality
   - `deck_test.dart` — shuffle, deal counts
   - `game_engine_test.dart` — full game simulation, edge cases
   - `card_validator_test.dart` — must-follow-suit rules
   - `score_calculator_test.dart` — all scoring variants
9. Achieve ≥ 90% line coverage

### Verification

```bash
cd packages/ohhell_engine
dart test --coverage=coverage
dart pub global run coverage:format_coverage --lcov --in=coverage --out=lcov.info
# check lcov.info summary for ≥ 90%
dart analyze --fatal-infos
```

### Exit Criteria

- `dart test` passes with ≥ 90% coverage
- `dart analyze` reports zero issues
- `GameEngine` can simulate a complete 7-player Oh Hell game from start to finish in a unit test

### Rollback

Revert `packages/ohhell_engine/` to empty stub from Step 1.

---

## Step 3a — Dart WebSocket Game Server

**Model tier:** default (sonnet)  
**Depends on:** Step 2  
**Parallel with:** Step 3b  

### Context Brief

`server/` is a Dart `shelf` application that manages game rooms over WebSockets. It imports `ohhell_engine` for all game logic. The server is authoritative: clients send intents (bid, play card), and the server validates and broadcasts the new `GameState` to all players in the room. No game logic lives in the server itself — it delegates entirely to `ohhell_engine`.

### Tasks

1. Add dependencies to `server/pubspec.yaml`:
   ```yaml
   dependencies:
     shelf: ^1.4
     shelf_web_socket: ^2.0
     shelf_router: ^1.1
     web_socket_channel: ^3.0
     ohhell_engine:
       path: ../packages/ohhell_engine
     uuid: ^4.0
     json_annotation: ^4.9
   ```
2. Define JSON message protocol in `lib/src/protocol/`:
   - `ClientMessage` types: `join_room`, `create_room`, `place_bid`, `play_card`, `ready`, `leave`
   - `ServerMessage` types: `room_joined`, `game_state`, `error`, `player_joined`, `player_left`
   - Use `json_serializable` for fromJson/toJson
3. Implement `RoomManager` in `lib/src/room_manager.dart`:
   - `createRoom(hostPlayer) → Room`
   - `joinRoom(roomCode, player) → Room`
   - `removePlayer(roomCode, playerId)`
   - In-memory `Map<String, Room>` (no persistence needed for v1)
4. Implement `Room` in `lib/src/room.dart`:
   - Holds `GameState`, connected WebSocket channels per player
   - `broadcast(ServerMessage)` — send to all players
   - `sendTo(playerId, ServerMessage)`
5. Implement `GameHandler` in `lib/src/game_handler.dart`:
   - Receives `ClientMessage`, calls `GameEngine`, broadcasts updated `GameState`
   - Validates turn order (reject out-of-turn plays with error message)
6. Implement HTTP + WebSocket server in `bin/server.dart`:
   - `GET /health` → 200 OK (for Docker health check)
   - `GET /ws` → upgrade to WebSocket
   - Configurable port via `PORT` env var (default 8080)
7. Write integration tests in `test/`:
   - Room creation/join
   - Full game round simulation over in-process WebSocket
   - Disconnect handling (reconnect grace period)
8. Write `Dockerfile.server` in `docker/`:
   ```dockerfile
   FROM dart:stable AS build
   WORKDIR /app
   COPY . .
   RUN dart pub get && dart compile exe bin/server.dart -o bin/server
   FROM scratch
   COPY --from=build /runtime/ /
   COPY --from=build /app/bin/server /app/bin/server
   EXPOSE 8080
   CMD ["/app/bin/server"]
   ```

### Verification

```bash
cd server
dart test
dart analyze --fatal-infos
dart run bin/server.dart &
curl http://localhost:8080/health    # should return 200
# test WebSocket with wscat or similar
```

### Exit Criteria

- Server starts and `/health` returns 200
- Integration tests pass for full game round
- `dart analyze` clean
- Docker build succeeds: `docker build -f docker/Dockerfile.server -t ohhell-server .`

### Rollback

Revert `server/` to the empty shelf stub from Step 1.

---

## Step 3b — Flutter Client Foundation

**Model tier:** default (sonnet)  
**Depends on:** Step 1  
**Parallel with:** Step 3a  

### Context Brief

`client/` is the Flutter application. This step establishes the design system, navigation scaffold, and core card UI widgets that all gameplay screens will build on. No networking yet — pure UI foundation. Uses Riverpod for state management.

### Tasks

1. Add Flutter dependencies to `client/pubspec.yaml`:
   ```yaml
   dependencies:
     flutter_riverpod: ^2.5
     go_router: ^14.0
     web_socket_channel: ^3.0
     freezed_annotation: ^2.4
   dev_dependencies:
     freezed: ^2.4
     build_runner: ^2.4
     flutter_test:
       sdk: flutter
   ```
2. Define design tokens in `lib/src/theme/`:
   - Color palette (dark felt green, card cream, suit red/black)
   - Typography scale (Google Fonts or bundled)
   - Card dimensions, border radii, shadows
   - `AppTheme.dark()` and `AppTheme.light()` `ThemeData` factories
3. Create `CardWidget` in `lib/src/widgets/card_widget.dart`:
   - Renders front-face with rank + suit (Unicode suit symbols: ♠♥♦♣)
   - Renders card back (decorative pattern)
   - `isSelected` state with elevation/translate animation
   - `isFaceDown` flag
   - Accessible semantics label
4. Create `HandWidget` in `lib/src/widgets/hand_widget.dart`:
   - Fan layout of `CardWidget`s
   - Tap to select/deselect (or play)
   - `onCardTap` callback
5. Create `TrickPileWidget` — displays cards played in current trick
6. Implement app routing with `go_router` in `lib/src/router.dart`:
   - `/` → `SplashScreen`
   - `/home` → `HomeScreen` (create/join game)
   - `/lobby/:roomCode` → `LobbyScreen`
   - `/game/:roomCode` → `GameScreen`
   - `/scores/:roomCode` → `ScoreScreen`
7. Implement screen shells (no real logic — placeholder content):
   - `SplashScreen`, `HomeScreen`, `LobbyScreen`, `GameScreen`, `ScoreScreen`
8. Add `main.dart` with `ProviderScope` wrapping `MaterialApp.router`
9. Write widget tests for `CardWidget` and `HandWidget`

### Verification

```bash
cd client
flutter pub get
flutter analyze
flutter test
flutter run -d linux    # or -d chrome; should show splash screen
```

### Exit Criteria

- `flutter analyze` clean
- Widget tests pass for `CardWidget` and `HandWidget`
- App runs on at least one desktop target showing navigation skeleton
- Card widget renders correctly with all 52 cards

### Rollback

Revert `client/` to Flutter scaffold from Step 1.

---

## Step 4 — Client–Server Integration

**Model tier:** default (sonnet)  
**Depends on:** Step 3a + Step 3b  
**Parallel with:** nothing  

### Context Brief

Wire the Flutter client to the Dart game server via WebSocket. Implement the Riverpod providers that own connection state and game state. After this step, a player can connect, create/join a room, and see live game state updates.

### Tasks

1. Create `GameServerClient` in `client/lib/src/network/`:
   - Wraps `WebSocketChannel`
   - `connect(host, port)` → establishes connection
   - `send(ClientMessage)` → serializes to JSON and sends
   - `messageStream → Stream<ServerMessage>` — parsed incoming messages
   - Auto-reconnect with exponential backoff (3 attempts, then surface error)
2. Create Riverpod providers in `client/lib/src/providers/`:
   - `gameServerClientProvider` — `GameServerClient` singleton
   - `connectionStateProvider` — `connected | connecting | disconnected | error`
   - `roomProvider` — current room code and player list
   - `gameStateProvider` — `AsyncValue<GameState>` synced from server messages
3. Update `HomeScreen`:
   - Text field for server host (default: `localhost` in debug, configurable)
   - "Create Game" button → sends `create_room`, navigates to `/lobby/:roomCode`
   - "Join Game" button + room code field → sends `join_room`
4. Update `LobbyScreen`:
   - Shows players in room, ready status
   - Host sees "Start Game" button (enabled when ≥ 3 players ready)
5. Update `GameScreen` to receive `gameStateProvider` updates
6. Handle disconnection gracefully: show reconnect dialog
7. Add `client/lib/src/config/app_config.dart`:
   - `serverHost` and `serverPort` — read from compile-time defines (`--dart-define`)
   - Default: `localhost:8080` for debug, configurable for release
8. Write integration test (using `fake_async` or in-process mock server):
   - Client connects → creates room → joins as second player → game state syncs

### Verification

```bash
# Terminal 1:
cd server && dart run bin/server.dart
# Terminal 2:
cd client && flutter run -d linux \
  --dart-define=SERVER_HOST=localhost \
  --dart-define=SERVER_PORT=8080
# Manual: create room on one instance, join from second chrome tab
```

### Exit Criteria

- Two Flutter instances can create/join the same room
- Game state changes on the server are reflected in both clients within 100ms
- Disconnection shows reconnect dialog; reconnection restores state

### Rollback

Remove network providers; revert screens to static placeholders.

---

## Step 5 — Gameplay Screens

**Model tier:** default (sonnet)  
**Depends on:** Step 4  
**Parallel with:** nothing  

### Context Brief

Implement the full game flow UI: lobby, bidding phase, trick-taking phase, and scoring. The game state comes from `gameStateProvider` (Step 4). This step focuses on UX correctness and playability — all platforms use the same screens.

### Tasks

1. **LobbyScreen** (complete):
   - Player list with avatar initials + ready toggle
   - Room code display with copy button
   - Config panel (host only): round variant selector
   - "Start Game" button
2. **BiddingScreen** (within `GameScreen` when `phase == GamePhase.bidding`):
   - Show player hand (face-up)
   - Trump card displayed prominently
   - Bid slider/spinner (0 to hand size)
   - Bid table showing other players' bids as they come in
   - Submit button (enabled only on player's turn)
3. **TrickPlayScreen** (within `GameScreen` when `phase == GamePhase.playing`):
   - Center: trick pile showing played cards
   - Bottom: current player's hand; tap a card to play it
   - Sides: opponent hand backs (card count visible)
   - Current trick leader indicator
   - Trump suit indicator (corner badge)
   - Animated card-play: card flies from hand to trick pile
4. **RoundEndScreen** (modal overlay when `phase == GamePhase.roundEnd`):
   - Per-player: bid vs actual, points earned this round, running total
   - "Next Round" button (host only, or auto-advance timer)
5. **GameEndScreen** (`phase == GamePhase.gameEnd`):
   - Final leaderboard with podium styling
   - "Play Again" button
6. Responsive layout:
   - Mobile: portrait-first, hand at bottom
   - Desktop/tablet: landscape-aware, wider trick area
7. Accessibility: all interactive elements have semantic labels and keyboard focus order
8. Widget tests for all five screen states using fake `gameStateProvider`

### Verification

```bash
cd client
flutter test
flutter run -d linux    # play through a full game with 3+ players
flutter run -d chrome   # verify web layout
```

### Exit Criteria

- Full game playable from lobby through game end on desktop
- No layout overflow on 360px-wide (mobile) viewport
- Animations complete within 16ms budget (no jank on debug build)

### Rollback

Revert screen implementations to placeholders from Step 3b.

---

## Step 6 — Android & iOS Platform Configuration

**Model tier:** default (sonnet)  
**Depends on:** Step 5  
**Parallel with:** Step 7  

### Context Brief

Configure Flutter platform targets for Android and iOS release builds. This step does not add features — it ensures the app builds and runs correctly on mobile, handles signing configuration, and sets appropriate metadata.

### Tasks

**Android (`client/android/`):**
1. Set `minSdkVersion 21` (Android 5.0+), `targetSdkVersion 34`
2. Configure `applicationId`: `com.bearyjd.ohhell`
3. Add internet permission to `AndroidManifest.xml`
4. Configure ProGuard rules for Dart/Flutter
5. Create keystore and signing config (`key.properties` — gitignored, documented in README)
6. Configure `flutter build apk --release` and `flutter build appbundle`
7. Set app name, launcher icon (use `flutter_launcher_icons` package with card/spade icon)
8. Verify dark/light theme on Android

**iOS (`client/ios/`):**
1. Set `IPHONEOS_DEPLOYMENT_TARGET` to 14.0
2. Set `PRODUCT_BUNDLE_IDENTIFIER`: `com.bearyjd.ohhell`
3. Add `NSLocalNetworkUsageDescription` in `Info.plist` (for LAN multiplayer)
4. Configure signing (Xcode managed, document requirements in README)
5. Set app name and launcher icon (same `flutter_launcher_icons` config)
6. Verify `flutter build ios --release --no-codesign` succeeds

### Verification

```bash
cd client
flutter build apk --release
flutter build appbundle
flutter build ios --release --no-codesign   # requires macOS — document in CI
flutter analyze
```

### Exit Criteria

- `flutter build apk --release` produces valid APK
- `flutter build appbundle` produces valid AAB
- `flutter build ios --no-codesign` succeeds (iOS builds require macOS runner in CI)
- App icons and name display correctly

### Rollback

Revert `android/` and `ios/` to Flutter-generated defaults.

---

## Step 7 — Windows & Linux Desktop Configuration

**Model tier:** default (sonnet)  
**Depends on:** Step 5  
**Parallel with:** Step 6  

### Context Brief

Configure Flutter desktop targets for Windows and Linux. Produce redistributable binaries. Desktop builds require layout adjustments (mouse hover states, right-click handling, window sizing) not needed on mobile.

### Tasks

**Linux (`client/linux/`):**
1. Set app name and bundle ID in `CMakeLists.txt`
2. Verify GTK dependencies documented in README: `libgtk-3-dev`
3. Configure `flutter build linux --release`
4. Test window resize behavior (min size 800×600)
5. Package as tarball: `tar -czf ohhell-linux-x86_64.tar.gz -C build/linux/x64/release/bundle .`
6. Create `install.sh` helper script

**Windows (`client/windows/`):**
1. Set app name and company in `CMakeLists.txt` and `Runner.rc`
2. Configure `flutter build windows --release`
3. Test on Windows (or document CI requirement)
4. Package with MSIX using `msix` Flutter package:
   - Configure `msix_config` in `pubspec.yaml`
   - `flutter pub run msix:create`
5. Optionally create a zip artifact: `ohhell-windows-x64.zip`

**Desktop-specific UI polish:**
6. Add window title: "Oh Hell"
7. Add `window_manager` package: set minimum window size 800×600, center on start
8. Hover effects on `CardWidget` (cursor change to pointer)
9. Keyboard shortcut: `Escape` to leave game, `Enter` to confirm bid

### Verification

```bash
cd client
flutter build linux --release
# On Windows:
flutter build windows --release
flutter analyze
```

### Exit Criteria

- `flutter build linux --release` succeeds; bundle runs standalone
- `flutter build windows --release` succeeds (CI Windows runner)
- Window respects minimum size constraint
- Keyboard shortcuts work

### Rollback

Revert `linux/` and `windows/` to Flutter-generated defaults.

---

## Step 8 — Web Build + Docker Deployment

**Model tier:** default (sonnet)  
**Depends on:** Step 5  
**Parallel with:** Steps 6 and 7  

### Context Brief

Compile Flutter to WebAssembly/JS for web, serve via nginx, and bundle both the game server and the web client into a Docker Compose stack. The server listens on port 8080 (WebSocket); nginx serves the Flutter web app on port 80 and proxies `/ws` to the server.

### Tasks

1. Configure Flutter web build:
   - `flutter build web --release --web-renderer canvaskit`
   - Output goes to `client/build/web/`
2. Write `docker/nginx.conf`:
   ```nginx
   server {
     listen 80;
     root /usr/share/nginx/html;
     index index.html;
     
     location / {
       try_files $uri $uri/ /index.html;  # SPA routing
     }
     
     location /ws {
       proxy_pass http://server:8080/ws;
       proxy_http_version 1.1;
       proxy_set_header Upgrade $http_upgrade;
       proxy_set_header Connection "Upgrade";
       proxy_set_header Host $host;
       proxy_read_timeout 3600s;
     }
     
     location /health {
       proxy_pass http://server:8080/health;
     }
   }
   ```
3. Write `docker/Dockerfile.client`:
   ```dockerfile
   FROM nginx:alpine
   COPY client/build/web /usr/share/nginx/html
   COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
   EXPOSE 80
   ```
4. Write `docker/Dockerfile.server` (from Step 3a — finalize here with multi-stage Dart compile)
5. Write `docker-compose.yml` at repo root:
   ```yaml
   version: '3.9'
   services:
     server:
       build:
         context: .
         dockerfile: docker/Dockerfile.server
       environment:
         PORT: "8080"
       healthcheck:
         test: ["CMD", "wget", "-qO-", "http://localhost:8080/health"]
         interval: 10s
         timeout: 5s
         retries: 3
     client:
       build:
         context: .
         dockerfile: docker/Dockerfile.client
       ports:
         - "80:80"
       depends_on:
         server:
           condition: service_healthy
   ```
6. Configure Flutter web to connect to WebSocket at relative path `/ws` (not hardcoded host)
   - In `app_config.dart`: when `kIsWeb`, use `ws://${window.location.host}/ws`
7. Write `scripts/build-web.sh`:
   ```bash
   #!/bin/bash
   set -e
   cd client && flutter build web --release --web-renderer canvaskit
   cd .. && docker compose build
   echo "Run with: docker compose up"
   ```
8. Test full Docker stack locally:
   - `docker compose up`
   - Open `http://localhost` in browser
   - Verify WebSocket connects through nginx proxy

### Verification

```bash
flutter build web --release --web-renderer canvaskit
docker compose build
docker compose up -d
curl http://localhost/health        # should return 200
# Open browser at http://localhost — full game should work
docker compose down
```

### Exit Criteria

- `docker compose up` starts both containers without error
- Web app loads at `http://localhost`
- WebSocket connects via nginx proxy
- Full game playable in browser via Docker
- `docker compose down` clean shutdown

### Rollback

Remove `docker/`, `docker-compose.yml`, `scripts/build-web.sh`. Revert `app_config.dart` web URL logic.

---

## Step 9 — Testing & Polish

**Model tier:** default (sonnet)  
**Depends on:** Steps 6, 7, 8  
**Parallel with:** nothing  

### Context Brief

Harden the application before release: integration tests, error handling, reconnection resilience, and UX polish. This step does not add features — it ensures what exists is robust.

### Tasks

1. **Integration tests** (`client/integration_test/`):
   - `game_flow_test.dart`: launch server, connect two Flutter driver instances, play a full game
   - Uses `flutter_driver` or `integration_test` package
2. **Server stress test** (`server/test/stress_test.dart`):
   - Simulate 10 concurrent games with 7 players each
   - Verify no memory leaks (check `Isolate` metrics)
3. **Reconnection test**:
   - Server kills a player's WebSocket mid-game
   - Player reconnects within grace period (30s), game resumes
   - Player reconnects after grace period → game continues with AI/random play for that player
4. **Error handling sweep**:
   - Invalid room code → clear error message
   - Server unreachable → "Cannot connect to server" with retry button
   - Playing card out of turn → server rejects, client shows toast
   - Deck edge cases: last card is trump → no trump this round
5. **UI polish**:
   - Loading skeletons instead of blank screens
   - Empty states (lobby with 1 player)
   - Sound effects (optional: simple click/flip sounds using `just_audio`)
   - Card flip animation when trump is revealed
6. **Accessibility audit**:
   - Run `flutter test --tags=accessibility`
   - Verify VoiceOver/TalkBack compatibility on one screen
7. **Performance**:
   - Profile on mid-range Android device (Flutter DevTools)
   - Verify card animation holds 60fps on Chrome

### Verification

```bash
cd client
flutter test integration_test/
flutter analyze --fatal-infos

cd server
dart test test/stress_test.dart
```

### Exit Criteria

- Integration tests pass on Linux and Web targets
- No `flutter analyze` warnings or infos
- Reconnection test passes
- Zero known crashes in a full 7-player game session

### Rollback

Remove `integration_test/` and `test/stress_test.dart`. Revert sound/animation additions.

---

## Step 10 — CI/CD Release Pipeline

**Model tier:** default (sonnet)  
**Depends on:** Step 9  
**Parallel with:** nothing  

### Context Brief

Automate builds and releases via GitHub Actions. On every push to `main`: run tests. On tag `v*`: build all platform artifacts, publish Docker image to GitHub Container Registry, and create a GitHub Release with downloadable binaries.

### Tasks

1. Write `.github/workflows/ci.yml` (replace skeleton from Step 1):
   ```yaml
   name: CI
   on: [push, pull_request]
   jobs:
     engine-tests:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4
         - uses: dart-lang/setup-dart@v1
         - run: cd packages/ohhell_engine && dart test --coverage
     
     server-tests:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4
         - uses: dart-lang/setup-dart@v1
         - run: cd server && dart test
     
     flutter-analyze:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4
         - uses: subosito/flutter-action@v2
         - run: cd client && flutter pub get && flutter analyze
     
     flutter-test:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4
         - uses: subosito/flutter-action@v2
         - run: cd client && flutter test
   ```
2. Write `.github/workflows/release.yml`:
   ```yaml
   name: Release
   on:
     push:
       tags: ['v*']
   jobs:
     build-linux:
       runs-on: ubuntu-latest
       steps: [checkout, flutter-action, build linux, upload artifact]
     
     build-windows:
       runs-on: windows-latest
       steps: [checkout, flutter-action, build windows, create MSIX, upload artifact]
     
     build-android:
       runs-on: ubuntu-latest
       steps: [checkout, flutter-action, build APK + AAB, upload artifact]
     
     build-ios:
       runs-on: macos-latest
       steps: [checkout, flutter-action, build ios --no-codesign, upload artifact]
     
     build-web-docker:
       runs-on: ubuntu-latest
       steps:
         - checkout
         - flutter-action
         - run: flutter build web --release
         - uses: docker/build-push-action@v5
           with:
             context: .
             file: docker/Dockerfile.client
             push: true
             tags: ghcr.io/bearyjd/ohhell-client:${{ github.ref_name }}
         - build and push ohhell-server image to ghcr.io
     
     create-release:
       needs: [build-linux, build-windows, build-android, build-ios, build-web-docker]
       runs-on: ubuntu-latest
       steps:
         - uses: softprops/action-gh-release@v1
           with:
             files: |
               ohhell-linux-x86_64.tar.gz
               ohhell-windows-x64.zip
               ohhell-android.apk
               ohhell-android.aab
   ```
3. Add `DOCKER_REGISTRY` secret and `SIGNING_KEY` secrets to repo settings (document in README)
4. Test the release pipeline with a `v0.1.0` tag
5. Update README with:
   - Download links for each platform
   - `docker compose` quick-start
   - Development setup instructions
   - Game rules summary

### Verification

```bash
git tag v0.1.0
git push origin v0.1.0
# Watch GitHub Actions: all jobs should pass
# Check GitHub Releases page for artifacts
# Check GHCR for Docker images
```

### Exit Criteria

- All CI jobs pass on push to `main`
- Release tag `v0.1.0` produces:
  - `ohhell-linux-x86_64.tar.gz`
  - `ohhell-windows-x64.zip` (or MSIX)
  - `ohhell-android.apk`
  - Docker images at `ghcr.io/bearyjd/ohhell-{client,server}`
- GitHub Release page shows all artifacts

### Rollback

Delete the release tag: `git push --delete origin v0.1.0`. Remove workflow files if needed.

---

## Plan Mutation Protocol

To modify this plan mid-execution:

| Operation | Action |
|-----------|--------|
| Split a step | Mark original as `REPLACED`, add two new steps with `SPLIT FROM: StepN` |
| Skip a step | Mark as `SKIPPED: <reason>` and document downstream impact |
| Insert a step | Insert with `INSERTED AFTER: StepN`, update dependency graph |
| Abandon | Mark as `ABANDONED: <reason>` and summarize what was completed |

Always add an `AUDIT` entry at the bottom of this file when mutating.

---

## Audit Log

| Date | Action | Notes |
|------|--------|-------|
| 2026-04-11 | Created | Initial plan generated by Blueprint |
