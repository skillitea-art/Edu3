import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../teacher/teacher_dashboard.dart';
import '../student/student_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  
  bool _isSignUp = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = true;
  String _selectedRole = 'student'; // Default role

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _fadeController.forward();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email') ?? '';
    final savedPassword = prefs.getString('saved_password') ?? '';
    final remember = prefs.getBool('remember_me') ?? true;

    if (remember && savedEmail.isNotEmpty) {
      setState(() {
        _emailController.text = savedEmail;
        _passwordController.text = savedPassword;
        _rememberMe = remember;
      });
    }
  }

  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString('saved_email', _emailController.text.trim());
      await prefs.setString('saved_password', _passwordController.text);
      await prefs.setBool('remember_me', true);
    } else {
      await prefs.remove('saved_email');
      await prefs.remove('saved_password');
      await prefs.setBool('remember_me', false);
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    bool success;

    if (_isSignUp) {
      success = await authProvider.signUp(
        _emailController.text.trim(),
        _passwordController.text,
        _nameController.text.trim(),
        _selectedRole,
      );
      
      if (success) {
        // Send email verification
        await authProvider.sendEmailVerification();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verification email sent! Please check your inbox.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } else {
      success = await authProvider.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);

      if (success) {
        await _saveCredentials();
        final userRole = authProvider.userRole;
        Widget dashboard = userRole == 'teacher' ? const TeacherDashboard() : const StudentDashboard();
        
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, anim1, anim2) => dashboard,
            transitionsBuilder: (context, anim1, anim2, child) => FadeTransition(opacity: anim1, child: child),
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Authentication failed'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address first to reset password.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.sendPasswordReset(email);
    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Reset Email Sent'),
            content: Text('A password reset link has been sent to $email. Please check your spam folder if you do not see it.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage ?? 'Failed to send password reset email'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Stack(
        children: [
          // Beautiful Background Gradient Flow
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: isDark
                      ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                      : [const Color(0xFFEFF6FF), Colors.white],
                ),
              ),
            ),
          ),
          // Breathtaking glowing soft circles behind the content
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: isDark ? 0.15 : 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                color: AppTheme.secondaryColor.withValues(alpha: isDark ? 0.15 : 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // VEDO Brand Icon & Name
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withValues(alpha: 0.2),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.auto_stories,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppConstants.appName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Study • Focus • Grow',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                          color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 36),

                      // Auth Box Container (Glassmorphic Card feel)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.9) : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                          border: Border.all(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                            width: 1,
                          ),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _isSignUp ? 'Create Account' : 'Welcome Back',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Name Field (Sign Up Only)
                              if (_isSignUp) ...[
                                TextFormField(
                                  controller: _nameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Full Name',
                                    prefixIcon: Icon(Icons.person_outline),
                                  ),
                                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter your name';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                
                                // Role Selection
                                Text(
                                  'Join as a:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _RoleCard(
                                        icon: Icons.school_outlined,
                                        label: 'Student',
                                        isSelected: _selectedRole == 'student',
                                        onTap: () => setState(() => _selectedRole = 'student'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _RoleCard(
                                        icon: Icons.groups_outlined,
                                        label: 'Teacher',
                                        isSelected: _selectedRole == 'teacher',
                                        onTap: () => setState(() => _selectedRole = 'teacher'),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Email Field
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'Email Address',
                                  prefixIcon: Icon(Icons.mail_outline),
                                ),
                                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  if (!value.contains('@')) {
                                    return 'Please enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Password Field
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                      color: isDark ? Colors.grey : Colors.grey.shade600,
                                    ),
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                ),
                                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your password';
                                  }
                                  if (value.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                              ),
                              
                              // Remember Me & Forgot Password Row (Login Only)
                              if (!_isSignUp) ...[
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: Checkbox(
                                            value: _rememberMe,
                                            onChanged: (val) => setState(() => _rememberMe = val ?? true),
                                            activeColor: AppTheme.primaryColor,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Remember me',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    TextButton(
                                      onPressed: _forgotPassword,
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text(
                                        'Forgot Password?',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.secondaryColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              
                              const SizedBox(height: 24),

                              // Submit Button
                              _isLoading
                                  ? const Center(child: CircularProgressIndicator())
                                  : ElevatedButton(
                                      onPressed: _submitForm,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryColor,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: Text(
                                        _isSignUp ? 'Sign Up' : 'Login',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Toggle Screen Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isSignUp ? 'Already have an account? ' : 'Don\'t have an account? ',
                            style: TextStyle(
                              color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              setState(() {
                                _isSignUp = !_isSignUp;
                                _formKey.currentState?.reset();
                                _emailController.clear();
                                _passwordController.clear();
                                _nameController.clear();
                                context.read<AuthProvider>().clearError();
                              });
                            },
                            child: const Text(
                              'Sign Up',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppTheme.primaryColor.withValues(alpha: isDark ? 0.2 : 0.08)
              : (isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected 
                ? AppTheme.primaryColor 
                : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected ? AppTheme.primaryColor : (isDark ? Colors.grey : Colors.grey.shade600),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppTheme.primaryColor : (isDark ? Colors.white : Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
