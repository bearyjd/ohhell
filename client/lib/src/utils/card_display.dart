// Utilities for converting protocol card enum names to display strings.

const _rankLabels = <String, String>{
  'two': '2',
  'three': '3',
  'four': '4',
  'five': '5',
  'six': '6',
  'seven': '7',
  'eight': '8',
  'nine': '9',
  'ten': '10',
  'jack': 'J',
  'queen': 'Q',
  'king': 'K',
  'ace': 'A',
};

/// Convert a suit enum name (e.g. "spades") to its Unicode symbol.
String suitSymbol(String suitName) => switch (suitName) {
      'spades' => '\u2660',
      'hearts' => '\u2665',
      'diamonds' => '\u2666',
      'clubs' => '\u2663',
      _ => '?',
    };

/// Convert a rank enum name (e.g. "ace") to its display label.
String rankDisplay(String rankName) =>
    _rankLabels[rankName] ?? rankName;
