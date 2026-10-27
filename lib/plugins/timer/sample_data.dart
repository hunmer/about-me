/// 计时器插件示例数据
/// 首次打开插件时由引导页选择导入
library;

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:aboutme/plugins/timer/models/timer_item.dart';
import 'package:aboutme/plugins/timer/models/timer_task.dart';

class TimerSampleData {
  /// 获取示例计时器任务
  static List<TimerTask> getSampleTasks() {
    return [
      // 1. 正计时器：不限时长的自由专注
      TimerTask.create(
        id: const Uuid().v4(),
        name: '自由专注',
        color: Colors.blue,
        icon: Icons.timer,
        group: '专注',
        timerItems: [
          TimerItem.countUp(
            name: '正计时',
            targetDuration: const Duration(minutes: 30),
          ),
        ],
      ),
      // 2. 倒计时器：10 分钟小憩
      TimerTask.create(
        id: const Uuid().v4(),
        name: '休息片刻',
        color: Colors.red,
        icon: Icons.hourglass_empty,
        group: '休息',
        timerItems: [
          TimerItem.countDown(
            name: '倒计时',
            duration: const Duration(minutes: 10),
          ),
        ],
      ),
      // 3. 番茄钟：25 分钟专注 5 分钟休息
      TimerTask.create(
        id: const Uuid().v4(),
        name: '番茄工作法',
        color: Colors.green,
        icon: Icons.local_cafe,
        group: '工作效率',
        timerItems: [
          TimerItem.pomodoro(
            name: '番茄钟',
            workDuration: const Duration(minutes: 25),
            breakDuration: const Duration(minutes: 5),
            cycles: 4,
          ),
        ],
      ),
      // 4. 多计时器组合：专注 + 休息连跑
      TimerTask.create(
        id: const Uuid().v4(),
        name: '学习组合',
        color: Colors.purple,
        icon: Icons.timer_outlined,
        group: '工作效率',
        timerItems: [
          TimerItem.countUp(
            name: '专注 45 分钟',
            targetDuration: const Duration(minutes: 45),
          ),
          TimerItem.countDown(
            name: '休息 15 分钟',
            duration: const Duration(minutes: 15),
          ),
        ],
      ),
    ];
  }
}
