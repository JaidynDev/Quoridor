import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'firebase_options.dart';
import 'models/user_model.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'services/guest_service.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/lobby/lobby_screen.dart';
import 'screens/friends/friends_screen.dart';
import 'screens/game/game_screen.dart';
import 'screens/game/board_preview_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print("Firebase initialization failed: $e");
    // Allow running without firebase for UI testing if needed, but warn user.
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<GuestService>(
          create: (_) => GuestService(),
        ),
        Provider<AuthService>(
          create: (context) {
            final auth = AuthService();
            auth.setGuestService(context.read<GuestService>());
            return auth;
          },
          dispose: (_, auth) => auth.dispose(),
        ),
        Provider<DatabaseService>(
          create: (_) => DatabaseService(),
        ),
        StreamProvider<AuthStatus>(
          create: (context) => context.read<AuthService>().status,
          initialData: const AuthStatus(),
        ),
        ProxyProvider<AuthStatus, AppUser?>(
          update: (_, status, __) => status.user,
        ),
      ],
      child: const AppRouter(),
    );
  }
}

class _AuthRefresh extends ChangeNotifier {
  AppUser? user;
  bool ready = false;

  void update(AppUser? next, {required bool ready}) {
    final changed =
        user?.id != next?.id || user?.isGuest != next?.isGuest || this.ready != ready;
    user = next;
    this.ready = ready;
    if (changed) notifyListeners();
  }
}

class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  final _authRefresh = _AuthRefresh();
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
      initialLocation: '/',
      refreshListenable: _authRefresh,
      redirect: (context, state) {
        final authState = _authRefresh.user;
        final path = state.uri.path;
        final isLoggingIn = path == '/login';
        final isPreview = path == '/preview';

        if (!_authRefresh.ready) return null;
        if (isPreview) return null;
        // Guests land on home. Accounts leave the sign-in screen.
        if (authState != null && !authState.isGuest && isLoggingIn) return '/';

        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const AuthScreen(),
        ),
        GoRoute(
          path: '/lobby',
          builder: (context, state) => const LobbyScreen(),
        ),
        GoRoute(
          path: '/friends',
          builder: (context, state) => const FriendsScreen(),
        ),
        GoRoute(
          path: '/preview',
          builder: (context, state) => const BoardPreviewScreen(),
        ),
        GoRoute(
          path: '/game/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return GameScreen(gameId: id);
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    _router.dispose();
    _authRefresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = context.watch<AuthStatus>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _authRefresh.update(status.user, ready: status.ready);
      }
    });

    return MaterialApp.router(
      title: 'Quoridor',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}
