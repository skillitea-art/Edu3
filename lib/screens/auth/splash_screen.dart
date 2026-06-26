import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import 'onboarding_screen.dart';
import 'login_screen.dart';
import '../teacher/teacher_dashboard.dart';
import '../../services/update_service.dart';
import '../student/student_dashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _logoController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _logoController.forward().then((_) => _checkSession());
  }

  @override
  void dispose() {
    _logoController.dispose();
    super.dispose();
  }

  Future<void> _checkSession() async {
    // Wait an additional second to let user appreciate the premium splash
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();
    await authProvider.initializeUser();

    final prefs = await SharedPreferences.getInstance();
    final isFirstTime = prefs.getBool('is_first_time') ?? true;

    if (!mounted) return;

    if (isFirstTime) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, anim1, anim2) => const OnboardingScreen(),
          transitionsBuilder: (context, anim1, anim2, child) => FadeTransition(opacity: anim1, child: child),
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    } else {
      if (authProvider.isLoggedIn) {
        final role = authProvider.userRole;
        Widget dashboard = role == 'teacher' ? const TeacherDashboard() : const StudentDashboard();

        if (mounted) {
          final canContinue = await checkForUpdate(context);
          if (!canContinue || !mounted) return;
        }
        
        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, anim1, anim2) => dashboard,
            transitionsBuilder: (context, anim1, anim2, child) => FadeTransition(opacity: anim1, child: child),
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, anim1, anim2) => const LoginScreen(),
            transitionsBuilder: (context, anim1, anim2, child) => FadeTransition(opacity: anim1, child: child),
            transitionDuration: const Duration(milliseconds: 600),
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
      body: Center(
        child: AnimatedBuilder(
          animation: _logoController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              ),
            );
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Beautiful Premium Logo Container
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.auto_stories,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // VEDO App Name
              Text(
                AppConstants.appName.toUpperCase(),
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              // Tagline
              Text(
                'Study • Focus • Grow',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.0,
                  color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 48),
              // Minimal Loading Dot/Bar Indicator
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDark ? AppTheme.primaryDark : AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
