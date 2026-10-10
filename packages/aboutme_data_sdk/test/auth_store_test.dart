import 'dart:io';

import 'package:aboutme_data_sdk/io.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late AuthStore auth;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('aboutme_auth_test');
    auth = AuthStore(
      dataDir: tempDir.path,
      jwtSecret: 'test-secret',
      adminUsername: 'admin',
      adminPassword: 'admin123',
    );
    await auth.initialize();
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('管理员账号初始化', () async {
    final admin = await auth.findUserByUsername('admin');
    expect(admin, isNotNull);
    expect(admin!.isAdmin, isTrue);
    expect(
      PasswordHasher.verifyPassword(
        'admin123',
        admin.salt,
        admin.passwordHash,
      ),
      isTrue,
    );
  });

  test('注册 → 登录 → 错误密码拒绝', () async {
    final registered = await auth.register(
      username: 'alice',
      password: 'secret66',
      deviceId: 'device-1',
      deviceName: 'iPhone',
    );
    expect(registered.success, isTrue);
    expect(registered.userSalt, isNotEmpty);

    final login = await auth.login(
      username: 'alice',
      password: 'secret66',
      deviceId: 'device-1',
    );
    expect(login.success, isTrue);
    expect(login.userId, registered.userId);

    final bad = await auth.login(
      username: 'alice',
      password: 'wrong',
      deviceId: 'device-1',
    );
    expect(bad.success, isFalse);

    final duplicate = await auth.register(
      username: 'alice',
      password: 'secret66',
      deviceId: 'device-1',
    );
    expect(duplicate.success, isFalse);
  });

  test('Token 刷新与 API Key 生命周期', () async {
    final registered = await auth.register(
      username: 'bob',
      password: 'secret66',
      deviceId: 'd1',
    );
    final refreshed = await auth.refreshToken(registered.token!);
    expect(refreshed.success, isTrue);
    expect(
      auth.getUserIdFromToken(refreshed.token!),
      registered.userId,
    );

    final apiKey = await auth.generateApiKey(
      userId: registered.userId!,
      name: 'phone',
      expiry: ApiKeyExpiry.never,
    );
    expect(apiKey.key.startsWith('mk_'), isTrue);
    expect(apiKey.keyHash.length, 64); // sha256 hex

    final verified = await auth.verifyApiKey(apiKey.key);
    expect(verified, isNotNull);
    expect(verified!.userId, registered.userId);
    expect(verified.keyName, 'phone');

    await auth.revokeApiKey(registered.userId!, apiKey.id);
    expect(await auth.verifyApiKey(apiKey.key), isNull);
  });

  test('过期 API Key 拒绝', () async {
    final user = await auth.register(
      username: 'carol',
      password: 'secret66',
      deviceId: 'd1',
    );
    final apiKey = await auth.generateApiKey(
      userId: user.userId!,
      name: 'temp',
      expiry: ApiKeyExpiry.days7,
    );
    expect(await auth.verifyApiKey(apiKey.key), isNotNull);
  });

  test('设备管理与 API 访问状态', () async {
    final user = await auth.register(
      username: 'dave',
      password: 'secret66',
      deviceId: 'd1',
    );
    final devices = await auth.getDevices(user.userId!);
    expect(devices.length, 1);

    await auth.registerDevice(
      userId: user.userId!,
      deviceId: 'd2',
      deviceName: 'iPad',
      platform: 'ios',
    );
    expect((await auth.getDevices(user.userId!)).length, 2);

    await auth.deleteDevice(user.userId!, 'd2');
    expect((await auth.getDevices(user.userId!)).length, 1);

    expect(await auth.getApiAccessStatus(user.userId!), isFalse);
    await auth.setApiAccessStatus(user.userId!, true);
    expect(await auth.getApiAccessStatus(user.userId!), isTrue);
  });
}
