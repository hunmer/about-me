import 'package:aboutme_data_sdk/io.dart';
import 'package:test/test.dart';

void main() {
  const secret = 'test-secret-123';
  // 以下 token 均由 nodejs jsonwebtoken 生成
  const nodeToken =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyLWFiYyIsImlhdCI6MTc5MTY1NTY2NywiZXhwIjo0OTQ3NDE1NjY3fQ.H6vD_MxxJ1B079avD3kfLZQF_sapusi3-nIoX6vkSRE';
  const wrongSecretToken =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyLWFiYyIsImlhdCI6MTc5MTY1MDI5OSwiZXhwIjoxNzkxNjUzODk5fQ.83VaejoJTXqseyPqlv8bWmvFresAbiTUo1w5uf1m0Vs';
  const expiredToken =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyLWFiYyIsImlhdCI6MTc5MTY1NTY2NywiZXhwIjoxNzkxNjUyMDY3fQ.HQI3kqN0Qi1AnVd7d5lY0CXR7wlg1V_VqS62YaRK39c';

  test('验证 nodejs jsonwebtoken 签发的 token', () {
    final payload = JwtHs256.verify(nodeToken, secret);
    expect(payload, isNotNull);
    expect(payload!['sub'], 'user-abc');
  });

  test('拒绝错误密钥签发的 token', () {
    expect(JwtHs256.verify(wrongSecretToken, secret), isNull);
  });

  test('拒绝过期 token', () {
    expect(JwtHs256.verify(expiredToken, secret), isNull);
  });

  test('Dart 签发的 token 可被自身验证', () {
    final token = JwtHs256.sign(
      payload: {'sub': 'u1'},
      secret: secret,
      lifetime: const Duration(hours: 1),
    );
    final payload = JwtHs256.verify(token, secret);
    expect(payload, isNotNull);
    expect(payload!['sub'], 'u1');
  });
}
