import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohhell_client/src/providers/game_provider.dart';
import 'package:ohhell_client/src/providers/session_provider.dart';
import 'package:ohhell_client/src/providers/ws_provider.dart';
import 'package:ohhell_client/src/theme/app_theme.dart';
import 'package:ohhell_client/src/utils/card_display.dart';
import 'package:ohhell_client/src/widgets/hand_widget.dart';
import 'package:ohhell_client/src/widgets/trick_pile_widget.dart';
import 'package:ohhell_protocol/ohhell_protocol.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({required this.roomCode, super.key});

  final String roomCode;

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  int? _selectedCardIndex;

  void _onCardTap(int index) {
    final gameState = ref.read(gameStateProvider);
    final session = ref.read(sessionProvider);
    if (gameState?.phase != 'playing') return;

    final hand = session.hand;
    if (index < 0 || index >= hand.length) return;

    final card = hand[index];
    ref.read(wsProvider.notifier).send(
          PlayCardMessage(suit: card.suit, rank: card.rank),
        );
  }

  void _showBidDialog(int cardsPerHand) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF154A19),
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Place Your Bid',
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (int i = 0; i <= cardsPerHand; i++)
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        ref.read(wsProvider.notifier).send(
                              PlaceBidMessage(bid: i),
                            );
                      },
                      child: Text('$i'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameStateProvider);
    final session = ref.watch(sessionProvider);
    final hand = session.hand;
    final playerId = session.playerId;

    ref.listen(gameStateProvider, (prev, next) {
      if (next == null) return;
      if (next.phase == 'round_end' || next.phase == 'game_end') {
        if (mounted) {
          context.go('/scores/${widget.roomCode}');
        }
      }
    });

    // Determine if it's bidding phase and our turn
    final round = gameState?.currentRound;
    final isBiddingPhase = gameState?.phase == 'bidding';
    final isPlayingPhase = gameState?.phase == 'playing';

    final needsBid = isBiddingPhase &&
        playerId != null &&
        round != null &&
        !round.bids.containsKey(playerId);

    // Show bid dialog when it's our turn in bidding phase
    if (needsBid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showBidDialog(round.cardsPerHand);
        }
      });
    }

    // Convert hand to CardRecord list
    final cardRecords = hand
        .map(
          (c) => (
            suit: suitSymbol(c.suit),
            rank: rankDisplay(c.rank),
            isPlayable: isPlayingPhase,
          ),
        )
        .toList();

    // Convert current trick to TrickPlay list
    final trickPlays = <TrickPlay>[];
    final currentTrick = round?.currentTrick;
    if (currentTrick != null) {
      final players = gameState?.players ?? [];
      for (final play in currentTrick.plays) {
        final playerName = players
                .where((p) => p.id == play.playerId)
                .firstOrNull
                ?.name ??
            play.playerId;
        trickPlays.add((
          suit: suitSymbol(play.card.suit),
          rank: rankDisplay(play.card.rank),
          playerName: playerName,
        ));
      }
    }

    final trumpDisplay =
        round?.trumpSuit != null
            ? suitSymbol(round!.trumpSuit!)
            : null;

    // Score info
    final myBid =
        playerId != null ? round?.bids[playerId] : null;
    final myTricks = gameState?.players
        .where((p) => p.id == playerId)
        .firstOrNull
        ?.tricksWon;

    return Scaffold(
      appBar: AppBar(
        title: Text('Game \u2014 ${widget.roomCode}'),
        actions: [
          TextButton.icon(
            onPressed: () =>
                context.go('/scores/${widget.roomCode}'),
            icon: const Icon(
              Icons.scoreboard,
              color: AppColors.gold,
            ),
            label: const Text(
              'Scores',
              style: TextStyle(color: AppColors.gold),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _ScoreInfoBar(
            roundNumber: round?.roundNumber,
            completedTricks: round?.completedTricks,
            cardsPerHand: round?.cardsPerHand,
            myBid: myBid,
            myTricks: myTricks,
          ),
          if (isBiddingPhase)
            Container(
              padding: const EdgeInsets.symmetric(
                vertical: 8,
                horizontal: 16,
              ),
              color: AppColors.gold.withAlpha(51),
              child: Text(
                needsBid
                    ? 'Your turn to bid!'
                    : 'Waiting for other players to bid...',
                style: const TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: Center(
              child: TrickPileWidget(
                plays: trickPlays,
                trumpSuit: trumpDisplay,
              ),
            ),
          ),
          _HandArea(
            hand: cardRecords,
            selectedIndex: _selectedCardIndex,
            onCardTap: _onCardTap,
          ),
        ],
      ),
    );
  }
}

class _ScoreInfoBar extends StatelessWidget {
  const _ScoreInfoBar({
    this.roundNumber,
    this.completedTricks,
    this.cardsPerHand,
    this.myBid,
    this.myTricks,
  });

  final int? roundNumber;
  final int? completedTricks;
  final int? cardsPerHand;
  final int? myBid;
  final int? myTricks;

  @override
  Widget build(BuildContext context) {
    final trickStr = cardsPerHand != null
        ? '${completedTricks ?? 0}/$cardsPerHand'
        : '-';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      color: const Color(0xFF154A19),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _InfoChip(
            label: 'Round',
            value: '${roundNumber ?? '-'}',
          ),
          _InfoChip(label: 'Trick', value: trickStr),
          _InfoChip(
            label: 'Your Bid',
            value: '${myBid ?? '-'}',
          ),
          _InfoChip(
            label: 'Taken',
            value: '${myTricks ?? 0}',
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.gold,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textOnDark,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class _HandArea extends StatelessWidget {
  const _HandArea({
    required this.hand,
    required this.selectedIndex,
    required this.onCardTap,
  });

  final List<CardRecord> hand;
  final int? selectedIndex;
  final void Function(int) onCardTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF154A19),
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Your Hand',
            style: TextStyle(
              color: AppColors.gold,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: HandWidget(
              cards: hand,
              selectedIndex: selectedIndex,
              onCardTap: onCardTap,
            ),
          ),
        ],
      ),
    );
  }
}
