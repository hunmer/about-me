#!/usr/bin/env node
import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import path from 'path';
import fs from 'fs';
import http from 'http';
import multer from 'multer';
import { config, printConfig } from './config/serverConfig';
import { FileStorageService } from './services/fileStorageService';
import { AuthService } from './services/authService';
import { PluginDataService } from './services/pluginDataService';
import { PluginService } from './services/pluginService';
import { authMiddleware, apiEnabledMiddleware } from './middleware';
import { createAuthRoutes } from './routes/authRoutes';
import { createPluginRoutesIndex } from './routes/pluginRoutes';
import { createPluginSystemRoutes } from './routes/pluginSystemRoutes';
import { createStorageRoutes } from './routes/storageRoutes';
import { StorageWebSocketService } from './services/storageWebSocketService';
import { createMcpRouter } from './mcp';

// 文件上传配置
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB
  },
});

/**
 * MIME 类型映射
 */
const MIME_TYPES: Record<string, string> = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
  '.eot': 'application/vnd.ms-fontobject',
};

/**
 * 获取 MIME 类型
 */
function getMimeType(fileName: string): string {
  const ext = path.extname(fileName).toLowerCase();
  return MIME_TYPES[ext] || 'application/octet-stream';
}

async function main() {
  console.log('====================================');
  console.log('  Aboutme HTTP Storage Server (Node.js)');
  console.log('====================================');
  console.log('');

  // 1. 打印配置
  printConfig();
  console.log('');

  // 2. 初始化服务
  const storageService = new FileStorageService(config.dataDir);
  await storageService.initialize();
  console.log(`文件存储服务初始化完成: ${config.dataDir}`);

  const authService = new AuthService({
    storageService,
    jwtSecret: config.jwtSecret,
    dataDir: config.dataDir,
    tokenExpiryDays: config.tokenExpiryDays,
    adminUsername: config.adminUsername,
    adminPassword: config.adminPassword,
  });
  console.log('认证服务初始化完成');

  // 初始化管理员账号
  await authService.initializeAdmin();

  const pluginDataService = new PluginDataService(storageService, config.dataDir);
  await pluginDataService.initialize();
  console.log('插件数据服务初始化完成');

  // 插件系统服务
  const pluginService = new PluginService(config.dataDir);
  await pluginService.initialize();
  console.log('插件系统服务初始化完成');
  const storageWebSocket = new StorageWebSocketService(authService);

  // 3. 创建 Express 应用
  const app = express();

  // 解析 JSON 请求体
  app.use(express.json({ limit: config.maxRequestSize }));

  // CORS 支持
  if (config.enableCors) {
    // 当 corsOrigins 为 ['*'] 时，使用 true 允许所有来源
    const corsOrigin = config.corsOrigins.length === 1 && config.corsOrigins[0] === '*'
      ? true
      : config.corsOrigins;
    app.use(cors({
      origin: corsOrigin,
      methods: ['GET', 'HEAD', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
      allowedHeaders: ['Origin', 'Content-Type', 'Authorization', 'X-API-Key', 'X-Encryption-Key', 'X-Device-ID', 'If-Match', 'If-None-Match', 'X-Force-Overwrite', 'Mcp-Session-Id', 'Mcp-Protocol-Version', 'Last-Event-ID'],
      exposedHeaders: ['ETag', 'Content-Length', 'Last-Modified', 'Mcp-Session-Id'],
      credentials: true,
    }));
  }

  // 请求日志
  if (config.enableLogging) {
    app.use((req, res, next) => {
      console.log(`${new Date().toISOString()} ${req.method} ${req.path}`);
      next();
    });
  }

  // 4. 创建路由

  // 健康检查 (无需认证)
  app.get('/health', (req, res) => {
    res.json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
    });
  });

  // 版本信息 (无需认证)
  app.get('/version', (req, res) => {
    res.json({
      version: '1.0.0',
      name: 'Aboutme HTTP Storage Server (Node.js)',
    });
  });

  // 认证路由 (无需认证)
  const authRoutes = createAuthRoutes(authService, pluginDataService, storageService, config.allowRegister);
  app.use('/api/v1/auth', authRoutes);

  app.use(
    '/api/v1/storage',
    authMiddleware(authService),
    createStorageRoutes(storageService, {
      maxFileSizeBytes: config.maxStorageFileSizeBytes,
      rateLimitPerMinute: config.storageRateLimitPerMinute,
    }, storageWebSocket),
  );

  // 插件路由 (需要认证 + API 启用)
  const pluginRoutes = createPluginRoutesIndex(pluginDataService, storageWebSocket);
  for (const [pluginId, router] of pluginRoutes) {
    app.use(
      `/api/v1/plugins/${pluginId}`,
      authMiddleware(authService),
      apiEnabledMiddleware(),
      router,
    );
  }
  console.log(`已挂载 ${pluginRoutes.size} 个插件路由: ${Array.from(pluginRoutes.keys()).join(', ')}`);

  // 插件系统管理路由 (需要管理员权限)
  const pluginSystemRoutes = createPluginSystemRoutes(pluginService, authService);
  app.use('/api/v1/system', upload.single('plugin'), pluginSystemRoutes);
  console.log('插件系统管理路由已挂载: /api/v1/system/plugins');

  // MCP 端点 (需要认证 + 加密密钥)
  app.use('/mcp', createMcpRouter(authService, pluginDataService, storageWebSocket));
  console.log('MCP 端点已挂载: /mcp');

  // 5. 创建 HTTP 服务器
  const server = http.createServer(app);
  storageWebSocket.attach(server);

  // 管理界面静态文件服务
  const adminDir = path.join(__dirname, 'admin');
  console.log(`管理界面目录: ${adminDir}`);

  // 检查管理界面目录
  if (fs.existsSync(adminDir)) {
    // 根路径重定向到管理界面
    app.get('/', (req, res) => {
      res.redirect('/admin/');
    });

    // 管理界面主页
    app.get('/admin/', (req, res) => {
      const indexFile = path.join(adminDir, 'index.html');
      if (fs.existsSync(indexFile)) {
        res.sendFile(indexFile);
      } else {
        res.status(404).send('Admin page not found');
      }
    });

    // 管理界面静态资源
    app.get('/admin/*', (req, res) => {
      const filePath = (req.params as Record<string, string>)[0] || '';

      // 安全检查：防止路径遍历攻击
      if (filePath.includes('..')) {
        res.status(403).send('Invalid path');
        return;
      }

      const fullPath = path.join(adminDir, filePath);

      if (fs.existsSync(fullPath) && fs.statSync(fullPath).isFile()) {
        res.setHeader('Content-Type', getMimeType(filePath));
        res.sendFile(fullPath);
      } else {
        // SPA 路由支持：返回 index.html
        const indexFile = path.join(adminDir, 'index.html');
        if (fs.existsSync(indexFile)) {
          res.sendFile(indexFile);
        } else {
          res.status(404).send('File not found');
        }
      }
    });
  } else {
    console.log(`警告: 管理界面目录不存在: ${adminDir}`);
    // 简单的根路由
    app.get('/', (req, res) => {
      res.json({
        name: 'Aboutme HTTP Storage Server',
        version: '1.0.0',
        status: 'running',
      });
    });
  }

  // 6. 启动服务器
  server.listen(config.port, () => {
    console.log('');
    console.log('服务器启动成功!');
    console.log(`  http://127.0.0.1:${config.port}`);
    console.log('');
    console.log('可用端点:');
    console.log('  GET  /                    - 服务信息');
    console.log('  GET  /health              - 健康检查');
    console.log('  GET  /version             - 版本信息');
    console.log('  POST /api/v1/auth/register - 用户注册');
    console.log('  POST /api/v1/auth/login    - 用户登录');
    console.log('  POST /api/v1/auth/verify-encryption-key - 验证加密密钥');
    console.log('  GET  /api/v1/storage/health - 存储连接检查 (需认证)');
    console.log('  *    /api/v1/storage/files  - 加密文件存储 (需认证)');
    console.log('');
    console.log('插件 API (需认证 + X-Encryption-Key 请求头):');
    for (const pluginId of pluginRoutes.keys()) {
      console.log(`  /api/v1/plugins/${pluginId}`);
    }
    console.log('');
    console.log('MCP 端点 (需认证 + X-Encryption-Key 请求头):');
    console.log('  POST /mcp                - AI 工具 (Streamable HTTP)');
    console.log('');

    // 自预热: 触发认证/存储路由链的懒加载, 消除首批真实请求的冷启动阻塞。
    // 请求预期返回 401/404 无妨, 目的只是让模块链提前加载执行。
    const warmupPaths = ['/health', '/api/v1/storage/health', '/api/v1/storage/files/__warmup__'];
    setTimeout(async () => {
      try {
        await Promise.all(
          warmupPaths.map(async (p) => {
            const res = await fetch(`http://127.0.0.1:${config.port}${p}`, {
              headers: { 'X-API-Key': 'warmup' },
            });
            await res.arrayBuffer();
          }),
        );
        console.log(`预热完成: ${warmupPaths.join(', ')}`);
      } catch (err) {
        console.log(`预热失败(忽略): ${err}`);
      }
    }, 100);
  });

  // 优雅关闭
  process.on('SIGINT', () => {
    console.log('收到关闭信号，正在停止服务器...');
    server.close(() => {
      console.log('服务器已停止');
      process.exit(0);
    });
  });
}

main().catch((error) => {
  console.error('服务器启动失败:', error);
  process.exit(1);
});
