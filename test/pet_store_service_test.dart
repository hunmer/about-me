import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aboutme/plugins/live2d/video/pet_store_catalog.dart';
import 'package:aboutme/plugins/live2d/video/pet_store_service.dart';
import 'package:aboutme/plugins/live2d/video/video_pet_import.dart';
import 'package:aboutme/plugins/live2d/video/video_pet_manifest.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
// 测试内直接实现 PathProviderPlatform 以将持久化指向临时目录；
// 该接口包由 path_provider 传递依赖提供，不为此扩大 pubspec 依赖。
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final tempDir = Directory.systemTemp.createTempSync('pet_store_test');
  late _FakeStore store;

  setUpAll(() async {
    store = _FakeStore(_buildStoreFiles());
  });

  tearDownAll(() async {
    tempDir.deleteSync(recursive: true);
  });

  setUp(() {
    PathProviderPlatform.instance = _TemporaryPaths(tempDir);
  });

  tearDown(() {
    PathProviderPlatform.instance = _originalPaths;
  });

  PetStoreService serviceFor(Uri base) => PetStoreService(
    baseUrl: base.toString(),
    client: store.client,
    persistToDisk: true,
  );

  group('目录解析与 URL 安全', () {
    test('fetchPets 将相对路径解析为商店根下的绝对 URL', () async {
      final pets = await serviceFor(store.root).fetchPets();
      expect(pets, hasLength(1));
      final pet = pets.single;
      expect(pet.id, 'dsh-pet');
      expect(pet.name, '蓝毛小女仆');
      expect(
        pet.manifestUrl,
        store.root.resolve('pets/dsh/manifest.json').toString(),
      );
      expect(
        pet.actionsUrl,
        store.root.resolve('pets/dsh/actions.json').toString(),
      );
      expect(
        pet.coverUrl,
        store.root.resolve('pets/dsh/cover.webp').toString(),
      );
    });

    test('子目录商店：pets.json 不在根路径时相对路径不丢前缀', () async {
      final pets = await serviceFor(store.root.resolve('shop/')).fetchPets();
      expect(
        pets.single.manifestUrl,
        store.root.resolve('shop/pets/dsh/manifest.json').toString(),
      );
    });

    test('schemaVersion 不支持时拒绝', () async {
      store.files['/pets.json'] = _json({'schemaVersion': 2, 'pets': []});
      try {
        await serviceFor(store.root).fetchPets();
        fail('应当抛出 FormatException');
      } on FormatException catch (error) {
        expect(error.message, contains('schemaVersion'));
      } finally {
        store.files['/pets.json'] = _buildStoreFiles()['/pets.json']!;
      }
    });

    test('缺少 pets 数组时拒绝', () async {
      store.files['/pets.json'] = _json({'schemaVersion': 1});
      try {
        await serviceFor(store.root).fetchPets();
        fail('应当抛出 FormatException');
      } on FormatException catch (error) {
        expect(error.message, contains('pets'));
      } finally {
        store.files['/pets.json'] = _buildStoreFiles()['/pets.json']!;
      }
    });

    test('目录指向商店以外服务器时拒绝（协议相对/绝对/file）', () async {
      for (final evil in [
        '//evil.example/manifest.json',
        'http://evil.example/manifest.json',
        'file:///etc/passwd',
      ]) {
        store.files['/pets.json'] = _json({
          'schemaVersion': 1,
          'pets': [
            {
              'id': 'dsh-pet',
              'name': 'x',
              'description': 'x',
              'cover': 'pets/dsh/cover.webp',
              'manifest': evil,
              'actions': 'pets/dsh/actions.json',
            },
          ],
        });
        try {
          await serviceFor(store.root).fetchPets();
          fail('应当抛出 FormatException: $evil');
        } on FormatException catch (error) {
          expect(
            error.message,
            anyOf(contains('协议'), contains('以外')),
            reason: evil,
          );
        }
      }
      store.files['/pets.json'] = _buildStoreFiles()['/pets.json']!;
    });
  });

  group('HTTP 错误处理', () {
    test('目录 404 / manifest 500 / 资源 404 都抛 FormatException', () async {
      final service = serviceFor(store.root);
      final pets = await service.fetchPets();

      store.files.remove('/pets.json');
      try {
        await service.fetchPets();
        fail('应当抛出 FormatException');
      } on FormatException catch (error) {
        expect(error.message, contains('HTTP 404'));
      }
      store.files['/pets.json'] = _buildStoreFiles()['/pets.json']!;

      store.failing.add('/pets/dsh/manifest.json');
      try {
        await service.installPet(pets.single);
        fail('应当抛出 FormatException');
      } on FormatException catch (error) {
        expect(error.message, contains('HTTP 500'));
      }
      store.failing.remove('/pets/dsh/manifest.json');

      store.files.remove('/pets/dsh/螃蟹走路.webp');
      try {
        await service.installPet(pets.single);
        fail('应当抛出 FormatException');
      } on FormatException catch (error) {
        expect(error.message, contains('HTTP 404'));
      }
      store.files['/pets/dsh/螃蟹走路.webp'] = _webp('螃蟹走路');
    });
  });

  group('installPet 安装与持久化', () {
    test('下载全部资源真实落盘且 manifest 自包含', () async {
      final service = serviceFor(store.root);
      final pet = (await service.fetchPets()).single;
      final package = await service.installPet(pet);

      expect(package.baseUri, startsWith('file://'));
      final base = Uri.parse(package.baseUri);
      expect(File.fromUri(base.resolve('manifest.json')).existsSync(), isTrue);
      expect(
        File.fromUri(base.resolve('media/0.webp')).readAsBytesSync(),
        _webp('螃蟹走路'),
      );
      expect(
        File.fromUri(base.resolve('media/1.webp')).readAsBytesSync(),
        _webp('待机呼吸休闲'),
      );

      final manifest = package.manifest;
      expect(manifest.id, 'dsh-pet');
      expect(manifest.animations, hasLength(2));
      expect(manifest.metadata[kPetStoreMetadataPetId], 'dsh-pet');
      expect(manifest.metadata[kPetStoreMetadataActionsUrl], pet.actionsUrl);
      for (final animation in manifest.animations) {
        final source = animation.imageSource!;
        expect(source, startsWith('file://'));
        expect(File.fromUri(Uri.parse(source)).existsSync(), isTrue);
      }
      // 运行时 manifest 通过 toJson/fromJson 往返后依旧有效。
      final roundTrip = VideoPetManifest.fromJson(
        jsonDecode(jsonEncode(manifest.toJson())) as Map<String, dynamic>,
      );
      roundTrip.validate();
      expect(roundTrip.animations, hasLength(2));

      service.close();
    });

    test('persistToDisk=false 时源退化为 data URI', () async {
      final service = PetStoreService(
        baseUrl: store.root.toString(),
        client: store.client,
        persistToDisk: false,
      );
      final pet = (await service.fetchPets()).single;
      final package = await service.installPet(pet);
      expect(package.baseUri, pet.manifestUrl);
      for (final animation in package.manifest.animations) {
        expect(animation.imageSource, startsWith('data:image/webp'));
      }
      service.close();
    });

    test('多个动作引用同一源文件时去重下载', () async {
      final root = store.root;
      final manifestJson = _storeManifestJson(root);
      // 让两个动作共用同一张精灵图。
      (manifestJson['animations'] as List)[1]['sources'] = {
        'webp': '螃蟹走路.webp',
      };
      store.files['/pets/dsh/manifest.json'] = _json(manifestJson);
      final service = serviceFor(root);
      final pet = (await service.fetchPets()).single;
      final hitsBefore = store.hits['/pets/dsh/螃蟹走路.webp'] ?? 0;
      final package = await service.installPet(pet);
      final mediaDir = Directory.fromUri(
        Uri.parse(package.baseUri).resolve('media'),
      );
      expect(mediaDir.listSync(), hasLength(1));
      expect(store.hits['/pets/dsh/螃蟹走路.webp'], hitsBefore + 1);
      service.close();
      store.files['/pets/dsh/manifest.json'] =
          _buildStoreFiles()['/pets/dsh/manifest.json']!;
    });
  });

  group('prepareForPlayback 兼容', () {
    test('商店安装包不做内置刷新，动作与源保持原样', () async {
      final service = serviceFor(store.root);
      final pet = (await service.fetchPets()).single;
      final package = await service.installPet(pet);
      final prepared = await const VideoPetImportService().prepareForPlayback(
        package.manifest,
        baseUri: package.baseUri,
      );
      expect(prepared.manifest.animations, hasLength(2));
      for (final animation in prepared.manifest.animations) {
        expect(animation.imageSource, startsWith('file://'));
      }
      // 未持久化形态（baseUri 缺失）同样不得按内置 assets 刷新。
      final bare = await const VideoPetImportService().prepareForPlayback(
        package.manifest,
      );
      expect(bare.manifest.animations, hasLength(2));
      service.close();
    });

    test('商店包 id 为 dsh-pet 时也跳过内置刷新与 additions 注入', () async {
      final service = serviceFor(store.root);
      final pet = (await service.fetchPets()).single;
      final package = await service.installPet(pet);
      // 安装后的存档形态：源为绝对 file URI。即便 id 与内置 dsh-pet 相同，
      // 也不得按内置刷新或注入 bundledAdditions（否则会涌入 16 个新动作）。
      expect(isStorePetManifest(package.manifest), isTrue);
      final bare = await const VideoPetImportService().prepareForPlayback(
        package.manifest,
        baseUri: null,
      );
      expect(bare.manifest.animations, hasLength(2));
      for (final animation in bare.manifest.animations) {
        expect(animation.imageSource, startsWith('file://'));
      }
      service.close();
    });

    test('旧档案迁移时补齐内置默认的商店关联 metadata', () async {
      // 真实内置 assets manifest 自带 storePetId / storeActionsUrl；
      // 旧存档（metadata 为空）迁移后应补齐，否则无法解锁动作下载。
      const service = VideoPetImportService();
      final defaults = await service.loadDefault();
      final archive = defaults.manifest.copyWith(metadata: const {});
      final prepared = await service.prepareForPlayback(archive);
      expect(
        prepared.manifest.metadata[kPetStoreMetadataPetId],
        defaults.manifest.metadata[kPetStoreMetadataPetId],
      );
      expect(
        prepared.manifest.metadata[kPetStoreMetadataActionsUrl],
        defaults.manifest.metadata[kPetStoreMetadataActionsUrl],
      );
    });

    test('内置包降级：丢失动作被丢弃且引用被剪枝', () async {
      final service = _DegradeImportService(_fakeDefaultsManifest());
      final archive = VideoPetManifest.fromJson(_legacyArchiveJson());
      final prepared = await service.prepareForPlayback(archive);
      final manifest = prepared.manifest;

      // 东张西望（资产已迁出且源不可寻）被丢弃；螃蟹走路来自 defaults；
      // 旧扩展（源仍存在于内置 assets）保留原源。
      final ids = manifest.animations.map((a) => a.id).toList();
      expect(ids, containsAll(['螃蟹走路', '旧扩展']));
      expect(ids, isNot(contains('东张西望')));
      final legacy = manifest.animations.singleWhere((a) => a.id == '旧扩展');
      expect(legacy.imageSource, 'spritesheet/螃蟹走路.webp');
      // idle 引用被剪枝到首个保留动作。
      expect(manifest.idleAnimationId, '螃蟹走路');
      // hover/region 引用剪枝后为空（合法禁用）。
      expect(manifest.hover.animationIds, isEmpty);
      expect(manifest.regions.single.click!.animationIds, isEmpty);
      // movement 失效引用清空，有效引用保留。
      expect(manifest.movement.turnLeftAnimationId, isEmpty);
      expect(manifest.movement.leftAnimationId, '螃蟹走路');
      manifest.validate();
    });

    test('内置包自带绝对源的扩展动作原样保留', () async {
      final service = _DegradeImportService(_fakeDefaultsManifest());
      final archive = VideoPetManifest.fromJson(
        _legacyArchiveJson(extraAbsolute: true),
      );
      final prepared = await service.prepareForPlayback(archive);
      final extra = prepared.manifest.animations.singleWhere(
        (a) => a.id == '绝对源动作',
      );
      expect(extra.imageSource, startsWith('data:image/webp'));
    });

    test('内置包所有动作缺失资源时抛出降级失败', () async {
      final service = _DegradeImportService(_fakeDefaultsManifest());
      final archive = VideoPetManifest.fromJson(
        _legacyArchiveJson(onlyGhost: true),
      );
      try {
        await service.prepareForPlayback(archive);
        fail('应当抛出 FormatException');
      } on FormatException catch (error) {
        expect(error.message, contains('降级'));
      }
    });
  });

  group('fetchActions 与 downloadAction', () {
    test('fetchActions 返回源绝对化且校验 petId 的动作列表', () async {
      final service = serviceFor(store.root);
      final pet = (await service.fetchPets()).single;
      final package = await service.installPet(pet);
      final actions = await service.fetchActions(package.manifest);

      expect(actions, hasLength(2));
      final work = actions.singleWhere((a) => a.id == '工作加班');
      expect(
        work.imageSource,
        store.root.resolve('pets/dsh/工作加班.webp').toString(),
      );
      expect(
        work.audio,
        store.root.resolve('pets/dsh/audio/加班.m4a').toString(),
      );

      // petId 不匹配时拒绝。
      store.files['/pets/dsh/actions.json'] = _json({
        'schemaVersion': 1,
        'petId': 'other-pet',
        'animations': [_animationJson('工作加班', '工作状态')],
      });
      try {
        await service.fetchActions(package.manifest);
        fail('应当抛出 FormatException');
      } on FormatException catch (error) {
        expect(error.message, contains('不匹配'));
      } finally {
        store.files['/pets/dsh/actions.json'] =
            _buildStoreFiles()['/pets/dsh/actions.json']!;
      }
      service.close();
    });

    test('metadata 缺少商店关联时 fetchActions 拒绝', () async {
      final manifestJson = _storeManifestJson(store.root);
      (manifestJson as Map)['metadata'] = {};
      final manifest = VideoPetManifest.fromJson(manifestJson);
      try {
        await serviceFor(store.root).fetchActions(manifest);
        fail('应当抛出 FormatException');
      } on FormatException catch (error) {
        expect(error.message, contains('未关联'));
      }
    });

    test('fetchLatestActions 优先目录条目的最新动作地址', () async {
      final service = serviceFor(store.root);
      final pet = (await service.fetchPets()).single;
      final package = await service.installPet(pet);
      // 商店目录把动作列表挪到新地址（metadata 里仍是安装时的旧地址）。
      store.files['/pets/dsh/actions-v2.json'] = _json({
        'schemaVersion': 1,
        'petId': 'dsh-pet',
        'animations': [_animationJson('新动作', '扩展')],
      });
      store.files['/pets/dsh/新动作.webp'] = _webp('新动作');
      store.files['/pets.json'] = _json({
        'schemaVersion': 1,
        'pets': [
          {
            'id': 'dsh-pet',
            'name': '蓝毛小女仆',
            'description': '测试用商店宠物',
            'cover': 'pets/dsh/cover.webp',
            'manifest': 'pets/dsh/manifest.json',
            'actions': 'pets/dsh/actions-v2.json',
          },
        ],
      });
      try {
        final actions = await service.fetchLatestActions(package.manifest);
        expect(actions.map((a) => a.id), ['新动作']);
        expect(
          actions.single.imageSource,
          store.root.resolve('pets/dsh/新动作.webp').toString(),
        );
      } finally {
        store.files['/pets.json'] = _buildStoreFiles()['/pets.json']!;
        store.files.remove('/pets/dsh/actions-v2.json');
        store.files.remove('/pets/dsh/新动作.webp');
      }
      service.close();
    });

    test('目录不可用时 fetchLatestActions 回退 metadata 地址', () async {
      final service = serviceFor(store.root);
      final pet = (await service.fetchPets()).single;
      final package = await service.installPet(pet);
      final original = store.files['/pets.json']!;
      store.files['/pets.json'] = _json({'schemaVersion': 2, 'pets': []});
      try {
        final actions = await service.fetchLatestActions(package.manifest);
        expect(actions, hasLength(2));
      } finally {
        store.files['/pets.json'] = original;
      }
      service.close();
    });

    test('downloadAction 落盘动作与音频并加入 manifest', () async {
      final service = serviceFor(store.root);
      final pet = (await service.fetchPets()).single;
      var package = await service.installPet(pet);
      final work = (await service.fetchActions(
        package.manifest,
      )).singleWhere((a) => a.id == '工作加班');

      package = await service.downloadAction(package: package, animation: work);
      expect(package.manifest.animations, hasLength(3));
      final added = package.manifest.animations.singleWhere(
        (a) => a.id == '工作加班',
      );
      expect(added.imageSource, startsWith('file://'));
      expect(added.audio, startsWith('file://'));
      // 下载 ≠ 启用：新动作默认不参与 Jev 自动动作决策
      expect(added.enabled, isFalse);
      final storeDir = Directory.fromUri(
        Uri.parse(package.baseUri).resolve('store'),
      );
      // 单次下载的所有文件落在同一个 UUID 子目录内。
      final batchDirs = storeDir.listSync();
      expect(batchDirs, hasLength(1));
      expect(Directory.fromUri(batchDirs.single.uri).listSync(), hasLength(2));

      // 追加后的 manifest 保存/加载往返仍有效。
      final roundTrip = VideoPetManifest.fromJson(
        jsonDecode(jsonEncode(package.manifest.toJson()))
            as Map<String, dynamic>,
      );
      roundTrip.validate();
      expect(roundTrip.animations, hasLength(3));
      service.close();
    });

    test('downloadAction 幂等：重复下载不发起请求也不改 manifest', () async {
      final service = serviceFor(store.root);
      final pet = (await service.fetchPets()).single;
      var package = await service.installPet(pet);
      final work = (await service.fetchActions(
        package.manifest,
      )).singleWhere((a) => a.id == '工作加班');
      package = await service.downloadAction(package: package, animation: work);
      final hitsBefore = store.hits['/pets/dsh/工作加班.webp'];

      final again = await service.downloadAction(
        package: package,
        animation: work,
      );
      expect(again, same(package));
      expect(again.manifest.animations, hasLength(3));
      expect(store.hits['/pets/dsh/工作加班.webp'], hitsBefore);
      service.close();
    });

    test('未持久化包上 downloadAction 退化为 data URI 源', () async {
      final service = PetStoreService(
        baseUrl: store.root.toString(),
        client: store.client,
        persistToDisk: false,
      );
      final pet = (await service.fetchPets()).single;
      var package = await service.installPet(pet);
      final work = (await service.fetchActions(
        package.manifest,
      )).singleWhere((a) => a.id == '工作加班');
      package = await service.downloadAction(package: package, animation: work);
      final added = package.manifest.animations.singleWhere(
        (a) => a.id == '工作加班',
      );
      expect(added.imageSource, startsWith('data:image/webp'));
      expect(added.audio, startsWith('data:audio'));
      package.manifest.validate();
      service.close();
    });

    test('连续下载两个不同动作互不覆盖且字节保持', () async {
      final service = serviceFor(store.root);
      final pet = (await service.fetchPets()).single;
      var package = await service.installPet(pet);
      final actions = await service.fetchActions(package.manifest);
      final work = actions.singleWhere((a) => a.id == '工作加班');
      final look = actions.singleWhere((a) => a.id == '东张西望');

      package = await service.downloadAction(package: package, animation: work);
      final workSource = package.manifest.animations
          .singleWhere((a) => a.id == '工作加班')
          .imageSource!;
      final workBytes = File.fromUri(Uri.parse(workSource)).readAsBytesSync();
      expect(workBytes, _webp('工作加班'));

      package = await service.downloadAction(package: package, animation: look);
      final lookSource = package.manifest.animations
          .singleWhere((a) => a.id == '东张西望')
          .imageSource!;
      expect(
        File.fromUri(Uri.parse(lookSource)).readAsBytesSync(),
        _webp('东张西望'),
      );
      // 第二次下载后，第一个动作的文件字节保持不变（未被覆盖）。
      expect(File.fromUri(Uri.parse(workSource)).readAsBytesSync(), workBytes);
      // 两次下载落在不同的 UUID 子目录。
      expect(
        Uri.parse(workSource).resolve('.').toString(),
        isNot(Uri.parse(lookSource).resolve('.').toString()),
      );
      service.close();
    });

    test('PET_STORE_URL 指向局域网时内置默认动作地址重基到当前商店', () async {
      final service = PetStoreService(
        baseUrl: 'http://192.168.1.5:8765/',
        client: store.client,
        persistToDisk: false,
      );
      // 旧档案迁移携带的是内置默认（127.0.0.1）的 actionsUrl。
      final manifest = VideoPetManifest.fromJson(
        _storeManifestJson(Uri.parse('http://127.0.0.1:8765/')),
      );
      final actions = await service.fetchActions(manifest);
      final work = actions.singleWhere((a) => a.id == '工作加班');
      expect(
        work.imageSource,
        Uri.parse(
          'http://192.168.1.5:8765/',
        ).resolve('pets/dsh/工作加班.webp').toString(),
      );
      // 一般跨源 URL 仍然拒绝（重基机制不放宽任意跨源）。
      final evil = VideoPetManifest.fromJson(
        _storeManifestJson(Uri.parse('http://evil.example/')),
      );
      try {
        await service.fetchActions(evil);
        fail('应当抛出 FormatException');
      } on FormatException catch (error) {
        expect(error.message, contains('以外'));
      }
      service.close();
    });

    test('GitHub Raw 重基保留仓库路径前缀', () async {
      final root = Uri.parse(kProductionPetStoreBaseUrl);
      final service = PetStoreService(
        baseUrl: root.toString(),
        client: MockClient((request) async {
          expect(request.url, root.resolve('pets/dsh/actions.json'));
          return http.Response.bytes(
            _buildStoreFiles()['/pets/dsh/actions.json']!,
            200,
          );
        }),
        persistToDisk: false,
      );
      addTearDown(service.close);
      final manifest = VideoPetManifest.fromJson(
        _storeManifestJson(Uri.parse(kDefaultPetStoreBaseUrl)),
      );
      final actions = await service.fetchActions(manifest);
      expect(
        actions.singleWhere((a) => a.id == '工作加班').imageSource,
        root.resolve('pets/dsh/工作加班.webp').toString(),
      );
    });

    test('默认地址按构建模式选择且可显式覆盖', () {
      final service = PetStoreService();
      addTearDown(service.close);
      expect(
        service.baseUrl.toString(),
        const String.fromEnvironment(
          'PET_STORE_URL',
          defaultValue: bool.fromEnvironment('dart.vm.product')
              ? kProductionPetStoreBaseUrl
              : kDefaultPetStoreBaseUrl,
        ),
      );
      final override = PetStoreService(baseUrl: 'https://custom.example/pets/');
      addTearDown(override.close);
      expect(override.baseUrl.toString(), 'https://custom.example/pets/');
    });

    test('请求超时抛 FormatException 而非永久等待', () async {
      final service = PetStoreService(
        baseUrl: store.root.toString(),
        client: MockClient((_) => Completer<http.Response>().future),
        requestTimeout: const Duration(milliseconds: 50),
      );
      try {
        await service.fetchPets();
        fail('应当抛出 FormatException');
      } on FormatException catch (error) {
        expect(error.message, contains('超时'));
      }
      service.close();
    });
  });
}

