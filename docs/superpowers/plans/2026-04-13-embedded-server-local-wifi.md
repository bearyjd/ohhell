# Embedded Server — Local WiFi Play Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let one phone act as the game server on a shared WiFi network so other phones can join without a separate computer or internet connection.

**Architecture:** The existing Dart shelf server (`RoomManager` + WebSocket handler) is extracted into a `startEmbeddedServer()` function inside the `server` package. The Flutter client adds `server` as a path dependency and gains an `EmbeddedServerNotifier` (Riverpod `StateNotifier`) that starts/stops the in-process server, discovers the device's LAN IP via `dart:io`, and exposes a `ServerRunning(localIp, port)` state. Because `dart:io` is unavailable on web, the provider uses Dart's conditional export mechanism to provide a no-op stub on web builds. The `HomeScreen` gains a "Host on this device" button that starts the server and displays the LAN address for other players to type into their Server Host field.

**Tech Stack:** Dart shelf + shelf_router + shelf_web_socket (already in server package), `dart:io` NetworkInterface (native only), Flutter Riverpod manual StateNotifier, conditional Dart exports (`if (dart.library.html)`), `flutter/services.dart` Clipboard

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `server/lib/src/embedded_server.dart` | `startEmbeddedServer({port})` — binds shelf+RoomManager to a socket |
| Create | `server/lib/server.dart` | Public barrel export for the server package |
| Modify | `client/pubspec.yaml` | Add `server: path: ../server` dependency |
| Create | `client/lib/src/providers/embedded_server_status.dart` | Sealed status types — platform-agnostic, imported by both platform files |
| Create | `client/lib/src/providers/embedded_server_native.dart` | Native notifier (dart:io + server package) |
| Create | `client/lib/src/providers/embedded_server_web.dart` | Web stub notifier (no-op, no dart:io) |
| Create | `client/lib/src/providers/embedded_server_provider.dart` | Conditional export selecting native vs web |
| Create | `client/test/unit/embedded_server_provider_test.dart` | 5 unit tests for the notifier |
| Modify | `client/lib/src/screens/home_screen.dart` | "Host on this device" button + IP share card |

---

## Task 1: Server package — expose `startEmbeddedServer()`

**Files:**
- Create: `server/lib/src/embedded_server.dart`
- Create: `server/lib/server.dart`

- [ ] **Step 1: Create `server/lib/src/embedded_server.dart`**

```dart
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';

import 'room_manager.dart';

/// Starts an in-process WebSocket game server bound to all IPv4 interfaces.
///
/// [port] defaults to 0, which lets the OS assign a free port. The actual
/// bound port is available via the returned [HttpServer.port].
///
/// Caller is responsible for calling [HttpServer.close] when done.
Future<HttpServer> startEmbeddedServer({int port = 0}) async {
  final manager = RoomManager();
  final router = Router()
    ..get('/ws', webSocketHandler(manager.handleNewConnection));
  final handler = Pipeline().addHandler(router.call);
  return io.serve(handler, InternetAddress.anyIPv4, port);
}
```

- [ ] **Step 2: Create `server/lib/server.dart`**

```dart
/// Public API for the server package.
///
/// Consumers can start an in-process server with [startEmbeddedServer].
library server;

export 'src/embedded_server.dart';
export 'src/room_manager.dart';
```

- [ ] **Step 3: Verify compilation**

```bash
cd /var/home/user/Documents/vibe-code/games/ohhell
dart analyze server
```
Expected: No issues found.

- [ ] **Step 4: Run server tests to confirm nothing broke**

```bash
dart test server
```
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add server/lib/src/embedded_server.dart server/lib/server.dart
git commit -m "feat: expose startEmbeddedServer() as public server package API"
```

---

## Task 2: Client — `EmbeddedServerNotifier` with platform split

**Files:**
- Modify: `client/pubspec.yaml`
- Create: `client/lib/src/providers/embedded_server_status.dart`
- Create: `client/lib/src/providers/embedded_server_native.dart`
- Create: `client/lib/src/providers/embedded_server_web.dart`
- Create: `client/lib/src/providers/embedded_server_provider.dart`
- Create: `client/test/unit/embedded_server_provider_test.dart`

- [ ] **Step 1: Write the failing tests first**

Create `client/test/unit/embedded_server_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ohhell_client/src/providers/embedded_server_provider.dart';

