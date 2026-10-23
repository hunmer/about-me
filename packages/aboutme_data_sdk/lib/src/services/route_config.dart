import 'types.dart';

/// 所有插件的 RESTful 路由配置（移植自 nodejs routeConfig.ts）。
final pluginRouteConfigs = <PluginRouteConfig>[
  // ==================== Chat ====================
  PluginRouteConfig(pluginId: 'chat', routes: [
    PluginRouteDefinition(method: 'get', path: '/channels', handler: 'getList', resourceName: 'channels'),
    PluginRouteDefinition(method: 'get', path: '/channels/:id', handler: 'getById', resourceName: 'channels'),
    PluginRouteDefinition(method: 'post', path: '/channels', handler: 'create', resourceName: 'channels'),
    PluginRouteDefinition(method: 'put', path: '/channels/:id', handler: 'update', resourceName: 'channels'),
    PluginRouteDefinition(method: 'delete', path: '/channels/:id', handler: 'delete', resourceName: 'channels'),
    PluginRouteDefinition(method: 'get', path: '/channels/:channelId/messages', handler: 'getMessages', resourceName: 'messages'),
    PluginRouteDefinition(method: 'post', path: '/channels/:channelId/messages', handler: 'sendMessage', resourceName: 'messages'),
    PluginRouteDefinition(method: 'delete', path: '/channels/:channelId/messages/:messageId', handler: 'deleteMessage', resourceName: 'messages'),
    PluginRouteDefinition(method: 'get', path: '/find/channel', handler: 'findChannel', resourceName: 'channels'),
    PluginRouteDefinition(method: 'get', path: '/find/message', handler: 'findMessage', resourceName: 'messages'),
  ]),
  // ==================== Notes ====================
  PluginRouteConfig(pluginId: 'notes', routes: [
    PluginRouteDefinition(method: 'get', path: '/notes', handler: 'getList', resourceName: 'notes'),
    PluginRouteDefinition(method: 'get', path: '/notes/:id', handler: 'getById', resourceName: 'notes'),
    PluginRouteDefinition(method: 'post', path: '/notes', handler: 'create', resourceName: 'notes'),
    PluginRouteDefinition(method: 'put', path: '/notes/:id', handler: 'update', resourceName: 'notes'),
    PluginRouteDefinition(method: 'delete', path: '/notes/:id', handler: 'delete', resourceName: 'notes'),
    PluginRouteDefinition(method: 'post', path: '/notes/:id/move', handler: 'moveNote', resourceName: 'notes'),
    PluginRouteDefinition(method: 'get', path: '/search', handler: 'search', resourceName: 'notes'),
    PluginRouteDefinition(method: 'get', path: '/folders', handler: 'getFolders', resourceName: 'folders'),
    PluginRouteDefinition(method: 'get', path: '/folders/:id', handler: 'getFolderById', resourceName: 'folders'),
    PluginRouteDefinition(method: 'post', path: '/folders', handler: 'createFolder', resourceName: 'folders'),
    PluginRouteDefinition(method: 'put', path: '/folders/:id', handler: 'updateFolder', resourceName: 'folders'),
    PluginRouteDefinition(method: 'delete', path: '/folders/:id', handler: 'deleteFolder', resourceName: 'folders'),
    PluginRouteDefinition(method: 'get', path: '/folders/:id/notes', handler: 'getFolderNotes', resourceName: 'notes'),
  ]),
  // ==================== Activity ====================
  PluginRouteConfig(pluginId: 'activity', routes: [
    PluginRouteDefinition(method: 'get', path: '/activities', handler: 'getList', resourceName: 'activities'),
    PluginRouteDefinition(method: 'post', path: '/activities', handler: 'create', resourceName: 'activities'),
    PluginRouteDefinition(method: 'put', path: '/activities/:id', handler: 'update', resourceName: 'activities'),
    PluginRouteDefinition(method: 'delete', path: '/activities/:id', handler: 'delete', resourceName: 'activities'),
    PluginRouteDefinition(method: 'get', path: '/stats/today', handler: 'getTodayStats', resourceName: 'activities'),
  ]),
  // ==================== Goods ====================
  PluginRouteConfig(pluginId: 'goods', routes: [
    PluginRouteDefinition(method: 'get', path: '/warehouses', handler: 'getWarehouses', resourceName: 'warehouses'),
    PluginRouteDefinition(method: 'post', path: '/warehouses', handler: 'createWarehouse', resourceName: 'warehouses'),
    PluginRouteDefinition(method: 'delete', path: '/warehouses/:id', handler: 'deleteWarehouse', resourceName: 'warehouses'),
    PluginRouteDefinition(method: 'get', path: '/items', handler: 'getList', resourceName: 'items'),
    PluginRouteDefinition(method: 'post', path: '/items', handler: 'create', resourceName: 'items'),
    PluginRouteDefinition(method: 'put', path: '/items/:id', handler: 'update', resourceName: 'items'),
    PluginRouteDefinition(method: 'delete', path: '/items/:id', handler: 'delete', resourceName: 'items'),
    PluginRouteDefinition(method: 'get', path: '/search', handler: 'search', resourceName: 'items'),
  ]),
  // ==================== Bill ====================
  PluginRouteConfig(pluginId: 'bill', routes: [
    PluginRouteDefinition(method: 'get', path: '/accounts', handler: 'getList', resourceName: 'accounts'),
    PluginRouteDefinition(method: 'get', path: '/accounts/:id', handler: 'getById', resourceName: 'accounts'),
    PluginRouteDefinition(method: 'post', path: '/accounts', handler: 'create', resourceName: 'accounts'),
    PluginRouteDefinition(method: 'put', path: '/accounts/:id', handler: 'update', resourceName: 'accounts'),
    PluginRouteDefinition(method: 'delete', path: '/accounts/:id', handler: 'delete', resourceName: 'accounts'),
    PluginRouteDefinition(method: 'get', path: '/bills', handler: 'getBills', resourceName: 'bills'),
    PluginRouteDefinition(method: 'get', path: '/bills/:id', handler: 'getBillById', resourceName: 'bills'),
    PluginRouteDefinition(method: 'post', path: '/bills', handler: 'createBill', resourceName: 'bills'),
    PluginRouteDefinition(method: 'put', path: '/bills/:id', handler: 'updateBill', resourceName: 'bills'),
    PluginRouteDefinition(method: 'delete', path: '/bills/:id', handler: 'deleteBill', resourceName: 'bills'),
    PluginRouteDefinition(method: 'get', path: '/accounts/:accountId/bills', handler: 'getBillsByAccount', resourceName: 'bills'),
    PluginRouteDefinition(method: 'post', path: '/accounts/:accountId/bills', handler: 'createBillForAccount', resourceName: 'bills'),
    PluginRouteDefinition(method: 'get', path: '/stats', handler: 'getStats', resourceName: 'bills'),
  ]),
  // ==================== Todo ====================
  PluginRouteConfig(pluginId: 'todo', routes: [
    PluginRouteDefinition(method: 'get', path: '/tasks', handler: 'getList', resourceName: 'tasks'),
    PluginRouteDefinition(method: 'get', path: '/tasks/:id', handler: 'getById', resourceName: 'tasks'),
    PluginRouteDefinition(method: 'post', path: '/tasks', handler: 'create', resourceName: 'tasks'),
    PluginRouteDefinition(method: 'put', path: '/tasks/:id', handler: 'update', resourceName: 'tasks'),
    PluginRouteDefinition(method: 'delete', path: '/tasks/:id', handler: 'delete', resourceName: 'tasks'),
    PluginRouteDefinition(method: 'post', path: '/tasks/:id/complete', handler: 'completeTask', resourceName: 'tasks'),
    PluginRouteDefinition(method: 'get', path: '/tasks/filter/today', handler: 'getTodayTasks', resourceName: 'tasks'),
    PluginRouteDefinition(method: 'get', path: '/tasks/filter/overdue', handler: 'getOverdueTasks', resourceName: 'tasks'),
    PluginRouteDefinition(method: 'get', path: '/search', handler: 'search', resourceName: 'tasks'),
    PluginRouteDefinition(method: 'get', path: '/stats', handler: 'getStats', resourceName: 'tasks'),
  ]),
  // ==================== Diary ====================
  PluginRouteConfig(pluginId: 'diary', routes: [
    PluginRouteDefinition(method: 'get', path: '/entries', handler: 'getList', resourceName: 'entries'),
    PluginRouteDefinition(method: 'get', path: '/entries/:date', handler: 'getByDate', resourceName: 'entries'),
    PluginRouteDefinition(method: 'post', path: '/entries', handler: 'create', resourceName: 'entries'),
    PluginRouteDefinition(method: 'put', path: '/entries/:date', handler: 'updateByDate', resourceName: 'entries'),
    PluginRouteDefinition(method: 'delete', path: '/entries/:date', handler: 'deleteByDate', resourceName: 'entries'),
    PluginRouteDefinition(method: 'get', path: '/search', handler: 'search', resourceName: 'entries'),
    PluginRouteDefinition(method: 'get', path: '/stats', handler: 'getStats', resourceName: 'entries'),
  ]),
  // ==================== Checkin ====================
  PluginRouteConfig(pluginId: 'checkin', routes: [
    PluginRouteDefinition(method: 'get', path: '/items', handler: 'getList', resourceName: 'items'),
    PluginRouteDefinition(method: 'get', path: '/items/:id', handler: 'getById', resourceName: 'items'),
    PluginRouteDefinition(method: 'post', path: '/items', handler: 'create', resourceName: 'items'),
    PluginRouteDefinition(method: 'put', path: '/items/:id', handler: 'update', resourceName: 'items'),
    PluginRouteDefinition(method: 'delete', path: '/items/:id', handler: 'delete', resourceName: 'items'),
    PluginRouteDefinition(method: 'post', path: '/items/:id/checkin', handler: 'addRecord', resourceName: 'records'),
    PluginRouteDefinition(method: 'get', path: '/stats', handler: 'getStats', resourceName: 'items'),
  ]),
  // ==================== Calendar ====================
  PluginRouteConfig(pluginId: 'calendar', routes: [
    PluginRouteDefinition(method: 'get', path: '/events', handler: 'getList', resourceName: 'events'),
    // 静态路由需先于参数路由注册, 否则 /events/search 会被 /events/:id 抢先匹配
    PluginRouteDefinition(method: 'get', path: '/events/search', handler: 'search', resourceName: 'events'),
    PluginRouteDefinition(method: 'get', path: '/events/:id', handler: 'getById', resourceName: 'events'),
    PluginRouteDefinition(method: 'post', path: '/events', handler: 'create', resourceName: 'events'),
    PluginRouteDefinition(method: 'put', path: '/events/:id', handler: 'update', resourceName: 'events'),
    PluginRouteDefinition(method: 'delete', path: '/events/:id', handler: 'delete', resourceName: 'events'),
    PluginRouteDefinition(method: 'post', path: '/events/:id/complete', handler: 'completeEvent', resourceName: 'events'),
  ]),
  // ==================== Contact ====================
  PluginRouteConfig(pluginId: 'contact', routes: [
    PluginRouteDefinition(method: 'get', path: '/contacts', handler: 'getList', resourceName: 'contacts'),
    PluginRouteDefinition(method: 'get', path: '/contacts/search', handler: 'search', resourceName: 'contacts'),
    PluginRouteDefinition(method: 'get', path: '/contacts/:id', handler: 'getById', resourceName: 'contacts'),
    PluginRouteDefinition(method: 'post', path: '/contacts', handler: 'create', resourceName: 'contacts'),
    PluginRouteDefinition(method: 'put', path: '/contacts/:id', handler: 'update', resourceName: 'contacts'),
    PluginRouteDefinition(method: 'delete', path: '/contacts/:id', handler: 'delete', resourceName: 'contacts'),
    PluginRouteDefinition(method: 'get', path: '/stats/total-contacts', handler: 'getStats', resourceName: 'contacts'),
  ]),
  // ==================== Tracker ====================
  PluginRouteConfig(pluginId: 'tracker', routes: [
    PluginRouteDefinition(method: 'get', path: '/goals', handler: 'getList', resourceName: 'goals'),
    PluginRouteDefinition(method: 'get', path: '/goals/:id', handler: 'getById', resourceName: 'goals'),
    PluginRouteDefinition(method: 'post', path: '/goals', handler: 'create', resourceName: 'goals'),
    PluginRouteDefinition(method: 'put', path: '/goals/:id', handler: 'update', resourceName: 'goals'),
    PluginRouteDefinition(method: 'delete', path: '/goals/:id', handler: 'delete', resourceName: 'goals'),
    PluginRouteDefinition(method: 'post', path: '/records', handler: 'addRecord', resourceName: 'records'),
    PluginRouteDefinition(method: 'get', path: '/goals/:goalId/records', handler: 'getRecords', resourceName: 'records'),
    PluginRouteDefinition(method: 'get', path: '/stats', handler: 'getStats', resourceName: 'goals'),
  ]),
  // ==================== Day ====================
  PluginRouteConfig(pluginId: 'day', routes: [
    PluginRouteDefinition(method: 'get', path: '/days', handler: 'getList', resourceName: 'days'),
    PluginRouteDefinition(method: 'get', path: '/days/:id', handler: 'getById', resourceName: 'days'),
    PluginRouteDefinition(method: 'post', path: '/days', handler: 'create', resourceName: 'days'),
    PluginRouteDefinition(method: 'put', path: '/days/:id', handler: 'update', resourceName: 'days'),
    PluginRouteDefinition(method: 'delete', path: '/days/:id', handler: 'delete', resourceName: 'days'),
    PluginRouteDefinition(method: 'get', path: '/search', handler: 'search', resourceName: 'days'),
    PluginRouteDefinition(method: 'get', path: '/stats', handler: 'getStats', resourceName: 'days'),
  ]),
  // ==================== 其他插件使用通用路由 ====================
  ..._genericPlugins.map(
    (id) => PluginRouteConfig(pluginId: id, routes: _genericRoutes),
  ),
];

const _genericPlugins = [
  'agent_chat',
  'calendar_album',
  'database',
  'nodes',
  'openai',
  'store',
  'timer',
];

/// 通用 CRUD 插件的路由（全部复用同一组定义）。
const _genericRoutes = [
  PluginRouteDefinition(method: 'get', path: '/items', handler: 'getList', resourceName: 'items'),
  PluginRouteDefinition(method: 'get', path: '/item/:id', handler: 'getById', resourceName: 'items'),
  PluginRouteDefinition(method: 'post', path: '/item', handler: 'create', resourceName: 'items'),
  PluginRouteDefinition(method: 'put', path: '/item/:id', handler: 'update', resourceName: 'items'),
  PluginRouteDefinition(method: 'delete', path: '/item/:id', handler: 'delete', resourceName: 'items'),
];

PluginRouteConfig? pluginRouteConfigOf(String pluginId) {
  for (final config in pluginRouteConfigs) {
    if (config.pluginId == pluginId) return config;
  }
  return null;
}
