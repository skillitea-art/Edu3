import 'package:flutter/material.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../models/feedback_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/custom_textfield.dart';
import '../../widgets/custom_button.dart';
import 'package:provider/provider.dart';

class AddFeedbackScreen extends StatefulWidget {
  const AddFeedbackScreen({super.key});

  @override
  State<AddFeedbackScreen> createState() => _AddFeedbackScreenState();
}

class _AddFeedbackScreenState extends State<AddFeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  UserModel? _selectedStudent;
  int _rating = 5;
  List<UserModel> _students = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Use Future.microtask to access context after initState completes
    Future.microtask(() => _loadStudents());
  }

  Future<void> _loadStudents() async {
    final authProvider = context.read<AuthProvider>();
    final tuitionId = authProvider.tuitionId;
    
    if (tuitionId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No class selected')),
        );
        Navigator.of(context).pop();
      }
      return;
    }
    
    final studentsMap = await _firestoreService.getStudentsForFeedback(tuitionId);
    setState(() {
      _students = studentsMap.map((map) => UserModel.fromMap(map)).toList();
      _isLoading = false;
    });
  }

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a student')),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.currentUser;
    
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated')),
      );
      return;
    }

    final feedback = FeedbackModel(
      id: '',
      studentId: _selectedStudent!.uid,
      teacherId: currentUser.uid,
      rating: _rating,
      comment: _commentController.text.trim(),
      createdAt: DateTime.now(),
    );

    try {
      await _firestoreService.createFeedback(feedback.toMap());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Feedback sent successfully')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send feedback: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_students.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Give Feedback')),
        body: const Center(
          child: Text('No students in your tuition yet'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Give Feedback'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                DropdownButtonFormField<UserModel>(
                  decoration: const InputDecoration(
                    labelText: 'Select Student',
                    prefixIcon: Icon(Icons.person),
                  ),
                  items: _students.map((student) {
                    return DropdownMenuItem(
                      value: student,
                      child: Text(student.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedStudent = value);
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Rating',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    5,
                    (index) => IconButton(
                      icon: Icon(
                        index < _rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 40,
                      ),
                      onPressed: () {
                        setState(() => _rating = index + 1);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'Comment',
                  controller: _commentController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a comment';
                    }
                    return null;
                  },
                  maxLines: 4,
                  prefixIcon: const Icon(Icons.comment),
                ),
                const SizedBox(height: 32),
                CustomButton(
                  text: 'Send Feedback',
                  onPressed: _submitFeedback,
                  icon: Icons.send,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
