import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'firebase_options.dart';
import 'models/user_model.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/lobby/lobby_screen.dart';
import 'screens/friends/friends_screen.dart';
import 'screens/game/game_screen.dart';

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
        Provider<AuthService>(
          create: (_) => AuthService(),
        ),
        Provider<DatabaseService>(
          create: (_) => DatabaseService(),
        ),
        StreamProvider<AppUser?>(
          create: (context) => context.read<AuthService>().user,
          initialData: null,
        ),
      ],
      child: const AppRouter(),
    );
  }
}

class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AppUser?>();
    
    final GoRouter _router = GoRouter(
      initialLocation: '/',
      redirect: (context, state) {
        final isLoggedIn = authState != null;
        final isLoggingIn = state.uri.toString() == '/login';
        
        if (!isLoggedIn && !isLoggingIn) return '/login';
        if (isLoggedIn && isLoggingIn) return '/';
        
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
          path: '/game/:id',
          builder: (context, state) {
             final id = state.pathParameters['id']!;
             return GameScreen(gameId: id);
          },
        ),
      ],
    );

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
