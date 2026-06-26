import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPageData> _pages = [
    OnboardingPageData(
      title: 'Study Smarter',
      description: 'Manage all your classes, access files, check announcements and submit homework easily.',
      icon: Icons.school_rounded,
      color: AppTheme.primaryColor,
    ),
    OnboardingPageData(
      title: 'Focus Better',
      description: 'Boost productivity with our advanced Pomodoro study timer, streak keeper, and focus mode.',
      icon: Icons.timer_rounded,
      color: AppTheme.secondaryColor,
    ),
    OnboardingPageData(
      title: 'Grow Faster',
      description: 'View deep performance statistics, charts, and direct feedback to accelerate your learning.',
      icon: Icons.trending_up_rounded,
      color: Colors.purple.shade600,
    ),
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_first_time', false);
    
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, anim1, anim2) => const LoginScreen(),
        transitionsBuilder: (context, anim1, anim2, child) => FadeTransition(opacity: anim1, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppTheme.bgDark : AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _completeOnboarding,
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.grey.shade400 : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Slider Content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return _buildPageContent(page, isDark);
                },
              ),
            ),
            
            // Bottom Action Area
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Page Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => _buildIndicator(index, isDark),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Navigation Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentPage == _pages.length - 1) {
                          _completeOnboarding();
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _pages[_currentPage].color,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageContent(OnboardingPageData page, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Graphic container
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              color: page.color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [page.color, page.color.withValues(alpha: 0.6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: page.color.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  page.icon,
                  size: 80,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 48),
          
          // Slide Title
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          
          // Slide Description
          Text(
            page.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicator(int index, bool isDark) {
    final isSelected = _currentPage == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      height: 8.0,
      width: isSelected ? 24.0 : 8.0,
      decoration: BoxDecoration(
        color: isSelected 
            ? _pages[_currentPage].color 
            : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4.0),
      ),
    );
  }
}

class OnboardingPageData {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  OnboardingPageData({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}
