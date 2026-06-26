import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../../providers/auth_provider.dart';
import '../../providers/task_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/tuition_model.dart';
import '../../models/task_model.dart';
import '../../services/firestore_service.dart';
import '../../services/update_service.dart';
import '../auth/login_screen.dart';
import '../common/class_hub_screen.dart';
import '../common/test_practice_screen.dart';
import '../../widgets/custom_chart.dart';
import 'create_tuition_screen.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0;
  TuitionModel? _selectedTuitionForHub;
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => checkForUpdate(context));
  }

  // Profile Edit controller
  final _nameController = TextEditingController();

  // Feedback controller
  String? _selectedFeedbackStudentId;
  int _feedbackRating = 5;
  final _feedbackCommentController = TextEditingController();
  bool _isSavingFeedback = false;

  @override
  void dispose() {
    _nameController.dispose();
    _feedbackCommentController.dispose();
    super.dispose();
  }

  Widget _buildAppDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryColor, Color(0xFF5BA3F5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                'Vedo Menu',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.system_update_alt),
            title: const Text('Check for updates'),
            onTap: () {
              Navigator.of(context).pop();
              checkForUpdate(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.quiz_outlined),
            title: const Text('Test Practice'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TestPracticeScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('App info'),
            subtitle: const Text('Check app status and version'),
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isDark = authProvider.isDarkMode;

    final List<Widget> tabs = [
      _buildHomeTab(authProvider, isDark),
      _buildClassesTab(authProvider, isDark),
      _buildStudentsTab(authProvider, isDark),
      _buildHomeworkTab(authProvider, isDark),
      _buildProfileTab(authProvider, isDark),
    ];

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildAppDrawer(context),
      backgroundColor: isDark ? AppTheme.bgDark : AppTheme.backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          tooltip: 'Menu',
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppTheme.primaryColor, AppTheme.secondaryColor]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.school, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'VEDO',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            onPressed: () => authProvider.toggleDarkMode(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawerEnableOpenDragGesture: true,
      body: tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
            // Clear class hub detail selection when switching tabs
            if (index != 1) {
              _selectedTuitionForHub = null;
            }
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: isDark ? AppTheme.primaryDark : AppTheme.primaryColor,
        unselectedItemColor: isDark ? Colors.grey : Colors.grey.shade500,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 10,
        selectedFontSize: 12,
        unselectedFontSize: 11,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.class_outlined),
            activeIcon: Icon(Icons.class_rounded),
            label: 'Classes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people_rounded),
            label: 'Students',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment_rounded),
            label: 'Homework',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle_outlined),
            activeIcon: Icon(Icons.account_circle_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  // ================= TAB 1: HOME =================
  Widget _buildHomeTab(AuthProvider authProvider, bool isDark) {
    final user = authProvider.currentUser;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Premium Welcome Banner
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryColor, Color(0xFF5BA3F5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back,',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.name ?? 'Teacher',
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(30)),
                        child: Text(
                          'Role: Teacher Console',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                  child: const Icon(Icons.auto_awesome, size: 40, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Stats Row
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('tuitions')
                .where('teacherId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
                .snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              final tuitionCount = docs.length;
              int studentCount = 0;
              for (var doc in docs) {
                final data = doc.data() as Map<String, dynamic>?;
                final studentsList = data?['students'] as List<dynamic>? ?? [];
                studentCount += studentsList.length;
              }

              return Row(
                children: [
                  Expanded(
                    child: _buildHomeStatCard(
                      title: 'My Classes',
                      value: '$tuitionCount',
                      icon: Icons.school_rounded,
                      color: AppTheme.primaryColor,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildHomeStatCard(
                      title: 'Total Students',
                      value: '$studentCount',
                      icon: Icons.people_rounded,
                      color: AppTheme.secondaryColor,
                      isDark: isDark,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Custom visual painter Chart for Teacher Class Performance
          CustomChart(
            title: 'Weekly Student Submissions',
            values: const [24, 35, 18, 45, 52, 38, 40],
            labels: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
          ),
          const SizedBox(height: 24),

          // Productivity Tip card
          Card(
            elevation: 0,
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline, color: AppTheme.secondaryColor, size: 30),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Teacher Productivity Tip',
                          style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Publish homework with clear milestones to increase submission rates by up to 30%.',
                          style: TextStyle(fontSize: 12.5, color: isDark ? Colors.grey : Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeStatCard({required String title, required String value, required IconData icon, required Color color, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black),
                ),
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.grey : Colors.grey.shade600, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassesTab(AuthProvider authProvider, bool isDark) {
    if (_selectedTuitionForHub != null) {
      return WillPopScope(
        onWillPop: () async {
          setState(() {
            _selectedTuitionForHub = null;
          });
          return false;
        },
        child: ClassHubScreen(tuition: _selectedTuitionForHub!),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tuitions')
            .where(
              'teacherId',
              isEqualTo: FirebaseAuth.instance.currentUser!.uid,
            )
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final querySnapshot = snapshot.data;
          final docs = querySnapshot?.docs ?? [];
          final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

          debugPrint('Current user uid: $currentUid');
          debugPrint('Number of documents returned: ${docs.length}');

          if (docs.isEmpty) {
            debugPrint('Firestore response (empty): ${querySnapshot?.docs}');
          } else {
            for (var doc in docs) {
              final data = doc.data() as Map<String, dynamic>?;
              debugPrint('Teacher uid from Firebase: ${data?['teacherId']}');
            }
          }

          if (docs.isEmpty) {
            return _buildClassesEmptyState(isDark);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id;
              final tuition = TuitionModel.fromMap(data);

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100),
                ),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedTuitionForHub = tuition;
                    });
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              tuition.name,
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                              child: Text(
                                tuition.subject,
                                style: const TextStyle(color: AppTheme.primaryColor, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Timing: ${tuition.timing}',
                          style: TextStyle(color: isDark ? Colors.grey : Colors.grey.shade600, fontSize: 13),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.people_outline, size: 16, color: AppTheme.secondaryColor),
                                const SizedBox(width: 6),
                                Text(
                                  '${tuition.students.length} Students Joined',
                                  style: TextStyle(fontSize: 12.5, color: isDark ? Colors.grey : Colors.grey.shade600, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppTheme.primaryColor),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Code: ${tuition.tuitionCode}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateTuitionScreen()),
          );
        },
        label: const Text('New Class'),
        icon: const Icon(Icons.add),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildClassesEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_outlined, size: 80, color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No Classes Yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the button below to create your first class and invite students.',
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? Colors.grey : Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  // ================= TAB 3: STUDENTS & FEEDBACK =================
  Widget _buildStudentsTab(AuthProvider authProvider, bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tuitions')
          .where('teacherId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];
        final List<Map<String, dynamic>> allStudents = [];

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          final tuition = TuitionModel.fromMap(data);
          for (var s in tuition.students) {
            if (!allStudents.any((element) => element['uid'] == s['uid'])) {
              allStudents.add({
                ...s,
                'class': tuition.name,
                'classId': tuition.id,
              });
            }
          }
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: allStudents.isEmpty
              ? Center(
                  child: Text(
                    'No students joined any of your classes yet.',
                    style: TextStyle(color: isDark ? Colors.grey : Colors.grey.shade600),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: allStudents.length,
                  itemBuilder: (context, index) {
                    final student = allStudents[index];
                    final name = student['name'] ?? 'No Name';
                    final email = student['email'] ?? 'No Email';
                    final className = student['class'] ?? '';
                    final uid = student['uid'] ?? '';

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                          child: Text(name[0].toUpperCase(), style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(email, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey : Colors.grey.shade600)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: AppTheme.secondaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                              child: Text(className, style: const TextStyle(fontSize: 10, color: AppTheme.secondaryColor, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        trailing: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectedFeedbackStudentId = uid;
                              _feedbackRating = 5;
                            });
                            _showFeedbackDialog(name, authProvider.currentUser?.uid ?? '');
                          },
                          icon: const Icon(Icons.star, size: 14),
                          label: const Text('Rate', style: TextStyle(fontSize: 11)),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            minimumSize: const Size(60, 32),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  void _showFeedbackDialog(String studentName, String teacherId) {
    showDialog(
      context: context,
      builder: (context) {
        final mediaQuery = MediaQuery.of(context);
        final screenWidth = mediaQuery.size.width;
        final screenHeight = mediaQuery.size.height;

        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: SizedBox(
              width: double.infinity,
              child: Text(
                'Rate $studentName',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: screenHeight * 0.6,
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Stars Row wrapped inside a scroll view just in case screen size is extremely narrow
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (index) {
                            return IconButton(
                              icon: Icon(
                                index < _feedbackRating ? Icons.star : Icons.star_border,
                                color: Colors.amber,
                                size: screenWidth < 360 ? 28 : 32,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                setDialogState(() {
                                  _feedbackRating = index + 1;
                                });
                              },
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _feedbackCommentController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Feedback comment...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actionsOverflowDirection: VerticalDirection.down,
            actionsAlignment: MainAxisAlignment.end,
            actions: [
              TextButton(
                onPressed: () {
                  _feedbackCommentController.clear();
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: _isSavingFeedback
                    ? null
                    : () async {
                        setDialogState(() => _isSavingFeedback = true);
                        try {
                          await _firestoreService.createFeedback({
                            'studentId': _selectedFeedbackStudentId,
                            'teacherId': teacherId,
                            'rating': _feedbackRating,
                            'comment': _feedbackCommentController.text.trim(),
                            'createdAt': DateTime.now().millisecondsSinceEpoch,
                          });
                          _feedbackCommentController.clear();
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Feedback saved successfully!'), backgroundColor: Colors.green));
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
                          }
                        } finally {
                          setDialogState(() => _isSavingFeedback = false);
                        }
                      },
                child: _isSavingFeedback
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save Feedback'),
              ),
            ],
          ),
        );
      },
    );
  }

  // ================= TAB 4: HOMEWORK =================
  Widget _buildHomeworkTab(AuthProvider authProvider, bool isDark) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.primaryColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Manage homework submissions directly in the "Classes" tab details.',
                      style: TextStyle(fontSize: 12.5, color: isDark ? Colors.grey : Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('tasks')
                  .where('createdBy', isEqualTo: authProvider.currentUser?.uid ?? '')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No homework assignments created yet.',
                      style: TextStyle(color: isDark ? Colors.grey : Colors.grey.shade600),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final task = TaskModel.fromMap(doc.data() as Map<String, dynamic>);
                    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(task.deadline);

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100),
                      ),
                      child: ListTile(
                        title: Text(task.title, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                        subtitle: Text('Due: $dateStr • Subject: ${task.subject}', style: const TextStyle(fontSize: 12)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () async {
                            final check = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Homework?'),
                                content: const Text('This will delete this homework permanently for all students.'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                    child: const Text('Delete', style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ),
                            );
                            if (check == true) {
                              await context.read<TaskProvider>().deleteTask(task.id);
                            }
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ================= TAB 5: PROFILE =================
  Widget _buildProfileTab(AuthProvider authProvider, bool isDark) {
    final user = authProvider.currentUser;
    _nameController.text = user?.name ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          CircleAvatar(
            radius: 54,
            backgroundColor: AppTheme.primaryColor,
            child: Text(
              user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 48, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user?.name ?? 'Teacher Name',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
          ),
          Text(
            user?.email ?? 'teacher@example.com',
            style: TextStyle(color: isDark ? Colors.grey : Colors.grey.shade600, fontSize: 14),
          ),
          const SizedBox(height: 24),
          
          // Profile settings box
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // Full name input
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person)),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      if (_nameController.text.trim().isEmpty) return;
                      try {
                        await _firestoreService.updateUser(user!.uid, {'name': _nameController.text.trim()});
                        await authProvider.initializeUser(); // Refresh
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated!'), backgroundColor: Colors.green));
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                    child: const Text('Update Profile'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          
          // Sign out button
          ElevatedButton.icon(
            onPressed: () async {
              await authProvider.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign Out'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 54),
            ),
          ),
        ],
      ),
    );
  }
}
