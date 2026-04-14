import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohhell_client/src/providers/game_provider.dart';
import 'package:ohhell_client/src/providers/session_provider.dart';
import 'package:ohhell_client/src/providers/ws_provider.dart';
import 'package:ohhell_client/src/theme/app_theme.dart';
import 'package:ohhell_client/src/widgets/network_status_overlay.dart';
import 'package:ohhell_protocol/ohhell_protocol.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({required this.roomCode, super.key});

  final String roomCode;

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final gameState = ref.watch(gameStateProvider);
    final players = gameState?.players ?? <PlayerDto>[];

    ref.listen(gameStateProvider, (prev, next) {
      if (next == null) return;
      final phase = next.phase;
      if (phase == 'dealing' ||
          phase == 'bidding' ||
          phase == 'playing') {
        if (mounted) {
          context.go('/game/${widget.roomCode}');
        }
      }
    });

    return NetworkStatusOverlay(
      child: Scaffold(
        appBar: AppBar(
          title: Text('Lobby \u2014 ${widget.roomCode}'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              ref.read(wsProvider.notifier).disconnect();
              ref.read(sessionProvider.notifier).reset();
              context.go('/home');
            },
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _RoomCodeCard(roomCode: widget.roomCode),
              const SizedBox(height: 24),
              Text(
                'Players',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: players.isEmpty
                    ? const Center(
                        child: Text(
                          'Waiting for players...',
                          style: TextStyle(
                            color: AppColors.textOnDark,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: players.length,
                        itemBuilder: (context, index) {
                          final player = players[index];
                          return _PlayerTile(
                            name: player.name,
                            isHost: index == 0,
                          );
                        },
                      ),
              ),
              if (session.error != null) ...[
                const SizedBox(height: 8),
                Text(
                  session.error!,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed:
                    session.isHost && players.length >= 2
                        ? () => ref
                              .read(wsProvider.notifier)
                              .send(const StartGameMessage())
                        : null,
                child: const Text('Start Game'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomCodeCard extends StatelessWidget {
  const _RoomCodeCard({required this.roomCode});

  final String roomCode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 16,
        horizontal: 24,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF2E7D32),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withAlpha(128)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Room Code',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          Text(
            roomCode,
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(
                  color: AppColors.gold,
                  letterSpacing: 4,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({
    required this.name,
    required this.isHost,
  });

  final String name;
  final bool isHost;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(
        vertical: 12,
        horizontal: 16,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF2E7D32),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.person,
            color:
                isHost ? AppColors.gold : AppColors.textOnDark,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          if (isHost)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.gold.withAlpha(51),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.gold),
              ),
              child: const Text(
                'HOST',
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
