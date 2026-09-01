# Aboutme 事件系统 JavaScript API 文档

## 概述

Aboutme 提供了完整的事件系统 JavaScript API,允许 JavaScript 代码订阅和监听应用内各个插件的数据变化事件。

## 快速开始

### 基本用法

```javascript
// 订阅事件
const subscriptionId = await Aboutme.events.on('task_added', (event) => {
  console.log('新任务已添加:', event);
  console.log('任务ID:', event.data.itemId);
  console.log('任务标题:', event.data.title);
});

// 取消订阅
await Aboutme.events.off(subscriptionId);
```

---

## API 参考

### Aboutme.events.on()

订阅一个事件,当事件发生时执行回调函数。

#### 语法

```javascript
Aboutme.events.on(eventName, handler) -> Promise<String>
```

#### 参数

| 参数 | 类型 | 说明 |
|------|------|------|
| `eventName` | String | 事件名称(见下方事件列表) |
| `handler` | Function | 事件处理函数,接收事件对象作为参数 |

#### 返回值

返回 Promise,resolve 为订阅 ID(字符串),用于后续取消订阅。

#### 事件对象结构

```javascript
{
  eventName: String,           // 事件名称
  whenOccurred: String,        // 事件发生时间(ISO 8601格式)
  data: {
    itemId: String,            // 项目ID
    title: String,             // 项目标题
    action: String             // 操作类型(added/updated/deleted/completed)
  }
}
```

#### 示例

```javascript
// 监听任务添加事件
const subId = await Aboutme.events.on('task_added', (event) => {
  console.log('新任务:', event.data.title);
  console.log('添加时间:', event.whenOccurred);
});

// 监听日记删除事件
await Aboutme.events.on('calendar_entry_deleted', (event) => {
  console.log('日记已删除:', event.data.itemId);
});
```

---

### Aboutme.events.off()

取消事件订阅,停止接收事件通知。

#### 语法

```javascript
Aboutme.events.off(subscriptionId) -> Promise<Object>
```

#### 参数

| 参数 | 类型 | 说明 |
|------|------|------|
| `subscriptionId` | String | 由 `on()` 方法返回的订阅 ID |

#### 返回值

返回 Promise,resolve 为操作结果对象:

```javascript
{
  success: Boolean  // true 表示成功取消订阅
}
```

#### 示例

```javascript
// 订阅事件
const subId = await Aboutme.events.on('task_completed', handler);

// 稍后取消订阅
const result = await Aboutme.events.off(subId);
console.log('取消成功:', result.success);
```

---

## 可用事件列表

### Todo 插件事件

| 事件名 | 触发时机 | data 内容 |
|--------|---------|-----------|
| `task_added` | 新建任务时 | itemId: 任务ID<br>title: 任务标题<br>action: 'added' |
| `task_deleted` | 删除任务时 | itemId: 任务ID<br>title: 任务标题<br>action: 'deleted' |
| `task_completed` | 任务完成并移入历史时 | itemId: 任务ID<br>title: 任务标题<br>action: 'completed' |

### Calendar Album 插件事件

| 事件名 | 触发时机 | data 内容 |
|--------|---------|-----------|
| `calendar_entry_added` | 新建日记时 | itemId: 日记ID<br>title: 日记标题<br>action: 'added' |
| `calendar_entry_updated` | 更新日记时 | itemId: 日记ID<br>title: 日记标题<br>action: 'updated' |
| `calendar_entry_deleted` | 删除日记时 | itemId: 日记ID<br>title: 日记标题<br>action: 'deleted' |
| `calendar_tag_added` | 添加标签时 | itemId: 标签名称<br>title: 标签名称<br>action: 'added' |
| `calendar_tag_deleted` | 删除标签时 | itemId: 标签名称<br>title: 标签名称<br>action: 'deleted' |

---

## 完整示例

### 示例 1: 监听任务状态变化

