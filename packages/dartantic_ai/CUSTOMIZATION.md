# dartantic_ai 本地定制

## 上游来源

- 来源：pub.dev `dartantic_ai`
- 当前基线：`3.4.2`
- 上游缓存复制到本目录；SDK 与 example 的 `pubspec.yaml` 均移除了上游 workspace 专用的 `resolution: workspace`，example 改为 path 引用本地 SDK。
- 根项目通过 path dependency 引用本目录。此版本要求 Dart `^3.10.0`。

## 本地修改

| 文件 | 修改 | 原因 |
|------|------|------|
| `lib/src/providers/anthropic_provider.dart` | `AnthropicProvider` 构造函数开放 `Uri? baseUrl`，去掉尾部 `/v1` 后传给 provider 基类 | 让标准 Anthropic provider 和 chat model 使用自定义 Anthropic 兼容 endpoint，避免 SDK 再追加 `/v1/...` 时重复版本路径 |
| `example/pubspec.yaml` | 移除 workspace 声明，改用 `path: ../` 依赖本地 SDK | 让复制到独立仓库的上游示例仍可解析并验证本地改动 |
| `test/anthropic_custom_base_url_test.dart` | 新增本地 HTTP/SSE 测试，验证请求发送到配置的 endpoint，并由 SDK 追加 `/v1/messages` | 防止 provider 收到参数但请求仍发到官方域名 |

传给 provider 的 URL 可以带或不带尾部 `/v1`；provider 会归一化尾部版本段，底层 SDK 再追加 `/v1/messages`。例如 `https://api.anthropic.com/v1` 和 `https://api.anthropic.com` 最终都请求官方 Messages endpoint，`https://open.bigmodel.cn/api/anthropic` 则请求其前缀下的 `/v1/messages`。

## 同步上游最新版

1. 查询 pub.dev 最新版本，下载对应 tarball，记录版本号和最低 Dart SDK 约束。
2. 将包解压到临时目录，与本目录比较；迁移源码时保留 `CUSTOMIZATION.md`，不要直接覆盖本地目录。
3. 从上游基线重新应用本节列出的 `AnthropicProvider` 改动，并检查新版本是否已原生支持 `baseUrl`；若已支持，则删除重复补丁并更新文档。
4. 保留或迁移 `anthropic_custom_base_url_test.dart`，确认带 `/v1` 的传入 URL 最终用于 Messages 请求且没有重复路径。
5. 更新本文件的上游版本与修改记录，在 SDK/example 清单中移除 `resolution: workspace`（若上游仍包含），并让 example 继续 path 引用本包；检查根项目 Dart SDK 约束和 path dependency。
6. 在 SDK 包目录运行 `dart pub get`、`dart test test/anthropic_custom_base_url_test.dart`；回到仓库根目录运行 `flutter pub get`、相关 Flutter 测试与 `flutter analyze`。

不要直接在 pub cache 中修改 SDK；pub cache 会被依赖重装覆盖。