/// 本地假商店：注入式 http.Client（MockClient），文件表 + 命中计数 +
/// 可注入失败路径。
///
/// 注：flutter_tester 的 socket 层在本机被环境代理拦截（一律 400），
/// 因此用 MockClient 模拟商店响应；URL 解析/同源校验逻辑全在客户端
/// 侧，覆盖不受影响。持久化仍走真实文件系统（path_provider mock）。
class _FakeStore {
  _FakeStore(this.files);

  final Map<String, Uint8List> files;
  final Map<String, int> hits = {};
  final Set<String> failing = {};

  final Uri root = Uri.parse('http://pet-store.test/');

  http.Client get client => MockClient((request) async {
    final path = Uri.decodeComponent(request.url.path);
    hits[path] = (hits[path] ?? 0) + 1;
    if (failing.contains(path)) {
      return http.Response('', 500);
    }
    final body = files[path];
    if (body == null) {
      return http.Response('', 404);
    }
    return http.Response.bytes(body, 200);
  });
}

final PathProviderPlatform _originalPaths = PathProviderPlatform.instance;

class _TemporaryPaths extends PathProviderPlatform {
  _TemporaryPaths(this.directory);

  final Directory directory;

  @override
  Future<String?> getApplicationSupportPath() async => directory.path;
}

