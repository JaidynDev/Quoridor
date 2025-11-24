import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<AppUser?> get user {
    return _auth.authStateChanges().asyncMap((User? user) async {
      if (user == null) return null;
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        return AppUser.fromMap(doc.data()!, user.uid);
      }
      // Fallback if user exists in Auth but not Firestore (shouldn't happen in normal flow)
      return AppUser(id: user.uid, email: user.email ?? '', username: 'User');
    });
  }

  Future<AppUser?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      User? user = result.user;
      if (user != null) {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        return AppUser.fromMap(doc.data()!, user.uid);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<AppUser?> signUp(String email, String password, String username, String? photoUrl) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      User? user = result.user;
      if (user != null) {
        final newUser = AppUser(
          id: user.uid,
          email: email,
          username: username,
          photoUrl: photoUrl,
        );
        await _firestore.collection('users').doc(user.uid).set(newUser.toMap());
        return newUser;
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
  
  Future<void> updateProfile(String uid, {String? username, String? photoUrl}) async {
     final updates = <String, dynamic>{};
     if (username != null) updates['username'] = username;
     if (photoUrl != null) updates['photoUrl'] = photoUrl;
     
     if (updates.isNotEmpty) {
       await _firestore.collection('users').doc(uid).update(updates);
     }
  }
}
