/// SDK 到 shared_models 的薄适配，不把频道/消息 UI 缓存作为查询来源。
library;

import 'package:shared_models/shared_models.dart';
import 'package:aboutme_data_sdk/aboutme_data_sdk.dart'
    show AboutmeData, QueryFailure;
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/plugins/chat/services/chat_data_service.dart';
import 'package:aboutme/plugins/chat/services/chat_config_service.dart';
import 'package:flutter/material.dart';

class ClientChatRepository extends IChatRepository {
  final ChatDataService dataService;
  final ChatConfigService configService;
  final Color pluginColor;
  ClientChatRepository({
    required this.dataService,
    required this.configService,
    required this.pluginColor,
  });
  AboutmeData get _data => AboutmeDataService.instance.data;

  Future<Result<T>> _run<T>(Future<T> Function() operation) async {
    try {
      return Result.success(await operation());
    } on QueryFailure catch (error) {
      return Result.failure(
        error.toString(),
        code: error.result['code']?.toString() ?? ErrorCodes.serverError,
      );
    } catch (error) {
      return Result.failure(error.toString(), code: ErrorCodes.serverError);
    }
  }

  Future<dynamic> _call(
    String action, [
    Map<String, dynamic> params = const {},
  ]) async =>
      ChatDataService.resultData(await _data.call('chat', action, params));
  Map<String, dynamic> _pagination(PaginationParams? page) => {
    if (page?.offset != null) 'offset': page!.offset,
    if (page?.count != null) 'count': page!.count,
  };
  List<T> _items<T>(dynamic page, T Function(Map<String, dynamic>) decode) =>
      (page['data'] as List)
          .map((item) => decode(Map<String, dynamic>.from(item as Map)))
          .toList();

  ChannelDto _channel(Map<String, dynamic> response) => ChannelDto.fromJson({
    ...Map<String, dynamic>.from(ChatDataService.resultData(response) as Map),
    '_sdkVersion': response['version'],
  });
  List<ChannelDto> _channels(Map<String, dynamic> response) => _items(
    ChatDataService.resultData(response),
    (json) =>
        ChannelDto.fromJson({...json, '_sdkVersion': response['version']}),
  );

  @override
  Future<Result<List<ChannelDto>>> getChannels({
    PaginationParams? pagination,
  }) => _run(
    () async =>
        _channels(await _data.get('chat', 'getList', _pagination(pagination))),
  );
  @override
  Future<Result<ChannelDto?>> getChannelById(String id) => _run(() async {
    final result = await _data.get('chat', 'getById', {'id': id});
    if (result['code'] == 'NOT_FOUND') return null;
    return _channel(result);
  });
  @override
  Future<Result<ChannelDto>> createChannel(ChannelDto dto) => _run(
    () async => _channel(
      await _data.call('chat', 'create', {
        ...dto.toJson(),
        'clientMutationId': 'channel:${dto.id}',
      }),
    ),
  );
  @override
  Future<Result<ChannelDto>> updateChannel(String id, ChannelDto dto) =>
      patchChannel(id, {
        'title': dto.title,
        'icon': dto.iconCodePoint,
        'iconFontFamily': dto.iconFontFamily,
        'backgroundColor': dto.backgroundColor,
        'priority': dto.priority,
        'groups': dto.groups,
        'metadata': dto.metadata,
      }, expectedVersion: dto.version);
  @override
  Future<Result<ChannelDto>> patchChannel(
    String id,
    Map<String, dynamic> patch, {
    int? expectedVersion,
  }) => _run(
    () async => _channel(
      await _data.call('chat', 'patch', {
        ...patch,
        'id': id,
        if (expectedVersion != null) 'expectedVersion': expectedVersion,
      }),
    ),
  );
  @override
  Future<Result<bool>> deleteChannel(String id, {int? expectedVersion}) =>
      _run(() async {
        await _call('delete', {
          'id': id,
          if (expectedVersion != null) 'expectedVersion': expectedVersion,
        });
        return true;
      });
  @override
  Future<Result<List<ChannelDto>>> findChannels(ChannelQuery query) =>
      _run(() async {
        final values = _channels(
          await _data.get('chat', 'findChannel', {
            'field': query.field,
            'value': query.value,
            'fuzzy': query.fuzzy,
          }),
        );
        final selected = query.findAll ? values : values.take(1).toList();
        return PaginationUtils.paginate(
          selected,
          offset: query.pagination?.offset ?? 0,
          count: query.pagination?.count ?? selected.length,
        ).data;
      });
  @override
  Future<Result<List<MessageDto>>> getMessages(
    String channelId, {
    PaginationParams? pagination,
  }) => _run(
    () async => _items(
      await _call('getMessages', {
        'channelId': channelId,
        ..._pagination(pagination),
      }),
      MessageDto.fromJson,
    ),
  );
  @override
  Future<Result<MessageDto>> sendMessage(String channelId, MessageDto dto) =>
      _run(
        () async => MessageDto.fromJson(
          Map<String, dynamic>.from(
            await _call('sendMessage', {
                  ...dto.toJson(),
                  'channelId': channelId,
                  'clientMutationId': 'message:${dto.id}',
                })
                as Map,
          ),
        ),
      );
  @override
  Future<Result<bool>> deleteMessage(
    String channelId,
    String messageId, {
    int? expectedVersion,
  }) => _run(() async {
    await _call('deleteMessage', {
      'channelId': channelId,
      'messageId': messageId,
      if (expectedVersion != null) 'expectedVersion': expectedVersion,
    });
    return true;
  });
  @override
  Future<Result<List<MessageDto>>> findMessages(MessageQuery query) =>
      _run(() async {
        final values = _items(
          await _call('findMessage', {
            'channelId': query.channelId,
            'field': query.field,
            'value': query.value,
            'fuzzy': query.fuzzy,
          }),
          MessageDto.fromJson,
        );
        final selected = query.findAll ? values : values.take(1).toList();
        return PaginationUtils.paginate(
          selected,
          offset: query.pagination?.offset ?? 0,
          count: query.pagination?.count ?? selected.length,
        ).data;
      });
  @override
  Future<Result<UserDto>> getCurrentUser() => _run(() async {
    final config = configService;
    return UserDto(
      id: config.currentUser.id,
      name: config.currentUser.username,
      avatarPath: config.currentUserAvatarPath,
    );
  });
  @override
  Future<Result<UserDto?>> getAIUser() =>
      _run(() async => (await _users()).where((user) => user.isAI).firstOrNull);
  Future<List<UserDto>> _users() async {
    final result = await _call('getUsers') as Map;
    return (result['users'] as List? ?? [])
        .map((user) => UserDto.fromJson(Map<String, dynamic>.from(user as Map)))
        .toList();
  }

  @override
  Future<Result<List<UserDto>>> getUsers() => _run(_users);
}
