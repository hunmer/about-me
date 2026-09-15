/**
 * MCP (Model Context Protocol) HTTP 端点
 *
 * 以 Streamable HTTP 无状态模式挂载到主服务器的 /mcp 路径:
 * - POST   /mcp  - 处理 JSON-RPC 请求 (initialize / tools/list / tools/call)
 * - GET    /mcp  - 405 (无状态模式不支持服务器推送流)
 * - DELETE /mcp  - 405 (无状态模式无会话)
 *
 * 认证复用主服务器的 authMiddleware (X-API-Key 或 Bearer JWT)，
 * 并要求 X-Encryption-Key 请求头（插件数据解密需要）。
 * 工具调用通过进程内调用器直连插件处理器，无回环 HTTP 请求，
 * MCP 客户端的权限等同于其认证身份。
 */

import { Router, Request, Response } from 'express';
import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StreamableHTTPServerTransport } from '@modelcontextprotocol/sdk/server/streamableHttp.js';

import { AuthService } from '../services/authService';
import { PluginDataService } from '../services/pluginDataService';
import { authMiddleware } from '../middleware';
import { AboutmeClient } from './client';
import { createMcpServer } from './server';
import { createInternalInvoker } from './invoker';
import { StorageWebSocketService } from '../services/storageWebSocketService';

/**
 * JSON-RPC 错误响应
 */
function jsonRpcError(res: Response, code: number, message: string): void {
  res.status(code >= 400 ? code : 400).json({
    jsonrpc: '2.0',
    error: { code: -32600, message },
    id: null,
  });
}

/**
 * 创建 MCP 路由
 *
 * @param authService 认证服务
 * @param pluginDataService 插件数据服务（工具直调目标）
 */
export function createMcpRouter(
  authService: AuthService,
  pluginDataService: PluginDataService,
  webSocket?: StorageWebSocketService,
): Router {
  const router = Router();

  // 认证: X-API-Key 或 Bearer JWT (OPTIONS 预检由中间件内部跳过)
  router.use(authMiddleware(authService));

  // 插件数据 API 需要加密密钥
  router.use((req, res, next) => {
    const encryptionKey = req.headers['x-encryption-key'] as string | undefined;
    if (!encryptionKey || encryptionKey.length === 0) {
      res.status(403).json({
        success: false,
        error: '请通过 X-Encryption-Key 请求头传递加密密钥',
        timestamp: new Date().toISOString(),
      });
      return;
    }
    next();
  });

  router.post('/', async (req: Request, res: Response) => {
    const sourceDeviceId = req.header('X-Device-ID') || undefined;
    const invoke = createInternalInvoker(pluginDataService, (userId, pluginId) => {
      webSocket?.broadcastFileUpdate(userId, sourceDeviceId, `${pluginId}/`);
    });
    // 无状态模式: 每个请求创建新的 transport 和 server 实例
    const transport = new StreamableHTTPServerTransport({
      sessionIdGenerator: undefined,
    });

    const client = new AboutmeClient({
      userId: req.context!.userId!,
      encryptionKey: req.headers['x-encryption-key'] as string,
      invoke,
    });

    const server: Server = createMcpServer(client);
    res.on('close', () => {
      transport.close();
      server.close();
    });

    try {
      await server.connect(transport);
      await transport.handleRequest(req, res, req.body);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      // 响应可能已被 transport 部分写入
      if (!res.headersSent) {
        jsonRpcError(res, 400, `MCP 请求处理失败: ${message}`);
      }
    }
  });

  router.get('/', (_req: Request, res: Response) => {
    jsonRpcError(res, 405, '无状态 MCP 服务器不支持 GET');
  });

  router.delete('/', (_req: Request, res: Response) => {
    jsonRpcError(res, 405, '无状态 MCP 服务器不支持 DELETE');
  });

  return router;
}