void main() {
  test('starts in ServerIdle', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(embeddedServerProvider), isA<ServerIdle>());
  });

  test('stop() from idle stays idle', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(embeddedServerProvider.notifier).stop();
    expect(container.read(embeddedServerProvider), isA<ServerIdle>());
  });

  test('start() results in ServerRunning with valid port', () async {
    final container = ProviderContainer();
    addTearDown(() async {
      await container.read(embeddedServerProvider.notifier).stop();
      container.dispose();
    });
    await container.read(embeddedServerProvider.notifier).start();
    final status = container.read(embeddedServerProvider);
    expect(status, isA<ServerRunning>());
    final running = status as ServerRunning;
    expect(running.port, greaterThan(0));
    expect(running.localAddress, startsWith('localhost:'));
    expect(running.sharedAddress, contains(':'));
  });

  test('calling start() again when running does not change port', () async {
    final container = ProviderContainer();
    addTearDown(() async {
      await container.read(embeddedServerProvider.notifier).stop();
      container.dispose();
    });
    await container.read(embeddedServerProvider.notifier).start();
    final first = container.read(embeddedServerProvider) as ServerRunning;
    await container.read(embeddedServerProvider.notifier).start();
    final second = container.read(embeddedServerProvider);
    expect(second, isA<ServerRunning>());
    expect((second as ServerRunning).port, equals(first.port));
  });

  test('stop() after start() returns to ServerIdle', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(embeddedServerProvider.notifier).start();
    await container.read(embeddedServerProvider.notifier).stop();
    expect(container.read(embeddedServerProvider), isA<ServerIdle>());
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /var/home/user/Documents/vibe-code/games/ohhell
flutter test client/test/unit/embedded_server_provider_test.dart
```
Expected: compile error — `embedded_server_provider.dart` not found.

- [ ] **Step 3: Add server dependency to `client/pubspec.yaml`**

In `client/pubspec.yaml`, add `server` under `dependencies` (after `uuid: ^4.4.0`):

```yaml
  uuid: ^4.4.0
  server:
    path: ../server
```

Run:
```bash
dart pub get
```
Expected: Resolving dependencies... (no errors)

- [ ] **Step 4: Create `client/lib/src/providers/embedded_server_status.dart`**

This file has zero platform dependencies — it is imported by both the native and web implementations.

```dart
/// Status types for the embedded game server.
///
/// These are platform-agnostic — no dart:io or Flutter imports.
sealed class EmbeddedServerStatus {
  const EmbeddedServerStatus();
}

/// The embedded server is not running.
final class ServerIdle extends EmbeddedServerStatus {
  const ServerIdle();
}

/// The embedded server is binding to a port (transient).
final class ServerStarting extends EmbeddedServerStatus {
  const ServerStarting();
}

/// The embedded server is running and accepting connections.
final class ServerRunning extends EmbeddedServerStatus {
  const ServerRunning({required this.localIp, required this.port});

  /// The device's LAN IP address (e.g. "192.168.1.42").
  final String localIp;

  /// The TCP port the server is bound to.
  final int port;

  /// Address to show to other players — they type this into their app.
  String get sharedAddress => '$localIp:$port';

  /// Address the host device uses to connect to its own server.
  String get localAddress => 'localhost:$port';
}

/// The embedded server failed to start or was stopped due to an error.
final class ServerError extends EmbeddedServerStatus {
  const ServerError(this.message);
  final String message;
}
```

- [ ] **Step 5: Create `client/lib/src/providers/embedded_server_native.dart`**

```dart
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server/server.dart';

import 'embedded_server_status.dart';

export 'embedded_server_status.dart';

/// Manages an in-process shelf WebSocket server on native platforms
/// (Android, iOS, Linux, macOS, Windows).
class EmbeddedServerNotifier
    extends StateNotifier<EmbeddedServerStatus> {
  EmbeddedServerNotifier() : super(const ServerIdle());

  HttpServer? _server;

  /// Starts the embedded server. No-op if already starting or running.
  Future<void> start() async {
    if (state is ServerRunning || state is ServerStarting) return;
    state = const ServerStarting();
    try {
      _server = await startEmbeddedServer();
      final localIp = await _getLocalIp() ?? 'localhost';
      state = ServerRunning(localIp: localIp, port: _server!.port);
    } on Exception catch (e) {
      state = ServerError(e.toString());
    }
  }

  /// Stops the embedded server and resets to [ServerIdle].
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    state = const ServerIdle();
  }

  /// Returns the first non-loopback IPv4 address found on this device,
  /// or null if no suitable interface is available.
  Future<String?> _getLocalIp() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: false,
    );
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        if (!addr.isLoopback) return addr.address;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _server?.close(force: true);
    super.dispose();
  }
}

