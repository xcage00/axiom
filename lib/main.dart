import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/colors.dart';
import 'core/theme/theme_provider.dart';
import 'core/animations/widget_animations.dart';
import 'features/onboarding/screens/onboarding_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/auth_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://xxppgotrkdzhltgdtsqn.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh4cHBnb3Rya2R6aGx0Z2R0c3FuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY3ODk4MzUsImV4cCI6MjA5MjM2NTgzNX0.fGDnU_e_EdgeAT5su8_pM2Rslk64IYlVWw7zVCjRHWM',
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
              '/': (context) => const SplashDecision(),
              '/onboarding': (context) => const OnboardingScreen(),
              '/login': (context) => const LoginScreen(),
              '/home': (context) => const AuthWrapper(),
            },
          );
        },
      ),
    );
  }
}

class SplashDecision extends StatefulWidget {
  const SplashDecision({super.key});

  @override
  State<SplashDecision> createState() => _SplashDecisionState();
}

class _SplashDecisionState extends State<SplashDecision> {
  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

    // Simulate splash delay for smooth animation
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      if (hasSeenOnboarding) {
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        await prefs.setBool('hasSeenOnboarding', true);
        Navigator.pushReplacementNamed(context, '/onboarding');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: TweenAnimationBuilder(
          tween: Tween<double>(begin: 0.5, end: 1.0),
          duration: const Duration(milliseconds: 800),
          curve: Curves.elasticOut,
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.5),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.chat_bubble_outline,
                  size: 50,
                  color: Colors.white,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}