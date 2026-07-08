import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ohhell_client/src/providers/embedded_server_provider.dart';
import 'package:ohhell_client/src/providers/leave_session.dart';
import 'package:ohhell_client/src/providers/session_provider.dart';

void main() {
  test(
    'leaving without pressing Stop Hosting must not leak the listening '
    'port',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(embeddedServerProvider.notifier).start();
      final running =
          container.read(embeddedServerProvider) as ServerRunning;
      final port = running.port;

      // This is what GameScreen/LobbyScreen's PopScope and "Leave"
      // affordance now call on every leave path, and what the
      // AppLifecycleState.detached backstop calls indirectly via
      // embeddedServerProvider.notifier.stop().
      await leaveSession(container.read);

      expect(
        container.read(embeddedServerProvider),
        isA<ServerIdle>(),
        reason: 'leaveSession must stop a running embedded server',
      );

      // The port must be free — bind to it again to prove no leaked
      // listener remains bound after leaving.
      final probe = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        port,
      ).timeout(const Duration(seconds: 2));
      await probe.close(force: true);
    },
  );

  test('leaveSession resets session state (playerId/roomCode/isHost)',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(sessionProvider.notifier).onRoomJoined(
          playerId: 'player_1',
          roomCode: 'ABC123',
          isHost: true,
        );

    await leaveSession(container.read);

    final session = container.read(sessionProvider);
    expect(session.playerId, isNull);
    expect(session.roomCode, isNull);
    expect(session.isHost, isFalse);
  });

  test(
    'leaveSession is a no-op-safe when no embedded server was ever '
    'started (joining, not hosting)',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await leaveSession(container.read);

      expect(container.read(embeddedServerProvider), isA<ServerIdle>());
    },
  );
}
