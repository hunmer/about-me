/// 文件名仅用于展示与媒体解码提示，不参与存储路径。
String assetMediaType(String fileName) {
  final extension = fileName.split('.').last.toLowerCase();
  return const {
    'png': 'image/png', 'apng': 'image/apng', 'gif': 'image/gif',
    'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'webp': 'image/webp',
    'bmp': 'image/bmp', 'svg': 'image/svg+xml',
    'mp4': 'video/mp4', 'mov': 'video/quicktime', 'avi': 'video/x-msvideo',
    'webm': 'video/webm', 'mp3': 'audio/mpeg', 'wav': 'audio/wav',
    'm4a': 'audio/mp4', 'aac': 'audio/aac', 'ogg': 'audio/ogg',
    'pdf': 'application/pdf', 'txt': 'text/plain', 'zip': 'application/zip',
  }[extension] ?? 'application/octet-stream';
}
