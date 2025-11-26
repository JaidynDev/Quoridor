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
        ),
        Provider<DatabaseService>(
          create: (_) => DatabaseService(),
        ),
        StreamProvider<AppUser?>(
          create: (context) => _createUserStream(context),
          initialData: null,
        ),
      ],
      child: const AppRouter(),
    );
  }

  Stream<AppUser?> _createUserStream(BuildContext context) async* {
    final authService = context.read<AuthService>();
    final guestService = context.read<GuestService>();
    
    // Get initial guest user (in case there's no auth)
    final initialGuest = await guestService.getGuestUser();
    
    // Listen to auth state changes
    await for (final authUser in authService.user) {
      if (authUser != null) {
        // Authenticated user - yield them
        yield authUser;
      } else {
        // No authenticated user - use guest
        yield initialGuest;
      }
    }
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
        final isLoggingIn = state.uri.toString() == '/login';
        
        // Allow access if user exists (authenticated or guest) or if on login page
        if (authState == null && !isLoggingIn) return '/login';
        if (authState != null && isLoggingIn && !authState.isGuest) return '/';
        
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
