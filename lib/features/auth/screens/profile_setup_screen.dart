import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../data/services/auth_service.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _fullNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;
    final user = _authService.currentUser;
    if (user == null) {
      setState(
        () => _errorMessage = 'Your session expired. Please sign in again.',
      );
      return;
    }

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });
    try {
      await Supabase.instance.client.from('users').insert({
        'id': user.id,
        'username': _usernameController.text.trim().replaceFirst(
          RegExp(r'^@'),
          '',
        ),
        'full_name': _fullNameController.text.trim(),
        'bio': _bioController.text.trim(),
        'avatar_url': null,
        'online_status': true,
      });
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Profile could not be saved. The username may already be in use.';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Set up your profile',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: themeProvider.isDarkMode
                ? 'Switch to light theme'
                : 'Switch to dark theme',
            onPressed: themeProvider.toggleTheme,
            icon: Icon(
              themeProvider.isDarkMode
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 30),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(27),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.primary.withValues(alpha: .24),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.person_add_alt_1_rounded,
                              color: Colors.white,
                              size: 34,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Make it yours',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -.4,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            'Add the details your friends will recognize. You can add a profile photo later.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _fullNameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      maxLength: 80,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter your name'
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _usernameController,
                      textInputAction: TextInputAction.next,
                      maxLength: 30,
                      validator: (value) {
                        final username = (value ?? '').trim().replaceFirst(
                          RegExp(r'^@'),
                          '',
                        );
                        if (username.isEmpty) return 'Choose a username';
                        if (!RegExp(
                          r'^[A-Za-z0-9_]{3,30}$',
                        ).hasMatch(username)) {
                          return 'Use 3–30 letters, numbers, or underscores';
                        }
                        return null;
                      },
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        prefixText: '@',
                        prefixIcon: Icon(Icons.alternate_email_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _bioController,
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: 160,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'About you (optional)',
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Semantics(
                        liveRegion: true,
                        child: Container(
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: colors.errorContainer,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: colors.onErrorContainer),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: _isLoading ? null : _saveProfile,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Continue to Axiom'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
