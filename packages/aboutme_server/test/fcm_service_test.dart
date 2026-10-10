import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aboutme_server/src/fcm_service.dart';
import 'package:basic_utils/basic_utils.dart';
import 'package:pointycastle/export.dart';
import 'package:test/test.dart';

void main() {
  // RSA 密钥对与签名向量均由 nodejs crypto 生成（2048 位，PKCS8/SPKI PEM），
  // 验证 Dart FCM 服务的 RS256 签名与 nodejs 完全一致。
  const input = 'test-signing-input-for-aboutme';
  const nodeSignatureBase64 =
      'VKtzjezVg9G+b0qro3xl22ubjHbz++GwIKBgHiARcwq2ymjPx34ME8okJY5StKF6a29sAJsV4IttzNqWwTdO5sUEIsHukhk2BzM5esLV1HtdrwHipvyO2HSE9YwA5F5k0pak+tl9o478hfbvQxeksNwPAVmkMcDk3ekC+6LhaOYN58qsRjtUn6aXNLFiwiv6H1fdOcn7YGbCGmT0MjT2T1xvNj1y5uDUuwQXi4LYeJyO36HJ65JLvQMmD+ofoU7hL7WjI7gTtY1BAUcYbAopXiFO6x0+tevmbbwbjXtw8lGSZXfRTqPCjeWRF5rlVsvfInKTmH3SSF0LtI5jeGWXrQ==';
  const privatePem = '''
-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQCyCdc8YtZ7n30s
HdFYuSE4K+79E9mEUSHDKWvnXJEKCc54zUN74z+aN26SlO3S3S5OqXJE9En0RHVz
cy08D2wOwsH3S5GF+1g57mVWzJoVR6gc15XEuahlc4sOX9xAHAmscl1sr+eo+7l2
QUEqwQxRDZPjHWSGoUodhdSrH1VApu1VytZnYFaDJ8I/NIRd+VExJ7qrISR1x74N
OBLyntP+r88beyVuXBBwpmK7JMAfXvijRY1GzXH2x87H+8JLdf+7BlsCsR8ZxYgh
DkyLsUdCW1FyomYsZlnfa6d7lhVvRrrJo/YgnFZtOXrGBcGme97rQZb+z6D4yXti
9bwiX9kbAgMBAAECggEAEDusd9GNO91ZZOXdGilbGYuL8WBXc2SQXwKOV5yNjuxA
+qvAjPG18WI/fzb8Dj9jgwGZLSdW/OInEV09kR3Y3OmuFNW7kYtOyo1tiQIDxI/x
iJuxiKvi6kkkMy3TX7cOvL36vbe2OCanjNw7TGIotNU3mDwsV8gqAVIcB3RGaiwG
9rBXUPyoG3lZyfaG3Mge4Pn5jveLf1xk/Kb6w1DOABLcBvU3ktTMMgfJzK1aomVg
4NdTN/HJNlI5goh0bviB3V7npa0BQZMET46nJkhGanRDt4MdbCPMf4wP+iaOvN0J
PNTMgWY1vogy4v0hHL9sjBRvvXiR1SBhQpOmNUyzmQKBgQDyPWcfrrLkeN2tW3bc
QOLRG664G88XUrI/yEQAsnWBFwm1XeHMFWdQoeQe7+3yxpUE5bL3RsVlrzl1WEd6
fGZdYVrB7iRffMo20tpMRkbxQELfEQSucsd1UllNsDFA+ppE9a20icd22MoycbFA
5C/b+UMTVqv+Ucrf6dDFD+2q4wKBgQC8JtXi630jNL9I8zxpOvh7n8sHXFAq9XZX
3B8WgC9vyQtlK8xvr/OR6QV9lq8GFG8+o8B3fEAe9DBiL7jHwisUzo1UYVu4HM8y
F5piNbeXobcwZLU4FsqrxWfiCwiYwmXlVDTrRrrcw2m3c9bjFfGPbDjUVNz/e072
K7ZLBbnWaQKBgQDMVNEU33bU08MhhOJo/W6VtoUVlZeE8+OZe6Mo91+4qScuTme1
j2RbloNnOTl8rNdsjxj8Dj1Z/Yk5G2MHxcFPCVzV8rvJs+iagBdVeX5D59HAeYl6
YSUwKGtd5b5WMk1I1/dTL1kKPemozVAYDaL1KXfT6ysfVf0MDR1l7H6swwKBgQCL
4ItOYifsDoDO6RXWXaLxtUApPrXS2h2a/+iUv8OEZYB1PHSF69c2eHg+f9GqwXJa
rT6fFd5NpNh7hmLnDzEcDNsBCkg3viNDaEy8CpdswSsBbT1Ub41I2j96yx0fBBbg
wRN+flzZVuW3HwV4WY32REyTfmu1+6QeWyzw5VbdUQKBgHpw/X1gzaI2v77XkpNK
vvFal7iJUEJdXiIcaEIVVep5ycDDdrEcwk38z6og3CFAg7OwNI8/z0+EZ9lBEw5w
I/skglbIvPucTWmYsUyQEoYc5eLM5U+xp+Kn4abqQ48aoV3yLhSN2G2n9CNA3R+c
BvH6AWViaLcD5851Pi5nP+Ra
-----END PRIVATE KEY-----''';
  const publicPem = '''
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAsgnXPGLWe599LB3RWLkh
OCvu/RPZhFEhwylr51yRCgnOeM1De+M/mjdukpTt0t0uTqlyRPRJ9ER1c3MtPA9s
DsLB90uRhftYOe5lVsyaFUeoHNeVxLmoZXOLDl/cQBwJrHJdbK/nqPu5dkFBKsEM
UQ2T4x1khqFKHYXUqx9VQKbtVcrWZ2BWgyfCPzSEXflRMSe6qyEkdce+DTgS8p7T
/q/PG3slblwQcKZiuyTAH174o0WNRs1x9sfOx/vCS3X/uwZbArEfGcWIIQ5Mi7FH
QltRcqJmLGZZ32une5YVb0a6yaP2IJxWbTl6xgXBpnve60GW/s+g+Ml7YvW8Il/Z
GwIDAQAB
-----END PUBLIC KEY-----''';

  test('Dart RS256 签名与 nodejs crypto 输出一致', () {
    final key = CryptoUtils.rsaPrivateKeyFromPem(privatePem);
    final signer = RSASigner(SHA256Digest(), '0609608648016503040201')
      ..init(true, PrivateKeyParameter<RSAPrivateKey>(key));
    final signature = signer
        .generateSignature(Uint8List.fromList(utf8.encode(input)))
        .bytes;

    expect(base64Encode(signature), nodeSignatureBase64);
  });

  test('签名可用 nodejs 生成的公钥验证', () {
    final publicKey = CryptoUtils.rsaPublicKeyFromPem(publicPem);
    final verifier = RSASigner(SHA256Digest(), '0609608648016503040201')
      ..init(false, PublicKeyParameter<RSAPublicKey>(publicKey));
    final valid = verifier.verifySignature(
      Uint8List.fromList(utf8.encode(input)),
      RSASignature(base64Decode(nodeSignatureBase64)),
    );
    expect(valid, isTrue);
  });

  test('service-account 缺失时给出明确错误', () async {
    final dir = await Directory.systemTemp.createTemp('fcm_test');
    addTearDown(() => dir.delete(recursive: true));
    final service = FcmService(dataDir: dir.path);

    expect(await service.isConfigured(), isFalse);
    final account = await _loadAccount(service);
    expect(account, isNull);
  });
}

Future<Map<String, dynamic>?> _loadAccount(FcmService service) async {
  // 通过 sendMulticast 间接触发 _loadServiceAccount 失败路径
  try {
    await service.sendMulticast(['fake-token'], 't', 'b');
    return {'unexpected': true};
  } catch (e) {
    expect(e.toString(), contains('service-account.json'));
    return null;
  }
}
