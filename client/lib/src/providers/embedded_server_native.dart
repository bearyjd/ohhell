import 'dart:async';
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
      final server = await startEmbeddedServer();
      _server = server;
      final localIp = await _getLocalIp() ?? 'localhost';
      state = ServerRunning(localIp: localIp, port: server.port);
    } on Exception catch (e) {
      state = ServerError(e.toString());
    }
  }

  /// Stops the embedded server and resets to [ServerIdle].
  Future<void> stop() async {
    final server = _server;
    _server = null;
    state = const ServerIdle();
    await server?.close(force: true);
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
    unawaited(_server?.close(force: true));
    super.dispose();
  }
}

final embeddedServerProvider = StateNotifierProvider<
    EmbeddedServerNotifier, EmbeddedServerStatus>(
  (ref) => EmbeddedServerNotifier(),
);
