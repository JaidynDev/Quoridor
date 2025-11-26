import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';

class GuestService {
  static const String _guestIdKey = 'guest_id';
  static const String _guestUsernameKey = 'guest_username';
  static const String _guestPhotoUrlKey = 'guest_photo_url';
  
  final _uuid = const Uuid();

  /// Get or create a guest user for this device
  Future<AppUser> getGuestUser() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Get or create guest ID
    String? guestId = prefs.getString(_guestIdKey);
    if (guestId == null || guestId.isEmpty) {
      guestId = 'guest_${_uuid.v4()}';
      await prefs.setString(_guestIdKey, guestId);
    }
    
    // Get or create guest username
    String username = prefs.getString(_guestUsernameKey) ?? 'Guest${guestId.substring(0, 6)}';
    
    // Get guest photo URL (optional, can be null)
    String? photoUrl = prefs.getString(_guestPhotoUrlKey);
    
    return AppUser(
      id: guestId,
      email: '', // Guest users don't have email
      username: username,
      photoUrl: photoUrl,
      isGuest: true,
    );
  }

  /// Update guest username
  Future<void> updateGuestUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_guestUsernameKey, username);
  }

  /// Update guest photo URL
  Future<void> updateGuestPhotoUrl(String? photoUrl) async {
    final prefs = await SharedPreferences.getInstance();
    if (photoUrl != null) {
      await prefs.setString(_guestPhotoUrlKey, photoUrl);
    } else {
      await prefs.remove(_guestPhotoUrlKey);
    }
  }

  /// Check if current user is a guest
  Future<bool> isGuest() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_guestIdKey);
  }

  /// Clear guest data (when user signs in)
  Future<void> clearGuestData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_guestIdKey);
    await prefs.remove(_guestUsernameKey);
    await prefs.remove(_guestPhotoUrlKey);
  }
}

