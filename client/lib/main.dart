import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ohhell_client/src/providers/embedded_server_provider.dart';
import 'package:ohhell_client/src/router.dart';
import 'package:ohhell_client/src/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: OhHellApp()));
}

class OhHellApp extends ConsumerStatefulWidget {
  const OhHellApp({super.key});

  @override
  ConsumerState<OhHellApp> createState() => _OhHellAppState();
}

class _OhHellAppState extends ConsumerState<OhHellApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Backstop for players who quit without navigating back through
    // GameScreen/LobbyScreen's leave handling (e.g. force-quitting a
    // hosted session): stop the embedded server before the process is
    // torn down so its HttpServer doesn't outlive this widget tree.
    if (state == AppLifecycleState.detached) {
      unawaited(ref.read(embeddedServerProvider.notifier).stop());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Oh Hell',
      theme: AppTheme.dark(),
      routerConfig: router,
    );
  }
}
