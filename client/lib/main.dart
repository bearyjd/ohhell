import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ohhell_client/src/router.dart';
import 'package:ohhell_client/src/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: OhHellApp()));
}

class OhHellApp extends StatelessWidget {
  const OhHellApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Oh Hell',
      theme: AppTheme.dark(),
      routerConfig: router,
    );
  }
}
