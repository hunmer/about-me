import 'package:flutter_test/flutter_test.dart';
import 'package:aboutme/plugins/scripts_center/models/script_info.dart';

void main() {
  test('uses metadata title when API-created script has no name', () {
    final script = ScriptInfo.fromJson(
      {'title': 'scn script'},
      id: 'scn-script-mvm2kzxk',
      path: 'scripts_center/scripts/scn-script-mvm2kzxk',
    );

    expect(script.name, 'scn script');
  });

  test('prefers canonical name when both name and title are present', () {
    final script = ScriptInfo.fromJson(
      {'name': 'canonical name', 'title': 'legacy title'},
      id: 'script-1',
      path: 'scripts_center/scripts/script-1',
    );

    expect(script.name, 'canonical name');
  });
}
