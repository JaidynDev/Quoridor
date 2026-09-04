import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'guest_service.dart';

class AuthStatus {
  final AppUser? user;
  final bool ready;

  const AuthStatus({this.user, this.ready = false});
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  GuestService? _guestService;

  final _out = StreamController<AppUser?>.broadcast();
  final _firstEvent = Completer<void>();
  StreamSubscription<User?>? _authSub;
  bool _listening = false;
  bool _autoGuestBusy = false;
  AppUser? _current;

  /// True when Play as Guest fell back to a device-local id because
  /// Firebase Anonymous Auth is unavailable. Auth null events must not
  /// wipe that session.
  bool _localGuestActive = false;

  void setGuestService(GuestService guestService) {
    _guestService = guestService;
  }

  /// Signed-in account, explicit guest, or null on the login screen.
  Stream<AppUser?> get user => status.map((s) => s.user);

  Stream<AuthStatus> get status async* {
    _ensureListening();
    await _firstEvent.future;
    yield AuthStatus(user: _current, ready: true);
    yield* _out.stream.map((u) => AuthStatus(user: u, ready: true));
  }

  void _ensureListening() {
    if (_listening) return;
    _listening = true;
    _authSub = _auth.authStateChanges().listen((firebaseUser) async {
      try {
        if (firebaseUser == null) {
          if (_localGuestActive && _current != null) return;
          if (_autoGuestBusy) return;
          _autoGuestBusy = true;
          try {
            await playAsGuest();
          } finally {
            _autoGuestBusy = false;
          }
          return;
        }
        _emit(await _mapFirebaseUser(firebaseUser));
      } catch (_) {
        if (!_localGuestActive) {
          try {
            await playAsGuest();
          } catch (_) {
            _emit(null);
          }
        }
      }
    });
  }

  void _emit(AppUser? user) {
    _current = user;
    if (!_out.isClosed) _out.add(user);
    if (!_firstEvent.isCompleted) _firstEvent.complete();
  }

  Future<AppUser?> _mapFirebaseUser(User? user) async {
    if (user == null) {
      if (_localGuestActive) return _current;
      return null;
    }
    _localGuestActive = false;
    if (user.isAnonymous) return _guestFromAuth(user);

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      return AppUser.fromMap(doc.data()!, user.uid);
    }
    return AppUser(id: user.uid, email: user.email ?? '', username: 'User');
  }

  Future<AppUser> _guestFromAuth(User user) async {
    final local = await _guestService?.getGuestUser();
    final profile = AppUser(
      id: user.uid,
      email: '',
      username: local?.username ?? 'Guest',
      photoUrl: local?.photoUrl,
      isGuest: true,
    );
    try {
      await _firestore.collection('users').doc(user.uid).set(
        {
          'email': '',
          'username': profile.username,
          'photoUrl': profile.photoUrl,
          'isGuest': true,
        },
        SetOptions(merge: true),
      );
    } catch (_) {}
    return profile;
  }

  Future<AppUser?> signIn(String email, String password) async {
    _localGuestActive = false;
    UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email, password: password);
    User? user = result.user;
    if (user == null) return null;
    await _guestService?.clearGuestData();
    final mapped = await _mapFirebaseUser(user);
    _emit(mapped);
    return mapped;
  }

  Future<AppUser?> signUp(
    String email,
    String password,
    String username,
    String? photoUrl,
  ) async {
    _localGuestActive = false;
    User? user;
    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );

    if (_auth.currentUser?.isAnonymous == true) {
      user = (await _auth.currentUser!.linkWithCredential(credential)).user;
    } else {
      user = (await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      ))
          .user;
    }

    if (user == null) return null;
    await _guestService?.clearGuestData();
    final newUser = AppUser(
      id: user.uid,
      email: email,
      username: username,
      photoUrl: photoUrl,
    );
    await _firestore.collection('users').doc(user.uid).set(newUser.toMap());
    _emit(newUser);
    return newUser;
  }

  /// Explicit guest session for playing without an account.
  Future<AppUser> playAsGuest() async {
    try {
      final cred = await _auth.signInAnonymously();
      _localGuestActive = false;
      final guest = await _guestFromAuth(cred.user!);
      _emit(guest);
      return guest;
    } catch (_) {
      final guestService = _guestService;
      if (guestService == null) rethrow;
      _localGuestActive = true;
      final local = await guestService.getGuestUser();
      _emit(local);
      return local;
    }
  }

  /// Leaves an account session and continues as a guest.
  Future<void> signOut() async {
    _localGuestActive = false;
    await _guestService?.clearGuestData();
    if (_auth.currentUser != null) {
      await _auth.signOut();
    }
    if (_auth.currentUser == null && !(_current?.isGuest == true)) {
      await playAsGuest();
    }
  }

  Future<void> updateProfile(String uid,
      {String? username, String? photoUrl}) async {
    final updates = <String, dynamic>{};
    if (username != null) updates['username'] = username;
    if (photoUrl != null) updates['photoUrl'] = photoUrl;

    if (updates.isNotEmpty) {
      await _firestore.collection('users').doc(uid).update(updates);
    }
  }

  void dispose() {
    _authSub?.cancel();
    _out.close();
  }
}
