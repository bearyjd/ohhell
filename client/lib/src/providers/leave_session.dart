import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ohhell_protocol/ohhell_protocol.dart';

import 'embedded_server_provider.dart';
import 'session_provider.dart';
import 'ws_provider.dart';

/// Matches the signature of both [WidgetRef.read] and
/// [ProviderContainer.read], letting [leaveSession] be driven from a
/// widget (`leaveSession(ref.read)`) or exercised directly in a unit
/// test (`leaveSession(container.read)`) without a widget tree.
typedef ProviderReader = T Function<T>(ProviderListenable<T> provider);

/// Tears down a hosted or joined game session.
///
/// Called from every path a player can leave a [GameScreen]/[LobbyScreen]
/// by (back navigation, an explicit "Leave" affordance, or the app
/// lifecycle backstop): sends [LeaveRoomMessage] so the server can drop
/// this player immediately, disconnects the websocket, stops the
/// locally-hosted embedded server if this client is hosting one, and
/// resets local session state.
///
/// Every step is safe to call unconditionally — each is a no-op when not
/// applicable (e.g. stopping an embedded server that isn't running).
Future<void> leaveSession(ProviderReader read) async {
  read(wsProvider.notifier).send(const LeaveRoomMessage());
  read(wsProvider.notifier).disconnect();
  if (read(embeddedServerProvider) is ServerRunning) {
    await read(embeddedServerProvider.notifier).stop();
  }
  read(sessionProvider.notifier).reset();
}
