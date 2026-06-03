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
      
      // Update online status after successful login
      if (response.user != null) {
        await _supabase
            .from('users')
            .update({
              'online_status': true,
              'last_seen': DateTime.now().toIso8601String()
            })
            .eq('id', response.user!.id);
      }
      
      return response.user;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> signOut() async {
    final user = _supabase.auth.currentUser;
    
    // Update online status to false before logout
    if (user != null) {
      await _supabase
          .from('users')
          .update({
            'online_status': false,
            'last_seen': DateTime.now().toIso8601String()
          })
          .eq('id', user.id);
    }
    
    await _supabase.auth.signOut();
  }

  User? get currentUser => _supabase.auth.currentUser;
}