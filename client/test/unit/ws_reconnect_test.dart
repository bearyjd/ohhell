import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ohhell_client/src/providers/ws_provider.dart';

void main() {
  test('WsNotifier starts in WsDisconnected state', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(wsProvider), isA<WsDisconnected>());
  });

  test('WsReconnecting holds attempt and maxAttempts', () {
    const s = WsReconnecting(attempt: 2, maxAttempts: 5);
    expect(s.attempt, 2);
    expect(s.maxAttempts, 5);
  });

  test('manualReconnect before connect does not throw', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      () => container.read(wsProvider.notifier).manualReconnect(),
      returnsNormally,
    );
  });

  test(
    'connect to unreachable host results in WsError or WsReconnecting',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(wsProvider.notifier).connect('127.0.0.1:19999');
      await Future<void>.delayed(Duration.zero);

      final status = container.read(wsProvider);
      expect(status, anyOf(isA<WsError>(), isA<WsReconnecting>()));
    },
  );

  test('disconnect resets state to WsDisconnected', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(wsProvider.notifier);
    unawaited(notifier.connect('127.0.0.1:19999'));
    await Future<void>.delayed(Duration.zero);

    notifier.disconnect();
    expect(container.read(wsProvider), isA<WsDisconnected>());
  });
}