final embeddedServerProvider = StateNotifierProvider<
    EmbeddedServerNotifier, EmbeddedServerStatus>(
  (ref) => EmbeddedServerNotifier(),
);
```

- [ ] **Step 6: Create `client/lib/src/providers/embedded_server_web.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'embedded_server_status.dart';

export 'embedded_server_status.dart';

/// No-op stub for web builds.
///
/// `dart:io` (required for socket binding) is not available in browsers.
/// The host-on-device feature is hidden in the UI when running on web.
class EmbeddedServerNotifier
    extends StateNotifier<EmbeddedServerStatus> {
  EmbeddedServerNotifier() : super(const ServerIdle());

  Future<void> start() async =>
      state = const ServerError('Not supported on web');

  Future<void> stop() async => state = const ServerIdle();
}

final embeddedServerProvider = StateNotifierProvider<
    EmbeddedServerNotifier, EmbeddedServerStatus>(
  (ref) => EmbeddedServerNotifier(),
);
```

- [ ] **Step 7: Create `client/lib/src/providers/embedded_server_provider.dart`**

```dart
// Selects the correct implementation at compile time:
//   - dart.library.html  → web (no dart:io, no shelf)
//   - otherwise          → native (dart:io + shelf server)
export 'embedded_server_native.dart'
    if (dart.library.html) 'embedded_server_web.dart';
```

- [ ] **Step 8: Run the unit tests**

```bash
flutter test client/test/unit/embedded_server_provider_test.dart
```
Expected: All 5 tests pass.

- [ ] **Step 9: Run full client test suite**

```bash
flutter test client
```
Expected: All tests pass (no regressions).

- [ ] **Step 10: Commit**

```bash
git add client/pubspec.yaml \
        client/lib/src/providers/embedded_server_status.dart \
        client/lib/src/providers/embedded_server_native.dart \
        client/lib/src/providers/embedded_server_web.dart \
        client/lib/src/providers/embedded_server_provider.dart \
        client/test/unit/embedded_server_provider_test.dart
git commit -m "feat: EmbeddedServerNotifier — start/stop in-process shelf server for local WiFi play"
```

---

## Task 3: HomeScreen — "Host on this device" button + IP share card

**Files:**
- Modify: `client/lib/src/screens/home_screen.dart`

The current `HomeScreen` has a "Server Host" text field defaulting to `localhost:8080`. This task adds a button above that field to start the embedded server. When running, the field is auto-filled with `localhost:{port}` (for the host) and a card shows the LAN address to share with other players.

- [ ] **Step 1: Read the current file**

Read `client/lib/src/screens/home_screen.dart` to confirm line numbers before editing.

- [ ] **Step 2: Add two imports at the top of `home_screen.dart`**

After the existing import block (after line 8 `import 'package:ohhell_protocol/ohhell_protocol.dart';`), add:

```dart
import 'package:flutter/services.dart';
import 'package:ohhell_client/src/providers/embedded_server_provider.dart';
```

- [ ] **Step 3: Add `serverStatus` watch and `ref.listen` in the `build` method**

In the `build` method, directly after the existing two `ref.listen` blocks (after the closing `}` of the `ref.listen(wsProvider, ...)` block, around line 92), add:

```dart
    final serverStatus = ref.watch(embeddedServerProvider);

    ref.listen(embeddedServerProvider, (prev, next) {
      if (next is ServerRunning) {
        _serverHostController.text = next.localAddress;
      } else if (prev is ServerRunning && next is ServerIdle) {
        _serverHostController.text = 'localhost:8080';
      }
    });
