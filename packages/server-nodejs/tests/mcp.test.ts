import request from 'supertest';

const baseUrl = process.env.TEST_BASE_URL || 'http://localhost:8874';
const user = {
  username: `mcp_user_${Date.now()}`,
  password: 'test_password_123',
  device_id: 'mcp_test_device',
  device_name: 'MCP Test Device',
};

let apiKey: string;

function rpc(method: string, params: Record<string, unknown>, id: number | string) {
  return { jsonrpc: '2.0', id, method, params };
}

/**
 * 解析 MCP 响应（SDK 可能返回 application/json 或 SSE 格式）
 */
function parseRpcResult(res: { text?: string; body: any; headers: Record<string, unknown> }) {
  const contentType = String(res.headers['content-type'] || '');
  if (contentType.includes('application/json')) {
    return res.body;
  }
  const dataLine = (res.text || '').split('\n').find((l: string) => l.startsWith('data:'));
  return dataLine ? JSON.parse(dataLine.slice(5).trim()) : null;
}

function mcpPost(body: unknown) {
  return request(baseUrl)
    .post('/mcp')
    .set('X-API-Key', apiKey)
    // 合法的 32 字节 AES-256 密钥 (base64: 'A' * 32)
    .set('X-Encryption-Key', 'QUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUE=')
    .set('Accept', 'application/json, text/event-stream')
    .send(body as object);
}

describe('MCP endpoint (Streamable HTTP)', () => {
  beforeAll(async () => {
    const reg = await request(baseUrl)
      .post('/api/v1/auth/register')
      .send(user)
      .expect(200);
    const keyResponse = await request(baseUrl)
      .post('/api/v1/auth/api-keys')
      .set('Authorization', `Bearer ${reg.body.token}`)
      .send({ name: 'MCP tests', expiry: 'never' })
      .expect(200);
    apiKey = keyResponse.body.api_key.key;
    expect(apiKey).toMatch(/^mk_/);
  });

  it('rejects unauthenticated requests', async () => {
    const res = await request(baseUrl)
      .post('/mcp')
      .set('Accept', 'application/json, text/event-stream')
      .send(rpc('initialize', {}, 1));
    expect(res.status).toBe(401);
  });

  it('requires X-Encryption-Key header', async () => {
    const res = await request(baseUrl)
      .post('/mcp')
      .set('X-API-Key', apiKey)
      .send(rpc('initialize', {}, 1));
    expect(res.status).toBe(403);
    expect(res.body.error).toContain('加密密钥');
  });

  it('supports CORS preflight with MCP headers', async () => {
    const res = await request(baseUrl)
      .options('/mcp')
      .set('Origin', 'https://example.com')
      .set('Access-Control-Request-Method', 'POST')
      .set('Access-Control-Request-Headers', 'x-api-key, x-encryption-key, mcp-session-id, mcp-protocol-version')
      .expect(204);
    expect(res.headers['access-control-allow-headers']).toContain('Mcp-Session-Id');
  });

  it('handles initialize handshake', async () => {
    const res = await mcpPost(
      rpc('initialize', {
        protocolVersion: '2025-06-18',
        capabilities: {},
        clientInfo: { name: 'test-client', version: '1.0.0' },
      }, 1),
    ).expect(200);
    const payload = parseRpcResult(res);
    expect(payload.result.serverInfo.name).toContain('aboutme');
    expect(payload.result.capabilities.tools).toBeTruthy();
  });

  it('acknowledges initialized notification with 202', async () => {
    const res = await mcpPost({
      jsonrpc: '2.0',
      method: 'notifications/initialized',
    });
    expect(res.status).toBe(202);
  });

  it('lists tools', async () => {
    const res = await mcpPost(rpc('tools/list', {}, 2)).expect(200);
    const payload = parseRpcResult(res);
    const names: string[] = payload.result.tools.map((t: { name: string }) => t.name);
    expect(names).toContain('aboutme_chat_getChannels');
    expect(names).toContain('aboutme_calendar_createEvent');
    expect(names).toContain('aboutme_day_getMemorialDays');
    expect(names.length).toBeGreaterThan(60);
  });

  it('calls a tool end-to-end', async () => {
    const res = await mcpPost(
      rpc('tools/call', { name: 'aboutme_chat_getChannels', arguments: { count: 5 } }, 3),
    ).expect(200);
    const payload = parseRpcResult(res);
    expect(payload.result.content[0].type).toBe('text');
    expect(typeof payload.result.content[0].text).toBe('string');
  });

  it('creates and reads data via in-process tool invocation', async () => {
    // 新注册用户无历史数据，首次写入用任意有效密钥即可成功
    const created = await mcpPost(
      rpc('tools/call', {
        name: 'aboutme_chat_createChannel',
        arguments: { name: 'MCP 测试频道', description: 'created by test' },
      }, 5),
    ).expect(200);
    const createdPayload = parseRpcResult(created);
    expect(createdPayload.result.isError).toBeFalsy();
    const channel = JSON.parse(createdPayload.result.content[0].text);
    expect(channel.name).toBe('MCP 测试频道');
    expect(channel.id).toBeTruthy();

    const listed = await mcpPost(
      rpc('tools/call', { name: 'aboutme_chat_getChannels', arguments: {} }, 6),
    ).expect(200);
    const listedPayload = parseRpcResult(listed);
    expect(listedPayload.result.isError).toBeFalsy();
    const channels = JSON.parse(listedPayload.result.content[0].text);
    expect(channels.data.some((c: { name: string }) => c.name === 'MCP 测试频道')).toBe(true);
  });

  it('returns tool error for unknown tool', async () => {
    const res = await mcpPost(
      rpc('tools/call', { name: 'nonexistent_tool', arguments: {} }, 4),
    ).expect(200);
    const payload = parseRpcResult(res);
    expect(payload.result.isError).toBe(true);
    expect(payload.result.content[0].text).toContain('未知工具');
  });

  it('serves static search routes not shadowed by :id routes', async () => {
    // 回归: /contacts/search 与 /events/search 曾被 /contacts/:id、/events/:id 抢先匹配
    for (const [tool, keyword] of [
      ['aboutme_contact_searchContacts', '张'],
      ['aboutme_calendar_searchEvents', '会议'],
    ] as const) {
      const res = await mcpPost(
        rpc('tools/call', { name: tool, arguments: { keyword } }, `search-${tool}`),
      ).expect(200);
      const payload = parseRpcResult(res);
      expect(payload.result.isError).toBeFalsy();
      expect(typeof payload.result.content[0].text).toBe('string');
    }
  });

  it('rejects GET and DELETE in stateless mode', async () => {
    await request(baseUrl)
      .get('/mcp')
      .set('X-API-Key', apiKey)
      .set('X-Encryption-Key', 'x')
      .expect(405);
    await request(baseUrl)
      .delete('/mcp')
      .set('X-API-Key', apiKey)
      .set('X-Encryption-Key', 'x')
      .expect(405);
  });
});
