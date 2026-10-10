import 'package:aboutme_data_sdk/io.dart';
import 'package:test/test.dart';

void main() {
  test('PBKDF2 输出与 nodejs crypto.pbkdf2Sync 完全一致', () {
    // 由 nodejs 生成：
    // crypto.pbkdf2Sync('password123', salt, 10000, 64, 'sha256')
    const salt = 'xcRRLxN6lWsK+KRYK8BhCA==';
    const expected =
        '9GKr6Fk7QxS/dLub3xKMwkdHkeq4DOEZygSyozsKNPSRHK+4Pw8dhDzXSuZat/VlVSHWD9e3OwEtZ5g4KAXtJg==';

    expect(PasswordHasher.hashPassword('password123', salt), expected);
    expect(
      PasswordHasher.verifyPassword('password123', salt, expected),
      isTrue,
    );
    expect(
      PasswordHasher.verifyPassword('wrong-password', salt, expected),
      isFalse,
    );
  });

  test('generateSalt 生成合法 Base64 16 字节', () {
    final salt = PasswordHasher.generateSalt();
    expect(salt, isNot(isEmpty));
    expect(() => PasswordHasher.hashPassword('x', salt), returnsNormally);
  });
}
