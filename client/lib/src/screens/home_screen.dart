import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohhell_client/src/providers/session_provider.dart';
import 'package:ohhell_client/src/providers/ws_provider.dart';
import 'package:ohhell_client/src/theme/app_theme.dart';
import 'package:ohhell_protocol/ohhell_protocol.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _playerNameController = TextEditingController();
  final _serverHostController = TextEditingController(
    text: 'localhost:8080',
  );
  final _joinCodeController = TextEditingController();
  bool _isConnecting = false;

  @override
  void dispose() {
    _playerNameController.dispose();
    _serverHostController.dispose();
    _joinCodeController.dispose();
    super.dispose();
  }

  Future<void> _connectAndJoin({String? roomCode}) async {
    final name = _playerNameController.text.trim();
    if (name.isEmpty) {
      ref.read(sessionProvider.notifier).setError('Enter a player name');
      return;
    }

    setState(() => _isConnecting = true);
    ref.read(sessionProvider.notifier).clearError();

    final host = _serverHostController.text.trim();
    await ref.read(wsProvider.notifier).connect(host);

    if (!mounted) return;

    final wsStatus = ref.read(wsProvider);
    if (wsStatus is WsError) {
      setState(() => _isConnecting = false);
      return;
    }

    ref.read(wsProvider.notifier).send(
          JoinRoomMessage(playerName: name, roomCode: roomCode),
        );
  }

  void _onCreateGame() {
    _connectAndJoin();
  }

  void _onJoinGame() {
    final code = _joinCodeController.text.trim();
    if (code.isEmpty) {
      ref.read(sessionProvider.notifier).setError('Enter a room code');
      return;
    }
    _connectAndJoin(roomCode: code);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final wsStatus = ref.watch(wsProvider);

    ref.listen(sessionProvider, (prev, next) {
      if (next.roomCode != null && prev?.roomCode == null) {
        if (mounted) {
          setState(() => _isConnecting = false);
          context.go('/lobby/${next.roomCode}');
        }
      }
    });

    ref.listen(wsProvider, (prev, next) {
      if (next is WsError) {
        if (mounted) {
          setState(() => _isConnecting = false);
        }
      }
    });

    final errorText = switch (wsStatus) {
      WsError(:final message) => message,
      _ => session.error,
    };

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
                  if (errorText != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withAlpha(51),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.error),
                      ),
                      child: Text(
                        errorText,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  ElevatedButton.icon(
                    onPressed:
                        _isConnecting ? null : _onCreateGame,
                    icon: _isConnecting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.add_circle_outline),
                    label: Text(
                      _isConnecting
                          ? 'Connecting...'
                          : 'Create Game',
                    ),
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
                        onPressed:
                            _isConnecting ? null : _onJoinGame,
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
