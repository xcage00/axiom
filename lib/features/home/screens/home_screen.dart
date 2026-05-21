import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../data/services/auth_service.dart';
import '../../chat/screens/chats_list_screen.dart';
import '../../groups/screens/groups_list_screen.dart';
import '../../contacts/screens/contacts_screen.dart';
import '../../profile/screens/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  
  final List<Widget> _pages = [
    const ChatsListScreen(),
    const GroupsListScreen(),
    const ContactsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final authService = AuthService();
    
    return Scaffold(
      backgroundColor: isDark ? AxiomColors.darkBackground : AxiomColors.lightBackground,
      appBar: AppBar(
        title: const Text('Axiom'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: () => themeProvider.toggleTheme(),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authService.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AxiomColors.darkSurface : AxiomColors.lightSurface,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            type: BottomNavigationBarType.fixed,
            backgroundColor: isDark ? AxiomColors.darkSurface : AxiomColors.lightSurface,
            elevation: 0,
            selectedItemColor: AxiomColors.accent,
            unselectedItemColor: isDark ? AxiomColors.darkTextSecondary : AxiomColors.lightTextSecondary,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chats'),
              BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Groups'),
              BottomNavigationBarItem(icon: Icon(Icons.people_outline), label: 'Contacts'),
              BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }
}