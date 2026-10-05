/// JS 引擎平台接口
abstract class JSEngine {
  /// 初始化 JS 引擎
  Future<void> initialize();

  /// 执行 JS 代码（用户代码，包装后等待结果）
  ///
  /// [timeout] 等待结果的最大时长，为 null 时使用引擎默认值
  Future<JSResult> evaluate(String code, {Duration? timeout});

  /// 直接执行 JS 代码（内部使用，不包装，不等待结果）
  /// 用于注册函数、创建命名空间等操作
  Future<void> evaluateDirect(String code);

  /// 设置全局变量
  Future<void> setGlobal(String name, dynamic value);

  /// 获取全局变量
  Future<dynamic> getGlobal(String name);

  /// 注册 Dart 函数到 JS
  Future<void> registerFunction(String name, Function dartFunction);

  /// 终止当前正在执行的脚本（协作式：reject 挂起 Promise + 轮询退出）
  void requestAbortAll();

  /// 释放资源
  Future<void> dispose();

  /// 获取支持的平台
  bool get isSupported;
}

/// JS 执行结果
class JSResult {
  final bool success;
  final dynamic result;
  final String? error;

  JSResult.success(this.result)
      : success = true,
        error = null;
  JSResult.error(this.error)
      : success = false,
        result = null;

  @override
  String toString() {
    if (success) {
      return 'Success: ${result.toString()}';
    } else {
      return 'Error: $error';
    }
  }
}