```javascript
// 创建一个任务状态追踪器
class TaskTracker {
  constructor() {
    this.subscriptions = [];
    this.init();
  }

  async init() {
    // 监听任务添加
    const addSub = await Aboutme.events.on('task_added', (event) => {
      console.log('✅ 任务已创建:', event.data.title);
      this.updateDashboard();
    });
    this.subscriptions.push(addSub);

    // 监听任务完成
    const completeSub = await Aboutme.events.on('task_completed', (event) => {
      console.log('🎉 任务已完成:', event.data.title);
      this.showCelebration();
      this.updateDashboard();
    });
    this.subscriptions.push(completeSub);

    // 监听任务删除
    const deleteSub = await Aboutme.events.on('task_deleted', (event) => {
      console.log('🗑️ 任务已删除:', event.data.title);
      this.updateDashboard();
    });
    this.subscriptions.push(deleteSub);
  }

  updateDashboard() {
    // 更新仪表板UI
    console.log('更新任务仪表板...');
  }

  showCelebration() {
    // 显示庆祝动画
    console.log('🎊 庆祝动画!');
  }

  async cleanup() {
    // 清理所有订阅
    for (const subId of this.subscriptions) {
      await Aboutme.events.off(subId);
    }
    this.subscriptions = [];
  }
}

// 使用
const tracker = new TaskTracker();

// 清理(在脚本结束时调用)
// await tracker.cleanup();
```

### 示例 2: 日记统计

```javascript
// 创建日记统计器
class DiaryStats {
  constructor() {
    this.todayCount = 0;
    this.totalCount = 0;
    this.init();
  }

  async init() {
    // 监听日记添加
    await Aboutme.events.on('calendar_entry_added', (event) => {
      this.totalCount++;

      // 检查是否是今天的日记
      const eventDate = new Date(event.whenOccurred);
      const today = new Date();
      if (this.isSameDay(eventDate, today)) {
        this.todayCount++;
      }

      console.log(`📊 统计: 今日 ${this.todayCount} 篇, 总计 ${this.totalCount} 篇`);
    });

    // 监听日记删除
    await Aboutme.events.on('calendar_entry_deleted', (event) => {
      this.totalCount--;
      console.log(`📊 统计: 总计 ${this.totalCount} 篇`);
    });
  }

  isSameDay(date1, date2) {
    return date1.getFullYear() === date2.getFullYear() &&
           date1.getMonth() === date2.getMonth() &&
           date1.getDate() === date2.getDate();
  }
}

// 使用
const stats = new DiaryStats();
```

### 示例 3: 标签热度追踪

```javascript
// 标签使用频率追踪
const tagHeatMap = {};
const tagSubscriptions = [];

// 监听标签添加
const addSub = await Aboutme.events.on('calendar_tag_added', (event) => {
  const tagName = event.data.title;

  if (!tagHeatMap[tagName]) {
    tagHeatMap[tagName] = 0;
  }
  tagHeatMap[tagName]++;

  console.log(`🏷️ 标签 "${tagName}" 使用次数:`, tagHeatMap[tagName]);
  console.log('热门标签 Top 5:', getTopTags(5));
});
tagSubscriptions.push(addSub);

// 监听标签删除
const delSub = await Aboutme.events.on('calendar_tag_deleted', (event) => {
  const tagName = event.data.title;
  delete tagHeatMap[tagName];
  console.log(`🗑️ 标签 "${tagName}" 已删除`);
});
tagSubscriptions.push(delSub);

// 获取使用最多的标签
function getTopTags(count) {
  return Object.entries(tagHeatMap)
    .sort(([, a], [, b]) => b - a)
    .slice(0, count)
    .map(([tag, count]) => ({ tag, count }));
}

// 清理订阅
async function cleanup() {
  for (const subId of tagSubscriptions) {
    await Aboutme.events.off(subId);
  }
}
```

### 示例 4: 自动备份触发器

```javascript
// 自动备份系统
class AutoBackup {
  constructor(config = {}) {
    this.config = {
      backupThreshold: 10,      // 10次操作后备份
      ...config
    };
    this.operationCount = 0;
    this.subscriptions = [];
    this.init();
  }

  async init() {
    // 监听所有数据变更事件
    const events = [
      'task_added',
      'task_deleted',
      'task_completed',
      'calendar_entry_added',
      'calendar_entry_updated',
      'calendar_entry_deleted',
    ];

    for (const eventName of events) {
      const subId = await Aboutme.events.on(eventName, (event) => {
        this.operationCount++;
        console.log(`📝 操作计数: ${this.operationCount}`);

        if (this.operationCount >= this.config.backupThreshold) {
          this.triggerBackup();
          this.operationCount = 0;
        }
      });
      this.subscriptions.push(subId);
    }
  }

  triggerBackup() {
    console.log('💾 触发自动备份...');
    // 这里调用备份 API
    // await Aboutme.plugins.backup.createBackup();
  }

  async cleanup() {
    for (const subId of this.subscriptions) {
      await Aboutme.events.off(subId);
    }
    this.subscriptions = [];
  }
}

// 使用
const backup = new AutoBackup({ backupThreshold: 5 });
```

