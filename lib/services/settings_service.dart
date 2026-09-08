import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Play preferences that belong to this device rather than to a match.
///
/// Kept out of the game document on purpose: two people at the same table can
/// disagree about whether they want a confirm step.
class SettingsService extends ChangeNotifier {
  static const confirmWallsKey = 'settings_confirm_walls';
  static const confirmMovesKey = 'settings_confirm_moves';
  static const moveHintsKey = 'settings_move_hints';
  static const hapticsKey = 'settings_haptics';

  bool _confirmWalls = true;
  bool _confirmMoves = false;
  bool _moveHints = true;
  bool _haptics = true;
  bool _loaded = false;

  /// Drag a wall, then commit it with a button instead of on release.
  bool get confirmWalls => _confirmWalls;

  /// Tap a square, then commit the step with a button.
  bool get confirmMoves => _confirmMoves;

  /// Glow the squares your pawn can reach on your turn.
  bool get moveHints => _moveHints;

  /// Buzz when a move or wall is committed.
  bool get haptics => _haptics;

  bool get loaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _confirmWalls = prefs.getBool(confirmWallsKey) ?? true;
    _confirmMoves = prefs.getBool(confirmMovesKey) ?? false;
    _moveHints = prefs.getBool(moveHintsKey) ?? true;
    _haptics = prefs.getBool(hapticsKey) ?? true;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setConfirmWalls(bool value) {
    if (_confirmWalls == value) return Future.value();
    _confirmWalls = value;
    return _persist(confirmWallsKey, value);
  }

  Future<void> setConfirmMoves(bool value) {
    if (_confirmMoves == value) return Future.value();
    _confirmMoves = value;
    return _persist(confirmMovesKey, value);
  }

  Future<void> setMoveHints(bool value) {
    if (_moveHints == value) return Future.value();
    _moveHints = value;
    return _persist(moveHintsKey, value);
  }

  Future<void> setHaptics(bool value) {
    if (_haptics == value) return Future.value();
    _haptics = value;
    return _persist(hapticsKey, value);
  }

  Future<void> _persist(String key, bool value) async {
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }
}
