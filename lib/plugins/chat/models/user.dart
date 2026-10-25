class User {
  final String id;
  final String username;

  const User({required this.id, required this.username});

  /// 将用户信息转换为JSON格式
  Map<String, dynamic> toJson() {
    return {'id': id, 'username': username};
  }

  /// 从JSON格式创建User实例
  static User fromJson(Map<String, dynamic> json) {
    return User(id: json['id'] as String, username: json['username'] as String);
  }

  /// 创建一个新的User实例，可选择性地更新某些字段
  User copyWith({String? id, String? username}) {
    return User(id: id ?? this.id, username: username ?? this.username);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          username == other.username;

  @override
  int get hashCode => id.hashCode ^ username.hashCode;
}
