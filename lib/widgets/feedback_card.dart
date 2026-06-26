import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/helpers.dart';

class FeedbackCard extends StatelessWidget {
  final int rating;
  final String comment;
  final DateTime createdAt;
  final String? teacherName;

  const FeedbackCard({
    super.key,
    required this.rating,
    required this.comment,
    required this.createdAt,
    this.teacherName,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (teacherName != null)
                  Text(
                    teacherName!,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                const Spacer(),
                Text(
                  Helpers.formatDate(createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(
                5,
                (index) => Icon(
                  index < rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              comment,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
