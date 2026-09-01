# 入口与启动

> 所属：packages/api_forwarding_server · [返回索引](../CLAUDE.md)

## 启动

```bash
npm install
npm run dev      # tsc && node dist/index.js
npm run watch    # tsc --watch（开发）
npm run build && npm start
```

- 入口 `src/index.ts`：创建 WebSocket 服务监听 **8654**。
- 客户端侧对接：Memento 客户端内置 `lib/core/api_forwarding/`（ApiForwardingService/Config），在应用设置中配置服务器地址与配对密钥即可。

## 部署提示

- 个人使用可本地运行；公网暴露建议置于反代之后并限制来源，本服务自身无鉴权（见 [架构总览](overview.md)）。
