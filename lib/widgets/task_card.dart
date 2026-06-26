import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/helpers.dart';

class TaskCard extends StatelessWidget {
  final String title;
  final String subject;
  final DateTime deadline;
  final bool isCompleted;
  final VoidCallback? onToggle;

  const TaskCard({
    super.key,
    required this.title,
    required this.subject,
    required this.deadline,
    this.isCompleted = false,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (onToggle != null)
              Checkbox(
                value: isCompleted,
                onChanged: (_) => onToggle!(),
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isCompleted ? AppTheme.textSecondary : AppTheme.textPrimary,
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subject,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Due: ${Helpers.formatDate(deadline)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
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
}
