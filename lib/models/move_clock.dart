import 'game_model.dart';

/// The per-move clock a table agreed on when the match was created.
///
/// Everything is derived from `turnStartedAt`, which is written with the
/// server's clock, so all four seats count down together even if their
/// devices disagree about the time.
class MoveClock {
  /// A turn that has been over this long may be forced along by another
  /// player, which is how an abandoned match gets unstuck.
  static const Duration grace = Duration(seconds: 5);

  const MoveClock._();

  static bool isRunning(GameModel game) =>
      game.status == 'playing' &&
      game.settings.timeLimitSeconds > 0 &&
      game.turnStartedAt != null;

  static Duration? elapsed(GameModel game, {DateTime? now}) {
    final started = game.turnStartedAt;
    if (!isRunning(game) || started == null) return null;
    final since = (now ?? DateTime.now()).difference(started);
    return since.isNegative ? Duration.zero : since;
  }

  /// Time the player on turn has left, or null when no clock applies.
  static Duration? remaining(GameModel game, {DateTime? now}) {
    final since = elapsed(game, now: now);
    if (since == null) return null;
    final left = Duration(seconds: game.settings.timeLimitSeconds) - since;
    return left.isNegative ? Duration.zero : left;
  }

  /// How far past the limit this turn has run, or null when it has not.
  static Duration? overrun(GameModel game, {DateTime? now}) {
    final since = elapsed(game, now: now);
    if (since == null) return null;
    final over = since - Duration(seconds: game.settings.timeLimitSeconds);
    return over.isNegative ? null : over;
  }

  static bool hasExpired(GameModel game, {DateTime? now}) =>
      overrun(game, now: now) != null;

  /// True once anyone at the table may force the turn along.
  static bool isAbandoned(GameModel game, {DateTime? now}) {
    final over = overrun(game, now: now);
    return over != null && over >= grace;
  }

  static String label(Duration left) {
    // Rounded up so a fresh 60s turn reads 1:00 rather than 0:59, and only
    // shows zero once the time is actually gone.
    final total = (left.inMilliseconds / 1000).ceil();
    if (total >= 60) {
      final minutes = total ~/ 60;
      final seconds = (total % 60).toString().padLeft(2, '0');
      return '$minutes:$seconds';
    }
    return '${total}s';
  }
}
