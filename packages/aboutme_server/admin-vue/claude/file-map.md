# 文件地图

> 所属：packages/server-nodejs/admin-vue · [返回索引](../CLAUDE.md)

```
src/
├── main.ts · App.vue                 # 入口与根组件
├── api/
│   ├── index.ts                      # ApiClient + authApi/syncApi/devicesApi/pluginsApi
│   └── types.ts                      # 接口类型
├── stores/                           # Pinia：auth · files · devices · plugins · ui
├── utils/format.ts                   # 格式化工具
├── assets/                           # hero.png、图标
└── components/
    ├── layout/    AppHeader · TabNavigation
    ├── common/    LoadingOverlay · NaiveProviderContent
    ├── login/     LoginForm · RegisterForm
    ├── overview/  OverviewTab · StatsGrid · ActivityList
    ├── files/     FilesTab
    ├── devices/   DevicesTab
    ├── plugins/   PluginsTab
    ├── api-keys/  ApiKeysTab · CreateKeyModal · KeyResultModal
    └── settings/  SettingsTab · ApiControl · DataOperations
```

工程配置：`package.json`、`tsconfig`（@vue/tsconfig）、`vite.config.*`、`index.html`。
