import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workspace/models/game_model.dart';
import 'package:workspace/models/user_model.dart';
import 'package:workspace/screens/game/game_screen.dart';
import 'package:workspace/services/database_service.dart';
import 'package:workspace/services/settings_service.dart';

class _StreamingDatabase extends DatabaseService {
  _StreamingDatabase(this.games);

  final Stream<GameModel?> games;

  @override
  Stream<GameModel?> streamGame(String gameId) => games;

  @override
  Stream<List<AppUser>> streamUsersByIds(List<String> ids) =>
      Stream.value(const []);
}

Future<void> _open(WidgetTester tester, Stream<GameModel?> games) async {
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsService();
  await settings.load();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<DatabaseService>.value(value: _StreamingDatabase(games)),
        ChangeNotifierProvider<SettingsService>.value(value: settings),
        Provider<AppUser?>.value(value: null),
      ],
      child: const MaterialApp(home: GameScreen(gameId: 'missing123')),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('a link to a match that is gone says so', (tester) async {
    await _open(tester, Stream<GameModel?>.value(null));
    await tester.pump();

    expect(find.text('That match is not here'), findsOneWidget);
    expect(find.textContaining('missing123'), findsOneWidget);
    expect(find.text('Back to menu'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a read that fails explains itself', (tester) async {
    await _open(tester, Stream<GameModel?>.error(StateError('denied')));
    await tester.pump();

    expect(find.text('Could not open that match'), findsOneWidget);
    expect(find.textContaining('denied'), findsOneWidget);
  });

  testWidgets('a slow connection spins, then offers a way out', (tester) async {
    final controller = StreamController<GameModel?>();
    addTearDown(controller.close);

    await _open(tester, controller.stream);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Opening match'), findsOneWidget);
    expect(find.text('Back to menu'), findsNothing);

    await tester.pump(const Duration(seconds: 9));

    expect(find.text('Still reaching the table'), findsOneWidget);
    expect(find.text('Back to menu'), findsOneWidget);
  });
}
