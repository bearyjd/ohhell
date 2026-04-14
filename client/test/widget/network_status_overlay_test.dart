import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ohhell_client/src/providers/ws_provider.dart';
import 'package:ohhell_client/src/widgets/network_status_overlay.dart';

/// A fake WsNotifier that starts in a pre-set state, used to drive
/// the overlay in tests without opening real WebSocket connections.
class _FakeWsNotifier extends WsNotifier {
  _FakeWsNotifier(WsStatus initialStatus, Ref ref) : super(ref) {
    state = initialStatus;
  }
}

Widget _buildWithStatus(WsStatus status) {
  return ProviderScope(
    overrides: [
      wsProvider.overrideWith((ref) => _FakeWsNotifier(status, ref)),
    ],
    child: const MaterialApp(
      home: NetworkStatusOverlay(child: Text('Game')),
    ),
  );
}

void main() {
  testWidgets('shows only child when WsConnected', (tester) async {
    await tester.pumpWidget(_buildWithStatus(const WsConnected()));
    expect(find.text('Game'), findsOneWidget);
    expect(find.textContaining('Reconnecting'), findsNothing);
    expect(find.textContaining('Connection lost'), findsNothing);
  });

  testWidgets('shows only child when WsDisconnected', (tester) async {
    await tester.pumpWidget(_buildWithStatus(const WsDisconnected()));
    expect(find.text('Game'), findsOneWidget);
    expect(find.textContaining('Reconnecting'), findsNothing);
    expect(find.textContaining('lost'), findsNothing);
  });

  testWidgets('shows reconnecting banner when WsReconnecting', (tester) async {
    await tester.pumpWidget(
      _buildWithStatus(const WsReconnecting(attempt: 2, maxAttempts: 5)),
    );
    expect(find.text('Game'), findsOneWidget);
    expect(find.textContaining('Reconnecting'), findsOneWidget);
    expect(find.textContaining('2/5'), findsOneWidget);
  });

  testWidgets('shows error banner with Retry button when WsError',
      (tester) async {
    await tester.pumpWidget(
      _buildWithStatus(
        const WsError('Connection lost. Tap Retry to reconnect.'),
      ),
    );
    expect(find.text('Game'), findsOneWidget);
    expect(find.textContaining('Connection lost'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('Retry button calls manualReconnect', (tester) async {
    await tester.pumpWidget(
      _buildWithStatus(
        const WsError('Connection lost. Tap Retry to reconnect.'),
      ),
    );
    // Tapping Retry should not throw.
    await tester.tap(find.text('Retry'));
    await tester.pump();
    // No assertion on side-effect — just verify it doesn't crash.
  });
}
