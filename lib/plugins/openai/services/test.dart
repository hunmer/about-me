import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

Future<String?> uploadFileToOpenAI(
  String apiKey,
  String filePath,
  String purpose,
) async {
  final file = File(filePath);
  if (!file.existsSync()) return null;

  final uri = Uri.parse('https://api.openai.com/v1/files');
  final request =
      http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $apiKey'
        ..files.add(await http.MultipartFile.fromPath('file', filePath))
        ..fields['purpose'] = purpose;

  final response = await request.send();
  if (response.statusCode == 200) {
    final body = await response.stream.bytesToString();
    final json = jsonDecode(body);
    return json['id'];
  }
  return null;
}

void main() async {
  final key = Platform.environment['OPENAI_API_KEY'];
  if (key == null || key.isEmpty) {
    print('Set OPENAI_API_KEY to run the file upload smoke test.');
    return;
  }
  final fileId = await uploadFileToOpenAI(
    key,
    'path/to/your/file.txt',
    'assistants',
  );
  print(fileId == null ? 'Upload failed' : 'Uploaded file: $fileId');
}