/// 注入假内置 defaults 的导入服务（persistToDisk=false，测降级逻辑）。
class _DegradeImportService extends VideoPetImportService {
  _DegradeImportService(this.defaults) : super(persistToDisk: false);

  final VideoPetManifest defaults;

  @override
  Future<VideoPetPackage> loadDefault() async => VideoPetPackage(
    manifest: defaults,
    baseUri: Uri.parse(kDefaultVideoPetManifestAsset).resolve('.').toString(),
  );
}

Uint8List _json(Object json) =>
    Uint8List.fromList(utf8.encode(jsonEncode(json)));

Uint8List _webp(String name) =>
    Uint8List.fromList(utf8.encode('webp-of-$name'));

Map<String, Uint8List> _buildStoreFiles() => {
  '/pets.json': _json({
    'schemaVersion': 1,
    'pets': [
      {
        'id': 'dsh-pet',
        'name': '蓝毛小女仆',
        'description': '测试用商店宠物',
        'cover': 'pets/dsh/cover.webp',
        'manifest': 'pets/dsh/manifest.json',
        'actions': 'pets/dsh/actions.json',
      },
    ],
  }),
  '/shop/pets.json': _json({
    'schemaVersion': 1,
    'pets': [
      {
        'id': 'dsh-pet',
        'name': '蓝毛小女仆',
        'description': '子目录商店测试',
        'cover': 'pets/dsh/cover.webp',
        'manifest': 'pets/dsh/manifest.json',
        'actions': 'pets/dsh/actions.json',
      },
    ],
  }),
  '/pets/dsh/manifest.json': _json(_storeManifestJson(null)),
  '/pets/dsh/actions.json': _json({
    'schemaVersion': 1,
    'petId': 'dsh-pet',
    'animations': [
      _animationJson('工作加班', '工作状态', audio: 'audio/加班.m4a'),
      _animationJson('东张西望', '转向'),
    ],
  }),
  '/pets/dsh/cover.webp': _webp('cover'),
  '/pets/dsh/螃蟹走路.webp': _webp('螃蟹走路'),
  '/pets/dsh/待机呼吸休闲.webp': _webp('待机呼吸休闲'),
  '/pets/dsh/工作加班.webp': _webp('工作加班'),
  '/pets/dsh/东张西望.webp': _webp('东张西望'),
  '/pets/dsh/audio/加班.m4a': Uint8List.fromList(utf8.encode('m4a-of-加班')),
};

