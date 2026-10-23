import 'dart:convert';
import 'package:aboutme_data_sdk/aboutme_data_sdk.dart';
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/plugins/contact/models/contact_model.dart';
import 'package:aboutme/plugins/contact/models/interaction_record_model.dart';
import 'package:aboutme/plugins/contact/models/filter_sort_config.dart';
import 'package:aboutme/plugins/base_plugin.dart';
import 'package:aboutme/core/event/event_manager.dart';

/// Thin UI adapter. SDK owns canonical state and atomic interaction/contact changes.
class ContactController {
  final BasePlugin plugin;
  ContactController(this.plugin);
  AboutmeData get _data => AboutmeDataService.instance.data;
  int? _version;
  final _originals = <String, Map<String, dynamic>>{};
  dynamic _result(Map<String, dynamic> r) {
    if (r['success'] != true) throw QueryFailure(r);
    _version = r['version'] as int?;
    return r['data'];
  }

  Future<dynamic> _query(
    String action, [
    Map<String, dynamic> p = const {},
  ]) async => _result(await _data.query('contact', action, p));
  Future<dynamic> _command(
    String action,
    Map<String, dynamic> p, {
    bool checkVersion = false,
  }) async => _result(
    await _data.call('contact', action, {
      ...p,
      if (checkVersion && _version != null) 'expectedVersion': _version,
    }),
  );
  Map<String, dynamic> _patch(Map<String, dynamic> row) {
    final old = _originals[row['id']];
    if (old == null) throw StateError('编辑前必须重新读取联系人或交互记录');
    return {
      'id': row['id'],
      for (final e in row.entries)
        if (e.key != 'id' && jsonEncode(e.value) != jsonEncode(old[e.key]))
          e.key: e.value,
    };
  }

  Contact _contact(dynamic r) {
    final c = Contact.fromJson(r as Map);
    _originals[c.id] = c.toJson();
    return c;
  }

  InteractionRecord _interaction(dynamic r) {
    final c = InteractionRecord.fromJson(Map<String, dynamic>.from(r as Map));
    _originals[c.id] = c.toJson();
    return c;
  }

  Stream<QuerySnapshot> watchSnapshot() =>
      _data.watch('contact', 'getSnapshot');
  Future<List<Contact>> getAllContacts() async {
    final r = await _query('getList');
    return (r['data'] as List).map(_contact).toList();
  }

  Future<Contact?> getContact(String id) async {
    final r = await _data.query('contact', 'getById', {'id': id});
    return _contact(_result(r));
  }

  Future<Contact> addContact(Contact contact) async {
    final c = _contact(await _command('create', contact.toJson()));
    _event('contact_created');
    return c;
  }

  Future<Contact> updateContact(Contact contact) async {
    final c = _contact(
      await _command('update', _patch(contact.toJson()), checkVersion: true),
    );
    _event('contact_updated');
    return c;
  }

  Future<void> deleteContact(String id) async {
    await _command('delete', {'id': id}, checkVersion: true);
    _originals.remove(id);
    _event('contact_deleted');
  }

  Future<List<InteractionRecord>> getAllInteractions() async {
    final r = await _query('getInteractions');
    return (r['data'] as List).map(_interaction).toList();
  }

  Future<List<InteractionRecord>> getInteractionsByContactId(String id) async {
    final r = await _query('getInteractions', {'contactId': id});
    return (r['data'] as List).map(_interaction).toList();
  }

  Future<InteractionRecord> addInteraction(InteractionRecord record) async {
    final saved = _interaction(
      await _command('addInteraction', record.toJson()),
    );
    _event('contact_interaction_added');
    return saved;
  }

  Future<InteractionRecord> updateInteraction(InteractionRecord record) async =>
      _interaction(
        await _command(
          'updateInteraction',
          _patch(record.toJson()),
          checkVersion: true,
        ),
      );
  Future<void> deleteInteraction(String id) async {
    await _command('deleteInteraction', {'id': id}, checkVersion: true);
  }

  Future<void> deleteInteractionsByContactId(String id) async {
    await _command('deleteContactInteractions', {
      'contactId': id,
    }, checkVersion: true);
  }

  Future<void> saveFilterConfig(FilterConfig c) async {
    await _command('updatePreferences', {'filter': c.toJson()});
  }

  Future<FilterConfig> getFilterConfig() async {
    final r = await _query('getPreferences');
    return FilterConfig.fromJson(Map<String, dynamic>.from(r['filter'] as Map));
  }

  Future<void> saveSortConfig(SortConfig c) async {
    await _command('updatePreferences', {'sort': c.toJson()});
  }

  Future<SortConfig> getSortConfig() async {
    final r = await _query('getPreferences');
    return SortConfig.fromJson(Map<String, dynamic>.from(r['sort'] as Map));
  }

  Future<List<Contact>> getFilteredAndSortedContacts() async {
    final r = await _query('getList', {'filtered': true});
    return (r['data'] as List).map(_contact).toList();
  }

  Future<List<String>> getAllTags() async =>
      {for (final c in await getAllContacts()) ...c.tags}.toList()..sort();
  Future<int> getRecentlyContactedCount() async {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    return (await getAllContacts())
        .where((c) => c.lastContactTime.isAfter(cutoff))
        .length;
  }

  Future<int> getTodayInteractionCount() async {
    final now = DateTime.now();
    return (await getAllInteractions())
        .where(
          (r) =>
              r.date.year == now.year &&
              r.date.month == now.month &&
              r.date.day == now.day,
        )
        .length;
  }

  Future<int> getContactInteractionsCount(String id) async =>
      (await getInteractionsByContactId(id)).length;
  Future<void> createDefaultContacts() async {
    await _command('seedExamples', {
      'groups': ['contacts'],
      'templateVersion': 1,
    });
  }

  Future<void> saveAllChanges() async {}
  void _event(String name) =>
      EventManager.instance.broadcast(name, EventArgs(name));
}
