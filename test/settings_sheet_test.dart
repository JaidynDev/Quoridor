import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workspace/services/settings_service.dart';
import 'package:workspace/widgets/settings_sheet.dart';

Future<SettingsService> _pumpSheet(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsService();
  await settings.load();

  await tester.pumpWidget(
    ChangeNotifierProvider<SettingsService>.value(
      value: settings,
      child: const MaterialApp(
        home: Scaffold(body: SettingsSheet()),
      ),
    ),
  );
  return settings;
}

void main() {
  testWidgets('settings sheet offers confirm wall placement plus the basics',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpSheet(tester);

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Confirm wall placement'), findsOneWidget);
    expect(find.text('Confirm pawn moves'), findsOneWidget);
    expect(find.text('Show move hints'), findsOneWidget);
    expect(find.text('Haptic feedback'), findsOneWidget);
    expect(find.text('How to play'), findsOneWidget);
  });

  testWidgets('toggling confirm wall placement updates the service',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final settings = await _pumpSheet(tester);
    expect(settings.confirmWalls, isTrue);

    await tester.tap(find.text('Confirm wall placement'));
    await tester.pumpAndSettle();

    expect(settings.confirmWalls, isFalse);

    await tester.tap(find.text('Confirm wall placement'));
    await tester.pumpAndSettle();

    expect(settings.confirmWalls, isTrue);
  });
}
