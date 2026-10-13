part of 'webview_plugin.dart';

// ==================== 本地 HTTP 服务器管理 ====================
//
// 独立 part 文件：本地 HTTP 服务器启停、项目文件复制、
// file:// / ./ 相对路径与 HTTP URL 互转等文件服务职责。

extension WebViewPluginLocalServer on WebViewPlugin {
  /// 获取本地文件存储路径
  String get localFilesPath =>
      '${storage.getPluginStoragePath(id)}/local_files';

  /// 检查 URL 是否为本地文件
  bool isLocalFileUrl(String url) {
    return url.startsWith('file://') || url.contains(localFilesPath);
  }

  /// 启动本地 HTTP 服务器
  Future<void> _startLocalHttpServer() async {
    // 使用统一的 HTTP 服务器根目录
    final rootDir = await getHttpServerRootDir();

    final success = await localHttpServer.start(rootDir: rootDir, port: 8899);

    if (!success) {
      debugPrint('[WebViewPlugin] 本地 HTTP 服务器启动失败');
    }
  }

  /// 获取 HTTP 服务器根目录
  ///
  /// 返回 app_data 目录，以便访问 app_images 等共享目录
  Future<String> getHttpServerRootDir() async {
    if (kIsWeb) {
      return 'http_server'; // Web 平台使用相对路径
    }

    // 返回 app_data 根目录，以便访问 app_images 等共享目录
    final appDataDir = await storageManager.getApplicationDataDirectory();
    return appDataDir.path;
  }

  /// 获取 WebView 项目文件存储目录
  ///
  /// 返回 app_data/webview/http_server 目录，用于存储项目文件
  Future<String> _getWebViewHttpServerDir() async {
    if (kIsWeb) {
      return 'http_server';
    }

    final appDataDir = await storageManager.getApplicationDataDirectory();
    final pluginPath = storageManager.getPluginStoragePath('webview');
    return path.join(appDataDir.path, pluginPath, 'http_server');
  }

  /// 复制本地文件/目录到 HTTP 服务器目录
  ///
  /// [sourcePath] 源文件或目录的绝对路径
  /// [projectName] 项目名称（将作为子目录名）
  /// 返回：复制后的相对路径（如 ./projectName/index.html）
  Future<String> copyToHttpServer({
    required String sourcePath,
    required String projectName,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('Web 平台不支持本地文件操作');
    }

    // 验证项目名称（只允许字母、数字、下划线、连字符）
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(projectName)) {
      throw ArgumentError('项目名称只能包含字母、数字、下划线和连字符');
    }

    // 使用 WebView 专用的 HTTP 服务器目录
    final webViewHttpRoot = await _getWebViewHttpServerDir();
    final projectDir = path.join(webViewHttpRoot, projectName);

    // 获取 HTTP 服务器根目录（用于计算相对路径）
    final httpRoot = await getHttpServerRootDir();

