import 'package:aboutme/widgets/interests_interactive_demo.dart';
import 'package:flutter/material.dart';

class InterestsInteractiveExample extends StatelessWidget {
  const InterestsInteractiveExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Interests 兴趣选择'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF202022),
      ),
      body: const SafeArea(
        child: SingleChildScrollView(child: InterestsInteractiveDemo()),
      ),
    );
  }
}
