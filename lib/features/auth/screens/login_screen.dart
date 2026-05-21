import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../data/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  
  bool _isLogin = true;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String _errorMessage = '';

 Future<void> _handleAuth() async {
  setState(() {
    _errorMessage = '';
    _isLoading = true;
  });

  final email = _emailController.text.trim();
  final password = _passwordController.text.trim();

  if (email.isEmpty || password.isEmpty) {
    setState(() {
      _errorMessage = 'Please fill all fields';
      _isLoading = false;
    });
    return;
  }

  try {
    if (_isLogin) {
      await _authService.signIn(email, password);
      // After successful login, go to AuthWrapper which will check profile
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/');
      }
    } else {
      await _authService.signUp(email, password);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created! Please sign in.'),
            backgroundColor: AxiomColors.accent,
          ),
        );
        setState(() {
          _isLogin = true;
          _isLoading = false;
        });
        return;
      }
    }
  } catch (e) {
    setState(() {
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
    });
  }

  setState(() => _isLoading = false);
}

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    
    return Scaffold(
      backgroundColor: isDark ? AxiomColors.darkBackground : AxiomColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
              color: isDark ? AxiomColors.darkText : AxiomColors.lightText,
            ),
            onPressed: () {
              themeProvider.toggleTheme();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AxiomColors.accent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline,
                  size: 44,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 48),
              
              // Title
              Text(
                _isLogin ? 'Welcome Back' : 'Create Account',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AxiomColors.darkText : AxiomColors.lightText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isLogin ? 'Sign in to continue' : 'Join Axiom today',
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? AxiomColors.darkTextSecondary : AxiomColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 48),
              
              // Email field
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AxiomColors.darkSurface : AxiomColors.lightSurface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: _emailController,
                  style: TextStyle(
                    color: isDark ? AxiomColors.darkText : AxiomColors.lightText,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Email',
                    hintStyle: TextStyle(
                      color: isDark ? AxiomColors.darkTextSecondary : AxiomColors.lightTextSecondary,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
              ),
              const SizedBox(height: 16),
              
              // Password field
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AxiomColors.darkSurface : AxiomColors.lightSurface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: TextStyle(
                    color: isDark ? AxiomColors.darkText : AxiomColors.lightText,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Password',
                    hintStyle: TextStyle(
                      color: isDark ? AxiomColors.darkTextSecondary : AxiomColors.lightTextSecondary,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: isDark ? AxiomColors.darkTextSecondary : AxiomColors.lightTextSecondary,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    _errorMessage,
                    style: TextStyle(
                      color: AxiomColors.error,
                      fontSize: 13,
                    ),
                  ),
                ),
              
              const SizedBox(height: 24),
              
              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleAuth,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AxiomColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isLogin ? 'Sign In' : 'Sign Up',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Toggle between login and signup
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isLogin ? "Don't have an account?" : "Already have an account?",
                    style: TextStyle(
                      color: isDark ? AxiomColors.darkTextSecondary : AxiomColors.lightTextSecondary,
                      fontSize: 14,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isLogin = !_isLogin;
                        _errorMessage = '';
                      });
                    },
                    child: Text(
                      _isLogin ? 'Sign Up' : 'Sign In',
                      style: TextStyle(
                        color: AxiomColors.accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}