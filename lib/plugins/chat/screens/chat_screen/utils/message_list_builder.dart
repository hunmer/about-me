import 'package:uuid/uuid.dart';
import 'package:aboutme/plugins/chat/models/message.dart';
import 'package:path/path.dart' as path;

class MessageListBuilder {
  /// 解析文件名和大小信息
  static Map<String, dynamic>? _parseFileInfo(
    String content,
    MessageType type,
  ) {
    if (type != MessageType.file &&
        type != MessageType.video &&
        type != MessageType.image) {
      return null;
    }

    // 解析文件大小
    final sizeMatch = RegExp(r'\(([\d.]+)\s*([KMG]?B)\)$').firstMatch(content);
    if (sizeMatch == null) return null;

    // 解析文件名
    final fileNameMatch = RegExp(r'[📎🎥📷]?\s*(.+?)\s*\(').firstMatch(content);
    if (fileNameMatch == null) return null;

    String fileName = fileNameMatch.group(1)?.trim() ?? '';
    String fileSizeStr = sizeMatch.group(1) ?? '0';
    String sizeUnit = sizeMatch.group(2) ?? 'B';

    // 生成唯一ID
    String id = const Uuid().v4();

    // 计算文件大小（转换为字节）
    double size = double.parse(fileSizeStr);
    switch (sizeUnit) {
      case 'KB':
        size *= 1024;
        break;
      case 'MB':
        size *= 1024 * 1024;
        break;
      case 'GB':
        size *= 1024 * 1024 * 1024;
        break;
    }

    // 推测文件类型
    String mimeType;
    switch (type) {
      case MessageType.video:
        mimeType = 'video/mp4';
        break;
      case MessageType.image:
        mimeType = 'image/${path.extension(fileName).replaceAll('.', '')}';
        break;
      default:
        mimeType = 'application/octet-stream';
    }

    // 对文件名进行URL编码，避免特殊字符导致的问题
    String encodedFileName = Uri.encodeFull(fileName);

    return {
      Message.metadataKeyFileInfo: {
        'id': id,
        'fileName': encodedFileName,
        'filePath': encodedFileName, // 实际路径应该根据你的文件存储策略来设置
        'fileSize': size.toInt(),
        'mimeType': mimeType,
        'timestamp': DateTime.now().toIso8601String(),
        'type':
            type == MessageType.video
                ? 'video'
                : type == MessageType.image
                ? 'image'
                : 'document',
      },
    };
  }

  /// 构建带有日期分隔符的消息列表
  static Future<List<dynamic>> buildMessageListWithDateSeparators(
    List<Message> messages,
    DateTime? selectedDate,
  ) async {
    if (messages.isEmpty) {
      return [];
    }

    // 创建消息列表的副本，并确保文件类型消息的metadata正确设置
    List<Message> filteredMessages = await Future.wait(
      messages.map((msg) async {
        if (msg.metadata == null) {
          final metadata = _parseFileInfo(msg.content, msg.type);
          if (metadata != null) {
            return await msg.copyWith(metadata: metadata);
          }
        }
        return msg;
      }),
    );

    // 如果选择了日期，过滤出该日期的消息
    if (selectedDate != null) {
      filteredMessages =
          filteredMessages.where((msg) {
            final msgDate = DateTime(
              msg.date.year,
              msg.date.month,
              msg.date.day,
            );
            final selected = DateTime(
              selectedDate.year,
              selectedDate.month,
              selectedDate.day,
            );
            return msgDate.isAtSameMomentAs(selected);
          }).toList();

      if (filteredMessages.isEmpty) {
        return [];
      }
    }

    // 按日期时间升序排序（因为ListView是reverse的，所以这里用升序）
    filteredMessages.sort(
      (a, b) => a.date.millisecondsSinceEpoch.compareTo(
        b.date.millisecondsSinceEpoch,
      ),
    );

    // 构建包含日期分隔符的列表
    List<dynamic> result = [];
    DateTime? lastDate;

    // 由于ListView是reverse的，所以这里反向遍历消息列表
    for (int i = filteredMessages.length - 1; i >= 0; i--) {
      final message = filteredMessages[i];
      final messageDate = DateTime(
        message.date.year,
        message.date.month,
        message.date.day,
      );

      // 如果是新的一天或者是最后一条消息，添加日期分隔符
      if (lastDate == null || !_isSameDay(lastDate, messageDate)) {
        // 添加日期分隔符（如果不是第一条消息）
        if (lastDate != null) {
          result.add(lastDate);
        }
        lastDate = messageDate;
      }
      result.add(message);
    }

    // 添加最后一个日期分隔符
    if (lastDate != null) {
      result.add(lastDate);
    }

    return result;
  }

  /// 判断两个日期是否为同一天
  static bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}
