import { Server } from 'http';
import { WebSocket, WebSocketServer } from 'ws';
import { AuthService } from './authService';

interface ClientConnection {
  socket: WebSocket;
  userId: string;
  deviceId: string;
}

export class StorageWebSocketService {
  private readonly server = new WebSocketServer({ noServer: true });
  private readonly clients = new Set<ClientConnection>();

  constructor(private readonly authService: AuthService) {
    this.server.on('connection', (socket: WebSocket) => {
      const authTimeout = setTimeout(() => socket.close(1008, 'Authentication timeout'), 10_000);
      socket.once('message', async raw => {
        clearTimeout(authTimeout);
        try {
          const message = JSON.parse(raw.toString()) as { type?: string; token?: string; device_id?: string };
          const auth = message.type === 'auth' && message.token
            ? await this.authService.verifyApiKey(message.token)
            : null;
          if (!auth || !message.device_id) {
            socket.close(1008, 'Unauthorized');
            return;
          }
          const client: ClientConnection = { socket, userId: auth.userId, deviceId: message.device_id };
          this.clients.add(client);
          socket.send(JSON.stringify({ type: 'auth_success', user_id: client.userId }));
          socket.on('close', () => this.clients.delete(client));
          socket.on('error', () => this.clients.delete(client));
        } catch {
          socket.close(1008, 'Invalid authentication message');
        }
      });
    });
  }

  attach(httpServer: Server): void {
    httpServer.on('upgrade', async (request, socket, head) => {
      const url = new URL(request.url || '/', 'http://localhost');
      if (url.pathname !== '/api/v1/storage/ws') return;
      this.server.handleUpgrade(request, socket, head, ws => this.server.emit('connection', ws, request));
    });
  }

  broadcastFileUpdate(userId: string, sourceDeviceId: string | undefined, filePath: string): void {
    const message = JSON.stringify({
      type: 'file_updated',
      data: {
        file_path: filePath,
        modified_at: new Date().toISOString(),
        source_device_id: sourceDeviceId || '',
      },
    });
    for (const client of this.clients) {
      if (client.userId === userId && client.deviceId !== sourceDeviceId && client.socket.readyState === WebSocket.OPEN) {
        client.socket.send(message);
      }
    }
  }
}
