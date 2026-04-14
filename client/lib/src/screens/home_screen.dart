import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohhell_client/src/providers/embedded_server_provider.dart';
import 'package:ohhell_client/src/providers/session_provider.dart';
import 'package:ohhell_client/src/providers/ws_provider.dart';
import 'package:ohhell_client/src/theme/app_theme.dart';
import 'package:ohhell_client/src/widgets/suit_symbols_row.dart';
import 'package:ohhell_protocol/ohhell_protocol.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const _defaultServerHost = 'localhost:8080';

  final _playerNameController = TextEditingController();
  final _serverHostController = TextEditingController(
    text: _defaultServerHost,
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

  Widget _buildHostSection(EmbeddedServerStatus serverStatus) {
    return switch (serverStatus) {
      ServerRunning() => _buildRunningCard(serverStatus),
      ServerError(:final message) => _buildServerErrorBanner(message),
      ServerStarting() || ServerIdle() => _buildStartButton(serverStatus),
    };
  }

  Widget _buildRunningCard(ServerRunning serverStatus) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.amber.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.amber.withAlpha(120)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wifi, color: AppColors.amber, size: 16),
              const SizedBox(width: 6),
              const Text(
                'Hosting on this device',
                style: TextStyle(
                  color: AppColors.amber,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () =>
                    ref.read(embeddedServerProvider.notifier).stop(),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.suitRed,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Stop'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Share: ${serverStatus.sharedAddress}',
                  style: const TextStyle(
                    color: AppColors.textOnDark,
                    fontSize: 13,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.copy,
                  size: 16,
                  color: AppColors.amber,
                ),
                onPressed: () => Clipboard.setData(
                  ClipboardData(text: serverStatus.sharedAddress),
                ),
                tooltip: 'Copy address',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServerErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withAlpha(120)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () =>
                ref.read(embeddedServerProvider.notifier).start(),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.amber,
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton(EmbeddedServerStatus serverStatus) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: serverStatus is ServerStarting
            ? null
            : () => ref.read(embeddedServerProvider.notifier).start(),
        icon: serverStatus is ServerStarting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.router_outlined),
        label: Text(
          serverStatus is ServerStarting
              ? 'Starting...'
              : 'Host on this device',
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.amber,
          side: BorderSide(color: AppColors.amber.withAlpha(120)),
        ),
      ),
    );
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

    final serverStatus = ref.watch(embeddedServerProvider);

    ref.listen(embeddedServerProvider, (prev, next) {
      if (next is ServerRunning &&
          (_serverHostController.text == _defaultServerHost ||
              _serverHostController.text.isEmpty)) {
        _serverHostController.text = next.localAddress;
      } else if (prev is ServerRunning && next is ServerIdle) {
        _serverHostController.text = _defaultServerHost;
      }
    });

    final errorText = switch (wsStatus) {
      WsError(:final message) => message,
      _ => session.error,
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.appBar,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SuitSymbolsRow(fontSize: 24),
                  const SizedBox(height: 8),
                  Text(
                    'Oh Hell',
                    style: Theme.of(context)
                        .textTheme
                        .displayMedium
                        ?.copyWith(
                          color: AppColors.amber,
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
                        color: AppColors.amber,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildHostSection(serverStatus),
                  const SizedBox(height: 8),
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
                        color: AppColors.amber,
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
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isConnecting ? null : _onCreateGame,
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
                        _isConnecting ? 'Connecting...' : 'Create Game',
                      ),
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
                        onPressed: _isConnecting ? null : _onJoinGame,
                        icon: const Icon(Icons.login),
                        label: const Text('Join'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Divider(color: AppColors.amber.withAlpha(80)),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/local-game/setup'),
                    icon: const Icon(Icons.smart_toy_outlined),
                    label: const Text('Play vs Bots'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textOnDark,
                      side: BorderSide(
                        color: AppColors.amber.withAlpha(120),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('scorekeeper_button'),
                    onPressed: () => context.go('/scorer/setup'),
                    icon: const Icon(Icons.score),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.amber,
                      side: const BorderSide(color: AppColors.amber),
                    ),
                    label: const Text('Scorekeeper'),
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
