/// Thrown when a player attempts an illegal move.
class IllegalMoveException implements Exception {
  const IllegalMoveException(this.message);

  final String message;

  @override
  String toString() => 'IllegalMoveException: $message';
}

/// Thrown when game state is invalid for the requested operation.
class InvalidGameStateException implements Exception {
  const InvalidGameStateException(this.message);

  final String message;

  @override
  String toString() => 'InvalidGameStateException: $message';
}
