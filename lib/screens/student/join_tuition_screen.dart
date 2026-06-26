import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tuition_provider.dart';
import '../../core/theme/app_theme.dart';

class JoinTuitionScreen extends StatefulWidget {
  const JoinTuitionScreen({super.key});

  @override
  State<JoinTuitionScreen> createState() => _JoinTuitionScreenState();
}

class _JoinTuitionScreenState extends State<JoinTuitionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isJoining = false;

  Future<void> _joinTuition() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isJoining = true);

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
      setState(() => _isJoining = false);
      return;
    }

    final tuitionCode = _codeController.text.trim().toUpperCase();
    
    final tuition = await tuitionProvider.joinTuition(
      code: tuitionCode,
      studentId: user.uid,
      studentName: user.name,
      studentEmail: user.email,
    );

    if (mounted) {
      setState(() => _isJoining = false);

      if (tuition != null) {
        // Update auth provider with tuition ID
        await authProvider.setTuitionId(tuition.id);
        
        // Show success message
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
                  Text('Joined Successfully!'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You have joined:',
                    style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tuition.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Subject: ${tuition.subject}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  Text(
                    'Timing: ${tuition.timing}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  Text(
                    'Teacher: ${tuition.teacherName}',
                    style: const TextStyle(fontSize: 14),
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
            content: Text(tuitionProvider.error ?? 'Failed to join class'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Class'),
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
                  Icons.group_add,
                  size: 80,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Enter Class Code',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Get the 6-character code from your teacher',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                
                // Code Input Field
                TextFormField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'Class Code',
                    hintText: 'e.g., ABC123',
                    prefixIcon: Icon(Icons.vpn_key),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    counterText: '',
                  ),
                  maxLength: 6,
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter tuition code';
                    }
                    if (value.trim().length != 6) {
                      return 'Code must be exactly 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                
                // Helper Text
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'The code is case-insensitive and will be converted to uppercase',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
                // Join Button
                _isJoining
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: _joinTuition,
                        icon: const Icon(Icons.login, size: 24),
                        label: const Text(
                          'Join Class',
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
                          Icons.help_outline,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Contact your teacher if you don\'t have a class code.',
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
