import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workspace/models/game_model.dart';
import 'package:workspace/models/quoridor_logic.dart';
import 'package:workspace/models/user_model.dart';
import 'package:workspace/screens/game/game_screen.dart';
import 'package:workspace/services/database_service.dart';
import 'package:workspace/services/settings_service.dart';

class _FakeDatabase extends DatabaseService {
  _FakeDatabase(this.game);

  GameModel game;
  final joined = <String>[];

  @override
  Stream<GameModel?> streamGame(String gameId) => Stream.value(game);

  @override
  Stream<List<AppUser>> streamUsersByIds(List<String> ids) =>
      Stream.value(const []);

  @override
  Stream<AppUser?> streamUser(String userId) => Stream.value(null);

  @override
  Future<void> joinGame(String gameId, String userId) async {
    joined.add(userId);
  }
}

GameModel _game({
  String status = 'waiting',
  List<String> playerIds = const ['host'],
  int seats = 2,
}) {
  return GameModel(
    id: 'game123',
    hostId: 'host',
    playerIds: playerIds,
    status: status,
    settings: GameSettings(playerCount: seats, timeLimitSeconds: 0),
    gameState: QuoridorLogic.initialState(seats),
  );
}

Future<_FakeDatabase> _open(
  WidgetTester tester, {
  required GameModel game,
  AppUser? user,
}) async {
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsService();
  await settings.load();
  final db = _FakeDatabase(game);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<DatabaseService>.value(value: db),
        ChangeNotifierProvider<SettingsService>.value(value: settings),
        Provider<AppUser?>.value(value: user),
      ],
      child: const MaterialApp(home: GameScreen(gameId: 'game123')),
    ),
  );
  await tester.pump();
  await tester.pump();
  return db;
}

AppUser _user(String id) => AppUser(id: id, email: '', username: id);

void main() {
  testWidgets('opening a link takes the free seat', (tester) async {
    final db = await _open(
      tester,
      game: _game(),
      user: _user('visitor'),
    );

    expect(db.joined, ['visitor']);
  });

  testWidgets('a player already at the table is not rejoined', (tester) async {
    final db = await _open(
      tester,
      game: _game(playerIds: const ['host']),
      user: _user('host'),
    );

    expect(db.joined, isEmpty);
  });

  testWidgets('a full table is watched, not joined', (tester) async {
    final db = await _open(
      tester,
      game: _game(playerIds: const ['host', 'rival']),
      user: _user('visitor'),
    );

    expect(db.joined, isEmpty);
    expect(find.textContaining('watching'), findsOneWidget);
  });

  testWidgets('a match already under way is not joined', (tester) async {
    final db = await _open(
      tester,
      game: _game(status: 'playing', playerIds: const ['host', 'rival']),
      user: _user('visitor'),
    );

    expect(db.joined, isEmpty);
  });

  testWidgets('nothing happens until a session exists', (tester) async {
    final db = await _open(tester, game: _game(), user: null);

    expect(db.joined, isEmpty);
  });

  testWidgets('the waiting room shows a link that opens the match',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _open(tester, game: _game(), user: _user('host'));

    expect(find.textContaining('#/game/game123'), findsOneWidget);
    expect(find.text('Share link'), findsOneWidget);
    expect(find.text('Copy link'), findsOneWidget);
  });
}
