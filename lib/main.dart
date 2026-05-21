import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/colors.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/profile_setup_screen.dart';
import 'features/home/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
await Supabase.initialize(
  url: 'https://xxppgotrkdzhltgdtsqn.supabase.co',
  anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh4cHBnb3Rya2R6aGx0Z2R0c3FuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY3ODk4MzUsImV4cCI6MjA5MjM2NTgzNX0.fGDnU_e_EdgeAT5su8_pM2Rslk64IYlVWw7zVCjRHWM',
  headers: {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  },
);
  runApp(const AxiomApp());
}

class AxiomApp extends StatelessWidget {
  const AxiomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Axiom',
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            themeMode: themeProvider.themeMode,
            debugShowCheckedModeBanner: false,
            initialRoute: '/',
            routes: {
              '/': (context) => const AuthWrapper(),
              '/login': (context) => const LoginScreen(),
              '/profile_setup': (context) => const ProfileSetupScreen(),
              '/home': (context) => const HomeScreen(),
            },
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Future<bool> _hasProfile(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();
      return response != null;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    
    if (session != null) {
      return FutureBuilder(
        future: _hasProfile(session.user.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
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
}