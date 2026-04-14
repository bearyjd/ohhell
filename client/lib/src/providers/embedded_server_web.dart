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
