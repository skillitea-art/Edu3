import 'package:flutter/material.dart';

class TestPracticeScreen extends StatelessWidget {
  const TestPracticeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Practice'),
        backgroundColor: const Color(0xFF5BA3F5),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Test Practice screen is working.',
            style: TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
