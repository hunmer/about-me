import 'dart:convert';
import 'dart:typed_data';

import 'package:aboutme_server/src/business_request_body.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  test('流读取达到上限后停止，不消费剩余请求体', () async {
    var consumed = 0;
    Stream<List<int>> body() async* {
      for (var i = 0; i < 40; i++) { consumed++; yield Uint8List(1024 * 1024); }
    }
    final request = Request('POST', Uri.parse('http://localhost/upload'), body: body());
    await expectLater(readBusinessRequestBody(request), throwsA(isA<BusinessBodyTooLarge>()));
    expect(consumed, 25);
  });
  test('严格 UTF-8 JSON，只有显式允许时接受空体', () async {
    Request request(List<int> bytes) => Request('POST', Uri.parse('http://localhost/upload'), body: bytes);
    expect(await readBusinessRequestBody(request(utf8.encode('{"id":"001"}'))), {'id': '001'});
    expect(await readBusinessRequestBody(request([]), allowEmpty: true), isNull);
    await expectLater(readBusinessRequestBody(request([])), throwsFormatException);
    await expectLater(readBusinessRequestBody(request([0xff])), throwsFormatException);
  });
}
