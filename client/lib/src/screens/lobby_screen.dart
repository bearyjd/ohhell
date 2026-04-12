import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ohhell_client/src/theme/app_theme.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({required this.roomCode, super.key});

  final String roomCode;

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  bool _isReady = false;

  // Placeholder player list
  static const _dummyPlayers = [
    (name: 'Alice', isReady: true, isHost: true),
    (name: 'Bob', isReady: false, isHost: false),
    (name: 'Charlie', isReady: true, isHost: false),
  ];

  void _onToggleReady() {
    setState(() {
      _isReady = !_isReady;
    });
  }

  void _onStartGame() {
    context.go('/game/${widget.roomCode}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Lobby — ${widget.roomCode}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
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
              child: ListView.builder(
                itemCount: _dummyPlayers.length,
                itemBuilder: (context, index) {
                  final player = _dummyPlayers[index];
                  return _PlayerTile(
                    name: player.name,
                    isReady: player.isReady,
                    isHost: player.isHost,
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _onToggleReady,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _isReady
                          ? Colors.greenAccent
                          : AppColors.textOnDark,
                      side: BorderSide(
                        color: _isReady
                            ? Colors.greenAccent
                            : AppColors.gold.withAlpha(128),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      _isReady ? 'Ready!' : 'Not Ready',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    // Placeholder: only host can start
                    onPressed: _onStartGame,
                    child: const Text('Start Game'),
                  ),
                ),
              ],
            ),
          ],
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
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
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
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
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
    required this.isReady,
    required this.isHost,
  });

  final String name;
  final bool isReady;
  final bool isHost;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF2E7D32),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.person,
            color: isHost ? AppColors.gold : AppColors.textOnDark,
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
          Icon(
            isReady ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isReady ? Colors.greenAccent : AppColors.textOnDark,
          ),
        ],
      ),
    );
  }
}
