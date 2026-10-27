import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/plugins/timer/models/timer_task.dart';
import 'package:aboutme/core/services/plugin_widget_sync_helper.dart';

class TimerController {
  final StorageManager storage;
  List<TimerTask> _tasks = [];

  TimerController(this.storage);

  List<TimerTask> getTasks() => _tasks;

  /// 重新加载数据（供同步后刷新使用）
  Future<void> reloadData() async {
    await loadTasks();
  }

  // 从存储加载任务
  Future<Map<String, dynamic>> loadTasks() async {
    try {
      final res = await AboutmeDataService.instance
          .call('timer', 'getSnapshot', {});
      final data = res['success'] == true ? res['data'] : null;
      _tasks =
          data is Map && data['tasks'] != null
              ? (data['tasks'] as List)
                  .map(
                    (data) => TimerTask.fromJson(data as Map<String, dynamic>),
                  )
                  .toList()
              : <TimerTask>[];
      return {'tasks': _tasks};
    } catch (e) {
      _tasks = <TimerTask>[];
      return {'tasks': _tasks};
    }
  }

  // 保存任务到存储
  Future<void> saveTasks(List<TimerTask> tasks) async {
    final tasksData = tasks.map((task) => task.toJson()).toList();
    await AboutmeDataService.instance.call('timer', 'saveSnapshot', {
      'snapshot': {'tasks': tasksData},
    });
    await _syncWidget();
  }

  // 同步小组件数据
  Future<void> _syncWidget() async {
    await PluginWidgetSyncHelper.instance.syncTimer();
  }

  // 获取所有任务的分组名称（去重）
  List<String> getGroups() {
    final groups = _tasks.map((task) => task.group).toSet().toList();
    return groups;
  }

  // 更新所有任务的分组名称
  void updateTaskGroups(String oldName, String newName) {
    for (var task in _tasks) {
      if (task.group == oldName) {
        task.group = newName;
      }
    }
    saveTasks(_tasks);
  }

  // 删除分组并将相关任务移动到默认分组
  void deleteGroup(String groupName) {
    for (var task in _tasks) {
      if (task.group == groupName) {
        task.group = '默认';
      }
    }
    saveTasks(_tasks);
  }
}
