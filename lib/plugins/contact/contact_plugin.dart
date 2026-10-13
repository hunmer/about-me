import 'dart:convert';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/plugins/base_plugin.dart';

import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/config_manager.dart';
import 'package:aboutme/core/js_bridge/js_bridge_plugin.dart';
import 'package:shared_models/repositories/contact/contact_repository.dart';
import 'controllers/contact_controller.dart';
import 'models/contact_model.dart';
import 'models/interaction_record_model.dart';
import 'package:aboutme/core/services/plugin_data_selector/index.dart';

// UseCase 架构相关导入
import 'package:shared_models/usecases/contact/contact_usecase.dart';
import 'repositories/client_contact_repository.dart';

// HTTP 服务器导入
import 'package:aboutme/plugins/webview/services/local_http_server.dart';

// 主界面（同时 export 保持旧的导入路径可用）
import 'screens/contact_main_view.dart';
export 'screens/contact_main_view.dart';

import 'widgets/contact_plugin_card.dart';

part 'contact_js_api.dart';
part 'contact_data_selectors.dart';

class ContactPlugin extends BasePlugin with JSBridgePlugin {
  late ContactController _controller;
  late ContactUseCase _useCase;

  // 静态实例，供 part 文件访问
  static ContactPlugin? _instance;
  static ContactPlugin get instance {
    if (_instance == null) {
      _instance = PluginManager.instance.getPlugin('contact') as ContactPlugin?;
      if (_instance == null) {
        throw StateError('ContactPlugin has not been initialized');
      }
    }
    return _instance!;
  }

  // 暴露控制器和 UseCase 供外部访问
  ContactController get controller => _controller;
  ContactUseCase get useCase => _useCase;

  @override
  Map<String, Function> defineJSAPI() {
    return {
      // 联系人相关
      'getContacts': _jsGetContacts,
      'getContact': _jsGetContact,
      'createContact': _jsCreateContact,
      'updateContact': _jsUpdateContact,
      'deleteContact': _jsDeleteContact,

      // 记录相关
      'addInteraction': _jsAddInteraction,
      'getInteractions': _jsGetInteractions,
      'deleteInteraction': _jsDeleteInteraction,

      // 筛选与统计
      'getRecentContacts': _jsGetRecentContacts,
      'getAllTags': _jsGetAllTags,

      // 联系人查找方法
      'findContactBy': _jsFindContactBy,
      'findContactById': _jsFindContactById,
      'findContactByName': _jsFindContactByName,

      // 交互记录查找方法
      'findInteractionBy': _jsFindInteractionBy,
      'findInteractionById': _jsFindInteractionById,
    };
  }

  @override
  String get id => 'contact';

  @override
  Color get color => Colors.deepPurple;

  @override
  IconData get icon => Icons.contacts;

  @override
  Future<void> initialize() async {
    // 1. 初始化控制器
    _controller = ContactController(this);

    // 2. 创建 Repository
    final repository = ClientContactRepository(controller: _controller);

    // 3. 创建 UseCase
    _useCase = ContactUseCase(repository as IContactRepository);

    // 4. 初始化默认数据
    await _controller.createDefaultContacts();

    // 5. 注册 JS API（最后一步）
    await registerJSAPI();

    // 6. 注册数据选择器
    _registerDataSelectors();
  }

  @override
  Future<void> registerToApp(
    PluginManager pluginManager,
    ConfigManager configManager,
  ) async {
    // 插件已在 initialize() 中完成初始化
    // 这里可以添加额外的应用级注册逻辑
  }

  @override
  Widget buildMainView(BuildContext context) {
    return ContactMainView();
  }

  @override
  String? getPluginName(context) {
    return 'contact_name'.tr;
  }

  @override
  Widget buildCardView(BuildContext context) {
    return ContactPluginCard(plugin: this);
  }

  /// 获取用于 watchOS 显示的联系人列表
  Future<List<Map<String, dynamic>>> getWatchContactItems() async {
    try {
      // 获取所有联系人
      final contacts = await _controller.getAllContacts();

      // 获取交互记录用于统计
      final interactions = await _controller.getAllInteractions();

      // 按最后联系时间排序，最近的在前
      final sortedContacts = List<Contact>.from(contacts)
        ..sort((a, b) => b.lastContactTime.compareTo(a.lastContactTime));

      // 转换为 watchOS 需要的格式
      return sortedContacts.map((contact) {
        // 计算该联系人的交互次数
        final contactInteractions =
            interactions.where((i) => i.contactId == contact.id).toList();
        final interactionCount = contactInteractions.length;

        // 获取最近交互类型和时间
        String? lastInteractionType;
        String? lastInteractionTime;
        if (contactInteractions.isNotEmpty) {
          final lastInteraction = contactInteractions.reduce(
            (a, b) => a.date.isAfter(b.date) ? a : b,
          );
          lastInteractionType = 'Call'; // 默认类型
          final now = DateTime.now();
          final diff = now.difference(lastInteraction.date);
          if (diff.inDays == 0) {
            lastInteractionTime = '今天';
          } else if (diff.inDays == 1) {
            lastInteractionTime = '昨天';
          } else if (diff.inDays < 7) {
            lastInteractionTime = '${diff.inDays}天前';
          } else if (diff.inDays < 30) {
            lastInteractionTime = '${(diff.inDays / 7).floor()}周前';
          } else {
            lastInteractionTime = '${(diff.inDays / 30).floor()}个月前';
          }
        }

        // 处理性别
        String? gender;
        if (contact.gender != null) {
          gender = contact.gender!.name; // 'male', 'female', 'other'
        }

        // 截断备注预览
        String? notesPreview;
        if (contact.notes != null && contact.notes!.isNotEmpty) {
          notesPreview =
              contact.notes!.length > 20
                  ? '${contact.notes!.substring(0, 20)}...'
                  : contact.notes;
        }

        final data = {
          'id': contact.id,
          'name': contact.name,
          'phone': contact.phone,
          'avatar': contact.avatar,
          'gender': gender,
          'notes': notesPreview,
          'tags': contact.tags.take(3).toList(), // 最多显示3个标签
          'interactionCount': interactionCount,
          'lastInteractionType': lastInteractionType,
          'lastInteractionTime': lastInteractionTime,
          'lastContactTime': contact.lastContactTime.toIso8601String(),
        };

        // ⚠️ 移除所有 null 值，避免 WCErrorCodePayloadUnsupportedTypes
        data.removeWhere((key, value) => value == null);

        return data;
      }).toList();
    } catch (e) {
      print('[ContactPlugin] getWatchContactItems error: $e');
      return [];
    }
  }
}
