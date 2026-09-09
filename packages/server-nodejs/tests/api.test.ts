import fs from 'fs';
import path from 'path';
import request from 'supertest';

const baseUrl = process.env.TEST_BASE_URL || 'http://localhost:8874';
const testDataDir = path.join(__dirname, 'test_data');
const user = {
  username: `storage_user_${Date.now()}`,
  password: 'test_password_123',
  device_id: 'storage_test_device',
  device_name: 'Storage Test Device',
};

let token: string;
let userId: string;
let apiKey: string;

describe('Aboutme HTTP storage server', () => {
  it('serves public health and version endpoints', async () => {
    const health = await request(baseUrl).get('/health').expect(200);
    expect(health.body.status).toBe('healthy');
    const version = await request(baseUrl).get('/version').expect(200);
    expect(version.body.name).toContain('Aboutme');
  });

  it('registers a user and rejects duplicate registration', async () => {
    const response = await request(baseUrl)
      .post('/api/v1/auth/register').send(user).expect(200);
    expect(response.body.success).toBe(true);
    token = response.body.token;
    userId = response.body.user_id;
    expect(token).toBeTruthy();

    await request(baseUrl).post('/api/v1/auth/register').send(user).expect(400);
  });

  it('authenticates users and creates an API key', async () => {
    await request(baseUrl)
      .post('/api/v1/auth/login')
      .send({...user, password: 'wrong'})
      .expect(401);
    const login = await request(baseUrl)
      .post('/api/v1/auth/login').send(user).expect(200);
    expect(login.body.token).toBeTruthy();

    const keyResponse = await request(baseUrl)
      .post('/api/v1/auth/api-keys')
      .set('Authorization', `Bearer ${token}`)
      .send({name: 'Storage tests', expiry: 'never'})
      .expect(200);
    apiKey = keyResponse.body.api_key.key;
    expect(apiKey).toMatch(/^mk_/);
  });

  it('protects the authenticated storage health endpoint', async () => {
    await request(baseUrl).get('/api/v1/storage/health').expect(401);
    await request(baseUrl)
      .get('/api/v1/storage/health')
      .set('Authorization', 'Bearer invalid')
      .expect(401);
    const response = await request(baseUrl)
      .get('/api/v1/storage/health')
      .set('X-API-Key', apiKey)
      .expect(200);
    expect(response.body.user_id).toBe(userId);
  });

  describe('file CRUD and optimistic concurrency', () => {
    const filePath = 'notes/private.bin';
    const ciphertext = Buffer.from('{"version":1,"ciphertext":"opaque-one"}');
    let etag: string;

    it('requires explicit create semantics', async () => {
      await request(baseUrl)
        .put(`/api/v1/storage/files/${filePath}`)
        .set('Authorization', `Bearer ${token}`)
        .set('Content-Type', 'application/octet-stream')
        .send(ciphertext)
        .expect(412);

      const response = await request(baseUrl)
        .put(`/api/v1/storage/files/${filePath}`)
        .set('Authorization', `Bearer ${token}`)
        .set('Content-Type', 'application/octet-stream')
        .set('If-None-Match', '*')
        .send(ciphertext)
        .expect(200);
      etag = response.headers.etag;
      expect(etag).toMatch(/^"[a-f0-9]{64}"$/);
    });

    it('returns exact bytes and metadata', async () => {
      const head = await request(baseUrl)
        .head(`/api/v1/storage/files/${filePath}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(head.headers.etag).toBe(etag);
      expect(Number(head.headers['content-length'])).toBe(ciphertext.length);
      expect(head.headers['last-modified']).toBeTruthy();

      const response = await request(baseUrl)
        .get(`/api/v1/storage/files/${filePath}`)
        .set('Authorization', `Bearer ${token}`)
        .buffer(true)
        .parse((res, done) => {
          const chunks: Buffer[] = [];
          res.on('data', chunk => chunks.push(Buffer.from(chunk)));
          res.on('end', () => done(null, Buffer.concat(chunks)));
        })
        .expect(200);
      expect(Buffer.compare(response.body, ciphertext)).toBe(0);
    });

    it('rejects stale updates without losing data', async () => {
      await request(baseUrl)
        .put(`/api/v1/storage/files/${filePath}`)
        .set('Authorization', `Bearer ${token}`)
        .set('Content-Type', 'application/octet-stream')
        .set('If-Match', '"stale"')
        .send(Buffer.from('bad'))
        .expect(412);

      const current = await request(baseUrl)
        .get(`/api/v1/storage/files/${filePath}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(Buffer.from(current.body).toString('utf8')).toContain('opaque-one');
    });

    it('lists and conditionally deletes files', async () => {
      const list = await request(baseUrl)
        .get('/api/v1/storage/files?prefix=notes/')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(list.body.files).toContain(filePath);

      await request(baseUrl)
        .delete(`/api/v1/storage/files/${filePath}`)
        .set('Authorization', `Bearer ${token}`)
        .set('If-Match', '"stale"')
        .expect(412);
      await request(baseUrl)
        .delete(`/api/v1/storage/files/${filePath}`)
        .set('Authorization', `Bearer ${token}`)
        .set('If-Match', etag)
        .expect(204);
      await request(baseUrl)
        .get(`/api/v1/storage/files/${filePath}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(404);
    });
  });

  it('rejects path traversal', async () => {
    await request(baseUrl)
      .get('/api/v1/storage/files/%2e%2e%2fauth%2fusers.json')
      .set('Authorization', `Bearer ${token}`)
      .expect(400);
    await request(baseUrl)
      .get('/api/v1/storage/files/C:%2FWindows%2Fwin.ini')
      .set('Authorization', `Bearer ${token}`)
      .expect(400);
  });

  it('audits explicit force overwrite', async () => {
    await request(baseUrl)
      .put('/api/v1/storage/files/forced.bin')
      .set('Authorization', `Bearer ${token}`)
      .set('Content-Type', 'application/octet-stream')
      .set('X-Force-Overwrite', 'true')
      .send(Buffer.from('opaque'))
      .expect(200);
    const audit = fs.readFileSync(path.join(testDataDir, 'logs', 'storage_audit.log'), 'utf8');
    expect(audit).toContain('force-overwrite');
    expect(audit).toContain('forced.bin');
  });

  it('supports browser CORS preflight', async () => {
    const response = await request(baseUrl)
      .options('/api/v1/storage/files/demo.bin')
      .set('Origin', 'https://example.test')
      .set('Access-Control-Request-Method', 'PUT')
      .set('Access-Control-Request-Headers', 'if-match,x-force-overwrite')
      .expect(204);
    expect(response.headers['access-control-allow-headers']).toContain('If-Match');
    expect(response.headers['access-control-expose-headers']).toContain('ETag');
  });
});
