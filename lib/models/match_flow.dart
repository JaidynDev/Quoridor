import 'quoridor_logic.dart';

/// What a resignation does to the table.
class ResignationOutcome {
  final List<String> resignedIds;
  final int nextTurnIndex;

  /// Set when the resignation leaves a single player standing.
  final String? winnerId;

  /// False when the resignation changes nothing, e.g. a double tap.
  final bool changed;

  const ResignationOutcome({
    required this.resignedIds,
    required this.nextTurnIndex,
    this.winnerId,
    this.changed = true,
  });

  static const ResignationOutcome noop = ResignationOutcome(
    resignedIds: [],
    nextTurnIndex: 0,
    changed: false,
  );
}

/// Works out who is left and whose turn it is after [resignerId] walks away.
///
/// Kept free of Firestore so the turn-order rules can be tested directly.
ResignationOutcome resolveResignation({
  required List<String> playerIds,
  required List<String> resignedIds,
  required String resignerId,
  required int currentTurnIndex,
}) {
  if (!playerIds.contains(resignerId)) return ResignationOutcome.noop;
  if (resignedIds.contains(resignerId)) return ResignationOutcome.noop;

  final nextResigned = [...resignedIds, resignerId];
  final active = [
    for (final id in playerIds)
      if (!nextResigned.contains(id)) id,
  ];

  if (active.length <= 1) {
    return ResignationOutcome(
      resignedIds: nextResigned,
      nextTurnIndex: currentTurnIndex,
      winnerId: active.isEmpty ? null : active.first,
    );
  }

  final out = {
    for (var i = 0; i < playerIds.length; i++)
      if (nextResigned.contains(playerIds[i])) i,
  };

  // Only the player on turn leaving forces the table to move on.
  final nextTurn = out.contains(currentTurnIndex)
      ? QuoridorLogic.nextActiveSeat(
          currentTurnIndex,
          playerIds.length,
          out: out,
        )
      : currentTurnIndex;

  return ResignationOutcome(
    resignedIds: nextResigned,
    nextTurnIndex: nextTurn,
  );
}
