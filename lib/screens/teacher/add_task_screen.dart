import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/task_provider.dart';
import '../../models/task_model.dart';
import '../../widgets/custom_textfield.dart';
import '../../widgets/custom_button.dart';

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({super.key});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedSubject = 'Math';
  DateTime? _selectedDate;

  final List<String> _subjects = [
    'Math',
    'Science',
    'English',
    'History',
    'Geography',
    'Physics',
    'Chemistry',
    'Biology',
    'Other',
  ];

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _submitTask() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a deadline')),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final taskProvider = context.read<TaskProvider>();
    
    final tuitionId = authProvider.tuitionId;
    final currentUser = authProvider.currentUser;
    
    if (tuitionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No class selected')),
      );
      return;
    }
    
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated')),
      );
      return;
    }
    
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a deadline')),
      );
      return;
    }

    final task = TaskModel(
      id: '',
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      subject: _selectedSubject,
      tuitionId: tuitionId,
      createdBy: currentUser.uid,
      deadline: _selectedDate!,
    );

    await taskProvider.createTask(task);

    if (mounted) {
      if (taskProvider.error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task created successfully')),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(taskProvider.error!)),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Homework'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                CustomTextField(
                  label: 'Task Title',
                  controller: _titleController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter task title';
                    }
                    return null;
                  },
                  prefixIcon: const Icon(Icons.title),
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'Description / Instructions',
                  controller: _descriptionController,
                  maxLines: 3,
                  prefixIcon: const Icon(Icons.description),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    prefixIcon: Icon(Icons.book),
                  ),
                  items: _subjects.map((subject) {
                    return DropdownMenuItem(
                      value: subject,
                      child: Text(subject),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedSubject = value!);
                  },
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _selectDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Deadline',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      _selectedDate == null
                          ? 'Select Date'
                          : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Consumer<TaskProvider>(
                  builder: (context, provider, child) {
                    return CustomButton(
                      text: 'Create Task',
                      onPressed: _submitTask,
                      isLoading: provider.isLoading,
                      icon: Icons.add,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
