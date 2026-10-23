import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../plugin_data.dart';
import '../types.dart';
import '../handlers/record_domain_support.dart';

Map<String,List<String>> recordDomainFiles(String plugin) => switch(plugin) {
  'todo'=>{'tasks.json':['tasks','completedTasks']},
  'tracker'=>{'goals.json':['goals'],'records.json':['records']},
  _=>throw ArgumentError('Unsupported domain'),
};
dynamic _canonical(dynamic raw) {
  if(raw is Map){final keys=raw.keys.cast<String>().toList()..sort();return {for(final key in keys)key:_canonical(raw[key])};}
  if(raw is List)return raw.map(_canonical).toList();return raw;
}
String _checksum(dynamic raw)=>sha256.convert(utf8.encode(jsonEncode(_canonical(raw)))).toString();
Future<Map<String,dynamic>> _snapshot(PluginData data,String plugin) async {
  final files=<String,dynamic>{},ids=<String,dynamic>{};
  for(final e in recordDomainFiles(plugin).entries) {
    final decoded=await readDomainFile(data,plugin,e.key,e.value);
    files[e.key]=await data.read(plugin,e.key);
    for(final key in e.value){final values=(decoded[key] as List).map((e)=>e['id']).toList()..sort();if(values.toSet().length!=values.length)throw const DomainFailure('CORRUPT_DATA','Duplicate entity IDs');ids[key]=values;}
  }
  if(plugin=='tracker') {
    final goals=(ids['goals'] as List).toSet();
    for(final record in (files['records.json']?['records'] as List? ?? [])){if(!goals.contains(record['goalId']))throw const DomainFailure('CORRUPT_DATA','Orphan tracker record');}
  }
  return {'schemaVersion':1,'domain':plugin,'files':files,'entityIds':ids,'checksum':_checksum(files)};
}
Future<void> prepareRecordDomainMigration(PluginData data,String plugin) async {
  final manifest=await data.read('sdk_migrations','$plugin/v1.json');
  if(manifest!=null){if(manifest is! Map||manifest['verified']!=true||manifest['schemaVersion']!=1)throw const DomainFailure('CORRUPT_DATA','Invalid migration manifest');return;}
  final backup=await _snapshot(data,plugin);
  await data.write('sdk_migrations','$plugin/v1_backup.json',backup);
  final verified=await data.read('sdk_migrations','$plugin/v1_backup.json');
  if(verified is! Map || _checksum(verified['files'])!=backup['checksum'])throw const DomainFailure('CORRUPT_DATA','Backup verification failed');
  await data.write('sdk_migrations','$plugin/v1.json',{'schemaVersion':1,'verified':true,'domain':plugin,'backupChecksum':backup['checksum'],'entityIds':backup['entityIds'],'createdAt':DateTime.now().toIso8601String()});
}
PluginHandlers recordDomainMigrationHandlers(PluginData data,String plugin)=>{
  'migrate':domainAction((_)async{await prepareRecordDomainMigration(data,plugin);return data.read('sdk_migrations','$plugin/v1.json');}),
  'getMigrationReport':domainAction((_)async{
    final manifest=await data.read('sdk_migrations','$plugin/v1.json');
    if(manifest==null)return {'schemaVersion':1,'verified':false};
    if(manifest is! Map||manifest['verified']!=true||manifest['schemaVersion']!=1)throw const DomainFailure('CORRUPT_DATA','Invalid migration manifest');
    await prepareRecordDomainMigration(data,plugin);
    return data.read('sdk_migrations','$plugin/v1.json');
  }),
  'exportData':domainAction((_)=>_snapshot(data,plugin)),
  'restoreBackup':domainAction((p)async{
    if(p['confirmRestore']!=true)throw ArgumentError('confirmRestore required');
    final backup=await data.read('sdk_migrations','$plugin/v1_backup.json');
    if(backup is! Map || backup['schemaVersion']!=1 || backup['domain']!=plugin || _checksum(backup['files'])!=backup['checksum'])throw const DomainFailure('CORRUPT_DATA','Invalid backup');
    await data.write('sdk_migrations','$plugin/pre_restore.json',await _snapshot(data,plugin));
    final files=backup['files'] as Map;
    for(final file in recordDomainFiles(plugin).keys){final content=files[file];if(content==null){await data.delete(plugin,file);}else{await data.write(plugin,file,content);}}
    final restored=await _snapshot(data,plugin);if(restored['checksum']!=backup['checksum'])throw const DomainFailure('CORRUPT_DATA','Restore verification failed');
    return {'restored':true,'checksum':restored['checksum'],'entityIds':restored['entityIds']};
  }),
};

PluginHandlers withRecordDomainMigration(PluginData data,String plugin,PluginHandlers actions)=>{
  for(final entry in {...actions,...recordDomainMigrationHandlers(data,plugin)}.entries)
    entry.key:entry.key.startsWith('get')||entry.key.startsWith('search')||entry.key=='exportData'
      ?entry.value
      : (transaction,params)async{
        try{await prepareRecordDomainMigration(data,plugin);}on DomainFailure catch(e){return PluginResult.failure(e.message,e.code);}
        return entry.value(transaction,params);
      },
};
