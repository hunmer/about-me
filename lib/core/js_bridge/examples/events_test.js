/**
 * Aboutme 事件系统测试示例
 *
 * 此脚本演示如何使用 Aboutme.events API 监听应用内的数据变化事件
 */

// ============ 示例 1: 基础事件监听 ============

console.log('=== 示例 1: 基础事件监听 ===');

// 监听任务添加事件
const taskAddedSub = await Aboutme.events.on('task_added', (event) => {
  console.log('✅ 新任务已添加:');
  console.log('  - ID:', event.data.itemId);
  console.log('  - 标题:', event.data.title);
  console.log('  - 时间:', event.whenOccurred);
});

console.log('已订阅 task_added 事件, 订阅ID:', taskAddedSub);

// 监听任务完成事件
const taskCompletedSub = await Aboutme.events.on('task_completed', (event) => {
  console.log('🎉 任务已完成:', event.data.title);
});

console.log('已订阅 task_completed 事件, 订阅ID:', taskCompletedSub);

// ============ 示例 2: 日记事件监听 ============

console.log('\n=== 示例 2: 日记事件监听 ===');

// 监听日记添加
await Aboutme.events.on('calendar_entry_added', (event) => {
  console.log('📝 新日记已添加:', event.data.title);
});

// 监听日记更新
await Aboutme.events.on('calendar_entry_updated', (event) => {
  console.log('📝 日记已更新:', event.data.title);
});

// 监听日记删除
await Aboutme.events.on('calendar_entry_deleted', (event) => {
  console.log('🗑️ 日记已删除:', event.data.title);
});

// ============ 示例 3: 标签事件监听 ============

console.log('\n=== 示例 3: 标签事件监听 ===');

const tagStats = {
  added: 0,
  deleted: 0
};

await Aboutme.events.on('calendar_tag_added', (event) => {
  tagStats.added++;
  console.log(`🏷️ 新标签: ${event.data.title} (总计添加 ${tagStats.added} 个)`);
});

await Aboutme.events.on('calendar_tag_deleted', (event) => {
  tagStats.deleted++;
  console.log(`🗑️ 删除标签: ${event.data.title} (总计删除 ${tagStats.deleted} 个)`);
});

// ============ 示例 4: 事件统计 ============

console.log('\n=== 示例 4: 事件统计 ===');

const eventCounter = {};

// 创建一个通用的事件计数器
async function trackEvent(eventName) {
  await Aboutme.events.on(eventName, (event) => {
    if (!eventCounter[eventName]) {
      eventCounter[eventName] = 0;
    }
    eventCounter[eventName]++;
    console.log(`📊 事件统计 [${eventName}]: ${eventCounter[eventName]} 次`);
  });
}

// 追踪所有事件
const events = [
  'task_added',
  'task_deleted',
  'task_completed',
  'calendar_entry_added',
  'calendar_entry_updated',
  'calendar_entry_deleted',
  'calendar_tag_added',
  'calendar_tag_deleted'
];

for (const eventName of events) {
  await trackEvent(eventName);
}

console.log('已开始追踪所有事件');

// ============ 示例 5: 取消订阅 ============

console.log('\n=== 示例 5: 取消订阅演示 ===');

// 等待 10 秒后取消订阅
setTimeout(async () => {
  console.log('10秒后取消 task_added 订阅...');

  const result = await Aboutme.events.off(taskAddedSub);
  console.log('取消订阅结果:', result);

  if (result.success) {
    console.log('✓ 已成功取消 task_added 订阅');
  }
}, 10000);

// ============ 示例 6: 自动备份触发器 ============

console.log('\n=== 示例 6: 自动备份触发器 ===');

let operationCount = 0;
const BACKUP_THRESHOLD = 5;

// 监听所有数据变更事件
const changeEvents = [
  'task_added',
  'task_deleted',
  'calendar_entry_added',
  'calendar_entry_updated',
  'calendar_entry_deleted'
];

for (const eventName of changeEvents) {
  await Aboutme.events.on(eventName, (event) => {
    operationCount++;
    console.log(`📝 数据操作计数: ${operationCount}/${BACKUP_THRESHOLD}`);

    if (operationCount >= BACKUP_THRESHOLD) {
      console.log('💾 达到阈值,触发自动备份!');
      // 这里可以调用备份 API
      operationCount = 0;
    }
  });
}

// ============ 示例 7: 实时仪表板 ============

console.log('\n=== 示例 7: 实时仪表板 ===');

const dashboard = {
  tasks: {
    total: 0,
    completed: 0,
    pending: 0
  },
  diaries: {
    total: 0,
    today: 0
  }
};

// 任务统计
await Aboutme.events.on('task_added', () => {
  dashboard.tasks.total++;
  dashboard.tasks.pending++;
  updateDashboard();
});

await Aboutme.events.on('task_completed', () => {
  dashboard.tasks.completed++;
  dashboard.tasks.pending--;
  updateDashboard();
});

await Aboutme.events.on('task_deleted', () => {
  dashboard.tasks.total--;
  updateDashboard();
});

// 日记统计
await Aboutme.events.on('calendar_entry_added', (event) => {
  dashboard.diaries.total++;

  // 检查是否是今天的日记
  const eventDate = new Date(event.whenOccurred);
  const today = new Date();
  if (isSameDay(eventDate, today)) {
    dashboard.diaries.today++;
  }

  updateDashboard();
});

await Aboutme.events.on('calendar_entry_deleted', () => {
  dashboard.diaries.total--;
  updateDashboard();
});

function updateDashboard() {
  console.clear();
  console.log('┌─────────────────────────────────┐');
  console.log('│     Aboutme 实时仪表板          │');
  console.log('├─────────────────────────────────┤');
  console.log('│ 任务                            │');
  console.log(`│   总数: ${dashboard.tasks.total.toString().padEnd(5)} │`);
  console.log(`│   已完成: ${dashboard.tasks.completed.toString().padEnd(5)} │`);
  console.log(`│   待办: ${dashboard.tasks.pending.toString().padEnd(5)} │`);
  console.log('├─────────────────────────────────┤');
  console.log('│ 日记                            │');
  console.log(`│   总数: ${dashboard.diaries.total.toString().padEnd(5)} │`);
  console.log(`│   今日: ${dashboard.diaries.today.toString().padEnd(5)} │`);
  console.log('└─────────────────────────────────┘');
}

function isSameDay(date1, date2) {
  return date1.getFullYear() === date2.getFullYear() &&
         date1.getMonth() === date2.getMonth() &&
         date1.getDate() === date2.getDate();
}

// 初始化显示
updateDashboard();

console.log('\n✅ 所有事件监听器已设置完成!');
console.log('提示: 现在可以在应用中执行操作(添加任务、写日记等),事件会自动触发');
