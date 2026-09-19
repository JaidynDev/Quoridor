import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workspace/services/settings_service.dart';

void main() {
  test('confirm wall placement is on by default, confirm moves is not',
      () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService();
    await settings.load();

    expect(settings.confirmWalls, isTrue);
    expect(settings.confirmMoves, isFalse);
    expect(settings.moveHints, isTrue);
    expect(settings.haptics, isTrue);
    expect(settings.loaded, isTrue);
  });

  test('saved choices survive a reload', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService();
    await settings.load();

    await settings.setConfirmWalls(false);
    await settings.setConfirmMoves(true);
    await settings.setMoveHints(false);
    await settings.setHaptics(false);

    final reopened = SettingsService();
    await reopened.load();

    expect(reopened.confirmWalls, isFalse);
    expect(reopened.confirmMoves, isTrue);
    expect(reopened.moveHints, isFalse);
    expect(reopened.haptics, isFalse);
  });

  test('changing a setting notifies listeners once', () async {
    SharedPreferences.setMockInitialValues({
      SettingsService.confirmWallsKey: true,
    });
    final settings = SettingsService();
    await settings.load();

    var notifications = 0;
    settings.addListener(() => notifications++);

    await settings.setConfirmWalls(true); // already true, no work to do
    expect(notifications, 0);

    await settings.setConfirmWalls(false);
    expect(notifications, 1);
    expect(settings.confirmWalls, isFalse);
  });
}
