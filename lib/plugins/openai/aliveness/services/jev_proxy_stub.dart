import 'package:dio/dio.dart';

/// Web 无 dart:io，无法为 Dio 配置 HttpClient 代理，静默忽略。
void applyJevProxy(Dio dio, String? proxy) {}
