import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  Future<void> _selectRole(BuildContext context, String role) async {
    try {
      final authProvider = context.read<AuthProvider>();
      await authProvider.setUserRole(role);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to set role: $e'),
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
      backgroundColor: isDark ? AppTheme.bgDark : AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Choose Role'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Tell us who you are',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select your account type to configure your personal hub',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 48),
              
              // Student Card
              _PremiumRoleCard(
                icon: Icons.school_rounded,
                title: 'Student Hub',
                description: 'Join virtual classes, study with the Pomodoro focus timer, check feedback, and build your growth streak.',
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryColor, Color(0xFF5BA3F5)],
                ),
                onTap: () => _selectRole(context, 'student'),
              ),
              
              const SizedBox(height: 24),
              
              // Teacher Card
              _PremiumRoleCard(
                icon: Icons.groups_rounded,
                title: 'Teacher Console',
                description: 'Create interactive classes, track student homework, publish announcements, manage attendance, and rate progress.',
                gradient: const LinearGradient(
                  colors: [AppTheme.secondaryColor, Color(0xFFFFB366)],
                ),
                onTap: () => _selectRole(context, 'teacher'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumRoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Gradient gradient;
  final VoidCallback onTap;

  const _PremiumRoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade100,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Beautiful Icon Container
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: gradient.colors.first.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              
              // Text Information
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
