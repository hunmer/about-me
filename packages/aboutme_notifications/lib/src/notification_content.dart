/// 通知布局类型
enum AboutmeNotificationLayout {
  /// 默认布局
  basic,

  /// 大图布局
  bigPicture,

  /// 大文本布局
  bigText,

  /// 收件箱布局
  inbox,

  /// 进度条布局
  progressBar,

  /// 媒体播放布局
  mediaPlayer,

  /// 消息布局
  messaging,
}

/// 通知内容配置
class AboutmeNotificationContent {
  /// 通知唯一标识
  final int id;

  /// 通知通道标识
  final String channelKey;

  /// 通知标题
  final String title;

  /// 通知正文
  final String body;

  /// 通知布局
  final AboutmeNotificationLayout layout;

  /// 大图 URL（用于大图布局）
  final String? bigPicture;

  /// 大图标 URL
  final String? largeIcon;

  /// 摘要文本
  final String? summary;

  /// 自定义数据
  final Map<String, String>? payload;

  /// 是否自动取消
  final bool autoDismissible;

  /// 是否显示时间
  final bool showWhen;

  /// 进度值（0-100，用于进度条布局）
  final int? progress;

  const AboutmeNotificationContent({
    required this.id,
    required this.channelKey,
    required this.title,
    required this.body,
    this.layout = AboutmeNotificationLayout.basic,
    this.bigPicture,
    this.largeIcon,
    this.summary,
    this.payload,
    this.autoDismissible = true,
    this.showWhen = true,
    this.progress,
  });
}

/// 已接收的通知
class AboutmeReceivedNotification {
  /// 通知 ID
  final int? id;

  /// 通知标题
  final String? title;

  /// 通知正文
  final String? body;

  /// 自定义数据
  final Map<String, String?>? payload;

  /// 通道标识
  final String? channelKey;

  const AboutmeReceivedNotification({
    this.id,
    this.title,
    this.body,
    this.payload,
    this.channelKey,
  });
}

/// 已调度的通知
class AboutmeScheduledNotification {
  /// 通知 ID
  final int id;

  /// 通知标题
  final String? title;

  /// 通知正文
  final String? body;

  /// 调度时间
  final DateTime? scheduledDate;

  const AboutmeScheduledNotification({
    required this.id,
    this.title,
    this.body,
    this.scheduledDate,
  });
}