/// 商店 manifest fixture；[root] 非空时写入绝对的 actionsUrl，否则占位。
Map<String, dynamic> _storeManifestJson(Uri? root) => {
  'schemaVersion': 1,
  'id': 'dsh-pet',
  'name': '蓝毛小女仆',
  'canvasWidth': 640,
  'canvasHeight': 360,
  'animations': [_animationJson('螃蟹走路', '移动'), _animationJson('待机呼吸休闲', '待机')],
  'idleAnimationId': '待机呼吸休闲',
  'hover': {'animationIds': [], 'strategy': 'random'},
  'click': {'animationIds': [], 'strategy': 'random'},
  'movement': {
    'leftAnimationId': '螃蟹走路',
    'rightAnimationId': '螃蟹走路',
    'dragAnimationId': '',
    'speed': 40,
    'minIdleSeconds': 10,
    'maxIdleSeconds': 10,
  },
  'regions': [],
  'metadata': {
    'storePetId': 'dsh-pet',
    'storeActionsUrl': root == null
        ? 'http://127.0.0.1:1/pets/dsh/actions.json'
        : root.resolve('pets/dsh/actions.json').toString(),
  },
};

Map<String, dynamic> _animationJson(
  String name,
  String category, {
  String? audio,
  String? source,
  String facing = '',
}) => {
  'id': name,
  'name': name,
  'category': category,
  'facing': facing,
  'sources': {'webp': source ?? '$name.webp'},
  'spritesheet': {
    'frameWidth': 640,
    'frameHeight': 360,
    'columns': 8,
    'rows': 15,
    'frameCount': 120,
    'fps': 12,
  },
  if (audio != null) 'audio': audio,
};

