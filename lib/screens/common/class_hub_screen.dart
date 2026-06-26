import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_theme.dart';
import '../../models/tuition_model.dart';
import '../../models/task_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/task_provider.dart';
import '../../services/firestore_service.dart';

class ClassHubScreen extends StatefulWidget {
  final TuitionModel tuition;

  const ClassHubScreen({
    super.key,
    required this.tuition,
  });

  @override
  State<ClassHubScreen> createState() => _ClassHubScreenState();
}

class _ClassHubScreenState extends State<ClassHubScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirestoreService _firestoreService = FirestoreService();
  final _announcementController = TextEditingController();
  final _taskTitleController = TextEditingController();
  final _taskDescController = TextEditingController();
  
  // Attendance state
  DateTime _attendanceDate = DateTime.now();
  final Map<String, bool> _attendanceMap = {};
  bool _isSavingAttendance = false;
  
  // Homework state
  DateTime _taskDeadline = DateTime.now().add(const Duration(days: 7));

  TuitionModel? _resolvedTuition;
  bool _isLoadingTuition = true;

  Stream<QuerySnapshot>? _announcementsStream;
  Stream<QuerySnapshot>? _attendanceStream;
  Stream<QuerySnapshot>? _tasksStream;
  Stream<DocumentSnapshot>? _membersStream;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isTeacher = authProvider.userRole == 'teacher';
    _tabController = TabController(length: isTeacher ? 4 : 3, vsync: this);
    _resolveTuitionIdAndInit();
  }

  @override
  void didUpdateWidget(covariant ClassHubScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tuition.id != oldWidget.tuition.id || widget.tuition.tuitionCode != oldWidget.tuition.tuitionCode) {
      debugPrint('VedoDebug: ClassHubScreen tuition ID/code changed. Re-initializing streams.');
      setState(() {
        _isLoadingTuition = true;
      });
      _resolveTuitionIdAndInit();
    } else if (widget.tuition != oldWidget.tuition) {
      setState(() {
        _resolvedTuition = widget.tuition;
      });
    }
  }

  Future<void> _resolveTuitionIdAndInit() async {
    final String inputId = widget.tuition.id;
    TuitionModel? resolvedTuition;

    debugPrint('VedoDebug: Initiating tuition resolution for input ID/code: $inputId');

    try {
      // 1. Try to fetch document by inputId (as a document ID)
      final docSnap = await FirebaseFirestore.instance.collection('tuitions').doc(inputId).get();
      if (docSnap.exists && docSnap.data() != null) {
        final data = docSnap.data()!;
        data['id'] = docSnap.id;
        resolvedTuition = TuitionModel.fromMap(data);
        debugPrint('VedoDebug: Tuition resolved by document ID: ${resolvedTuition.id}');
      } else {
        // 2. Try to fetch document by tuitionCode
        final querySnap = await FirebaseFirestore.instance
            .collection('tuitions')
            .where('tuitionCode', isEqualTo: inputId)
            .get();
        if (querySnap.docs.isNotEmpty) {
          final doc = querySnap.docs.first;
          final data = doc.data();
          data['id'] = doc.id;
          resolvedTuition = TuitionModel.fromMap(data);
          debugPrint('VedoDebug: Tuition resolved by tuitionCode match: ${resolvedTuition.id}');
        }
      }
    } catch (e) {
      debugPrint('VedoDebug: Error resolving tuition ID/code: $e');
    }

    // Fallback if not resolved
    resolvedTuition ??= widget.tuition;

    if (mounted) {
      debugPrint('VedoStateDebug: setState resolvedTuition and streams initialisation');
      setState(() {
        _resolvedTuition = resolvedTuition;
        
        // Define persistent streams to prevent StreamBuilder reconstruction on rebuilds
        _announcementsStream = FirebaseFirestore.instance
            .collection('announcements')
            .where('tuitionId', isEqualTo: _resolvedTuition!.id)
            .orderBy('createdAt', descending: true)
            .snapshots();

        _attendanceStream = FirebaseFirestore.instance
            .collection('attendance')
            .where('tuitionId', isEqualTo: _resolvedTuition!.id)
            .orderBy('date', descending: true)
            .snapshots();

        _tasksStream = FirebaseFirestore.instance
            .collection('tasks')
            .where('tuitionId', isEqualTo: _resolvedTuition!.id)
            .orderBy('createdAt', descending: true)
            .snapshots();

        _membersStream = FirebaseFirestore.instance
            .collection('tuitions')
            .doc(_resolvedTuition!.id)
            .snapshots();

        _isLoadingTuition = false;
        
        // Initialize attendance map with false (absent) for all students
        _attendanceMap.clear();
        for (var student in _resolvedTuition!.students) {
          final uid = student['uid'] as String?;
          if (uid != null) {
            _attendanceMap[uid] = false;
          }
        }
      });
      
      _loadExistingAttendance();

      // Run diagnostics
      final auth = Provider.of<AuthProvider>(context, listen: false);
      _runClassHubDiagnostics(auth.currentUser?.uid);
    }
  }

  Future<void> _runClassHubDiagnostics(String? studentId) async {
    debugPrint('=== CLASS HUB DIAGNOSTICS START ===');
    debugPrint('Current student uid: $studentId');
    debugPrint('Current tuitionId: ${_resolvedTuition!.id}');
    debugPrint('Current class document id: ${_resolvedTuition!.id}');
    debugPrint('Current tuition code: ${_resolvedTuition!.tuitionCode}');
    
    // 3. Print Firestore query being executed
    debugPrint('Firestore query for announcements: FirebaseFirestore.instance.collection("announcements").where("tuitionId", isEqualTo: "${_resolvedTuition!.id}")');
    
    try {
      // 4. Print number of announcement documents returned, and 5. Print full data
      final filteredQuery = await FirebaseFirestore.instance
          .collection('announcements')
          .where('tuitionId', isEqualTo: _resolvedTuition!.id)
          .get();
      debugPrint('Number of announcement documents returned from filtered query: ${filteredQuery.docs.length}');
      for (var doc in filteredQuery.docs) {
        debugPrint('Filtered Announcement Doc [${doc.id}]: ${doc.data()}');
      }

      // Check all announcements to verify if any have a mismatch in tuitionId
      final allAnnouncements = await FirebaseFirestore.instance.collection('announcements').get();
      debugPrint('Total announcements in database (unfiltered): ${allAnnouncements.docs.length}');
      
      for (var doc in allAnnouncements.docs) {
        final data = doc.data();
        debugPrint('All Announcement Doc [${doc.id}]: $data');
        
        // 6. Verify that: announcement.tuitionId == current class tuitionId
        final bool tuitionIdMatches = data['tuitionId'] == _resolvedTuition!.id;
        debugPrint('  Verification - tuitionId matches ("${data['tuitionId']}" == "${_resolvedTuition!.id}"): $tuitionIdMatches');
        
        // 8. Verify field names exactly
        debugPrint('  Field Check - tuitionId present: ${data.containsKey("tuitionId")}');
        debugPrint('  Field Check - teacherId present: ${data.containsKey("teacherId")}');
        debugPrint('  Field Check - teacherName present: ${data.containsKey("teacherName")}');
        debugPrint('  Field Check - content present: ${data.containsKey("content")}');
      }

      // 7. Verify other collection names exactly (verify access)
      final attendanceDocs = await FirebaseFirestore.instance.collection('attendance').limit(1).get();
      debugPrint('Collection "attendance" exists/readable, count: ${attendanceDocs.docs.length}');

      final tasksDocs = await FirebaseFirestore.instance.collection('tasks').limit(1).get();
      debugPrint('Collection "tasks" exists/readable, count: ${tasksDocs.docs.length}');

      final tuitionsDocs = await FirebaseFirestore.instance.collection('tuitions').limit(1).get();
      debugPrint('Collection "tuitions" exists/readable, count: ${tuitionsDocs.docs.length}');

    } catch (e) {
      debugPrint('DIAGNOSTICS ERROR: $e');
    }
    debugPrint('=== CLASS HUB DIAGNOSTICS END ===');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _announcementController.dispose();
    _taskTitleController.dispose();
    _taskDescController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingAttendance() async {
    final dateStr = DateFormat('yyyy-MM-dd').format(_attendanceDate);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .where('tuitionId', isEqualTo: _resolvedTuition!.id)
          .get();
      
      debugPrint('VedoDebug: Current tuitionId = ${_resolvedTuition!.id}');
      debugPrint('VedoDebug: Fetched attendance count = ${snapshot.docs.length}');

      final history = snapshot.docs.map((doc) => doc.data()).toList();
      final todayAttendance = history.firstWhere(
        (att) => att['date'] == dateStr,
        orElse: () => {},
      );

      if (todayAttendance.isNotEmpty) {
        final presentIds = List<String>.from(todayAttendance['presentStudentIds'] ?? []);
        debugPrint('VedoStateDebug: setState in _loadExistingAttendance');
        setState(() {
          for (var uid in _attendanceMap.keys) {
            _attendanceMap[uid] = presentIds.contains(uid);
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading existing attendance: $e');
    }
  }

  Future<void> _postAnnouncement(String teacherId, String teacherName) async {
    final content = _announcementController.text.trim();
    if (content.isEmpty) return;

    try {
      await _firestoreService.createAnnouncement(
        _resolvedTuition!.id,
        content,
        teacherId,
        teacherName,
      );
      _announcementController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Announcement posted successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveAttendance() async {
    debugPrint('VedoStateDebug: setState in _saveAttendance (isSaving = true)');
    setState(() => _isSavingAttendance = true);
    final dateStr = DateFormat('yyyy-MM-dd').format(_attendanceDate);
    final presentIds = _attendanceMap.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    try {
      await _firestoreService.saveAttendance(_resolvedTuition!.id, dateStr, presentIds);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance recorded successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save attendance: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      debugPrint('VedoStateDebug: setState in _saveAttendance (isSaving = false)');
      setState(() => _isSavingAttendance = false);
    }
  }

  Future<void> _addTask(String creatorId) async {
    final title = _taskTitleController.text.trim();
    if (title.isEmpty) return;

    try {
      final task = TaskModel(
        id: '',
        title: title,
        description: _taskDescController.text.trim(),
        subject: _resolvedTuition!.subject,
        tuitionId: _resolvedTuition!.id,
        createdBy: creatorId,
        deadline: _taskDeadline,
      );
      
      await context.read<TaskProvider>().createTask(task);
      _taskTitleController.clear();
      _taskDescController.clear();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Homework created successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingTuition) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final authProvider = context.watch<AuthProvider>();
    final isTeacher = authProvider.userRole == 'teacher';
    final user = authProvider.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    debugPrint('VedoStateDebug: build called - currentUserUid = ${user?.uid}, resolvedTuitionId = ${_resolvedTuition!.id}, resolvedTuitionCode = ${_resolvedTuition!.tuitionCode}, isTeacher = $isTeacher');

    return Scaffold(
      backgroundColor: isDark ? AppTheme.bgDark : AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(_resolvedTuition!.name),
        bottom: TabBar(
          controller: _tabController,
          labelColor: isDark ? AppTheme.primaryDark : AppTheme.primaryColor,
          unselectedLabelColor: isDark ? Colors.grey : Colors.grey.shade600,
          indicatorColor: isDark ? AppTheme.primaryDark : AppTheme.primaryColor,
          tabs: isTeacher 
              ? const [
                  Tab(text: 'Announce', icon: Icon(Icons.campaign)),
                  Tab(text: 'Attendance', icon: Icon(Icons.check_circle_outline)),
                  Tab(text: 'Homework', icon: Icon(Icons.assignment)),
                  Tab(text: 'Members', icon: Icon(Icons.people)),
                ]
              : const [
                  Tab(text: 'Announce', icon: Icon(Icons.campaign)),
                  Tab(text: 'Attendance', icon: Icon(Icons.check_circle_outline)),
                  Tab(text: 'Members', icon: Icon(Icons.people)),
                ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: isTeacher
            ? [
                // Tab 1: Announcements
                _buildAnnouncementsTab(user, isTeacher, isDark),
                
                // Tab 2: Attendance
                _buildTeacherAttendanceTab(isDark),
                
                // Tab 3: Homework
                _buildHomeworkTab(user, isTeacher, isDark),
                
                // Tab 4: Members
                _buildMembersTab(isDark),
              ]
            : [
                // Tab 1: Announcements
                _buildAnnouncementsTab(user, isTeacher, isDark),
                
                // Tab 2: Attendance
                _buildStudentAttendanceTab(user?.uid ?? '', isDark),
                
                // Tab 3: Members
                _buildMembersTab(isDark),
              ],
      ),
    );
  }

  // ================= TAB: ANNOUNCEMENTS =================
  Widget _buildAnnouncementsTab(dynamic user, bool isTeacher, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          if (isTeacher) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _announcementController,
                    decoration: const InputDecoration(
                      hintText: 'Share announcement to class...',
                      prefixIcon: Icon(Icons.edit),
                    ),
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: AppTheme.primaryColor,
                  onPressed: () => _postAnnouncement(user.uid, user.name),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _announcementsStream,
              builder: (context, snapshot) {
                final hasData = snapshot.hasData;
                final docCount = snapshot.data?.docs.length ?? 0;
                
                debugPrint('VedoStreamDebug [Announcements]: tuitionId = ${_resolvedTuition?.id}, connectionState = ${snapshot.connectionState}, docsCount = $docCount, error = ${snapshot.error}');

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            'Error loading announcements:\n${snapshot.error}',
                            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting && !hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final docs = snapshot.data?.docs ?? [];

                final announcements = docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  data['id'] = doc.id;
                  return data;
                }).toList();

                // Sort in memory to avoid composite index requirements
                announcements.sort((a, b) {
                  final aTime = a['createdAt'] as Timestamp?;
                  final bTime = b['createdAt'] as Timestamp?;
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime);
                });

                if (announcements.isEmpty) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return Center(
                    child: Text(
                      'No announcements yet.',
                      style: TextStyle(color: isDark ? Colors.grey : Colors.grey.shade600),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: announcements.length,
                  itemBuilder: (context, index) {
                    final announcement = announcements[index];
                    final date = (announcement['createdAt'] as dynamic)?.toDate() ?? DateTime.now();
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                                  child: const Icon(Icons.person, color: AppTheme.primaryColor),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        announcement['teacherName'] ?? 'Teacher',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : Colors.black,
                                        ),
                                      ),
                                      Text(
                                        DateFormat('dd MMM yyyy, hh:mm a').format(date),
                                        style: TextStyle(fontSize: 11, color: isDark ? Colors.grey : Colors.grey.shade500),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              announcement['content'] ?? '',
                              style: TextStyle(
                                fontSize: 14.5,
                                color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                              ),
                            ),
                          ],
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

  // ================= TAB: TEACHER ATTENDANCE =================
  Widget _buildTeacherAttendanceTab(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Date: ${DateFormat('dd MMMM yyyy').format(_attendanceDate)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final pick = await showDatePicker(
                    context: context,
                    initialDate: _attendanceDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 90)),
                    lastDate: DateTime.now(),
                  );
                  if (pick != null) {
                    setState(() {
                      _attendanceDate = pick;
                    });
                    _loadExistingAttendance();
                  }
                },
                icon: const Icon(Icons.calendar_month, size: 18),
                label: const Text('Pick Date'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _resolvedTuition!.students.isEmpty
                ? Center(
                    child: Text(
                      'No students in this class.',
                      style: TextStyle(color: isDark ? Colors.grey : Colors.grey.shade600),
                    ),
                  )
                : ListView.builder(
                    itemCount: _resolvedTuition!.students.length,
                    itemBuilder: (context, index) {
                      final student = _resolvedTuition!.students[index];
                      final uid = student['uid'] as String? ?? '';
                      final name = student['name'] as String? ?? 'No Name';
                      final email = student['email'] as String? ?? 'No Email';
                      final isPresent = _attendanceMap[uid] ?? false;
 
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100),
                        ),
                        child: CheckboxListTile(
                          title: Text(
                            name,
                            style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                          ),
                          subtitle: Text(
                            email,
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.grey : Colors.grey.shade600),
                          ),
                          value: isPresent,
                          onChanged: (val) {
                            setState(() {
                               _attendanceMap[uid] = val ?? false;
                            });
                          },
                          secondary: CircleAvatar(
                            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                            child: Text(name[0].toUpperCase(), style: const TextStyle(color: AppTheme.primaryColor)),
                          ),
                          activeColor: AppTheme.primaryColor,
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isSavingAttendance ? null : _saveAttendance,
            child: _isSavingAttendance
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Save Attendance'),
          ),
        ],
      ),
    );
  }
 
  // ================= TAB: STUDENT ATTENDANCE =================
  Widget _buildStudentAttendanceTab(String studentId, bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: _attendanceStream,
      builder: (context, snapshot) {
        final hasData = snapshot.hasData;
        final docCount = snapshot.data?.docs.length ?? 0;
        
        debugPrint('VedoStreamDebug [Attendance]: tuitionId = ${_resolvedTuition?.id}, connectionState = ${snapshot.connectionState}, docsCount = $docCount, error = ${snapshot.error}');

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Error loading attendance:\n${snapshot.error}',
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting && !hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final docs = snapshot.data?.docs ?? [];
        
        final history = docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        }).toList();

        // Sort in memory by date descending
        history.sort((a, b) {
          final aDate = a['date'] as String? ?? '';
          final bDate = b['date'] as String? ?? '';
          return bDate.compareTo(aDate);
        });

        int totalDays = history.length;
        int attendedDays = 0;
        
        for (var day in history) {
          final presentIds = List<String>.from(day['presentStudentIds'] ?? []);
          if (presentIds.contains(studentId)) {
            attendedDays++;
          }
        }
        
        double rate = totalDays == 0 ? 100 : (attendedDays / totalDays) * 100;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Attendance Stats Card
              Card(
                elevation: 0,
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn('Attended', '$attendedDays', isDark),
                      _buildStatColumn('Total Days', '$totalDays', isDark),
                      _buildStatColumn('Rate', '${rate.toStringAsFixed(1)}%', isDark, isHighlight: true),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Attendance Log',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              if (history.isEmpty)
                snapshot.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator())
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 24.0),
                          child: Text('No attendance recorded yet.', style: TextStyle(color: isDark ? Colors.grey : Colors.grey.shade600)),
                        ),
                      )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final day = history[index];
                    final dateStr = day['date'] as String? ?? '';
                    final presentIds = List<String>.from(day['presentStudentIds'] ?? []);
                    final wasPresent = presentIds.contains(studentId);

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100),
                      ),
                      child: ListTile(
                        leading: Icon(
                          wasPresent ? Icons.check_circle : Icons.cancel,
                          color: wasPresent ? Colors.green : Colors.red,
                        ),
                        title: Text(
                          dateStr,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (wasPresent ? Colors.green : Colors.red).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            wasPresent ? 'Present' : 'Absent',
                            style: TextStyle(
                              fontSize: 12,
                              color: wasPresent ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatColumn(String label, String value, bool isDark, {bool isHighlight = false}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: isHighlight 
                ? AppTheme.secondaryColor 
                : (isDark ? Colors.white : Colors.black),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.grey : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  // ================= TAB: HOMEWORK =================
  Widget _buildHomeworkTab(dynamic user, bool isTeacher, bool isDark) {
    return Column(
      children: [
        if (isTeacher) ...[
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: () => _showCreateHomeworkDialog(user.uid),
              icon: const Icon(Icons.add),
              label: const Text('Add New Homework'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ),
        ],
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _tasksStream,
            builder: (context, snapshot) {
              final hasData = snapshot.hasData;
              final docCount = snapshot.data?.docs.length ?? 0;
              
              debugPrint('VedoStreamDebug [Homework]: tuitionId = ${_resolvedTuition?.id}, connectionState = ${snapshot.connectionState}, docsCount = $docCount, error = ${snapshot.error}');

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          'Error loading homework:\n${snapshot.error}',
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting && !hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final docs = snapshot.data?.docs ?? [];

              final tasks = docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                data['id'] = doc.id;
                return data;
              }).toList();

              // Sort in memory by deadline descending
              tasks.sort((a, b) {
                final aDead = a['deadline'] as int? ?? 0;
                final bDead = b['deadline'] as int? ?? 0;
                return bDead.compareTo(aDead);
              });

              if (tasks.isEmpty) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                return Center(
                  child: Text(
                    'No homework assignments yet.',
                    style: TextStyle(color: isDark ? Colors.grey : Colors.grey.shade600),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final taskMap = tasks[index];
                  final task = TaskModel.fromMap(taskMap);
                  
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100),
                    ),
                    child: ListTile(
                      title: Text(
                        task.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      subtitle: Text(
                        'Due: ${DateFormat('dd MMM, hh:mm a').format(task.deadline)}',
                        style: TextStyle(color: isDark ? Colors.grey : Colors.grey.shade600, fontSize: 12),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        if (isTeacher) {
                          _showSubmissionsList(task);
                        } else {
                          _showStudentSubmissionSheet(task, user.uid, user.name);
                        }
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showCreateHomeworkDialog(String creatorId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              top: 20,
              left: 20,
              right: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Create Homework',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _taskTitleController,
                  decoration: const InputDecoration(
                    labelText: 'Homework Title',
                    prefixIcon: Icon(Icons.title),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _taskDescController,
                  decoration: const InputDecoration(
                    labelText: 'Description / Instructions',
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Deadline: ${DateFormat('dd MMM, hh:mm a').format(_taskDeadline)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final pickDate = await showDatePicker(
                          context: context,
                          initialDate: _taskDeadline,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (pickDate != null) {
                          final pickTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(_taskDeadline),
                          );
                          if (pickTime != null) {
                            setModalState(() {
                              _taskDeadline = DateTime(
                                pickDate.year,
                                pickDate.month,
                                pickDate.day,
                                pickTime.hour,
                                pickTime.minute,
                              );
                            });
                          }
                        }
                      },
                      icon: const Icon(Icons.schedule),
                      label: const Text('Change'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => _addTask(creatorId),
                  child: const Text('Publish Homework'),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  // Teacher Submissions Viewer
  void _showSubmissionsList(TaskModel task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Submissions: ${task.title}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _firestoreService.getSubmissionsForTask(task.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final submissions = snapshot.data ?? [];
                    if (submissions.isEmpty) {
                      return const Center(child: Text('No submissions yet.'));
                    }
                    return ListView.builder(
                      itemCount: submissions.length,
                      itemBuilder: (context, index) {
                        final sub = submissions[index];
                        final subId = sub['id'] as String;
                        final name = sub['studentName'] ?? 'Student';
                        final text = sub['submissionText'] ?? '';
                        final isGraded = sub['isGraded'] ?? false;
                        final grade = sub['grade'] ?? '';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (isGraded)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                    child: Text('Grade: $grade', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                  )
                                else
                                  ElevatedButton(
                                    onPressed: () => _showGradeDialog(subId),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      minimumSize: const Size(60, 32),
                                    ),
                                    child: const Text('Grade', style: TextStyle(fontSize: 12)),
                                  ),
                              ],
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
      },
    );
  }

  void _showGradeDialog(String subId) {
    final gradeCtrl = TextEditingController();
    final feedCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        final mediaQuery = MediaQuery.of(context);
        final screenWidth = mediaQuery.size.width;
        final screenHeight = mediaQuery.size.height;
        final dialogWidth = screenWidth * 0.9;

        return AlertDialog(
          title: const Text('Grade Submission'),
          content: Container(
            width: dialogWidth,
            constraints: BoxConstraints(
              maxHeight: screenHeight * 0.5,
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: gradeCtrl,
                      decoration: const InputDecoration(labelText: 'Grade (e.g. A, B+, 95%)'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: feedCtrl,
                      decoration: const InputDecoration(labelText: 'Feedback remarks'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (gradeCtrl.text.trim().isEmpty) return;
                await _firestoreService.gradeSubmission(subId, gradeCtrl.text.trim(), feedCtrl.text.trim());
                if (context.mounted) {
                  Navigator.pop(context);
                  Navigator.pop(context); // Close sheet
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Graded successfully!'), backgroundColor: Colors.green));
                }
              },
              child: const Text('Submit Grade'),
            ),
          ],
        );
      },
    );
  }

  // Student Submission Sheet
  void _showStudentSubmissionSheet(TaskModel task, String studentId, String studentName) {
    final textController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 20,
          left: 20,
          right: 20,
        ),
        child: StreamBuilder<Map<String, dynamic>?>(
          stream: _firestoreService.getStudentSubmissionForTask(studentId, task.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final submission = snapshot.data;
            final isSubmitted = submission != null;

            if (isSubmitted) {
              final isGraded = submission['isGraded'] ?? false;
              final grade = submission['grade'] ?? '';
              final feedback = submission['feedback'] ?? '';
              
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Homework Submission', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text('Your Text Submission:', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                    child: Text(submission['submissionText'] ?? ''),
                  ),
                  const SizedBox(height: 16),
                  if (isGraded) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Grade Received: $grade', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                          if (feedback.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text('Teacher Remarks: $feedback', style: const TextStyle(fontSize: 14)),
                          ],
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.watch_later_outlined, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Pending Review from Teacher', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              );
            }

            // Unsubmitted Form
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Submit Homework: ${task.title}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                TextField(
                  controller: textController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Type your answer or paste sharing links here...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    final answer = textController.text.trim();
                    if (answer.isEmpty) return;

                    await _firestoreService.submitHomework({
                      'taskId': task.id,
                      'studentId': studentId,
                      'studentName': studentName,
                      'submissionText': answer,
                      'attachments': [],
                      'isGraded': false,
                    });

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Homework submitted successfully!'), backgroundColor: Colors.green));
                    }
                  },
                  child: const Text('Submit Solution'),
                ),
                const SizedBox(height: 20),
              ],
            );
          },
        ),
      ),
    );
  }

  // ================= TAB: MEMBERS =================
  Widget _buildMembersTab(bool isDark) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _membersStream,
      builder: (context, snapshot) {
        final hasData = snapshot.hasData;
        
        final tuitionData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final students = (tuitionData['students'] as List<dynamic>?)
                ?.map((student) => Map<String, dynamic>.from(student))
                .toList() ??
            [];
        final teacherName = tuitionData['teacherName'] ?? _resolvedTuition!.teacherName;

        debugPrint('VedoStreamDebug [Members]: tuitionId = ${_resolvedTuition?.id}, connectionState = ${snapshot.connectionState}, membersCount = ${students.length + 1}, error = ${snapshot.error}');

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Error loading members:\n${snapshot.error}',
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting && !hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Teacher Section
            Text(
              'Teacher',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.secondaryColor.withValues(alpha: 0.1),
                  child: const Icon(Icons.star, color: AppTheme.secondaryColor),
                ),
                title: Text(
                  teacherName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                subtitle: Text('Class Coordinator', style: TextStyle(color: isDark ? Colors.grey : Colors.grey.shade600, fontSize: 12)),
              ),
            ),
            const SizedBox(height: 24),

            // Enrolled Students Section
            Text(
              'Enrolled Students (${students.length})',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            if (students.isEmpty)
              snapshot.connectionState == ConnectionState.waiting
                  ? const Center(child: CircularProgressIndicator())
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 24.0),
                        child: Text(
                          'No students joined yet.',
                          style: TextStyle(color: isDark ? Colors.grey : Colors.grey.shade600),
                        ),
                      ),
                    )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: students.length,
                itemBuilder: (context, index) {
                  final student = students[index];
                  final name = student['name'] as String? ?? 'No Name';
                  final email = student['email'] as String? ?? 'No Email';

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      subtitle: Text(email, style: TextStyle(color: isDark ? Colors.grey : Colors.grey.shade600, fontSize: 12)),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

// Helper color extension
