/// ISO 时间字符串统一解析入口。
///
/// 服务端 / aboutme_data_sdk 以 UTC ISO（`Z` 结尾，见
/// `jsIsoDateTime`）存储时间，`DateTime.parse` 对带 `Z` 的字符串
/// 会得到 UTC `DateTime`，直接取 `hour`/`day` 展示会差时区
/// （东八区少 8 小时）。全仓 ISO 解析统一走本入口，解析后
/// `toLocal()`；无时区标记的字符串 `DateTime.parse` 本就返回
/// 本地时间，`toLocal()` 为恒等变换，安全。
library;

/// 解析 ISO 字符串并转为本地时区；格式非法抛 [FormatException]。
DateTime parseIsoDateTime(String input) => DateTime.parse(input).toLocal();

/// 解析 ISO 字符串并转为本地时区；输入为 null/空或格式非法返回 null。
DateTime? tryParseIsoDateTime(String? input) {
  if (input == null || input.isEmpty) return null;
  return DateTime.tryParse(input)?.toLocal();
}
