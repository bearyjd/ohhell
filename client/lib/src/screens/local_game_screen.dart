import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohhell_client/src/models/local_game_state.dart';
import 'package:ohhell_client/src/providers/local_game_provider.dart';
import 'package:ohhell_client/src/theme/app_theme.dart';
import 'package:ohhell_client/src/utils/card_display.dart';
import 'package:ohhell_client/src/widgets/hand_widget.dart';
import 'package:ohhell_client/src/widgets/trick_pile_widget.dart'
    as trick_pile;
import 'package:ohhell_engine/ohhell_engine.dart';

class LocalGameScreen extends ConsumerStatefulWidget {
  const LocalGameScreen({super.key});

  @override
  ConsumerState<LocalGameScreen> createState() => _LocalGameScreenState();
}

class _LocalGameScreenState extends ConsumerState<LocalGameScreen> {
  int? _selectedCardIndex;
  bool _bidDialogShowing = false;

  @override
  Widget build(BuildContext context) {
    final localState = ref.watch(localGameProvider);
    final gs = localState.gameState;
    final round = gs?.currentRound;

    // Navigate to local-scores when game is over.
    ref.listen(localGameProvider, (prev, next) {
      if (next.phase == LocalGamePhase.gameOver && mounted) {
        context.go('/local-scores');
      }

      // Show bid dialog when it becomes the human's turn to bid.
      if (next.phase == LocalGamePhase.bidding &&
          !_bidDialogShowing &&
          mounted) {
        final nextGs = next.gameState;
        final humanId = next.humanPlayerId;
        if (nextGs == null || humanId == null) return;
        final nextRound = nextGs.currentRound;
        if (nextRound == null) return;

        final isHumanTurn =
            nextGs.players[nextRound.currentPlayerIndex].id == humanId;
        final alreadyBid = nextRound.bids.containsKey(humanId);

        if (isHumanTurn && !alreadyBid) {
          _showBidDialog(context, nextRound.cardsPerHand);
        }
      }
    });

    if (gs == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Text(
            'No game in progress.',
            style: TextStyle(color: AppColors.textOnDark),
          ),
        ),
      );
    }

    final humanId = localState.humanPlayerId;

    // Build trick plays from current trick.
    final trickPlays = <trick_pile.TrickPlay>[];
    if (round != null) {
      for (final play in round.currentTrick.plays) {
        final playerName = gs.players
                .where((p) => p.id == play.playerId)
                .firstOrNull
                ?.name ??
            play.playerId;
        trickPlays.add((
          suit: play.card.suit.symbol,
          rank: rankDisplay(play.card.rank.name),
          playerName: playerName,
        ));
      }
    }

    final trumpDisplay = round?.trumpSuit?.symbol;

    // Build human's hand cards.
    final legalCards = localState.phase == LocalGamePhase.playing
        ? ref.read(localGameProvider.notifier).legalCardsForHuman()
        : <PlayingCard>[];
    final legalSet = legalCards.toSet();

    final humanPlayer = humanId != null
        ? gs.players.firstWhere(
            (p) => p.id == humanId,
            orElse: () => const Player(id: '', name: ''),
          )
        : null;

    final isHumanTurnToPlay = humanId != null &&
        round != null &&
        localState.phase == LocalGamePhase.playing &&
        gs.players[round.currentPlayerIndex].id == humanId;

    final handRecords = humanPlayer != null && humanPlayer.id.isNotEmpty
        ? humanPlayer.hand
            .map(
              (c) => (
                suit: c.suit.symbol,
                rank: rankDisplay(c.rank.name),
                isPlayable: isHumanTurnToPlay && legalSet.contains(c),
              ),
            )
            .toList()
        : <CardRecord>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.appBar,
        title: Text(
          round != null
              ? 'Round ${round.roundNumber}'
              : 'Local Game',
          style: const TextStyle(color: AppColors.amber),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.amber),
            tooltip: 'Quit game',
            onPressed: () {
              ref.read(localGameProvider.notifier).reset();
              context.go('/home');
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _ScoreBar(
                players: gs.players,
                currentPlayerIndex:
                    round?.currentPlayerIndex ?? -1,
                humanPlayerId: humanId,
              ),
              if (localState.awaitingBot)
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 16,
                  ),
                  color: AppColors.surface,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.amber,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Bot is thinking\u2026',
                        style: TextStyle(
                          color: AppColors.amber,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: Center(
                  child: trick_pile.TrickPileWidget(
                    plays: trickPlays,
                    trumpSuit: trumpDisplay,
                  ),
                ),
              ),
              _HandArea(
                hand: handRecords,
                selectedIndex: _selectedCardIndex,
                isHumanTurn: isHumanTurnToPlay,
                onCardTap: _onCardTap,
              ),
            ],
          ),
          // Round-end overlay.
          if (localState.phase == LocalGamePhase.roundEnd)
            _RoundEndOverlay(
              players: gs.players,
              onNextRound: () =>
                  ref.read(localGameProvider.notifier).dealNextRound(),
            ),
        ],
      ),
    );
  }

  void _onCardTap(int index) {
    final localState = ref.read(localGameProvider);
    final gs = localState.gameState;
    if (gs == null) return;
    if (localState.phase != LocalGamePhase.playing) return;

    final humanId = localState.humanPlayerId;
    if (humanId == null) return;

    final round = gs.currentRound;
    if (round == null) return;
    if (gs.players[round.currentPlayerIndex].id != humanId) return;

    final humanPlayer = gs.players.firstWhere(
      (p) => p.id == humanId,
      orElse: () => const Player(id: '', name: ''),
    );
    if (humanPlayer.id.isEmpty) return;
    if (index < 0 || index >= humanPlayer.hand.length) return;

    final legalCards =
        ref.read(localGameProvider.notifier).legalCardsForHuman();
    final card = humanPlayer.hand[index];
    if (!legalCards.contains(card)) return;

    setState(() => _selectedCardIndex = null);
    ref.read(localGameProvider.notifier).humanPlayCard(card);
  }

  void _showBidDialog(BuildContext context, int cardsPerHand) {
    _bidDialogShowing = true;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Place Your Bid',
                style: TextStyle(
                  color: AppColors.amber,
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
                        ref
                            .read(localGameProvider.notifier)
                            .humanPlaceBid(i);
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
    ).whenComplete(() {
      if (mounted) {
        setState(() => _bidDialogShowing = false);
      }
    });
  }
}

