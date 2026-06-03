import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../data/services/auth_service.dart';

final ImagePicker _picker = ImagePicker();

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  File? _avatarFile;
  
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _authService.currentUser;
    if (user == null) return;
    
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

  Future<void> _pickAndUploadAvatar() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      
      setState(() => _avatarFile = File(picked.path));
      
      final user = _authService.currentUser;
      final file = File(picked.path);
      final fileName = 'avatar_${user!.id}.jpg';
      
      // Upload to Supabase
      await Supabase.instance.client.storage.from('avatars').upload(fileName, file);
      final imageUrl = Supabase.instance.client.storage.from('avatars').getPublicUrl(fileName);
      
      // Update user record
      await Supabase.instance.client
          .from('users')
          .update({'avatar_url': imageUrl})
          .eq('id', user.id);
      
      await _loadUserData();
      setState(() => _avatarFile = null);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar updated!'), backgroundColor: AppColors.primary),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final user = _authService.currentUser;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // Edit profile - simple version
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Avatar
                  GestureDetector(
                    onTap: _pickAndUploadAvatar,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: AppColors.primary.withOpacity(0.2),
                          backgroundImage: _avatarFile != null
                              ? FileImage(_avatarFile!)
                              : (_userData?['avatar_url'] != null
                                  ? NetworkImage(_userData!['avatar_url'])
                                  : null) as ImageProvider?,
                          child: (_avatarFile == null && _userData?['avatar_url'] == null)
                              ? Text(
                                  (_userData?['full_name'] ?? 'U')[0].toUpperCase(),
                                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: AppColors.primary),
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _userData?['full_name'] ?? '',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '@${_userData?['username'] ?? ''}',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_userData?['bio'] != null && _userData?['bio'].isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        _userData?['bio'] ?? '',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? AppColors.darkText : AppColors.lightText,
                        ),
                      ),
                    ),
                  const SizedBox(height: 32),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.email_outlined),
                            const SizedBox(width: 12),
                            Expanded(child: Text(user?.email ?? '')),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today),
                            const SizedBox(width: 12),
                            const Text('Member since 2024'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}