import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/tuition_model.dart';
import '../student/join_tuition_screen.dart';

class MyTuitionScreen extends StatefulWidget {
  const MyTuitionScreen({super.key});

  @override
  State<MyTuitionScreen> createState() => _MyTuitionScreenState();
}

class _MyTuitionScreenState extends State<MyTuitionScreen> {
  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    final loggedInUid = user?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Classes'),
        elevation: 0,
      ),
      body: StreamBuilder<List<TuitionModel>>(
        stream: FirebaseFirestore.instance
            .collection('tuitions')
            .where('studentIds', arrayContains: loggedInUid)
            .snapshots()
            .map((snapshot) {
              debugPrint('MyTuitionScreen: Logged-in uid = $loggedInUid');
              debugPrint('MyTuitionScreen: Firestore raw doc count = ${snapshot.docs.length}');
              for (var doc in snapshot.docs) {
                debugPrint('MyTuitionScreen: Firestore doc details [id: ${doc.id}] data: ${doc.data()}');
              }
              
              final list = snapshot.docs.map((doc) {
                final map = doc.data();
                map['id'] = doc.id;
                return TuitionModel.fromMap(map);
              }).toList();
              
              // Sort in memory by joinedDate (using user.uid) descending
              list.sort((a, b) {
                final aStudent = a.students.firstWhere(
                  (s) => s['uid'] == loggedInUid,
                  orElse: () => <String, dynamic>{},
                );
                final bStudent = b.students.firstWhere(
                  (s) => s['uid'] == loggedInUid,
                  orElse: () => <String, dynamic>{},
                );
                final aDate = aStudent['joinedAt'] ?? '';
                final bDate = bStudent['joinedAt'] ?? '';
                return bDate.compareTo(aDate);
              });
              
              debugPrint('MyTuitionScreen: Parsed and sorted tuition count = ${list.length}');
              return list;
            }),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          
          final tuitions = snapshot.data ?? [];
          if (tuitions.isEmpty) {
            return _buildEmptyState();
          }
          
          return _buildTuitionList(tuitions, loggedInUid);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school_outlined,
              size: 100,
              color: AppTheme.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            const Text(
              'No joined classes yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Join a class using the code from your teacher',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const JoinTuitionScreen()),
                );
              },
              icon: const Icon(Icons.group_add),
              label: const Text('Join Class'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTuitionList(List<TuitionModel> tuitions, String loggedInUid) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tuitions.length,
      itemBuilder: (context, index) {
        final tuition = tuitions[index];
        return _buildTuitionCard(tuition, loggedInUid);
      },
    );
  }

  Widget _buildTuitionCard(TuitionModel tuition, String loggedInUid) {
    // Extract user's joined date
    final studentInfo = tuition.students.firstWhere(
      (s) => s['uid'] == loggedInUid,
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
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with name and code
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryColor, Color(0xFF5BA3F5)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.school,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tuition.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tuition.subject,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Details
            _buildDetailRow(Icons.schedule, 'Timing', tuition.timing),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.person, 'Teacher', tuition.teacherName),
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.calendar_today,
              'Joined Date',
              formattedJoinedDate,
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.check_circle_outline,
              'Join Status',
              'Joined',
            ),
            const SizedBox(height: 16),
            
            // Tuition Code Badge
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryColor,
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Class Code',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tuition.tuitionCode,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                      color: AppTheme.primaryColor,
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

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: AppTheme.textSecondary,
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
