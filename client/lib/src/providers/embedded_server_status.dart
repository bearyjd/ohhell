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
