import 'package:aboutme/widgets/siri_voice_assistant_orb_demo.dart';
import 'package:flutter/material.dart';

/// Siri 流光语音助手卡片示例页
class SiriVoiceAssistantOrbExample extends StatelessWidget {
  const SiriVoiceAssistantOrbExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Siri 流光语音助手')),
      body: const SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: SiriVoiceAssistantCard(),
          ),
        ),
      ),
    );
  }
}
