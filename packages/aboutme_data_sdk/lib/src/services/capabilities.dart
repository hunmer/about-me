import 'route_config.dart';
import '../legacy_write_policy.dart';

Map<String, dynamic> dataCapabilities() => {
  'protocolVersion': 1,
  'deployment': 'single-process',
  'mutationRetentionDays': 30,
  'assets': {'protocolVersion': 2, 'encoding': 'base64', 'maxBytes': 16 * 1024 * 1024,
    'chunked': {'maxBytes': 256 * 1024 * 1024, 'chunkBytes': 8 * 1024 * 1024},
    'migration': true, 'sweep': true},
  'migratedDomains': LegacyWritePolicy.migratedDomains,
  'protectedResources': ['assets', 'stickers/collections.json'],
  'actions': [
    for (final config in pluginRouteConfigs)
      for (final route in config.routes)
        {
          'actionId': '${config.pluginId}.${route.handler}',
          'method': route.method.toUpperCase(),
          'path': '/api/v1/plugins/${config.pluginId}${route.path}',
          'resource': route.resourceName,
          'capabilityVersion': route.capabilityVersion,
          'permission': route.permission,
          'requestModel': route.requestModel,
          'responseModel': route.responseModel,
        },
  ],
};
