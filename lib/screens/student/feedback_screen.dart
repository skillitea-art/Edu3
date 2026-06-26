import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/feedback_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/feedback_card.dart';

class FeedbackScreen extends StatelessWidget {
  const FeedbackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final firestoreService = FirestoreService();
    final currentUser = authProvider.currentUser;
    
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('User not authenticated')),
      );
    }
    
    final studentId = currentUser.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Feedback'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: firestoreService.getFeedbackForStudent(studentId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final feedbacks = snapshot.data ?? [];
          if (feedbacks.isEmpty) {
            return const Center(
              child: Text('No feedback received yet'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: feedbacks.length,
            itemBuilder: (context, index) {
              final feedbackMap = feedbacks[index];
              final feedback = FeedbackModel.fromMap(feedbackMap);
              return FeedbackCard(
                rating: feedback.rating,
                comment: feedback.comment,
                createdAt: feedback.createdAt,
              );
            },
          );
        },
      ),
    );
  }
}
