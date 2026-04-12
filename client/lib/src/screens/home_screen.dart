import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ohhell_client/src/theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _playerNameController = TextEditingController();
  final _serverHostController = TextEditingController(
    text: 'localhost:8080',
  );
  final _joinCodeController = TextEditingController();

  @override
  void dispose() {
    _playerNameController.dispose();
    _serverHostController.dispose();
    _joinCodeController.dispose();
    super.dispose();
  }

  void _onCreateGame() {
    // Placeholder — no logic yet
    context.go('/lobby/NEW001');
  }

  void _onJoinGame() {
    // Placeholder — no logic yet
    final code = _joinCodeController.text.trim();
    context.go('/lobby/${code.isEmpty ? 'ABC123' : code}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.feltGreen,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Oh Hell',
                    style: Theme.of(context)
                        .textTheme
                        .displayMedium
                        ?.copyWith(
                          color: AppColors.gold,
                          letterSpacing: 3,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  TextField(
                    controller: _playerNameController,
                    style: const TextStyle(
                      color: AppColors.textOnDark,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Player Name',
                      hintText: 'Enter your name',
                      prefixIcon: Icon(
                        Icons.person,
                        color: AppColors.gold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _serverHostController,
                    style: const TextStyle(
                      color: AppColors.textOnDark,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Server Host',
                      hintText: 'localhost:8080',
                      prefixIcon: Icon(
                        Icons.dns,
                        color: AppColors.gold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: _onCreateGame,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Create Game'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _joinCodeController,
                          style: const TextStyle(
                            color: AppColors.textOnDark,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Room Code',
                            hintText: 'ABC123',
                          ),
                          textCapitalization:
                              TextCapitalization.characters,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _onJoinGame,
                        icon: const Icon(Icons.login),
                        label: const Text('Join'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
