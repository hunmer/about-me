import express, { NextFunction, Request, Response } from 'express';
import { getAuthContextFromRequest, getUserIdFromContext } from '../middleware/authMiddleware';
import { FileStorageService, RawFileMetadata } from '../services/fileStorageService';
import { StorageWebSocketService } from '../services/storageWebSocketService';

function setMetadataHeaders(
  res: Response,
  metadata: RawFileMetadata,
  includeRepresentationHeaders = true,
): void {
  res.setHeader('ETag', metadata.etag);
  res.setHeader('Last-Modified', metadata.modifiedAt.toUTCString());
  if (includeRepresentationHeaders) {
    res.setHeader('Content-Length', String(metadata.size));
    res.setHeader('Content-Type', 'application/octet-stream');
  }
}

function storagePath(req: Request): string {
  return decodeURIComponent((req.params as Record<string, string>)[0] || '');
}

export function createStorageRoutes(
  storage: FileStorageService,
  options: { maxFileSizeBytes: number; rateLimitPerMinute: number },
  webSocket?: StorageWebSocketService,
) {
  const router = express.Router();
  const windows = new Map<string, { startedAt: number; count: number }>();

  router.use((req: Request, res: Response, next: NextFunction) => {
    const userId = getUserIdFromContext(req);
    if (!userId) return res.status(401).json({ error: '未认证' });
    const now = Date.now();
    const window = windows.get(userId);
    if (!window || now - window.startedAt >= 60_000) {
      windows.set(userId, { startedAt: now, count: 1 });
      return next();
    }
    window.count += 1;
    if (window.count > options.rateLimitPerMinute) {
      res.setHeader('Retry-After', '60');
      return res.status(429).json({ error: '请求过于频繁' });
    }
    next();
  });

  router.get('/health', (req, res) => {
    res.json({ status: 'healthy', user_id: getUserIdFromContext(req) });
  });

  router.get('/files', async (req, res) => {
    try {
      const files = await storage.listRawFiles(
        getUserIdFromContext(req)!,
        typeof req.query.prefix === 'string' ? req.query.prefix : '',
      );
      res.json({ files });
    } catch (error: any) {
      res.status(error?.message === 'INVALID_STORAGE_PATH' ? 400 : 500).json({ error: '无法列出文件' });
    }
  });

  router.delete('/files', async (req, res) => {
    try {
      const prefix = typeof req.query.prefix === 'string' ? req.query.prefix : '';
      const deleted = await storage.clearRawFiles(getUserIdFromContext(req)!, prefix);
      await storage.logStorageAudit({
        userId: getUserIdFromContext(req)!, action: 'clear-prefix', filePath: prefix,
        details: `deleted=${deleted}`,
      });
      webSocket?.broadcastFileUpdate(getUserIdFromContext(req)!, req.header('X-Device-ID') || undefined, prefix);
      res.json({ deleted });
    } catch (error: any) {
      res.status(error?.message === 'INVALID_STORAGE_PATH' ? 400 : 500).json({ error: '无法清除文件' });
    }
  });

  router.get('/files/*', async (req, res) => {
    try {
      const result = await storage.readRawFile(getUserIdFromContext(req)!, storagePath(req));
      if (!result) return res.status(404).json({ error: '文件不存在' });
      setMetadataHeaders(res, result.metadata);
      res.send(result.data);
    } catch (error: any) {
      res.status(error?.message === 'INVALID_STORAGE_PATH' ? 400 : 500).json({ error: '无法读取文件' });
    }
  });

  router.head('/files/*', async (req, res) => {
    try {
      const metadata = await storage.getRawFileMetadata(getUserIdFromContext(req)!, storagePath(req));
      if (!metadata) return res.sendStatus(404);
      setMetadataHeaders(res, metadata);
      res.status(200).end();
    } catch (error: any) {
      res.sendStatus(error?.message === 'INVALID_STORAGE_PATH' ? 400 : 500);
    }
  });

  router.put(
    '/files/*',
    express.raw({ type: 'application/octet-stream', limit: options.maxFileSizeBytes }),
    async (req, res) => {
      try {
        if (!Buffer.isBuffer(req.body)) return res.status(415).json({ error: '仅支持 application/octet-stream' });
        const filePath = storagePath(req);
        const force = req.header('X-Force-Overwrite')?.toLowerCase() === 'true';
        const result = await storage.writeRawFile(getUserIdFromContext(req)!, filePath, req.body, {
          ifMatch: req.header('If-Match') || undefined,
          ifNoneMatch: req.header('If-None-Match') || undefined,
          force,
        });
        if (result.status === 'precondition_failed') {
          if (result.metadata) setMetadataHeaders(res, result.metadata, false);
          return res.status(412).json({ error: '文件版本冲突' });
        }
        if (force) {
          const auth = getAuthContextFromRequest(req);
          await storage.logStorageAudit({
            userId: getUserIdFromContext(req)!, action: 'force-overwrite', filePath,
            details: auth?.isApiKey ? `api-key:${auth.keyId}` : 'jwt',
          });
        }
        setMetadataHeaders(res, result.metadata, false);
        webSocket?.broadcastFileUpdate(getUserIdFromContext(req)!, req.header('X-Device-ID') || undefined, filePath);
        res.status(200).end();
      } catch (error: any) {
        res.status(error?.message === 'INVALID_STORAGE_PATH' ? 400 : 500).json({ error: '无法写入文件' });
      }
    },
  );

  router.delete('/files/*', async (req, res) => {
    try {
      const filePath = storagePath(req);
      const force = req.header('X-Force-Overwrite')?.toLowerCase() === 'true';
      const result = await storage.deleteRawFile(getUserIdFromContext(req)!, filePath, {
        ifMatch: req.header('If-Match') || undefined,
        force,
      });
      if (result === 'not_found') return res.sendStatus(404);
      if (result === 'precondition_failed') return res.status(412).json({ error: '文件版本冲突' });
      if (force) {
        await storage.logStorageAudit({
          userId: getUserIdFromContext(req)!, action: 'force-delete', filePath,
        });
      }
      webSocket?.broadcastFileUpdate(getUserIdFromContext(req)!, req.header('X-Device-ID') || undefined, filePath);
      res.status(204).end();
    } catch (error: any) {
      res.status(error?.message === 'INVALID_STORAGE_PATH' ? 400 : 500).json({ error: '无法删除文件' });
    }
  });

  return router;
}
