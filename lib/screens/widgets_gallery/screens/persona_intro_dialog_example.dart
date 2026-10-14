import 'package:flutter/material.dart';

import 'package:aboutme/widgets/common/persona_intro_dialog.dart';

/// 人设介绍对话框示例
class PersonaIntroDialogExample extends StatelessWidget {
  const PersonaIntroDialogExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('人设介绍对话框示例'),
      ),
      body: Container(
        color: const Color(0xFFF2F2F7),
        width: double.infinity,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.person),
                  label: const Text('显示默认示例'),
                  onPressed: () => _showDefault(context),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.tune),
                  label: const Text('自定义文案示例'),
                  onPressed: () => _showCustom(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDefault(BuildContext context) {
    showPersonaIntroDialog(
      context: context,
      image: const AssetImage('assets/images/default_avatar.jpg'),
      title: '「山东momo」人设',
      subtitle: '考公圣体山东脑子的高情商标准回复~',
      buttonText: '添加到键盘试试',
    );
  }

  void _showCustom(BuildContext context) {
    showPersonaIntroDialog(
      context: context,
      width: 300,
      image: const AssetImage('assets/images/default_avatar.jpg'),
      badgeText: '限时活动',
      title: '「早八战神」人设',
      subtitle: '闹钟一响全宿舍最强战力，带你体验清晨的压迫感~',
      buttonText: '立即使用',
      onButtonPressed: () {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已点击「立即使用」')),
        );
      },
    );
  }
}
