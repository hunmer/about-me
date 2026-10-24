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

  test('并发 verifyApiKey 全部通过（读-改-写回写竞态回归）', () async {
    final user = await auth.register(
      username: 'erin',
      password: 'secret66',
      deviceId: 'd1',
    );
    final apiKey = await auth.generateApiKey(
      userId: user.userId!,
      name: 'concurrent',
      expiry: ApiKeyExpiry.never,
    );

    // 修复前：并发回写 lastUsedAt 时读侧命中写了一半的 JSON → 误判无效
    final results = await Future.wait(
      List.generate(30, (_) => auth.verifyApiKey(apiKey.key)),
    );
    expect(results.every((r) => r != null), isTrue);
  });

  test('并发注册同名用户恰好成功一个（users 锁回归）', () async {
    final results = await Future.wait(
      List.generate(
        10,
        (i) => auth.register(
          username: 'same-name',
          password: 'secret66',
          deviceId: 'd$i',
        ),
      ),
    );
    expect(results.where((r) => r.success).length, 1);
    final users = await auth.findUserByUsername('same-name');
    expect(users, isNotNull);
  });

  test('并发登录不覆盖设备登记且不死锁（users 锁回归）', () async {
    await auth.register(
      username: 'frank',
      password: 'secret66',
      deviceId: 'seed',
    );
    final results = await Future.wait(
      List.generate(
        8,
        (i) => auth.login(
          username: 'frank',
          password: 'secret66',
          deviceId: 'dev-$i',
          deviceName: 'Device $i',
        ),
      ),
    );
    expect(results.every((r) => r.success), isTrue);
    final devices = await auth.getDevices(results.first.userId!);
    // seed + 8 个并发登记的设备一条不丢
    expect(devices.length, 9);
  });
}