---

## 实现原理

### 事件轮询机制

Aboutme 事件系统使用**轮询机制**来实现 JavaScript 回调:

1. JavaScript 调用 `Aboutme.events.on()` 时,在 Dart 端注册订阅并返回订阅 ID
2. JavaScript 端启动一个定时器(500ms 间隔),定期轮询事件队列
3. 当 Dart 端有新事件时,将事件数据放入队列
4. JavaScript 轮询到新事件后,调用用户提供的回调函数
5. 调用 `Aboutme.events.off()` 时,停止轮询并清理订阅

```javascript
// 内部实现(简化版)
Aboutme.events.on = function(eventName, handler) {
  return Aboutme_events_on(eventName).then(function(subscriptionId) {
    // 启动轮询
    const intervalId = setInterval(function() {
      Aboutme_events_getEvents(subscriptionId).then(function(events) {
        events.forEach(function(event) {
          handler(event); // 调用用户回调
        });
      });
    }, 500);

    // 保存 intervalId 用于后续清理
    Aboutme.events._pollingIntervals[subscriptionId] = intervalId;

    return subscriptionId;
  });
};
```

---

## 注意事项

### 1. 轮询性能

- 轮询间隔为 500ms,不会对性能造成明显影响
- 建议不要订阅过多事件(建议 < 20 个订阅)
- 不再需要时及时调用 `off()` 取消订阅

### 2. 事件顺序

- 事件按发生顺序排列
- 同一轮询周期内的多个事件会批量传递
- 回调函数内的异步操作不会阻塞后续事件

### 3. 错误处理

```javascript
try {
  await Aboutme.events.on('task_added', (event) => {
    // 回调函数中的错误会被捕获
    throw new Error('处理失败');
  });
} catch (e) {
  console.error('订阅失败:', e);
}
```

### 4. 内存管理

```javascript
// ✅ 推荐: 保存订阅 ID 并在适当时机清理
const subscriptions = [];
subscriptions.push(await Aboutme.events.on('task_added', handler1));
subscriptions.push(await Aboutme.events.on('task_deleted', handler2));

// 清理
for (const subId of subscriptions) {
  await Aboutme.events.off(subId);
}

// ❌ 不推荐: 忘记取消订阅
await Aboutme.events.on('task_added', handler); // 内存泄漏风险
```

---

## 调试技巧

### 1. 查看所有订阅

```javascript
// 查看当前活动的订阅
console.log('活动订阅:', Object.keys(Aboutme.events._subscriptions));

// 示例输出: ['sub_1', 'sub_2', 'sub_3']
```

### 2. 记录所有事件

```javascript
// 创建一个事件记录器
const eventLogger = [];

// 订阅所有事件
const events = [
  'task_added', 'task_deleted', 'task_completed',
  'calendar_entry_added', 'calendar_entry_updated', 'calendar_entry_deleted',
  'calendar_tag_added', 'calendar_tag_deleted',
];

for (const eventName of events) {
  await Aboutme.events.on(eventName, (event) => {
    eventLogger.push({
      time: new Date().toISOString(),
      event: event
    });
    console.log(`[${new Date().toLocaleTimeString()}] ${event.eventName}:`, event.data);
  });
}

// 查看日志
console.table(eventLogger);
```

### 3. 性能监控

```javascript
// 监控回调执行时间
async function monitoredOn(eventName, handler) {
  return await Aboutme.events.on(eventName, (event) => {
    const startTime = performance.now();
    handler(event);
    const duration = performance.now() - startTime;

    if (duration > 10) {
      console.warn(`⚠️ 事件处理耗时过长: ${eventName} (${duration.toFixed(2)}ms)`);
    }
  });
}

// 使用
await monitoredOn('task_added', (event) => {
  // 你的处理逻辑
});
```

---

## 更新日志

- **v1.0.0** (2025-12-08): 初始版本,支持事件订阅/取消订阅
  - 添加 `Aboutme.events.on()` API
  - 添加 `Aboutme.events.off()` API
  - 支持 Todo 插件事件(task_added/deleted/completed)
  - 支持 Calendar Album 插件事件(entry 和 tag 相关)

---

## 相关文档

- [JS Bridge API 总览](JS_API_README.md)
- [Todo 插件 JS API](../../plugins/todo/JS_API.md)
- [系统 API 文档](JS_API_README.md)
