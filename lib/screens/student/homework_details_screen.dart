import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../models/task_model.dart';
import '../../services/firestore_service.dart';
import '../../core/theme/app_theme.dart';

class HomeworkDetailsScreen extends StatefulWidget {
  final TaskModel task;
  final String className;
  final String teacherName;

  const HomeworkDetailsScreen({
    super.key,
    required this.task,
    required this.className,
    required this.teacherName,
  });

  @override
  State<HomeworkDetailsScreen> createState() => _HomeworkDetailsScreenState();
}

class _HomeworkDetailsScreenState extends State<HomeworkDetailsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _submissionController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _submissionController.dispose();
    super.dispose();
  }

  Future<void> _submitHomework({
    required String studentId,
    required String studentName,
    String? overrideText,
  }) async {
    final text = overrideText ?? _submissionController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please write something to submit'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _firestoreService.submitHomework({
        'taskId': widget.task.id,
        'studentId': studentId,
        'studentName': studentName,
        'submissionText': text,
        'attachments': [],
        'isGraded': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Homework submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _submissionController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit homework: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    final isDark = authProvider.isDarkMode;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('User not authenticated')),
      );
    }

    final dateStr = DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(widget.task.deadline);
    final isOverdue = widget.task.deadline.isBefore(DateTime.now());

    return Scaffold(
      backgroundColor: isDark ? AppTheme.bgDark : AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('Homework Details'), elevation: 0),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: _firestoreService.getStudentSubmissionForTask(
          user.uid,
          widget.task.id,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final submission = snapshot.data;
          final isSubmitted = submission != null;
          final isGraded = isSubmitted && (submission['isGraded'] ?? false);
          final grade = isSubmitted ? (submission['grade'] ?? '') : '';
          final feedback = isSubmitted ? (submission['feedback'] ?? '') : '';

          String statusLabel = 'Pending';
          Color statusColor = Colors.orange;

          if (isSubmitted) {
            if (isGraded) {
              statusLabel = 'Graded: $grade';
              statusColor = Colors.green;
            } else {
              statusLabel = 'Submitted';
              statusColor = AppTheme.primaryColor;
            }
          } else if (isOverdue) {
            statusLabel = 'Overdue';
            statusColor = Colors.red;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header Card
                Card(
                  elevation: 0,
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey.shade100,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                widget.task.subject,
                                style: const TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                statusLabel,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.task.title,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Class: ${widget.className}',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.grey : Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(
                              Icons.person_outline,
                              size: 18,
                              color: AppTheme.secondaryColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Teacher: ${widget.teacherName}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? Colors.grey
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.event_outlined,
                              size: 18,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Due Date: $dateStr',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? Colors.grey
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Description Card
                Text(
                  'Instructions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey.shade100,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      widget.task.description.isEmpty
                          ? 'No additional instructions provided by the teacher.'
                          : widget.task.description,
                      style: TextStyle(
                        fontSize: 14.5,
                        color: isDark
                            ? Colors.grey.shade300
                            : Colors.grey.shade800,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Attachment (if available)
                if (widget.task.attachmentUrl.isNotEmpty) ...[
                  Text(
                    'Attachments',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 0,
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.grey.shade100,
                      ),
                    ),
                    child: ListTile(
                      leading: const Icon(
                        Icons.link,
                        color: AppTheme.primaryColor,
                      ),
                      title: Text(
                        widget.task.attachmentUrl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          decoration: TextDecoration.underline,
                          fontSize: 14,
                        ),
                      ),
                      onTap: () {
                        // Action could be added if URL launcher is available.
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Submission Box or Review Card
                Text(
                  'Your Submission',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                if (isSubmitted) ...[
                  Card(
                    elevation: 0,
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.grey.shade100,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Submission:',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? Colors.grey
                                  : Colors.grey.shade600,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            submission['submissionText'] ?? '',
                            style: TextStyle(
                              fontSize: 14.5,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 12),
                          if (isGraded) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.green.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Grade Received: $grade',
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (feedback.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Teacher Feedback: $feedback',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        color: isDark
                                            ? Colors.grey.shade300
                                            : Colors.grey.shade800,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.orange.withValues(alpha: 0.2),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.hourglass_empty,
                                    color: Colors.orange,
                                    size: 20,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Your work is pending grade review from the teacher.',
                                      style: TextStyle(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Allow resubmitting
                            ElevatedButton(
                              onPressed: () {
                                FirebaseFirestore.instance
                                    .collection('submissions')
                                    .doc('${widget.task.id}_${user.uid}')
                                    .delete();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark
                                    ? const Color(0xFF334155)
                                    : Colors.grey.shade200,
                                foregroundColor: isDark
                                    ? Colors.white
                                    : Colors.black,
                              ),
                              child: const Text('Resubmit Homework'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  // Submission Form
                  Card(
                    elevation: 0,
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.grey.shade100,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _submissionController,
                            maxLines: 5,
                            decoration: InputDecoration(
                              hintText:
                                  'Type your solution or paste links to your drive documents here...',
                              hintStyle: TextStyle(
                                color: isDark
                                    ? Colors.grey
                                    : Colors.grey.shade500,
                              ),
                              border: const OutlineInputBorder(),
                            ),
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _isSubmitting
                                ? null
                                : () => _submitHomework(
                                    studentId: user.uid,
                                    studentName: user.name,
                                  ),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                            ),
                            child: _isSubmitting
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : const Text('Submit Homework'),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton(
                            onPressed: _isSubmitting
                                ? null
                                : () => _submitHomework(
                                    studentId: user.uid,
                                    studentName: user.name,
                                    overrideText: 'Marked as completed',
                                  ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                              side: BorderSide(
                                color: isDark
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Text(
                              'Mark as Completed',
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
