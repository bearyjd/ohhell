import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ohhell_client/src/theme/app_theme.dart';
import 'package:ohhell_client/src/widgets/hand_widget.dart';
import 'package:ohhell_client/src/widgets/trick_pile_widget.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({required this.roomCode, super.key});

  final String roomCode;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  int? _selectedCardIndex;

  static const _dummyHand = <CardRecord>[
    (suit: '♠', rank: 'A', isPlayable: true),
    (suit: '♥', rank: 'K', isPlayable: true),
    (suit: '♦', rank: '7', isPlayable: true),
    (suit: '♣', rank: 'J', isPlayable: false),
    (suit: '♠', rank: '3', isPlayable: true),
  ];

  static const _dummyTrick = <TrickPlay>[
    (suit: '♠', rank: 'Q', playerName: 'Alice'),
    (suit: '♥', rank: '5', playerName: 'Bob'),
  ];

  void _onCardTap(int index) {
    setState(() {
      _selectedCardIndex =
          _selectedCardIndex == index ? null : index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Game — ${widget.roomCode}'),
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/scores/${widget.roomCode}'),
            icon: const Icon(Icons.scoreboard, color: AppColors.gold),
            label: const Text(
              'Scores',
              style: TextStyle(color: AppColors.gold),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _ScoreInfoBar(roomCode: widget.roomCode),
          Expanded(
            child: Center(
              child: TrickPileWidget(
                plays: _dummyTrick,
                trumpSuit: '♠',
              ),
            ),
          ),
          _HandArea(
            hand: _dummyHand,
            selectedIndex: _selectedCardIndex,
            onCardTap: _onCardTap,
          ),
        ],
      ),
    );
  }
}

class _ScoreInfoBar extends StatelessWidget {
  const _ScoreInfoBar({required this.roomCode});

  final String roomCode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF154A19),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _InfoChip(label: 'Round', value: '3'),
          _InfoChip(label: 'Trick', value: '2/5'),
          _InfoChip(label: 'Your Bid', value: '2'),
          _InfoChip(label: 'Taken', value: '1'),
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
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textOnDark,
            fontSize: 16,
            fontWeight: FontWeight.bold,
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
