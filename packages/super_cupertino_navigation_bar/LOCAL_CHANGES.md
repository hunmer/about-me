# 本地 vendor 说明

- 来源: https://github.com/kspo/super_cupertino_navigation_bar （克隆时 HEAD = b7e456a，版本 2.1.2，与 pub.dev 2.1.2 的 lib/ 逐字节一致）
- 已移除嵌套 `.git`、`example/`、`screenshots/`，仅保留 lib/pubspec/LICENSE/README/CHANGELOG

## 相对上游 2.1.2 的改动

### lib/models/super_search_bar.model.dart

1. `prefixIcon` 类型从 `Icon` 放宽为 `Widget`（默认值不变，向下游兼容），
   便于传入自定义图标组件
2. 新增 `searchFieldDecoration`（`BoxDecoration?`）：完全自定义搜索框
   容器外观（填充/描边/圆角/阴影）。提供时优先于 `backgroundColor`

### lib/src/super_cupertino_navigation_bar.dart

- 大标题分支下承载可见样式的 `CupertinoSearchTextField`（IgnorePointer
  副本）透传 `searchFieldDecoration`；此时 `backgroundColor` 传 null
  （SDK 侧两者互斥，同时传会 assert）。交互态那处本就是透明背景的
  叠加层，维持不变

## 同步上游

如需跟进上游更新：重新 clone 上游仓库后 `diff -r lib/` 对比，冲突点
集中在上述两个文件的标记区域。
