import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/colors.dart';
import 'login_screen.dart';
import '../../../features/home/screens/home_screen.dart';
import 'profile_setup_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  Future<bool>? _profileFuture;
  String? _checkedUserId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final session = Supabase.instance.client.auth.currentSession;

    if (session != null) {
      if (_checkedUserId != session.user.id || _profileFuture == null) {
        _checkedUserId = session.user.id;
        _profileFuture = _hasProfile(session.user.id);
      }
      return FutureBuilder(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(19),
                      ),
                      child: const Icon(
                        Icons.chat_bubble_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Getting your space ready',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cloud_off_rounded,
                          size: 42,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'We couldn’t check your profile',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Check your connection and try again.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: () => setState(
                            () => _profileFuture = _hasProfile(session.user.id),
                          ),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          if (snapshot.hasData && snapshot.data == true) {
            return const HomeScreen();
          } else {
            return const ProfileSetupScreen();
          }
        },
      );
    } else {
      return const LoginScreen();
    }
  }

  Future<bool> _hasProfile(String userId) async {
    final response = await Supabase.instance.client
        .from('users')
        .select('id')
        .eq('id', userId)
        .maybeSingle();
    return response != null;
  }
}
