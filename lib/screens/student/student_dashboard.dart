import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../services/update_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/tuition_model.dart';
import '../../models/task_model.dart';
import '../../services/firestore_service.dart';
import '../auth/login_screen.dart';
import '../common/class_hub_screen.dart';
import '../common/test_practice_screen.dart';
import '../../widgets/custom_chart.dart';
import 'join_tuition_screen.dart';
import 'homework_details_screen.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0;
  TuitionModel? _selectedTuitionForHub;
  final FirestoreService _firestoreService = FirestoreService();

  // Homework Tab Search & Filter State
  String _homeworkSearchQuery = '';
  String _homeworkFilter = 'All';

  // Pomodoro Study Timer State
  int _timerSeconds = 1500; // 25 minutes
  bool _timerRunning = false;
  late AnimationController _timerAnimationController;
  int _completedSessionsCount = 0;
  
  // Daily Streak
  int _streakCount = 3; // Mock default starting streak

  // Profile Edit controller
  final _nameController = TextEditingController();

  // Notes diary state
  final _noteController = TextEditingController();
  final List<String> _notesList = [];

  // Stream caching variables
  Stream<List<TuitionModel>>? _tuitionsStream;
  String? _lastLoadedUid;

  Stream<List<TuitionModel>> _getTuitionsStream(String uid) {
    if (_tuitionsStream != null && _lastLoadedUid == uid) {
      return _tuitionsStream!;
    }
    
    _lastLoadedUid = uid;
    _tuitionsStream = FirebaseFirestore.instance
        .collection('tuitions')
        .where('studentIds', arrayContains: uid)
        .snapshots()
        .map((snapshot) {
          debugPrint('VedoQueryDebug: Logged-in uid = $uid');
          debugPrint('VedoQueryDebug: Firestore raw doc count = ${snapshot.docs.length}');
          for (var doc in snapshot.docs) {
            debugPrint('VedoQueryDebug: Firestore doc details [id: ${doc.id}] data: ${doc.data()}');
          }
          
          final list = snapshot.docs.map((doc) {
            final map = doc.data();
            map['id'] = doc.id;
            return TuitionModel.fromMap(map);
          }).toList();
          
          // Sort in memory by joinedDate (using user.uid) descending
          list.sort((a, b) {
            final aStudent = a.students.firstWhere(
              (s) => s['uid'] == uid,
              orElse: () => <String, dynamic>{},
            );
            final bStudent = b.students.firstWhere(
              (s) => s['uid'] == uid,
              orElse: () => <String, dynamic>{},
            );
            final aDate = aStudent['joinedAt'] ?? '';
            final bDate = bStudent['joinedAt'] ?? '';
            return bDate.compareTo(aDate);
          });
          
          debugPrint('VedoQueryDebug: Parsed and sorted tuition count = ${list.length}');
          return list;
        });
    return _tuitionsStream!;
  }

  @override
  void initState() {
    super.initState();
    _timerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(minutes: 25),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => checkForUpdate(context));
  }

  @override
  void dispose() {
    _timerAnimationController.dispose();
    _nameController.dispose();
    _noteController.dispose();
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
            leading: const Icon(Icons.school),
            title: const Text('My classes'),
            onTap: () => Navigator.of(context).pop(),
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
        ],
      ),
    );
  }

  void _toggleTimer() {
    if (_timerRunning) {
      _timerAnimationController.stop();
      setState(() {
        _timerRunning = false;
      });
    } else {
      _timerAnimationController.forward(from: _timerAnimationController.value == 1.0 ? 0.0 : _timerAnimationController.value);
      setState(() {
        _timerRunning = true;
      });
      _runTimerTicker();
    }
  }

  void _runTimerTicker() async {
    while (_timerRunning && _timerSeconds > 0) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || !_timerRunning) return;
      
      setState(() {
        _timerSeconds--;
      });

      if (_timerSeconds == 0) {
        _timerFinished();
      }
    }
  }

  Future<void> _timerFinished() async {
    setState(() {
      _timerRunning = false;
      _timerSeconds = 1500;
      _completedSessionsCount++;
      _streakCount++; // Boost streak on completed session!
    });
    
    // Save to Firebase
    final authProvider = context.read<AuthProvider>();
    try {
      await _firestoreService.saveStudySession({
        'studentId': authProvider.currentUser?.uid ?? '',
        'durationMinutes': 25,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
      
      await _firestoreService.updateStudentStreak(
        authProvider.currentUser?.uid ?? '',
        _streakCount,
        DateFormat('yyyy-MM-dd').format(DateTime.now()),
      );
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.emoji_events, color: Colors.amber, size: 28),
                SizedBox(width: 10),
                Text('Great Job! 🎉'),
              ],
            ),
            content: const Text('You completed a 25-minute Pomodoro study session. Your streak is keeping hot!'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving session: $e');
    }
  }

  void _resetTimer() {
    _timerAnimationController.reset();
    setState(() {
      _timerRunning = false;
      _timerSeconds = 1500;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    final isDark = authProvider.isDarkMode;
    final loggedInUid = user?.uid ?? '';

    return StreamBuilder<List<TuitionModel>>(
      stream: _getTuitionsStream(loggedInUid),
      builder: (context, snapshot) {
        final tuitions = snapshot.data ?? [];
        final isStreamLoading = snapshot.connectionState == ConnectionState.waiting;

        final List<Widget> tabs = [
          _buildHomeTab(authProvider, isDark, tuitions),
          _buildClassesTab(authProvider, isDark, tuitions, isStreamLoading),
          _buildHomeworkTab(authProvider, isDark, tuitions),
          _buildStudyToolsTab(authProvider, isDark),
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
                  child: const Icon(Icons.auto_stories, color: Colors.white, size: 20),
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
          body: tabs[_currentIndex],
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
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
                icon: Icon(Icons.school_outlined),
                activeIcon: Icon(Icons.school_rounded),
                label: 'My Classes',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.assignment_outlined),
                activeIcon: Icon(Icons.assignment_rounded),
                label: 'Homework',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.timer_outlined),
                activeIcon: Icon(Icons.timer_rounded),
                label: 'Study Hub',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.account_circle_outlined),
                activeIcon: Icon(Icons.account_circle_rounded),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }

  // ================= TAB 1: HOME =================
  Widget _buildHomeTab(AuthProvider authProvider, bool isDark, List<TuitionModel> tuitions) {
    final user = authProvider.currentUser;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Premium Greeting Banner with Streak celebration
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
                        'Keep glowing,',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              user?.name ?? 'Student',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(30)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.local_fire_department, color: Colors.orange, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  '$_streakCount Day Streak',
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(30)),
                            child: Text(
                              'Study: $_completedSessionsCount sessions',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                  child: const Icon(Icons.emoji_events, size: 44, color: Colors.amber),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Activity overview statistics
          Row(
            children: [
              Expanded(
                child: _buildStatWidget(
                  title: 'Enrolled Classes',
                  value: '${tuitions.length}',
                  icon: Icons.school_rounded,
                  color: AppTheme.primaryColor,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildStatWidget(
                  title: 'Study streak',
                  value: '$_streakCount days',
                  icon: Icons.local_fire_department_rounded,
                  color: AppTheme.secondaryColor,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Custom canvas painter progress chart
          CustomChart(
            title: 'Weekly Study Hours (min)',
            values: const [25, 50, 0, 75, 100, 25, 25],
            labels: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
          ),
          const SizedBox(height: 24),

          // Daily notes diary preview
          Card(
            elevation: 0,
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100),
            ),
            child: ListTile(
              leading: const Icon(Icons.sticky_note_2, color: AppTheme.secondaryColor),
              title: Text('My Study Notes', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
              subtitle: Text('Manage your quick drafts and notes in the Study tab.', style: TextStyle(fontSize: 12.5, color: isDark ? Colors.grey : Colors.grey.shade600)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () => setState(() => _currentIndex = 3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatWidget({required String title, required String value, required IconData icon, required Color color, required bool isDark}) {
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
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black),
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

  // ================= TAB 2: MY CLASSES (With Inline Hub) =================
  Widget _buildClassesTab(AuthProvider authProvider, bool isDark, List<TuitionModel> tuitions, bool isStreamLoading) {
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

    final user = authProvider.currentUser;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: isStreamLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => authProvider.initializeUser(),
              child: tuitions.isEmpty
                  ? _buildClassesEmptyState(isDark)
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: tuitions.length,
                      itemBuilder: (context, index) {
                        final tuition = tuitions[index];
                        
                        // Extract user's joined date
                        final studentInfo = tuition.students.firstWhere(
                          (s) => s['uid'] == (user?.uid ?? ''),
                          orElse: () => <String, dynamic>{},
                        );
                        final joinedAtString = studentInfo['joinedAt'] as String?;
                        String formattedJoinedDate = 'Unknown';
                        if (joinedAtString != null && joinedAtString.isNotEmpty) {
                          try {
                            final dt = DateTime.parse(joinedAtString);
                            formattedJoinedDate = DateFormat('dd MMM yyyy').format(dt);
                          } catch (_) {}
                        }

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
                                    'Teacher: ${tuition.teacherName}',
                                    style: TextStyle(color: isDark ? Colors.grey : Colors.grey.shade600, fontSize: 13),
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.calendar_today, size: 16, color: AppTheme.secondaryColor),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Joined: $formattedJoinedDate',
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
                                        child: const Text(
                                          'Joined',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
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
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const JoinTuitionScreen()),
          );
        },
        label: const Text('Join Class'),
        icon: const Icon(Icons.group_add),
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
              'No joined classes yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the button below to join a class using the code from your teacher.',
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? Colors.grey : Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  // ================= TAB 3: HOMEWORK =================
  Widget _buildHomeworkTab(AuthProvider authProvider, bool isDark, List<TuitionModel> tuitions) {
    final user = authProvider.currentUser;
    if (user == null) {
      return const Center(child: Text('User not authenticated'));
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: TextField(
              onChanged: (val) {
                setState(() {
                  _homeworkSearchQuery = val;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search homework title or subject...',
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primaryColor),
                ),
              ),
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
          ),

          // Filters Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All', 'Pending', 'Completed', 'Overdue'].map((filter) {
                  final isSelected = _homeworkFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _homeworkFilter = filter;
                          });
                        }
                      },
                      selectedColor: AppTheme.primaryColor,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : (isDark ? Colors.grey.shade300 : Colors.black),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Main homework list
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _firestoreService.getStudentSubmissions(user.uid),
              builder: (context, submissionsSnapshot) {
                final submissions = submissionsSnapshot.data ?? [];
                // Map taskId to submission map
                final submissionsMap = {for (var sub in submissions) sub['taskId'] as String: sub};
                final completedTaskIds = submissionsMap.keys.toSet();

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('tasks').snapshots(),
                  builder: (context, tasksSnapshot) {
                    if (tasksSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (tasksSnapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error: ${tasksSnapshot.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      );
                    }

                    final docs = tasksSnapshot.data?.docs ?? [];
                    final studentClassIds = tuitions.map((t) => t.id).toList();

                    // Convert and filter tasks belonging to student's enrolled classes
                    var tasks = docs
                        .map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          data['id'] = doc.id;
                          return TaskModel.fromMap(data);
                        })
                        .where((task) => studentClassIds.contains(task.tuitionId))
                        .toList();

                    // Filter by search query
                    if (_homeworkSearchQuery.isNotEmpty) {
                      final query = _homeworkSearchQuery.toLowerCase();
                      tasks = tasks.where((task) {
                        return task.title.toLowerCase().contains(query) ||
                            task.subject.toLowerCase().contains(query);
                      }).toList();
                    }

                    // Filter by status tab
                    final now = DateTime.now();
                    tasks = tasks.where((task) {
                      final isCompleted = completedTaskIds.contains(task.id);
                      final isOverdue = task.deadline.isBefore(now);

                      switch (_homeworkFilter) {
                        case 'Pending':
                          return !isCompleted && !isOverdue;
                        case 'Completed':
                          return isCompleted;
                        case 'Overdue':
                          return !isCompleted && isOverdue;
                        case 'All':
                        default:
                          return true;
                      }
                    }).toList();

                    // Sort tasks by deadline descending
                    tasks.sort((a, b) => b.deadline.compareTo(a.deadline));

                    if (tasks.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.assignment_outlined,
                                size: 64,
                                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No homework found',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.grey : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        final tuition = tuitions.firstWhere(
                          (t) => t.id == task.tuitionId,
                          orElse: () => TuitionModel(
                            id: '',
                            name: 'Unknown Class',
                            subject: '',
                            timing: '',
                            teacherId: '',
                            teacherName: 'Teacher',
                            tuitionCode: '',
                            createdAt: DateTime.now(),
                            students: [],
                            studentIds: [],
                          ),
                        );

                        final isCompleted = completedTaskIds.contains(task.id);
                        final isOverdue = task.deadline.isBefore(now);
                        final sub = submissionsMap[task.id];
                        final isGraded = sub != null && (sub['isGraded'] ?? false);

                        String statusText = 'Pending';
                        Color badgeColor = Colors.orange;

                        if (isCompleted) {
                          if (isGraded) {
                            statusText = 'Graded';
                            badgeColor = Colors.green;
                          } else {
                            statusText = 'Completed';
                            badgeColor = AppTheme.primaryColor;
                          }
                        } else if (isOverdue) {
                          statusText = 'Overdue';
                          badgeColor = Colors.red;
                        }

                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100),
                          ),
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => HomeworkDetailsScreen(
                                    task: task,
                                    className: tuition.name,
                                    teacherName: tuition.teacherName,
                                  ),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          tuition.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.grey : Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: badgeColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          statusText,
                                          style: TextStyle(
                                            color: badgeColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    task.title,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Subject: ${task.subject}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      Text(
                                        'Due: ${DateFormat('dd MMM, hh:mm a').format(task.deadline)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isOverdue && !isCompleted ? Colors.red : Colors.grey,
                                          fontWeight: isOverdue && !isCompleted ? FontWeight.bold : FontWeight.normal,
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ================= TAB 4: STUDY & PROGRESS =================
  Widget _buildStudyToolsTab(AuthProvider authProvider, bool isDark) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(50),
            child: TabBar(
              labelColor: isDark ? AppTheme.primaryDark : AppTheme.primaryColor,
              indicatorColor: isDark ? AppTheme.primaryDark : AppTheme.primaryColor,
              unselectedLabelColor: isDark ? Colors.grey : Colors.grey.shade600,
              tabs: const [
                Tab(text: 'Pomodoro'),
                Tab(text: 'Notepad'),
                Tab(text: 'Badges'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _buildPomodoroTimer(isDark),
              _buildNotepad(isDark),
              _buildBadgesGrid(isDark),
            ],
          ),
        ),
      );
  }

  Widget _buildPomodoroTimer(bool isDark) {
    final minutes = (_timerSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_timerSeconds % 60).toString().padLeft(2, '0');
    final double percent = _timerSeconds / 1500;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          // Circular Progress Clock
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 220,
                height: 220,
                child: CircularProgressIndicator(
                  value: percent,
                  strokeWidth: 10,
                  backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
              ),
              Column(
                children: [
                  Text(
                    '$minutes:$seconds',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _timerRunning ? 'KEEP FOCUS' : 'READY TO STUDY',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: AppTheme.secondaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 48),
          
          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _toggleTimer,
                icon: Icon(_timerRunning ? Icons.pause : Icons.play_arrow),
                label: Text(_timerRunning ? 'Pause' : 'Start Focus'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _timerRunning ? AppTheme.secondaryColor : AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton(
                onPressed: _resetTimer,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  side: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text('Reset', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotepad(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    hintText: 'Draft a quick study note...',
                    prefixIcon: Icon(Icons.note_alt_outlined),
                  ),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.add_circle, size: 36, color: AppTheme.primaryColor),
                onPressed: () {
                  final text = _noteController.text.trim();
                  if (text.isEmpty) return;
                  setState(() {
                    _notesList.insert(0, text);
                    _noteController.clear();
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _notesList.isEmpty
                ? Center(
                    child: Text(
                      'No notes drafted yet. Type above to add!',
                      style: TextStyle(color: isDark ? Colors.grey : Colors.grey.shade600),
                    ),
                  )
                : ListView.builder(
                    itemCount: _notesList.length,
                    itemBuilder: (context, index) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100),
                        ),
                        child: ListTile(
                          title: Text(
                            _notesList[index],
                            style: TextStyle(color: isDark ? Colors.white : Colors.black),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _notesList.removeAt(index);
                              });
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgesGrid(bool isDark) {
    final badges = [
      {'name': 'First Step', 'desc': 'Joined a class', 'unlocked': true, 'icon': Icons.stars},
      {'name': 'Focus Star', 'desc': 'Completed Pomodoro', 'unlocked': _completedSessionsCount > 0, 'icon': Icons.timer},
      {'name': 'Consistency', 'desc': '3 day study streak', 'unlocked': _streakCount >= 3, 'icon': Icons.local_fire_department},
      {'name': 'A+ Student', 'desc': 'Received homework grade', 'unlocked': true, 'icon': Icons.emoji_events},
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.95,
      ),
      itemCount: badges.length,
      itemBuilder: (context, index) {
        final badge = badges[index];
        final unlocked = badge['unlocked'] as bool;
        final icon = badge['icon'] as IconData;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: unlocked 
                  ? AppTheme.primaryColor.withValues(alpha: 0.04) 
                  : Colors.transparent,
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 44,
                  color: unlocked ? AppTheme.secondaryColor : Colors.grey.shade400,
                ),
                const SizedBox(height: 12),
                Text(
                  badge['name'] as String,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: unlocked ? (isDark ? Colors.white : Colors.black) : Colors.grey,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  badge['desc'] as String,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
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
            user?.name ?? 'Student Name',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
          ),
          Text(
            user?.email ?? 'student@example.com',
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
