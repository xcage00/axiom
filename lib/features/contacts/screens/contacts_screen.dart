import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../chat/screens/chat_detail_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    
    final currentUser = Supabase.instance.client.auth.currentUser;
    
    final response = await Supabase.instance.client
        .from('users')
        .select()
        .neq('id', currentUser!.id);
    
    setState(() {
      _users = List<Map<String, dynamic>>.from(response);
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchQuery.isEmpty) return _users;
    return _users.where((user) {
      final name = user['full_name'].toLowerCase();
      final username = user['username'].toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || username.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    
    return Scaffold(
      backgroundColor: isDark ? AxiomColors.darkBackground : AxiomColors.lightBackground,
      appBar: AppBar(
        title: const Text('Contacts'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AxiomColors.darkSurface : AxiomColors.lightSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                style: TextStyle(
                  color: isDark ? AxiomColors.darkText : AxiomColors.lightText,
                ),
                decoration: InputDecoration(
                  hintText: 'Search users...',
                  hintStyle: TextStyle(
                    color: isDark ? AxiomColors.darkTextSecondary : AxiomColors.lightTextSecondary,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: isDark ? AxiomColors.darkTextSecondary : AxiomColors.lightTextSecondary,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          
          // Users list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 64,
                              color: isDark ? AxiomColors.darkTextSecondary : AxiomColors.lightTextSecondary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No users found',
                              style: TextStyle(
                                color: isDark ? AxiomColors.darkTextSecondary : AxiomColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          return _buildUserTile(user, isDark);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatDetailScreen(
                contactId: user['id'],
                contactName: user['full_name'],
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AxiomColors.darkSurface : AxiomColors.lightSurface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AxiomColors.accent.withOpacity(0.1),
                ),
                child: Center(
                  child: Text(
                    user['full_name'][0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AxiomColors.accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // User info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user['full_name'],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AxiomColors.darkText : AxiomColors.lightText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${user['username']}',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AxiomColors.darkTextSecondary : AxiomColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Chat button
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AxiomColors.accent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chat_bubble_outline,
                  size: 20,
                  color: AxiomColors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}