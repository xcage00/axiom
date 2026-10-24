import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  bool _isUploadingAvatar = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _authService.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('id, username, full_name, bio, avatar_url')
          .eq('id', user.id)
          .single();
      if (mounted) {
        setState(() {
          _userData = response;
          _loadError = null;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadError =
              'Your profile could not be loaded. Check your connection and try again.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    if (_isUploadingAvatar) return;
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null || !mounted) return;
      final user = _authService.currentUser;
      if (user == null) return;
      setState(() => _isUploadingAvatar = true);
      final bytes = await picked.readAsBytes();
      final path = '${user.id}/avatar';
      final storage = Supabase.instance.client.storage.from('avatars');
      await storage.uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(upsert: true),
      );
      final imageUrl =
          '${storage.getPublicUrl(path)}?v=${DateTime.now().millisecondsSinceEpoch}';
      await Supabase.instance.client
          .from('users')
          .update({'avatar_url': imageUrl})
          .eq('id', user.id);
      await _loadUserData();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile photo updated')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo could not be updated. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final user = _authService.currentUser;
    final themeProvider = context.watch<ThemeProvider>();
    final name = _userData?['full_name'] as String? ?? 'Axiom member';
    final username = _userData?['username'] as String? ?? '';
    final avatarUrl = _userData?['avatar_url'] as String?;
    final bio = _userData?['bio'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Profile',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh profile',
            onPressed: _loadUserData,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? _ProfileLoadError(message: _loadError!, onRetry: _loadUserData)
          : RefreshIndicator(
              onRefresh: _loadUserData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: colors.primary.withValues(alpha: .22),
                          blurRadius: 26,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Semantics(
                          button: true,
                          label: 'Change profile photo',
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _pickAndUploadAvatar,
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 48,
                                  backgroundColor: Colors.white.withValues(
                                    alpha: .2,
                                  ),
                                  backgroundImage:
                                      avatarUrl == null || avatarUrl.isEmpty
                                      ? null
                                      : NetworkImage(avatarUrl),
                                  onBackgroundImageError:
                                      avatarUrl == null || avatarUrl.isEmpty
                                      ? null
                                      : (_, _) {},
                                  child: avatarUrl == null || avatarUrl.isEmpty
                                      ? Text(
                                          name.isEmpty
                                              ? '?'
                                              : name.characters.first
                                                    .toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 34,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        )
                                      : null,
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: colors.surface,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: _isUploadingAvatar
                                        ? const Padding(
                                            padding: EdgeInsets.all(6),
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Icon(
                                            Icons.edit_rounded,
                                            size: 15,
                                            color: colors.primary,
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          name,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (username.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '@$username',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: .82),
                            ),
                          ),
                        ],
                        if (bio != null && bio.trim().isNotEmpty) ...[
                          const SizedBox(height: 14),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: Text(
                              bio,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  _ProfileSectionTitle(title: 'Account'),
                  const SizedBox(height: 10),
                  _ProfileTile(
                    icon: Icons.alternate_email_rounded,
                    title: 'Email address',
                    subtitle: user?.email ?? 'Not available',
                  ),
                  const SizedBox(height: 24),
                  _ProfileSectionTitle(title: 'Appearance'),
                  const SizedBox(height: 10),
                  Material(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(18),
                    child: SwitchListTile.adaptive(
                      secondary: Icon(
                        themeProvider.isDarkMode
                            ? Icons.dark_mode_rounded
                            : Icons.light_mode_rounded,
                        color: colors.primary,
                      ),
                      title: const Text('Dark appearance'),
                      subtitle: Text(
                        themeProvider.isDarkMode
                            ? 'Easy on the eyes at night'
                            : 'A brighter look for daytime',
                      ),
                      value: themeProvider.isDarkMode,
                      onChanged: (_) => themeProvider.toggleTheme(),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ProfileSectionTitle extends StatelessWidget {
  const _ProfileSectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
      ),
    ),
  );
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        leading: Icon(icon, color: colors.primary),
        title: Text(
          title,
          style: theme.textTheme.labelMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        subtitle: Text(subtitle, style: theme.textTheme.bodyMedium),
      ),
    );
  }
}

class _ProfileLoadError extends StatelessWidget {
  const _ProfileLoadError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 42),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}
