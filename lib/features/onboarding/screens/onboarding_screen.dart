import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingData> _pages = [
    OnboardingData(
      title: 'Welcome to Axiom',
      description:
          'A thoughtful place for the conversations\nthat bring you closer.',
      icon: Icons.chat_bubble_outline,
      color: AppColors.primary,
    ),
    OnboardingData(
      title: 'Stay in the moment',
      description: 'Keep up with your people through\nreal-time messaging.',
      icon: Icons.lock_outline,
      color: AppColors.secondary,
    ),
    OnboardingData(
      title: 'Share Stories & Moments',
      description:
          'Share photo moments with your circle\nand revisit them in Stories.',
      icon: Icons.bookmark_outline,
      color: AppColors.accent,
    ),
    OnboardingData(
      title: 'Real-time Voice & Video',
      description: 'Bring a conversation closer with\nvoice and video calls.',
      icon: Icons.call_outlined,
      color: AppColors.primary,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Animated background particles
          ...List.generate(30, (index) {
            return Positioned(
              left: (index * 50) % MediaQuery.of(context).size.width,
              top: (index * 30) % MediaQuery.of(context).size.height,
              child: TweenAnimationBuilder(
                tween: Tween<double>(begin: 0, end: 1),
                duration: Duration(seconds: 2 + (index % 3)),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: 0.3 * (value * 0.5 + 0.2),
                    child: Container(
                      width: 2,
                      height: 2,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: .45),
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                },
              ),
            );
          }),

          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              final page = _pages[index];
              return AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  double offset = 0.0;
                  if (_pageController.hasClients) {
                    offset = (_pageController.page ?? 0) - index;
                  }
                  return Transform.scale(
                    scale: 1.0 - offset.abs() * 0.2,
                    child: Opacity(
                      opacity: 1.0 - offset.abs() * 0.5,
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    page.color,
                                    page.color.withValues(alpha: 0.5),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(40),
                                boxShadow: [
                                  BoxShadow(
                                    color: page.color.withValues(alpha: 0.32),
                                    blurRadius: 30,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Icon(
                                page.icon,
                                size: 70,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 48),
                            Text(
                              page.title,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              page.description,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: colors.onSurfaceVariant,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),

          // Bottom indicator & buttons
          Positioned(
            bottom: 20 + MediaQuery.paddingOf(context).bottom,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pages.length, (index) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      width: _currentPage == index ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? colors.primary
                            : colors.outline,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 30),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    children: [
                      if (_currentPage < _pages.length - 1)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeOutCubic,
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colors.onSurface,
                              side: BorderSide(color: colors.outline),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              'Next',
                              style: TextStyle(color: colors.onSurface),
                            ),
                          ),
                        ),
                      if (_currentPage == _pages.length - 1)
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              // Navigate to login
                              Navigator.pushReplacementNamed(context, '/login');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Get Started',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      const SizedBox(width: 16),
                      if (_currentPage < _pages.length - 1)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pushReplacementNamed(context, '/login');
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colors.onSurface,
                              side: BorderSide(color: colors.outline),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              'Skip',
                              style: TextStyle(color: colors.onSurfaceVariant),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingData {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  OnboardingData({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}
