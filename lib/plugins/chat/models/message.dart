import 'package:aboutme/models/file_path_converter.dart';
import 'package:flutter/material.dart';
import 'user.dart';
import 'package:aboutme/utils/color_extension.dart';
import 'package:aboutme/plugins/chat/chat_plugin.dart';
enum MessageType { received, sent, file, image, video, audio }

class Message {
  Map<String, dynamic>? sdkSnapshot;
  int? sdkVersion;
  static const String metadataKeyFileInfo = 'fileInfo';

  final String id;
  String content; // 改为非final以支持编辑
  final User user;
  final DateTime date;
  final MessageType type;
  DateTime? editedAt; // 添加编辑时间字段
  String? fixedSymbol; // 添加固定符号字段
  String? channelId; // 频道ID
  Color? bubbleColor; // 添加气泡颜色字段
  Map<String, dynamic>? metadata; // 添加元数据字段，用于存储额外信息
  Message? replyTo; // 添加回复消息引用
  String? replyToId; // 添加回复消息ID

  // 添加getter，将updatedAt映射到editedAt
  DateTime? get updatedAt => editedAt;
  
  // 添加getter，将createdAt映射到date
  DateTime get createdAt => date;

  Message({
    required this.id,
    required this.content,
    required this.user,
    required this.type,
    DateTime? date,
    this.editedAt,
    this.fixedSymbol,
    this.bubbleColor,
    this.channelId,
    this.metadata,
    Message? replyTo,
    this.replyToId, 
  }) : date = date ?? DateTime.now() {
    // 如果提供了replyTo，确保设置replyToId
    if (replyTo != null) {
      replyToId = replyTo.id;
    }
  }

  /// 初始化消息，处理文件路径转换
  static Future<Message> create({
    required String id,
    required String content,
    required User user,
    required MessageType type,
    DateTime? date,
    DateTime? editedAt,
    String? fixedSymbol,
    String? channelId,
    Color? bubbleColor,
    Map<String, dynamic>? metadata,
    Message? replyTo,
    String? replyToId,
  }) async {
    // 创建基本消息实例
    final message = Message(
      id: id,
      channelId: channelId,
      content: content,
      user: user,
      type: type,
      date: date,
      editedAt: editedAt,
      fixedSymbol: fixedSymbol,
      bubbleColor: bubbleColor,
      metadata: metadata,
      replyTo: replyTo,
      replyToId: replyToId ?? replyTo?.id,
    );

    // 处理 metadata 中的文件路径，转换为绝对路径
    if (metadata != null && metadata.containsKey(Message.metadataKeyFileInfo)) {
      final fileInfo = Map<String, dynamic>.from(
        metadata[Message.metadataKeyFileInfo] as Map<String, dynamic>,
      );
      if (fileInfo.containsKey('filePath')) {
        final filePath = fileInfo['filePath'] as String;
        // 只有当路径是相对路径时才进行转换
        if (filePath.startsWith('./')) {
          // 使用FilePathConverter将相对路径转换为绝对路径
          fileInfo['filePath'] = await FilePathConverter.toAbsolutePath(
            filePath,
          );
        }
      }
      // 更新转换后的fileInfo
      message.metadata![Message.metadataKeyFileInfo] = fileInfo;
    }

    return message;
  }

  /// 创建消息的副本，可选择性地更新某些字段
  Future<Message> copyWith({
    String? id,
    String? content,
    User? user,
    DateTime? date,
    MessageType? type,
    DateTime? editedAt,
    String? fixedSymbol,
    Color? bubbleColor,
    String? channelId,
    Map<String, dynamic>? metadata,
    Message? replyTo,
    String? replyToId,
  }) async {
    final next = await create(
      id: id ?? this.id,
      content: content ?? this.content,
      user: user ?? this.user,
      date: date ?? this.date,
      type: type ?? this.type,
      editedAt: editedAt ?? this.editedAt,
      fixedSymbol: fixedSymbol ?? this.fixedSymbol,
      bubbleColor: bubbleColor ?? this.bubbleColor,
      channelId: channelId ?? this.channelId,
      metadata: metadata ?? this.metadata,
      replyTo: replyTo ?? this.replyTo,
      replyToId: replyToId ?? this.replyToId,
    );
    next.sdkSnapshot = sdkSnapshot;
    next.sdkVersion = sdkVersion;
    return next;
  }

  // 编辑消息内容
  void edit(String newContent) {
    content = newContent;
    editedAt = DateTime.now();
  }

  // 判断消息是否被编辑过
  bool get isEdited => editedAt != null;

  // 设置固定符号
  void setFixedSymbol(String? symbol) {
    fixedSymbol = symbol;
  }

  // 判断是否为音频消息
  bool get isAudioMessage => type == MessageType.audio;

