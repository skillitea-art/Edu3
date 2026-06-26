import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/study_session_model.dart';
import '../../services/firestore_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/helpers.dart';

class StudyTimerScreen extends StatefulWidget {
  const StudyTimerScreen({super.key});

  @override
  State<StudyTimerScreen> createState() => _StudyTimerScreenState();
}

class _StudyTimerScreenState extends State<StudyTimerScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  Timer? _timer;
  int _totalSeconds = AppConstants.pomodoroDurationMinutes * 60;
  bool _isRunning = false;

  int get _minutes => _totalSeconds ~/ 60;
  int get _seconds => _totalSeconds % 60;

  double get _progress => 1 - (_totalSeconds / (AppConstants.pomodoroDurationMinutes * 60));

  void _startTimer() {
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_totalSeconds > 0) {
        setState(() => _totalSeconds--);
      } else {
        _timer?.cancel();
        setState(() => _isRunning = false);
        _saveSession();
        _showCompletionDialog();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _totalSeconds = AppConstants.pomodoroDurationMinutes * 60;
    });
  }

  Future<void> _saveSession() async {
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.currentUser;
    
    if (currentUser == null) {
      debugPrint('StudyTimer: Cannot save session - user not authenticated');
      return;
    }
    
    final session = StudySessionModel(
      id: '',
      userId: currentUser.uid,
      duration: AppConstants.pomodoroDurationMinutes,
      date: DateTime.now(),
    );
    await _firestoreService.saveStudySession(session.toMap());
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Great Job!'),
        content: const Text('You completed a 25-minute study session!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetTimer();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Timer'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 250,
                    height: 250,
                    child: CircularProgressIndicator(
                      value: _progress,
                      strokeWidth: 12,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        Helpers.formatTime(_minutes, _seconds),
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isRunning ? 'Studying...' : 'Ready to Focus?',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!_isRunning)
                    ElevatedButton.icon(
                      onPressed: _startTimer,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: _pauseTimer,
                      icon: const Icon(Icons.pause),
                      label: const Text('Pause'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                    ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _resetTimer,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade300,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
