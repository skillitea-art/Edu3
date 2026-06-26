import 'package:flutter/material.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import 'package:provider/provider.dart';

class StudentListScreen extends StatelessWidget {
  const StudentListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final tuitionId = authProvider.tuitionId;
    final firestoreService = FirestoreService();

    // Null safety check for tuitionId
    if (tuitionId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Students'),
        ),
        body: const Center(
          child: Text('No class selected'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Students'),
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: firestoreService.getTuitionById(tuitionId),
        builder: (context, snapshot) {
          // Loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Error state
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Error loading students',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // No data or tuition not found
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(
              child: Text('Class not found'),
            );
          }

          final tuitionData = snapshot.data ?? {};
          final students = tuitionData['students'] as List<dynamic>? ?? [];

          // Empty students list
          if (students.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 100,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No Students Yet',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Students will appear here when they join your class',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          // Display students list
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: students.length,
            itemBuilder: (context, index) {
              final student = students[index] as Map<String, dynamic>;
              final studentName = student['name'] as String? ?? 'No Name';
              final studentEmail = student['email'] as String? ?? 'No Email';
              final studentInitial = studentName.isNotEmpty 
                  ? studentName[0].toUpperCase() 
                  : '?';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      studentInitial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  title: Text(
                    studentName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      studentEmail,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  trailing: Icon(
                    Icons.person,
                    color: Colors.grey.shade400,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
