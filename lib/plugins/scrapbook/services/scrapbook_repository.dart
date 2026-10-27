import 'dart:async';

import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:flutter/foundation.dart';

import '../models/scrapbook_page.dart';

/// 手账数据仓库
///
/// 插件 id 未在 aboutme_data_sdk 注册专用 handler，自动落到通用 CRUD
/// （数据存 plugins/scrapbook/data.json 的 items 数组）
class ScrapbookRepository {
  ScrapbookRepository._();

  static final ScrapbookRepository instance = ScrapbookRepository._();

  /// 拉取手账列表，按更新时间倒序
  Future<List<ScrapbookPage>> getList() async {
    final res = await AboutmeDataService.instance.call('scrapbook', 'getList', {
      'count': 500,
    });
    final payload = res['success'] == true ? res['data'] : null;
    final raw = payload is Map ? payload['data'] : null;
    if (raw is! List) {
      _throwIfFailed(res);
      return [];
    }
    final pages = raw
        .whereType<Map>()
        .map((m) => ScrapbookPage.fromMap(Map<String, dynamic>.from(m)))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return pages;
  }

  /// 新建一页手账，返回带 id 的完整记录
  Future<ScrapbookPage> create(ScrapbookPage page) async {
    final res = await AboutmeDataService.instance.call('scrapbook', 'create', {
      ...page.toMap(),
      'id': page.id.isEmpty ? null : page.id,
    });
    _throwIfFailed(res);
    final data = res['data'];
    if (data is Map<String, dynamic>) {
      return ScrapbookPage.fromMap(data);
    }
    return page;
  }

  /// 保存编辑内容（画布条目 + 涂鸦）
  Future<void> update(ScrapbookPage page) async {
    page.updatedAt = DateTime.now();
    final res = await AboutmeDataService.instance.call('scrapbook', 'update', {
      ...page.toMap(),
      'updatedAt': page.updatedAt.toIso8601String(),
    });
    _throwIfFailed(res);
  }

  Future<void> delete(String id) async {
    final res = await AboutmeDataService.instance.call('scrapbook', 'delete', {
      'id': id,
    });
    _throwIfFailed(res);
  }

  /// 订阅其它设备/远端写入触发的刷新，返回取消函数
  VoidCallback subscribe(VoidCallback onChanged) =>
      AboutmeDataService.instance.onPluginChanged('scrapbook', onChanged);

  void _throwIfFailed(Map<String, dynamic> res) {
    if (res['success'] != true) {
      throw StateError('scrapbook 数据操作失败: ${res['error'] ?? res['message']}');
    }
  }
}
