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
