/// 旧客户端与 MCP 格式兼容读取；保留全部未知字段。
/// 新业务写入使用 title、date、user；旧别名仅用于兼容已有消费者。
class ChatCodec {
  static Map<String, dynamic> channel(Map<String, dynamic> json) {
    final result = Map<String, dynamic>.from(json);
    result['title'] = (json['title'] ?? json['name'] ?? '未命名频道').toString();
    final color = json['backgroundColor'] ?? json['color'];
    if (color is int)
      result['backgroundColor'] = '#${color.toRadixString(16).padLeft(8, '0')}';
    if (json['icon'] is String) {
      result['icon'] = int.tryParse(json['icon'] as String) ?? 0xe0b7;
    }
    return result;
  }

  static Map<String, dynamic> message(Map<String, dynamic> json,
      {String? channelId}) {
    final result = Map<String, dynamic>.from(json);
    final rawUser = json['user'];
    final user = rawUser is Map
        ? Map<String, dynamic>.from(rawUser)
        : <String, dynamic>{};
    user['id'] ??=
        json['senderId'] ?? (rawUser is String ? rawUser : 'unknown');
    user['username'] ??= user['name'] ?? json['senderName'] ?? 'Unknown User';
    user['name'] ??= user['username'];
    user['iconPath'] ??= user['avatarPath'];
    result['user'] = user;
    result['channelId'] ??= channelId;
    result['date'] ??= json['createdAt'];
    result['createdAt'] ??= result['date'];
    result['type'] ??= 'sent';
    return result;
  }
}
