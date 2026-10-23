import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:aboutme/plugins/chat/models/file_message.dart';
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:aboutme_data_sdk/aboutme_data_sdk.dart' show assetMediaType;

// 用于返回保存文件的结果
class SaveFileResult {
  final File savedFile;
  final String systemFileName;
  final String? storagePath;

  SaveFileResult(this.savedFile, this.systemFileName, {this.storagePath});
}

class FileService {
  // 选择文件
  Future<FileMessage?> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: kIsWeb,
    );

    if (result != null && result.files.isNotEmpty) {
      final platformFile = result.files.first;
      final assets = AboutmeDataService.instance.data.assets;
      final asset = kIsWeb
        ? await assets.upload(platformFile.bytes ?? (throw StateError('选择器没有返回文件字节')),
            fileName: platformFile.name, mediaType: getMimeType(platformFile.name) ?? 'application/octet-stream',
            clientMutationId: const Uuid().v4())
        : await assets.importSelectedFile(platformFile.path ?? (throw StateError('选择器没有返回文件路径')),
            fileName: platformFile.name, mediaType: getMimeType(platformFile.name) ?? 'application/octet-stream',
            clientMutationId: const Uuid().v4());
      return FileMessage.fromAsset(asset, originalFileName: platformFile.name);
    }
    return null;
  }

  // 保存文件到应用目录
  Future<SaveFileResult> _saveFile(
    File sourceFile, {
    String? subdirectory,
  }) async {
    final assets = AboutmeDataService.instance.data.assets;
    final name = path.basename(sourceFile.path);
    final asset = await assets.importSelectedFile(sourceFile.path,
      fileName: name, mediaType: subdirectory == 'audios' && path.extension(name).toLowerCase() == '.webm'
        ? 'audio/webm' : getMimeType(name) ?? 'application/octet-stream',
      clientMutationId: const Uuid().v4());
    final localPath = await assets.resolvePath(asset.id);
    return SaveFileResult(File(localPath), asset.fileName, storagePath: asset.reference);
  }

  // 保存图片到应用目录
  Future<File> saveImage(File imageFile) async {
    final saveResult = await _saveFile(imageFile, subdirectory: 'images');
    return saveResult.savedFile;
  }

  // 保存视频到应用目录
  Future<File> saveVideo(File videoFile) async {
    final saveResult = await _saveFile(videoFile, subdirectory: 'videos');
    return saveResult.savedFile;
  }

  // 保存音频到应用目录
  Future<File> saveAudio(File audioFile) async {
    final saveResult = await _saveFile(audioFile, subdirectory: 'audios');
    return saveResult.savedFile;
  }

  /// 保存音频字节为聊天附件（Web 录音等无本地文件场景），
  /// 返回 './chat/chat_files/audios/xxx' 相对存储路径
  Future<String> saveAudioBytes(List<int> bytes, String fileName) async {
    final asset = await AboutmeDataService.instance.data.assets.upload(
      Uint8List.fromList(bytes), fileName: fileName,
      mediaType: path.extension(fileName).toLowerCase() == '.webm'
        ? 'audio/webm' : getMimeType(fileName) ?? 'application/octet-stream',
      clientMutationId: const Uuid().v4());
    return asset.reference;
  }

  /// 保存图片字节为聊天附件（内置表情等无本地文件场景），
  /// 返回 './chat/chat_files/images/xxx' 相对存储路径
  Future<String> saveImageBytes(List<int> bytes, String fileName) async {
    final asset = await AboutmeDataService.instance.data.assets.upload(
      Uint8List.fromList(bytes), fileName: fileName,
      mediaType: getMimeType(fileName) ?? 'application/octet-stream',
      clientMutationId: const Uuid().v4());
    return asset.reference;
  }

  // 删除文件
  Future<bool> deleteFile(String filePath) async {
    final assets = AboutmeDataService.instance.data.assets;
    final reference = filePath.startsWith('asset://') ? filePath : assets.referenceForResolvedPath(filePath);
    if (reference == null) throw ArgumentError('删除附件需要 SDK 资源引用');
    return assets.remove(reference.substring(8));
  }

  // 获取文件MIME类型
  String? getMimeType(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    switch (ext) {
      case '.pdf':
        return 'application/pdf';
      case '.doc':
        return 'application/msword';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case '.xls':
        return 'application/vnd.ms-excel';
      case '.xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case '.ppt':
        return 'application/vnd.ms-powerpoint';
      case '.pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case '.txt':
        return 'text/plain';
      // 图片格式
      case '.png':
        return 'image/png';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.gif':
        return 'image/gif';
      case '.bmp':
        return 'image/bmp';
      case '.webp':
        return 'image/webp';
      case '.svg':
        return 'image/svg+xml';
      // 音频格式
      case '.mp3':
        return 'audio/mpeg';
      // 视频格式
      case '.mp4':
        return 'video/mp4';
      case '.mov':
        return 'video/quicktime';
      case '.avi':
        return 'video/x-msvideo';
      case '.wmv':
        return 'video/x-ms-wmv';
      case '.flv':
        return 'video/x-flv';
      case '.webm':
        return 'video/webm';
      case '.zip':
        return 'application/zip';
      default:
        return assetMediaType(filePath);
    }
  }

  // 获取文件类型
  FileType getFileType(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.gif':
      case '.bmp':
      case '.webp':
      case '.svg':
        return FileType.image;
      case '.mp4':
      case '.mov':
      case '.avi':
      case '.wmv':
      case '.flv':
      case '.webm':
        return FileType.video;
      case '.mp3':
      case '.wav':
      case '.ogg':
      case '.m4a':
        return FileType.audio;
      default:
        return FileType.any;
    }
  }

  // 检查文件是否为图片
  bool isImage(String filePath) {
    return getFileType(filePath) == FileType.image;
  }

  // 检查文件是否为视频
  bool isVideo(String filePath) {
    return getFileType(filePath) == FileType.video;
  }

  // 检查文件是否为音频
  bool isAudio(String filePath) {
    return getFileType(filePath) == FileType.audio;
  }

  // 获取视频缩略图
  Future<String?> getVideoThumbnail(String videoPath) async {
    // 当前宿主尚未提供缩略图生成器；不能返回不存在的假文件路径。
    return null;
  }
}