/// 假内置 defaults：两个动作（spritesheet 源指向真实存在的内置资产）。
VideoPetManifest _fakeDefaultsManifest() => VideoPetManifest.fromJson({
  'schemaVersion': 1,
  'id': 'dsh-pet',
  'name': '蓝毛小女仆',
  'canvasWidth': 640,
  'canvasHeight': 360,
  'animations': [
    _animationJson('螃蟹走路', '移动', source: 'spritesheet/螃蟹走路.webp'),
    _animationJson('待机呼吸休闲', '待机', source: 'spritesheet/待机呼吸休闲.webp'),
  ],
  'idleAnimationId': '待机呼吸休闲',
  'hover': {'animationIds': [], 'strategy': 'random'},
  'click': {'animationIds': [], 'strategy': 'random'},
  'movement': {
    'leftAnimationId': '螃蟹走路',
    'rightAnimationId': '螃蟹走路',
    'dragAnimationId': '',
    'speed': 40,
    'minIdleSeconds': 10,
    'maxIdleSeconds': 10,
  },
  'regions': [],
});

/// 旧存档 fixture：动作全部带合法 webp 相对源 + 精灵图（fromJson 需过
/// validate）。降级由「id 不在新 defaults 且源文件已迁出内置 assets」触发。
Map<String, dynamic> _legacyArchiveJson({
  bool extraAbsolute = false,
  bool onlyGhost = false,
}) {
  final animations = <Map<String, dynamic>>[
    if (!onlyGhost)
      _animationJson('螃蟹走路', '移动', source: 'spritesheet/螃蟹走路.webp'),
    _animationJson('东张西望', '转向', source: 'spritesheet/东张西望.webp'),
    if (!onlyGhost)
      _animationJson('旧扩展', '小动作', source: 'spritesheet/螃蟹走路.webp'),
    if (extraAbsolute)
      _animationJson(
        '绝对源动作',
        '小动作',
        source: 'data:image/webp;base64,${base64Encode(utf8.encode('abs'))}',
      ),
  ];
  return {
    'schemaVersion': 1,
    'id': 'dsh-pet',
    'name': '蓝毛小女仆',
    'canvasWidth': 640,
    'canvasHeight': 360,
    'animations': animations,
    'idleAnimationId': '东张西望',
    'hover': {
      'animationIds': ['东张西望'],
      'strategy': 'random',
    },
    'click': {'animationIds': [], 'strategy': 'random'},
    'movement': {
      'leftAnimationId': onlyGhost ? '' : '螃蟹走路',
      'rightAnimationId': onlyGhost ? '' : '螃蟹走路',
      'turnLeftAnimationId': onlyGhost ? '' : '东张西望',
      'turnRightAnimationId': '',
      'dragAnimationId': '',
      'speed': 40,
      'minIdleSeconds': 10,
      'maxIdleSeconds': 10,
    },
    'regions': [
      {
        'id': 'head',
        'name': '头部',
        'x': 0.4,
        'y': 0.2,
        'width': 0.2,
        'height': 0.2,
        'enabled': true,
        'priority': 0,
        'click': {
          'animationIds': ['东张西望'],
          'strategy': 'sequence',
        },
      },
    ],
  };
}
