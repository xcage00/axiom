import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<User?> signUp(String email, String password) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );
      return response.user;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<User?> signIn(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      // Presence is best effort. A profile policy or transient network error
      // must not undo a successful authentication.
      if (response.user != null) {
        try {
          await _supabase
              .from('users')
              .update({
                'online_status': true,
                'last_seen': DateTime.now().toIso8601String(),
              })
              .eq('id', response.user!.id);
        } catch (_) {
          // Sign-in remains successful when presence cannot be updated.
        }
      }

      return response.user;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> signOut() async {
    final user = _supabase.auth.currentUser;

    if (user != null) {
      try {
        await _supabase
            .from('users')
            .update({
              'online_status': false,
              'last_seen': DateTime.now().toIso8601String(),
            })
            .eq('id', user.id);
      } catch (_) {
        // Sign-out must remain available if presence cannot be updated.
      }
    }

    await _supabase.auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  User? get currentUser => _supabase.auth.currentUser;
}
