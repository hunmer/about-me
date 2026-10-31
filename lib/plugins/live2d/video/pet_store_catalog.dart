/// 宠物商店目录（catalog）解析与 URL 规则。
///
/// 商店目录约定：
/// - 目录入口 `<baseUrl>pets.json` 返回 `{schemaVersion: 1, pets: [...]}`；
/// - 每个宠物的 cover / manifest / actions 均为相对商店根的路径，
///   解析后统一返回绝对 http(s) URL；
/// - 出于安全考虑，目录内出现的绝对 http(s) 链接必须与商店同源，
///   其余 scheme 一律拒绝（data: 允许原样保留，用于内联小图）。
library;

/// 内置 pets-store 的默认地址（PET_STORE_URL 未覆盖时使用）。
///
/// 内置 manifest 的 `storeActionsUrl` 元数据引用的就是这个地址；当
/// `PET_STORE_URL` 指向局域网地址时，商店服务只对这个已知默认 origin
/// 做重基（不放宽任意跨源 URL）。
const String kDefaultPetStoreBaseUrl = 'http://127.0.0.1:8765/';

/// manifest.metadata 中记录商店宠物 id 的键。
const String kPetStoreMetadataPetId = 'storePetId';

/// manifest.metadata 中记录商店动作列表 URL 的键。
const String kPetStoreMetadataActionsUrl = 'storeActionsUrl';

/// 宠物商店目录中的单个宠物条目。
///
/// 所有 URL 字段均为解析后的绝对 http(s) 地址。
class PetStoreEntry {
  /// 创建目录条目。
  const PetStoreEntry({
    required this.id,
    required this.name,
    required this.description,
    required this.coverUrl,
    required this.manifestUrl,
    required this.actionsUrl,
  });

  /// 宠物唯一 id（如 `dsh-pet`）。
  final String id;

  /// 展示名称。
  final String name;

  /// 介绍文案。
  final String description;

  /// 封面图绝对 URL。
  final String coverUrl;

  /// 基础动作 manifest 绝对 URL。
  final String manifestUrl;

  /// 动作列表绝对 URL。
  final String actionsUrl;

  @override
  bool operator ==(Object other) =>
      other is PetStoreEntry &&
      other.id == id &&
      other.name == name &&
      other.description == description &&
      other.coverUrl == coverUrl &&
      other.manifestUrl == manifestUrl &&
      other.actionsUrl == actionsUrl;

  @override
  int get hashCode =>
      Object.hash(id, name, description, coverUrl, manifestUrl, actionsUrl);

  @override
  String toString() =>
      'PetStoreEntry($id, $name, manifest: $manifestUrl, actions: $actionsUrl)';
}

/// 规范化商店基地址：必须是带 host 的 http(s) URL，自动补尾部斜杠。
Uri normalizeStoreBaseUrl(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    throw const FormatException('宠物商店地址不能为空');
  }
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.isScheme('HTTP') && !uri.isScheme('HTTPS')) {
    throw FormatException('宠物商店地址必须是 http(s) URL：$raw');
  }
  if (!uri.hasAuthority || uri.host.isEmpty) {
    throw FormatException('宠物商店地址缺少主机名：$raw');
  }
  if (trimmed.endsWith('/') || uri.path.isEmpty || trimmed.endsWith('=')) {
    return uri;
  }
  // 无路径或路径不以 / 结尾时补齐，保证相对路径按目录解析。
  return uri.replace(path: '${uri.path}/');
}

/// 解析目录里的一条 URL 字段。
///
/// - `data:` 内联资源原样保留（不参与同源判断）；
/// - 其余一律先按 [baseUri] 解析为绝对地址，再校验 http(s) 且与商店
///   同源（scheme + host + port 全一致）——这样 `//evil/x` 这类协议相对
///   URL、跨源绝对链接、file: 等其它协议都会被拒绝。
Uri resolveStoreUrl(String raw, Uri baseUri, String label) {
  final parsed = Uri.tryParse(raw);
  if (parsed == null) {
    throw FormatException('宠物商店 $label 地址无效：$raw');
  }
  if (parsed.isScheme('data')) {
    // data: URI 直接放行（不参与同源判断）。
    return parsed;
  }
  final resolved = baseUri.resolve(raw);
  if (!resolved.isScheme('HTTP') && !resolved.isScheme('HTTPS')) {
    throw FormatException('宠物商店 $label 不支持的协议：$raw');
  }
  if (resolved.scheme != baseUri.scheme ||
      resolved.host != baseUri.host ||
      resolved.port != baseUri.port) {
    throw FormatException('宠物商店 $label 指向了商店以外的服务器：$raw');
  }
  return resolved;
}

/// 解析 pets.json 顶层 JSON 为条目列表。
///
/// 结构约束：`schemaVersion == 1`，`pets` 为数组，每项含必填的
/// id / name / description 字符串与 cover / manifest / actions URL。
List<PetStoreEntry> parsePetStoreCatalog(Object? json, Uri catalogUri) {
  if (json is! Map) {
    throw const FormatException('宠物商店目录格式无效：顶层必须是 JSON 对象');
  }
  final schemaVersion = json['schemaVersion'];
  if (schemaVersion != 1) {
    throw FormatException('宠物商店目录 schemaVersion 不支持：$schemaVersion');
  }
  final pets = json['pets'];
  if (pets is! List) {
    throw const FormatException('宠物商店目录缺少 pets 数组');
  }
  final entries = <PetStoreEntry>[];
  for (final (index, item) in pets.indexed) {
    if (item is! Map) {
      throw FormatException('宠物商店目录 pets[$index] 必须是对象');
    }
    String requireString(String key) {
      final value = item[key];
      if (value is! String || value.isEmpty) {
        throw FormatException('宠物商店目录 pets[$index].$key 必须是非空字符串');
      }
      return value;
    }

    final id = requireString('id');
    final name = requireString('name');
    final description = requireString('description');
    // pets.json 所在目录（含尾斜杠），cover/manifest/actions 相对它解析。
    final root = catalogUri.resolve('.');
    entries.add(PetStoreEntry(
      id: id,
      name: name,
      description: description,
      coverUrl: resolveStoreUrl(requireString('cover'), root, '封面图')
          .toString(),
      manifestUrl: resolveStoreUrl(requireString('manifest'), root, 'manifest')
          .toString(),
      actionsUrl: resolveStoreUrl(requireString('actions'), root, '动作列表')
          .toString(),
    ));
  }
  return entries;
}

