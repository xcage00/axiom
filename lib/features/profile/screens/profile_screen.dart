import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../data/services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isEditing = false;
  
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _fullNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    
    final user = _authService.currentUser;
    
    if (user != null) {
      final response = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', user.id)
          .single();
      
      setState(() {
        _userData = response;
        _usernameController.text = response['username'] ?? '';
        _fullNameController.text = response['full_name'] ?? '';
        _bioController.text = response['bio'] ?? '';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    
    final user = _authService.currentUser;
    
    if (user != null) {
      await Supabase.instance.client
          .from('users')
          .update({
            'username': _usernameController.text.trim(),
            'full_name': _fullNameController.text.trim(),
            'bio': _bioController.text.trim(),
          })
          .eq('id', user.id);
      
      await _loadUserData();
    }
    
    setState(() {
      _isEditing = false;
      _isLoading = false;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile updated!'),
        backgroundColor: AxiomColors.accent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final user = _authService.currentUser;
    
    return Scaffold(
      backgroundColor: isDark ? AxiomColors.darkBackground : AxiomColors.lightBackground,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Profile' : 'Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: Icon(
                Icons.edit,
                color: isDark ? AxiomColors.darkText : AxiomColors.lightText,
              ),
              onPressed: () => setState(() => _isEditing = true),
            ),
          if (_isEditing)
            TextButton(
              onPressed: _updateProfile,
              child: Text(
                'Save',
                style: TextStyle(
                  color: AxiomColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Profile Photo
                  const SizedBox(height: 32),
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AxiomColors.accent.withOpacity(0.1),
                            border: Border.all(
                              color: AxiomColors.accent,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              (_userData?['full_name'] ?? 'U')[0].toUpperCase(),
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w600,
                                color: AxiomColors.accent,
                              ),
                            ),
                          ),
                        ),
                        if (_isEditing)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AxiomColors.accent,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Email
                  _buildInfoRow(
                    label: 'Email',
                    value: user?.email ?? '',
                    isEditing: false,
                    isDark: isDark,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Username
                  _buildInfoRow(
                    label: 'Username',
                    value: _userData?['username'] ?? '',
                    controller: _usernameController,
                    isEditing: _isEditing,
                    isDark: isDark,
                    prefix: '@',
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Full Name
                  _buildInfoRow(
                    label: 'Full Name',
                    value: _userData?['full_name'] ?? '',
                    controller: _fullNameController,
                    isEditing: _isEditing,
                    isDark: isDark,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Bio
                  _buildInfoRow(
                    label: 'Bio',
                    value: _userData?['bio'] ?? 'No bio yet',
                    controller: _bioController,
                    isEditing: _isEditing,
                    isDark: isDark,
                    maxLines: 3,
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Stats
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AxiomColors.darkSurface : AxiomColors.lightSurface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem('Member', 'Since 2024', isDark),
                        _buildStatItem('Status', 'Active', isDark),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    String? value,
    TextEditingController? controller,
    required bool isEditing,
    required bool isDark,
    String prefix = '',
    int maxLines = 1,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AxiomColors.darkSurface : AxiomColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AxiomColors.darkTextSecondary : AxiomColors.lightTextSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          if (isEditing && controller != null)
            TextField(
              controller: controller,
              style: TextStyle(
                color: isDark ? AxiomColors.darkText : AxiomColors.lightText,
              ),
              maxLines: maxLines,
              decoration: InputDecoration(
                hintText: label,
                hintStyle: TextStyle(
                  color: isDark ? AxiomColors.darkTextSecondary : AxiomColors.lightTextSecondary,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: isDark ? AxiomColors.darkBackground : Colors.white,
                contentPadding: const EdgeInsets.all(12),
              ),
            )
          else
            Text(
              prefix + (value ?? ''),
              style: TextStyle(
                fontSize: 16,
                color: isDark ? AxiomColors.darkText : AxiomColors.lightText,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String title, String value, bool isDark) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AxiomColors.darkTextSecondary : AxiomColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}