  // 获取音频消息的元数据
  Map<String, dynamic>? get audioMetadata {
    if (isAudioMessage &&
        metadata != null &&
        metadata!.containsKey(metadataKeyFileInfo)) {
      return metadata![metadataKeyFileInfo] as Map<String, dynamic>;
    }
    return null;
  }

  // 获取音频消息的时长（秒）
  int get audioDuration {
    final data = audioMetadata;
    if (data != null && data.containsKey('duration')) {
      return data['duration'] as int;
    }
    return 0;
  }

  /// 将消息转换为JSON格式
  Future<Map<String, dynamic>> toJson() async {
    // 获取原始的 metadata
    final messageMetadata =
        metadata != null
            ? Map<String, dynamic>.from(metadata!)
            : <String, dynamic>{};

    // 确保文件路径是相对路径格式
    if (messageMetadata.containsKey(Message.metadataKeyFileInfo)) {
      final fileInfo = Map<String, dynamic>.from(
        messageMetadata[Message.metadataKeyFileInfo] as Map<String, dynamic>,
      );
      if (fileInfo.containsKey('filePath')) {
        final filePath = fileInfo['filePath'] as String;
        fileInfo['filePath'] = (await FilePathConverter.toRelativePath(
          filePath,
        )).replaceAll('./app_data/', './');
      }
      // 更新转换后的fileInfo
      messageMetadata[Message.metadataKeyFileInfo] = fileInfo;
    }
    
    // 确保回复关系在metadata中也有记录
    final String? replyId = replyToId ?? replyTo?.id;
    // channelId不需要保存
    return {
      'id': id,
      'content': content,
      'user': {'id': user.id}, // 保存用户ID作为对象
      'type': type.toString().split('.').last,
      'date': date.toIso8601String(),
      'editedAt': editedAt?.toIso8601String(),
      'fixedSymbol': fixedSymbol,
      'bubbleColor': bubbleColor?.toHex(),
      'metadata': messageMetadata,
      'replyToId': replyId,
    };
  }

  /// 从JSON格式创建Message实例
  static Future<Message> fromJson(
    Map<String, dynamic> json,
  ) async {
    // 从JSON中获取用户信息
    Map<String, dynamic>? userMap;
    String userId;
    
    if (json.containsKey('user') && json['user'] is Map) {
      userMap = Map<String, dynamic>.from(json['user'] as Map<String, dynamic>);
      userId = userMap['id'] as String;
    } else {
      userId = json['senderId'] as String? ?? 'unknown_user';
      userMap = {'username': json['senderName']};
    }

    // 获取回复消息ID，优先从JSON直接获取，其次从metadata中获取
    final metadata = json['metadata'] as Map<String, dynamic>?;
    final replyToId = json['replyToId'] as String?;

    // 当前用户资料实时读取个人主页数据源（全局用户名/头像），
    // 不再使用消息内保存的资料；其他用户仍从用户列表读取
    final currentUser = ChatPlugin.instance.userService.currentUser;
    if (userId == currentUser.id) {
      return _createWithUser(json, currentUser, metadata, replyToId);
    }

    final users = ChatPlugin.instance.userService.getAllUsers();
    var user = users.firstWhere(
      (u) => u.id == userId,
      orElse: () => User(
        id: userId,
        username: userMap?['username'] as String? ?? 'Unknown User',
      ),
    );

    // 消息内仅允许覆盖用户名（历史消息展示名），头像不随消息保存
    if (userMap != null && userMap['username'] != null) {
      user = user.copyWith(username: userMap['username'] as String?);
    }
    return _createWithUser(json, user, metadata, replyToId);
  }

  static Future<Message> _createWithUser(
    Map<String, dynamic> json,
    User user,
    Map<String, dynamic>? metadata,
    String? replyToId,
  ) {
    // 从JSON中获取channelId，如果不存在则尝试从metadata中获取
    final channelId = json['channelId'] as String?;
    return create(
      id: json['id'] as String,
      content: json['content'] as String,
      user: user,
      type: MessageType.values.firstWhere(
        (t) => t.toString().split('.').last == json['type'],
        orElse: () => MessageType.received,
      ),
      // 服务端以 UTC ISO（Z 结尾）存储，统一入口解析并转本地时区
      date: parseIsoDateTime((json['date'] ?? json['createdAt']) as String),
      editedAt:
          json['editedAt'] != null
              ? parseIsoDateTime(json['editedAt'] as String)
              : null,
      fixedSymbol: json['fixedSymbol'] as String?,
      bubbleColor:
          json['bubbleColor'] != null
              ? HexColor.fromHex(json['bubbleColor'] as String)
              : null,
      channelId: channelId,
      metadata: metadata,
      replyToId: replyToId,
    );
  }

  // 获取原始文件路径（用于存储，保持相对路径）
  String? get originalFilePath {
    final data = metadata?[metadataKeyFileInfo];
    if (data != null &&
        data is Map<String, dynamic> &&
        data.containsKey('filePath')) {
      return data['filePath'] as String;
    }
    return null;
  }
}
