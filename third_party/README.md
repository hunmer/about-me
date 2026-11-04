# CI source dependencies（历史存档）

> **已废弃（2026-11-04）**：`flutter_live2d` 源码已并入本仓库
> `packages/flutter_live2d-main`，作为普通 path 依赖随仓库检出，
> CI 不再需要从 tarball 恢复（`setup-live2d` action 已删除）。
> 以下留作历史记录，tarball 保留为 7e829b6 版快照备份（不含后续
> 仓库内修改，如 `modelLoadError` / `setInteractive`）。

`flutter_live2d-7e829b6.tar.gz` contains the runtime source and bundled native
libraries from `hunmer/flutter_live2d` at commit
`7e829b67a6db220c3a50d857c09aeb69c9b068be`.
The upstream repository is private, so CI restored this snapshot without a
personal access token. The archive includes the upstream `LICENSE` and `NOTICES`.

Original refresh command (from the former sibling checkout):

```sh
git -C "../flutter_live2d-main" archive --format=tar.gz \\
  --output="../Aboutme/third_party/flutter_live2d-7e829b6.tar.gz" \\
  "7e829b67a6db220c3a50d857c09aeb69c9b068be" \\
  "android" "ios" "lib" "macos" "windows" "assets/web" \\
  "LICENSE" "NOTICES" "README.md" "pubspec.yaml"
```