    try {
      // 创建项目目录
      final dir = Directory(projectDir);
      if (await dir.exists()) {
        // 如果目录已存在，先删除
        await dir.delete(recursive: true);
      }
      await dir.create(recursive: true);

      // 优先使用 pendingFilesToCopy（Android 11+ SAF 方式）
      if (pendingFilesToCopy != null && pendingFilesToCopy!.isNotEmpty) {
        debugPrint(
          '[WebViewPlugin] 使用 pendingFilesToCopy 复制 ${pendingFilesToCopy!.length} 个文件',
        );
        await _copyFilesFromList(pendingFilesToCopy!, sourcePath, projectDir);
        pendingFilesToCopy = null; // 清空列表

        // 查找入口文件
        final entryFile = await _findEntryFile(projectDir);
        if (entryFile != null) {
          // 计算相对于 app_data 的路径
          final relativePath = path.relative(entryFile, from: httpRoot);
          return './${relativePath.replaceAll(path.separator, '/')}';
        } else {
          return './webview/http_server/$projectName/';
        }
      }

      // 传统方式：直接访问文件系统
      final source = FileSystemEntity.typeSync(sourcePath);

      if (source == FileSystemEntityType.file) {
        // 复制单个文件
        final sourceFile = File(sourcePath);
        final fileName = path.basename(sourcePath);
        final targetPath = path.join(projectDir, fileName);

        await sourceFile.copy(targetPath);
        debugPrint('[WebViewPlugin] 文件已复制: $sourcePath -> $targetPath');

        // 如果是 HTML 文件，同时复制同目录下的 preload.js（如果存在）
        if (fileName.endsWith('.html')) {
          final sourceDir = path.dirname(sourcePath);
          final preloadJsPath = path.join(sourceDir, 'preload.js');
          final preloadJsFile = File(preloadJsPath);

          if (await preloadJsFile.exists()) {
            final targetPreloadPath = path.join(projectDir, 'preload.js');
            await preloadJsFile.copy(targetPreloadPath);
            debugPrint(
              '[WebViewPlugin] preload.js 已复制: $preloadJsPath -> $targetPreloadPath',
            );
          }
        }

        // 返回相对路径（相对于 app_data）
        return './webview/http_server/$projectName/$fileName';
      } else if (source == FileSystemEntityType.directory) {
        // 复制整个目录
        await _copyDirectory(sourcePath, projectDir);
        debugPrint('[WebViewPlugin] 目录已复制: $sourcePath -> $projectDir');

        // 查找入口文件（index.html 或第一个 .html 文件）
        final entryFile = await _findEntryFile(projectDir);
        if (entryFile != null) {
          // 计算相对于 app_data 的路径
          final relativePath = path.relative(entryFile, from: httpRoot);
          return './${relativePath.replaceAll(path.separator, '/')}';
        } else {
          return './webview/http_server/$projectName/';
        }
      } else {
        throw ArgumentError('源路径不是有效的文件或目录: $sourcePath');
      }
    } catch (e) {
      debugPrint('[WebViewPlugin] 复制文件失败: $e');
      rethrow;
    }
  }

  /// 从文件列表复制文件（用于 Android 11+ SAF 方式）
  Future<void> _copyFilesFromList(
    List<String> filePaths,
    String baseSourcePath,
    String targetDir,
  ) async {
    int fileCount = 0;

    for (final filePath in filePaths) {
      try {
        final sourceFile = File(filePath);
        if (!await sourceFile.exists()) {
          debugPrint('[WebViewPlugin] 文件不存在，跳过: $filePath');
          continue;
        }

        // 计算相对路径（相对于 baseSourcePath）
        String relativePath;
        if (filePath.startsWith(baseSourcePath)) {
          relativePath = filePath.substring(baseSourcePath.length);
          if (relativePath.startsWith('/') || relativePath.startsWith('\\')) {
            relativePath = relativePath.substring(1);
          }
        } else {
          // 如果不在 baseSourcePath 下，只取文件名
          relativePath = path.basename(filePath);
        }

        final targetPath = path.join(targetDir, relativePath);

        // 确保目标目录存在
        final targetFileDir = Directory(path.dirname(targetPath));
        if (!await targetFileDir.exists()) {
          await targetFileDir.create(recursive: true);
        }

        await sourceFile.copy(targetPath);
        fileCount++;
        debugPrint('[WebViewPlugin] 文件复制成功: $relativePath');
      } catch (e) {
        debugPrint('[WebViewPlugin] 复制文件失败: $filePath, 错误: $e');
      }
    }

    debugPrint('[WebViewPlugin] 文件列表复制完成，共 $fileCount 个文件');
  }

  /// 递归复制目录
  Future<void> _copyDirectory(String sourcePath, String targetPath) async {
    final sourceDir = Directory(sourcePath);
    final targetDir = Directory(targetPath);

    // 检查源目录是否存在
    if (!await sourceDir.exists()) {
      debugPrint('[WebViewPlugin] 错误: 源目录不存在: $sourcePath');
      throw Exception('源目录不存在: $sourcePath');
    }

    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    // 统计文件数量
    int fileCount = 0;
    int dirCount = 0;

    try {
      final entities = await sourceDir.list(recursive: false).toList();
      debugPrint('[WebViewPlugin] 源目录包含 ${entities.length} 个项目: $sourcePath');

      for (final entity in entities) {
        final name = path.basename(entity.path);

        // 跳过隐藏文件和系统文件
        if (name.startsWith('.')) {
          debugPrint('[WebViewPlugin] 跳过隐藏文件: $name');
          continue;
        }

        if (entity is File) {
          final targetFile = path.join(targetPath, name);
          try {
            await entity.copy(targetFile);
            fileCount++;
            debugPrint('[WebViewPlugin] 文件复制成功: $name');
          } catch (e) {
            debugPrint('[WebViewPlugin] 文件复制失败: $name, 错误: $e');
            rethrow;
          }
        } else if (entity is Directory) {
          final targetSubDir = path.join(targetPath, name);
          debugPrint('[WebViewPlugin] 进入子目录: $name');
          await _copyDirectory(entity.path, targetSubDir);
          dirCount++;
        }
      }

      debugPrint(
        '[WebViewPlugin] 目录复制完成: $sourcePath -> $targetPath (文件: $fileCount, 子目录: $dirCount)',
      );
    } catch (e) {
      debugPrint('[WebViewPlugin] 列出目录内容失败: $sourcePath, 错误: $e');
      rethrow;
    }
  }

  /// 查找入口文件（index.html 或第一个 .html 文件）
  Future<String?> _findEntryFile(String directoryPath) async {
    final dir = Directory(directoryPath);

    // 优先查找 index.html
    final indexFile = File(path.join(directoryPath, 'index.html'));
    if (await indexFile.exists()) {
      return indexFile.path;
    }

    // 查找第一个 .html 文件
    await for (final entity in dir.list(recursive: false)) {
      if (entity is File && entity.path.toLowerCase().endsWith('.html')) {
        return entity.path;
      }
    }

    return null;
  }

  /// 获取项目列表（HTTP 服务器目录下的所有子目录）
  Future<List<String>> getHttpProjects() async {
    if (kIsWeb) return [];

    final httpRoot = await getHttpServerRootDir();
    final dir = Directory(httpRoot);

    if (!await dir.exists()) {
      return [];
    }

    final projects = <String>[];
    await for (final entity in dir.list(recursive: false)) {
      if (entity is Directory) {
        projects.add(path.basename(entity.path));
      }
    }

    return projects;
  }

  /// 删除 HTTP 项目
  Future<void> deleteHttpProject(String projectName) async {
    if (kIsWeb) return;

    final httpRoot = await getHttpServerRootDir();
    final projectDir = Directory(path.join(httpRoot, projectName));

    if (await projectDir.exists()) {
      await projectDir.delete(recursive: true);
      debugPrint('[WebViewPlugin] 已删除项目: $projectName');
    }
  }

  /// 停止本地 HTTP 服务器
  Future<void> stopLocalHttpServer() async {
    await localHttpServer.stop();
  }

  /// 将 file:// URL 转换为 HTTP URL（如果需要）
  ///
  /// 在 Windows 平台且本地服务器运行时，自动将 file:// URL 转换为 http://localhost URL
  /// 同时支持 ./ 相对路径转换
  String convertUrlIfNeeded(String url) {
    // Web 平台不转换
    if (kIsWeb) {
      return url;
    }

    // 处理 ./ 相对路径
    if (url.startsWith('./')) {
      // 确保服务器运行
      if (!localHttpServer.isRunning) {
        // 同步启动服务器（如果尚未启动）
        _startLocalHttpServer();
      }

      // 将 ./ 转换为 http://localhost:port/
      final relativePath = url.substring(2); // 移除 ./
      return '${localHttpServer.serverUrl}/$relativePath';
    }

    // 只在服务器运行时转换
    if (!localHttpServer.isRunning) {
      return url;
    }

    // 只在 Windows 平台转换 file:// URL
    if (!UniversalPlatform.isWindows) {
      return url;
    }

    // 如果是可转换的本地文件 URL，则转换
    if (localHttpServer.isConvertibleFileUrl(url)) {
      return localHttpServer.convertFileUrlToHttpUrl(url);
    }

    return url;
  }

  /// 将文件路径转换为可访问的 URL
  ///
  /// 优先使用 HTTP URL（Windows），否则使用 file:// URL
  String filePathToUrl(String filePath) {
    // Web 平台不支持本地文件
    if (kIsWeb) {
      return filePath;
    }

    // 如果服务器运行且是 Windows 平台，使用 HTTP URL
    if (localHttpServer.isRunning && UniversalPlatform.isWindows) {
      return localHttpServer.filePathToHttpUrl(filePath);
    }

    // 否则使用 file:// URL
    return _formatFileUrl(filePath);
  }

  /// 将文件路径转换为 file:// URL 格式
  String _formatFileUrl(String filePath) {
    String normalizedPath = filePath.replaceAll('\\', '/');

    if (UniversalPlatform.isWindows) {
      if (normalizedPath.length >= 2 && normalizedPath[1] == ':') {
        normalizedPath =
            normalizedPath[0].toUpperCase() + normalizedPath.substring(1);
      }
      return 'file:///$normalizedPath';
    } else {
      return 'file://$normalizedPath';
    }
  }
}
