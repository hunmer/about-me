# shared_models 共享数据模型

Memento 客户端与服务端共用的 Dart 包（v1.0.0，纯 Dart、无 Flutter 依赖）：定义 **20 个插件域的 Repository 抽象接口**与 **UseCase 业务层**、同步协议模型（`sync_request` / `sync_response`）、认证模型，以及分页/校验/Result 等通用工具。客户端经根 `pubspec.yaml` 的 path 依赖引入（`import 'package:shared_models/...'`）；序列化用 `json_annotation` + `json_serializable`（build_runner 生成）。

它是"UseCase 架构"的契约层：插件（JS API 适配）→ UseCase（本包）→ ClientRepository（客户端实现本包接口）→ Service/Controller。

## 约定的规则

- 改接口后跑 `dart run build_runner build` 重新生成序列化代码。
- 新插件接入 UseCase 架构：在 `lib/repositories/<plugin>/` 与 `lib/usecases/<plugin>/` 各加一组文件，并在 `lib/shared_models.dart` 导出（迁移指南 `docs/USECASE_MIGRATION_GUIDE.md`）。
- 本包保持纯 Dart（不得 import Flutter），以保证可被非 Flutter 侧复用。

## 文件索引

| 文件 | 用途 | 何时阅读 |
|------|------|----------|
| [架构总览](claude/overview.md) | 分层契约与目录结构 | 理解 UseCase 架构 |
| [数据模型](claude/data-model.md) | 各层模型与工具类说明 | 设计/修改数据结构 |
| [文件地图](claude/file-map.md) | 46 个 Dart 文件速查 | 找接口 |

## 模块索引

| 模块 | 说明 |
|------|------|
| `lib/repositories/` | 20 个插件域的 Repository 抽象接口 |
| `lib/usecases/` | 与 Repository 对应的 UseCase 层 |
| `lib/sync/` | 同步协议（request/response） |
| `lib/auth/` | 认证模型 |
| `lib/utils/` | pagination / validation / result / md5 / iterable 扩展 |
| `lib/shared_models.dart` | 总导出文件 |

## 扫描状态

- 更新时间：2026-09-01 23:48 (+0800)
- 已扫描：pubspec、全部 46 个 Dart 文件清单、总导出文件结构。
- 未深扫：各接口方法签名（用时可现查对应文件）。
