/**
 * MCP 工具的进程内调用器
 *
 * 将原 HTTP 回调（AboutmeClient -> fetch 127.0.0.1 -> Express 插件路由）
 * 替换为直接调用插件处理器，省去回环网络开销。
 *
 * 复用 PLUGIN_ROUTE_CONFIGS 的路由定义做匹配，保证与 HTTP 路由
 * 完全一致的分发语义（含注册顺序）。
 */

import { PluginDataService } from '../services/pluginDataService';
import { createHandlersForPlugin } from '../routes/pluginRoutes/factory';
import { PLUGIN_ROUTE_CONFIGS } from '../routes/pluginRoutes/routeConfig';
import { PluginHandlers } from '../routes/pluginRoutes/types';
import type { ApiResponse } from './types';

const PLUGIN_API_PREFIX = '/api/v1/plugins/';

export type HttpMethod = 'get' | 'post' | 'put' | 'delete';

export type InternalInvoke = (
  userId: string,
  encryptionKey: string,
  method: HttpMethod,
  path: string,
  query?: Record<string, unknown>,
  body?: unknown,
) => Promise<ApiResponse>;

/**
 * 匹配路由模式（如 /channels/:id），成功时返回路径参数
 */
function matchRoute(pattern: string, subPath: string): Record<string, string> | null {
  const patternParts = pattern.split('/');
  const pathParts = subPath.split('/');
  if (patternParts.length !== pathParts.length) {
    return null;
  }

  const params: Record<string, string> = {};
  for (let i = 0; i < patternParts.length; i++) {
    if (patternParts[i].startsWith(':')) {
      params[patternParts[i].slice(1)] = decodeURIComponent(pathParts[i]);
    } else if (patternParts[i] !== pathParts[i]) {
      return null;
    }
  }
  return params;
}

/**
 * 创建进程内调用器
 */
export function createInternalInvoker(pluginDataService: PluginDataService): InternalInvoke {
  const handlersCache = new Map<string, PluginHandlers>();

  return async (userId, encryptionKey, method, apiPath, query, body) => {
    const timestamp = new Date().toISOString();
    const fail = (error: string): ApiResponse => ({ success: false, error, timestamp });

    if (!apiPath.startsWith(PLUGIN_API_PREFIX)) {
      return fail(`不支持的路径: ${apiPath}`);
    }

    const rest = apiPath.slice(PLUGIN_API_PREFIX.length).replace(/\/+$/, '');
    const slash = rest.indexOf('/');
    const pluginId = slash === -1 ? rest : rest.slice(0, slash);
    const subPath = slash === -1 ? '/' : rest.slice(slash);

    const config = PLUGIN_ROUTE_CONFIGS.find(c => c.pluginId === pluginId);
    if (!config) {
      return fail(`未知插件: ${pluginId}`);
    }

    // 按注册顺序匹配，与 Express 路由行为一致
    let pathParams: Record<string, string> | null = null;
    let matched: (typeof config.routes)[number] | undefined;
    for (const route of config.routes) {
      if (route.method !== method) {
        continue;
      }
      const params = matchRoute(route.path, subPath);
      if (params) {
        matched = route;
        pathParams = params;
        break;
      }
    }
    if (!matched || !pathParams) {
      return fail(`未找到路由: ${method.toUpperCase()} ${apiPath}`);
    }

    let handlers = handlersCache.get(pluginId);
    if (!handlers) {
      handlers = createHandlersForPlugin(pluginDataService, pluginId);
      handlersCache.set(pluginId, handlers);
    }
    const handler = handlers[matched.handler];
    if (!handler) {
      return fail(`处理器不存在: ${matched.handler}`);
    }

    // 参数合并顺序与 factory.ts 的路由层一致: query -> path -> body
    const params = { ...query, ...pathParams, ...((body as Record<string, unknown>) || {}) };

    try {
      const result = await handler(userId, encryptionKey, params);
      if (result.isSuccess) {
        return { success: true, data: result.data, timestamp };
      }
      return { success: false, error: result.message, timestamp };
    } catch (e) {
      return fail(`服务器错误: ${e instanceof Error ? e.message : String(e)}`);
    }
  };
}