// ---------------------------------------------------------------------------
// Score bar at the top showing all players' status.
// ---------------------------------------------------------------------------

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({
    required this.players,
    required this.currentPlayerIndex,
    required this.humanPlayerId,
  });

  final List<Player> players;
  final int currentPlayerIndex;
  final String? humanPlayerId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      color: AppColors.appBar,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int i = 0; i < players.length; i++)
              _PlayerChip(
                player: players[i],
                isCurrentTurn: i == currentPlayerIndex,
                isHuman: players[i].id == humanPlayerId,
              ),
          ],
        ),
      ),
    );
  }
}

class _PlayerChip extends StatelessWidget {
  const _PlayerChip({
    required this.player,
    required this.isCurrentTurn,
    required this.isHuman,
  });

  final Player player;
  final bool isCurrentTurn;
  final bool isHuman;

  @override
  Widget build(BuildContext context) {
    final bidText = player.bid != null ? '${player.bid}' : '?';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isCurrentTurn
            ? AppColors.amber.withAlpha(51)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentTurn ? AppColors.amber : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isHuman)
                const Padding(
                  padding: EdgeInsets.only(right: 2),
                  child: Icon(
                    Icons.person,
                    color: AppColors.amber,
                    size: 12,
                  ),
                ),
              Text(
                player.name,
                style: TextStyle(
                  color: isCurrentTurn
                      ? AppColors.amber
                      : AppColors.textOnDark,
                  fontSize: 12,
                  fontWeight: isCurrentTurn
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Bid: $bidText  Won: ${player.tricksWon}',
            style: const TextStyle(
              color: AppColors.textOnDark,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hand area at the bottom.
// ---------------------------------------------------------------------------

class _HandArea extends StatelessWidget {
  const _HandArea({
    required this.hand,
    required this.selectedIndex,
    required this.isHumanTurn,
    required this.onCardTap,
  });

  final List<CardRecord> hand;
  final int? selectedIndex;
  final bool isHumanTurn;
  final void Function(int index) onCardTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF154A19),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isHumanTurn ? 'Your turn — tap a card' : 'Your Hand',
            style: TextStyle(
              color: isHumanTurn ? AppColors.amber : AppColors.gold,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: HandWidget(
              cards: hand,
              selectedIndex: selectedIndex,
              onCardTap: isHumanTurn ? onCardTap : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Round-end overlay.
// ---------------------------------------------------------------------------

class _RoundEndOverlay extends StatelessWidget {
  const _RoundEndOverlay({
    required this.players,
    required this.onNextRound,
  });

  final List<Player> players;
  final VoidCallback onNextRound;

  @override
  Widget build(BuildContext context) {
    final sorted = [...players]
      ..sort((a, b) => b.totalScore.compareTo(a.totalScore));

    return ColoredBox(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.amber.withAlpha(80)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Round Over',
                style: TextStyle(
                  color: AppColors.amber,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              for (final p in sorted)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        p.name,
                        style: const TextStyle(
                          color: AppColors.textOnDark,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${p.totalScore} pts',
                        style: const TextStyle(
                          color: AppColors.amber,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onNextRound,
                  child: const Text('Next Round'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
