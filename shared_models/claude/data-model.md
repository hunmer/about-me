# 数据模型

> 所属：shared_models · [返回索引](../CLAUDE.md)

## 各层模型

| 层 | 文件/目录 | 模型内容 |
|----|-----------|----------|
| Repository | `repositories/<plugin>/<plugin>_repository.dart` ×20 | 抽象接口：分页列表、按 ID 取、创建、更新、删除等（与 JS API 命名约定对齐） |
| UseCase | `usecases/<plugin>/<plugin>_usecase.dart` ×20 | 业务用例封装，屏蔽数据来源 |
| 同步协议 | `sync/sync_request.dart`、`sync/sync_response.dart` | 客户端 ↔ server-nodejs 的同步载荷 |
| 认证 | `auth/auth_models.dart` | 登录/令牌等认证 DTO |
| 总导出 | `shared_models.dart` | 统一 export 全部公开模型 |

## 通用工具（`lib/utils/`）

| 文件 | 用途 |
|------|------|
| `pagination.dart` | 分页参数与结果 |
| `validation.dart` | 参数校验 |
| `result.dart` | 统一结果类型（成功/失败） |
| `md5_utils.dart` | MD5（数据一致性校验/同步比对） |
| `iterable_extensions.dart` | Iterable 扩展方法 |

## 序列化

- 注解驱动：`json_annotation` 注解模型 → `dart run build_runner build` 生成 `.g.dart`。
- 改字段后必须重新生成，否则运行时序列化不一致。
