import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/plugins/openai/models/service_provider.dart';
import 'package:aboutme/core/plugin_manager.dart';

class ServiceProviderController {
  List<ServiceProvider> providers = [];

  Future<List<ServiceProvider>> loadProviders() async {
    final plugin = PluginManager.instance.getPlugin('openai');
    if (plugin == null) return [];

    final res = await AboutmeDataService.instance.call(
      'openai',
      'getProviders',
    );
    final data = res['success'] == true ? res['data'] : null;
    if (data is Map && data.isNotEmpty) {
      final List<dynamic> jsonList = (data['providers'] ?? []) as List<dynamic>;
      providers =
          jsonList
              .map(
                (item) =>
                    ServiceProvider.fromJson(item as Map<String, dynamic>),
              )
              .toList();
    }
    return providers;
  }

  Future<void> saveProvider(ServiceProvider provider) async {
    final plugin = PluginManager.instance.getPlugin('openai');
    if (plugin == null) return;

    // Load existing providers
    await loadProviders();

    // Update or add the provider
    final index = providers.indexWhere((p) => p.label == provider.label);
    if (index >= 0) {
      providers[index] = provider;
    } else {
      providers.add(provider);
    }

    // Save all providers
    await _saveProvidersFile();
  }

  Future<void> deleteProvider(String providerName) async {
    final plugin = PluginManager.instance.getPlugin('openai');
    if (plugin == null) return;

    providers.removeWhere((provider) => provider.label == providerName);
    await _saveProvidersFile();
  }

  /// 全量写 providers.json（整文件替换，保持 {providers:[...]} 结构）
  Future<void> _saveProvidersFile() =>
      AboutmeDataService.instance.call('openai', 'saveProviders', {
        'providers': {
          'providers': providers.map((p) => p.toJson()).toList(),
        },
      });
}
