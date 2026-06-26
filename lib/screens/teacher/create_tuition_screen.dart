import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tuition_provider.dart';
import '../../core/theme/app_theme.dart';

class CreateTuitionScreen extends StatefulWidget {
  const CreateTuitionScreen({super.key});

  @override
  State<CreateTuitionScreen> createState() => _CreateTuitionScreenState();
}

class _CreateTuitionScreenState extends State<CreateTuitionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _subjectController = TextEditingController();
  final _timingController = TextEditingController();
  bool _isCreating = false;

  Future<void> _createTuition() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isCreating = true);

    final authProvider = context.read<AuthProvider>();
    final tuitionProvider = context.read<TuitionProvider>();
    final user = authProvider.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User not authenticated'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isCreating = false);
      return;
    }

    final tuition = await tuitionProvider.createTuition(
      tuitionName: _nameController.text.trim(),
      subject: _subjectController.text.trim(),
      timing: _timingController.text.trim(),
      teacherId: user.uid,
      teacherName: user.name,
    );

    if (mounted) {
      setState(() => _isCreating = false);

      if (tuition != null) {
        // Update auth provider with tuition ID
        await authProvider.setTuitionId(tuition.id);
        
        // Show success message with tuition code
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 28),
                  SizedBox(width: 12),
                  Text('Class Created!'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Share this code with students:',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primaryColor,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      tuition.tuitionCode,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Class: ${tuition.name}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  Text(
                    'Subject: ${tuition.subject}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop(true);
                    }
                  },
                  child: const Text('Go to Dashboard'),
                ),
              ],
            ),
          );
        }
      } else {
        // Show error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tuitionProvider.error ?? 'Failed to create class'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _subjectController.dispose();
    _timingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Class'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                // Icon and Title
                Icon(
                  Icons.class_,
                  size: 80,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Create New Class',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Fill in the details. A unique code will be generated.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                
                // Class Name Field
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Class Name',
                    hintText: 'e.g., Mathematics Class 10',
                    prefixIcon: Icon(Icons.school),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter tuition name';
                    }
                    if (value.trim().length < 3) {
                      return 'Name must be at least 3 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                
                // Subject Field
                TextFormField(
                  controller: _subjectController,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    hintText: 'e.g., Mathematics, Physics',
                    prefixIcon: Icon(Icons.menu_book),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter subject';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                
                // Timing Field
                TextFormField(
                  controller: _timingController,
                  decoration: const InputDecoration(
                    labelText: 'Timing',
                    hintText: 'e.g., Mon-Fri 4:00 PM - 6:00 PM',
                    prefixIcon: Icon(Icons.schedule),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter timing';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                
                // Create Button
                _isCreating
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: _createTuition,
                        icon: const Icon(Icons.add_circle, size: 24),
                        label: const Text(
                          'Create Class',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                const SizedBox(height: 16),
                
                // Info Card
                Card(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'After creating, you\'ll get a unique code to share with students.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