```

- [ ] **Step 4: Add `_buildHostSection` method to `_HomeScreenState`**

Add this method to `_HomeScreenState` (e.g. after the `_onJoinGame` method, before `build`):

```dart
  Widget _buildHostSection(EmbeddedServerStatus serverStatus) {
    if (serverStatus is ServerRunning) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.amber.withAlpha(20),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.amber.withAlpha(120)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.wifi, color: AppColors.amber, size: 16),
                const SizedBox(width: 6),
                const Text(
                  'Hosting on this device',
                  style: TextStyle(
                    color: AppColors.amber,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () =>
                      ref.read(embeddedServerProvider.notifier).stop(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.suitRed,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Stop'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Share: ${serverStatus.sharedAddress}',
                    style: const TextStyle(
                      color: AppColors.textOnDark,
                      fontSize: 13,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.copy,
                    size: 16,
                    color: AppColors.amber,
                  ),
                  onPressed: () => Clipboard.setData(
                    ClipboardData(text: serverStatus.sharedAddress),
                  ),
                  tooltip: 'Copy address',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: serverStatus is ServerStarting
            ? null
            : () => ref.read(embeddedServerProvider.notifier).start(),
        icon: serverStatus is ServerStarting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.router_outlined),
        label: Text(
          serverStatus is ServerStarting
              ? 'Starting...'
              : 'Host on this device',
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.amber,
          side: BorderSide(color: AppColors.amber.withAlpha(120)),
        ),
      ),
    );
  }
```

- [ ] **Step 5: Insert host section into the Column in `build`**

In the Column's children list, find the `const SizedBox(height: 16)` that sits between the Player Name field and the Server Host field (around line 148). Change:

```dart
                  const SizedBox(height: 16),
                  TextField(
                    controller: _serverHostController,
```

to:

```dart
                  const SizedBox(height: 16),
                  _buildHostSection(serverStatus),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _serverHostController,
```

- [ ] **Step 6: Run full client test suite**

```bash
flutter test client
```
Expected: All tests pass.

- [ ] **Step 7: Run all Dart tests for regressions**

```bash
dart test packages/ohhell_engine packages/ohhell_protocol server
```
Expected: All tests pass.

- [ ] **Step 8: Commit**

```bash
git add client/lib/src/screens/home_screen.dart
git commit -m "feat: host-on-device button with LAN IP share card on HomeScreen"
```

---

## Self-Review

**Spec coverage:**
- ✅ Embed server in-process on the host device — Task 1 + 2
- ✅ Discover device LAN IP via `NetworkInterface.list` — Task 2 (native notifier)
- ✅ Start/stop server from UI — Task 3 (Host button + Stop button)
- ✅ Display shareable IP:port address — Task 3 (IP share card)
- ✅ Copy address to clipboard — Task 3 (copy icon button)
- ✅ Auto-fill server host field with `localhost:{port}` for the hosting player — Task 3 (`ref.listen`)
- ✅ Restore default host when server is stopped — Task 3 (`ref.listen`)
- ✅ Web builds not broken — Task 2 (conditional export stub)
- ✅ Android permissions already present (`INTERNET` + `usesCleartextTraffic`) — no change needed
- ✅ iOS ATS already has `NSAllowsLocalNetworking: true` — no change needed

**No placeholders:** All code blocks are complete and self-contained.

**Type consistency:**
- `startEmbeddedServer()` returns `HttpServer` — used as `_server` in Task 2 native notifier ✓
- `ServerRunning.sharedAddress` defined in Task 2 status file, rendered in Task 3 UI ✓
- `ServerRunning.localAddress` defined in Task 2 status file, used in Task 3 `ref.listen` ✓
- `embeddedServerProvider` defined in both native + web files, exported via Task 2 conditional provider ✓
- `EmbeddedServerNotifier` exposed via `embeddedServerProvider.notifier` in Task 3 UI ✓
