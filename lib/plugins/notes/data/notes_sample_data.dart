import 'package:flutter/material.dart';
import 'package:aboutme/plugins/notes/models/folder.dart';
import 'package:aboutme/plugins/notes/models/note.dart';

/// 笔记插件示例数据
/// 当插件的 JSON 文件不存在时，可以使用这些示例数据进行初始化
/// 包含生活相关的文件夹和笔记，避免编程类内容

class NotesSampleData {
  /// 获取示例文件夹数据
  static List<Folder> getSampleFolders() {
    final now = DateTime.now();
    return [
      // 根文件夹
      Folder(
        id: 'root',
        name: '我的笔记',
        parentId: null,
        createdAt: now,
        updatedAt: now,
        color: const Color(0xFF2196F3),
        icon: Icons.folder,
      ),

      // 生活记录
      Folder(
        id: '1703300000000',
        name: '生活记录',
        parentId: 'root',
        createdAt: now.subtract(const Duration(days: 40)),
        updatedAt: now.subtract(const Duration(days: 1)),
        color: const Color(0xFF4CAF50),
        icon: Icons.home_outlined,
      ),

      // 学习成长
      Folder(
        id: '1703450000000',
        name: '学习成长',
        parentId: 'root',
        createdAt: now.subtract(const Duration(days: 60)),
        updatedAt: now.subtract(const Duration(days: 7)),
        color: const Color(0xFFFF9800),
        icon: Icons.menu_book,
      ),
    ];
  }

  /// 获取示例笔记数据
  static List<Note> getSampleNotes() {
    final now = DateTime.now();
    return [
      // 生活记录 - 周末随笔
      Note(
        id: '1703400000000001',
        title: '周末的小确幸',
        content:
            r'[{"insert":"周末的小确幸"},{"insert":"\n","attributes":{"header":3}},{"insert":"今天是一个平凡却充满小惊喜的周末。\n"},{"insert":"上午时光","attributes":{"bold":true}},{"insert":"\n- ☀️ 难得睡了个懒觉，醒来时阳光正好洒在床头\n- ☕ 冲了一杯手冲咖啡，香味弥漫整个房间\n- 📰 慢悠悠地翻看喜欢的杂志\n"},{"insert":"下午时光","attributes":{"bold":true}},{"insert":"\n- 🌳 去了附近的公园散步\n- 📸 拍了很多照片\n- 🍦 买了一个冰淇淋，边走边吃\n"},{"insert":"感悟","attributes":{"bold":true}},{"insert":"\n有时候幸福不需要轰轰烈烈的大事，就是这些平凡的小时刻构成的。\n"},{"insert":"\n","attributes":{"italic":true}}]',
        folderId: '1703300000000',
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(hours: 3)),
        tags: ['心情', '日记'],
      ),

      // 学习成长 - 读书笔记
      Note(
        id: '1703500000000001',
        title: '《小王子》读书笔记',
        content:
            r'[{"insert":"《小王子》读书笔记"},{"insert":"\n","attributes":{"header":3}},{"insert":"作者：安东尼·德·圣-埃克苏佩里","attributes":{"italic":true}},{"insert":"\n\n"},{"insert":"核心语录","attributes":{"bold":true,"underline":true}},{"insert":"\n"},{"insert":"只有用心才能看得清。实质性的东西，用眼睛是看不见的。\n\n"},{"insert":"主题思考","attributes":{"bold":true}},{"insert":"\n"},{"insert":"1. ","attributes":{"bold":true}},{"insert":"关于爱与责任：爱是驯服，也是被驯服。正是你为你的玫瑰花费的时间，让它变得重要。\n\n"},{"insert":"2. ","attributes":{"bold":true}},{"insert":"关于成长：我们终将长大，但不能失去内心的纯真。\n\n"},{"insert":"3. ","attributes":{"bold":true}},{"insert":"关于关系：真正的朋友能看到你内心的美好。\n\n"},{"insert":"推荐语","attributes":{"bold":true}},{"insert":"\n这是一本适合所有年龄段的童话故事，推荐给每一个在成人世界中迷失的人。\n"}]',
        folderId: '1703450000000',
        createdAt: now.subtract(const Duration(days: 15)),
        updatedAt: now.subtract(const Duration(days: 7)),
        tags: ['读书', '经典'],
      ),

      // 生活记录 - 购物清单
      Note(
        id: '1704100000000001',
        title: '购物清单',
        content:
            r'[{"insert":"购物清单"},{"insert":"\n","attributes":{"header":3}},{"insert":"日常用品","attributes":{"bold":true}},{"insert":"\n- [ ] 洗发水\n- [ ] 牙膏\n- [ ] 牙刷\n- [ ] 洗面奶\n- [ ] 抽纸\n\n"},{"insert":"食品类","attributes":{"bold":true}},{"insert":"\n- [ ] 大米 5kg\n- [ ] 鸡蛋 30个\n- [ ] 牛奶 2箱\n- [ ] 坚果\n\n"},{"insert":"预算统计","attributes":{"bold":true,"underline":true}},{"insert":"\n预计总预算：约 ¥500\n\n"},{"insert":"省钱小贴士","attributes":{"bold":true}},{"insert":"\n1. 使用购物App对比价格\n2. 关注店铺优惠活动\n3. 参与团购活动\n"}]',
        folderId: '1703300000000',
        createdAt: now.subtract(const Duration(days: 10)),
        updatedAt: now.subtract(const Duration(days: 2)),
        tags: ['购物', '清单'],
      ),
    ];
  }

  /// 获取所有示例数据（文件夹 + 笔记）
  /// 可用于初始化笔记插件
  static Map<String, List<Map<String, dynamic>>> getAllSampleData() {
    final folders = getSampleFolders();
    final notes = getSampleNotes();

    return {
      'folders': folders.map((f) => f.toJson()).toList(),
      'notes': notes.map((n) => n.toJson()).toList(),
    };
  }
}
