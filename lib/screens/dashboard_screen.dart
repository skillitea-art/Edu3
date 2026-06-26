import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../core/theme/app_theme.dart';
import './common/profile_screen.dart';
import './common/notifications_center.dart';
import './common/my_tuition_screen.dart';
import './auth/login_screen.dart';
import '../services/update_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _animationController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => checkForUpdate(context));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: const Text('Vedo User'),
              accountEmail: const Text('user@example.com'),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  'V',
                  style: TextStyle(fontSize: 24, color: AppTheme.primaryColor),
                ),
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor, Color(0xFF5BA3F5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profile'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.class_),
              title: const Text('My Tuitions'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MyTuitionScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Notifications'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NotificationsCenter()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.system_update_alt),
              title: const Text('Check for updates'),
              onTap: () {
                checkForUpdate(context);
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('App version'),
              subtitle: FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  final info = snapshot.data;
                  final versionText = info != null ? '${info.version}+${info.buildNumber}' : 'Loading...';
                  return Text(versionText);
                },
              ),
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
      backgroundColor: AppTheme.backgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(120),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryColor,
                Color(0xFF5BA3F5),
                Color(0xFF7BB8F8),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white, size: 28),
                    tooltip: 'Menu',
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Vedo',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white, size: 28),
                    tooltip: 'Logout',
                    onPressed: _isLoggingOut
                        ? null
                        : () async {
                            try {
                              print('Dashboard: Starting logout process');
                              setState(() => _isLoggingOut = true);

                              final provider = context.read<AuthProvider>();
                              await provider.signOut();

                              if (mounted) {
                                print('Dashboard: Logout successful, navigating to login');
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    builder: (context) => const LoginScreen(),
                                  ),
                                  (route) => false,
                                );
                              }
                            } catch (e) {
                              print('Dashboard: Logout error - $e');
                              if (mounted) {
                                setState(() => _isLoggingOut = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Logout failed: $e'),
                                    backgroundColor: Colors.red,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            }
                          },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: Column(
            children: [
              // App Description Section
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Card(
                  elevation: 4,
                  shadowColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white,
                          AppTheme.primaryColor.withValues(alpha: 0.05),
                        ],
                      ),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          Text(
                            'Manage your classes smarter and faster',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Track students, homework and progress in one place',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Dashboard Options Grid (Scrollable)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.0,
                    padding: const EdgeInsets.only(bottom: 8),
                    children: [
                      _buildDashboardCard(
                        icon: Icons.add_circle_outline,
                        title: 'Add Class',
                        subtitle: 'Create new class',
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4A90E2), Color(0xFF5BA3F5)],
                        ),
                        onTap: () => _navigateToScreen(1),
                      ),
                      _buildDashboardCard(
                        icon: Icons.group_add,
                        title: 'Join Class',
                        subtitle: 'Enroll in class',
                        gradient: const LinearGradient(
                          colors: [Color(0xFF50C878), Color(0xFF6ED890)],
                        ),
                        onTap: () => _navigateToScreen(2),
                      ),
                      _buildDashboardCard(
                        icon: Icons.people_outline,
                        title: 'Student List',
                        subtitle: 'View all students',
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF9800), Color(0xFFFFA726)],
                        ),
                        onTap: () => _navigateToScreen(2),
                      ),
                      _buildDashboardCard(
                        icon: Icons.feedback_outlined,
                        title: 'Feedback',
                        subtitle: 'View feedback',
                        gradient: const LinearGradient(
                          colors: [Color(0xFF9C27B0), Color(0xFFBA68C8)],
                        ),
                        onTap: () => _navigateToScreen(3),
                      ),
                      _buildDashboardCard(
                        icon: Icons.account_circle_outlined,
                        title: 'Profile',
                        subtitle: 'Manage profile',
                        gradient: const LinearGradient(
                          colors: [Color(0xFF009688), Color(0xFF26A69A)],
                        ),
                        onTap: () => _navigateToScreen(4),
                      ),
                      // Logout Card in Grid
                      _buildDashboardCard(
                        icon: Icons.logout,
                        title: 'Logout',
                        subtitle: 'Sign out',
                        gradient: LinearGradient(
                          colors: [Colors.red.shade400, Colors.red.shade300],
                        ),
                        onTap: _isLoggingOut
                            ? null
                            : () async {
                                try {
                                  print('Dashboard: Starting logout process');
                                  setState(() => _isLoggingOut = true);

                                  final provider = context.read<AuthProvider>();
                                  await provider.signOut();

                                  if (mounted) {
                                    print('Dashboard: Logout successful, navigating to login');
                                    Navigator.of(context).pushAndRemoveUntil(
                                      MaterialPageRoute(
                                        builder: (context) => const LoginScreen(),
                                      ),
                                      (route) => false,
                                    );
                                  }
                                } catch (e) {
                                  print('Dashboard: Logout error - $e');
                                  if (mounted) {
                                    setState(() => _isLoggingOut = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Logout failed: $e'),
                                        backgroundColor: Colors.red,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                }
                              },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToScreen(int index) {
  setState(() {
    _currentIndex = index;
  });
}

  Widget _buildDashboardCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Gradient gradient,
    required VoidCallback? onTap,
  }) {
    return Card(
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  gradient.colors.first.withValues(alpha: 0.12),
                  gradient.colors.last.withValues(alpha: 0.04),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: gradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: gradient.colors.first.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      size: 28,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
