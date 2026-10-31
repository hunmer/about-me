import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/live2d/models/live2d_archive.dart';
import 'package:aboutme/plugins/live2d/screens/live2d_store_screen.dart';
import 'package:aboutme/plugins/live2d/screens/video_pet_editor_screen.dart';
import 'package:aboutme/plugins/live2d/video/pet_store_catalog.dart';
import 'package:aboutme/plugins/live2d/video/pet_store_service.dart';
import 'package:aboutme/plugins/live2d/video/video_pet_import.dart';
import 'package:aboutme/plugins/live2d/video/video_pet_manifest.dart';
import 'package:aboutme/widgets/adaptive_image.dart';

/// 可控的宠物商店服务桩：覆写全部网络方法，不产生真实网络请求
class _FakePetStoreService extends PetStoreService {
  _FakePetStoreService({
    this.pets = const [],
    this.actions = const [],
    this.failPetsCount = 0,
    this.failInstallCount = 0,
    this.failActionsCount = 0,
    this.failDownloadCount = 0,
  });

  final List<PetStoreEntry> pets;
  final List<VideoPetAnimation> actions;
  int failPetsCount;
  int failInstallCount;
  int failActionsCount;
  int failDownloadCount;
  int fetchPetsCalls = 0;
  int installCalls = 0;
  int fetchActionsCalls = 0;
  int downloadCalls = 0;

  @override
  Future<List<PetStoreEntry>> fetchPets() async {
    fetchPetsCalls++;
    if (failPetsCount > 0) {
      failPetsCount--;
      throw const FormatException('目录暂时不可用');
    }
    return pets;
  }

  VideoPetManifest _installManifest(PetStoreEntry pet) => VideoPetManifest(
    id: pet.id,
    name: pet.name,
    animations: const [
      VideoPetAnimation(
        id: 'idle',
        name: '待机',
        sources: {'webp': 'file:///pets/idle.webp'},
        spritesheet: _sheet,
      ),
    ],
    idleAnimationId: 'idle',
    metadata: {
      kPetStoreMetadataPetId: pet.id,
      kPetStoreMetadataActionsUrl:
          'http://127.0.0.1:8765/pets/test/actions.json',
    },
  );

  @override
  Future<VideoPetPackage> installPet(PetStoreEntry pet) async {
    installCalls++;
    if (failInstallCount > 0) {
      failInstallCount--;
      throw const FormatException('安装失败（测试）');
    }
    return VideoPetPackage(
      manifest: _installManifest(pet),
      baseUri: 'file:///pets/',
    );
  }

  @override
  Future<List<VideoPetAnimation>> fetchActions(
    VideoPetManifest manifest,
  ) async {
    fetchActionsCalls++;
    if (failActionsCount > 0) {
      failActionsCount--;
      throw const FormatException('动作列表暂时不可用');
    }
    return actions;
  }

  @override
  Future<VideoPetPackage> downloadAction({
    required VideoPetPackage package,
    required VideoPetAnimation animation,
  }) async {
    downloadCalls++;
    if (failDownloadCount > 0) {
      failDownloadCount--;
      throw const FormatException('下载失败（测试）');
    }
    final resolved = animation.copyWith(
      sources: {'webp': 'file:///pets/${animation.id}.webp'},
    );
    return VideoPetPackage(
      manifest: package.manifest.copyWith(
        animations: [...package.manifest.animations, resolved],
      ),
      baseUri: package.baseUri,
      resolvedSources: package.resolvedSources,
    );
  }
}

const _testPets = [
  PetStoreEntry(
    id: 'pet1',
    name: '蓝毛小女仆',
    description: '内置 5 个基础动作',
    coverUrl: 'http://127.0.0.1:8765/pets/pet1/cover.webp',
    manifestUrl: 'http://127.0.0.1:8765/pets/pet1/manifest.json',
    actionsUrl: 'http://127.0.0.1:8765/pets/pet1/actions.json',
  ),
  PetStoreEntry(
    id: 'pet2',
    name: '橘猫助手',
    description: '会翻肚皮的猫',
    coverUrl: 'http://127.0.0.1:8765/pets/pet2/cover.webp',
    manifestUrl: 'http://127.0.0.1:8765/pets/pet2/manifest.json',
    actionsUrl: 'http://127.0.0.1:8765/pets/pet2/actions.json',
  ),
];

Widget _wrap(Widget child) =>
    MaterialApp(home: DSThemeBridge(child: Scaffold(body: child)));

/// 测试用精灵图网格元数据（640×360、8 列、12fps，与真实商店资源一致）
const _sheet = VideoPetSpritesheet(
  frameWidth: 640,
  frameHeight: 360,
  columns: 8,
  rows: 1,
  frameCount: 8,
  fps: 12,
);

void main() {
  group('Live2DStoreScreen 宠物商店', () {
    testWidgets('加载目录并展示宠物列表（名称/id/描述/封面）', (tester) async {
      final fake = _FakePetStoreService(pets: _testPets);
      await tester.pumpWidget(_wrap(Live2DStoreScreen(service: fake)));
      await tester.pumpAndSettle();

      expect(fake.fetchPetsCalls, 1);
      expect(
        find.byKey(const ValueKey('live2dStorePet_pet1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('live2dStorePet_pet2')),
        findsOneWidget,
      );
      // 名称与 id/描述
      expect(find.text('蓝毛小女仆'), findsOneWidget);
      expect(find.text('橘猫助手'), findsOneWidget);
      expect(find.textContaining('pet1'), findsWidgets);
      // 真实封面
      expect(find.byType(AdaptiveImage), findsNWidgets(2));
    });

    testWidgets('安装宠物后按钮变为编辑动画，档案走 upsert 注入', (tester) async {
      final fake = _FakePetStoreService(pets: _testPets);
      final persisted = <Live2DArchive>[];
      final installed = <String, Live2DArchive>{};
      await tester.pumpWidget(
        _wrap(
          Live2DStoreScreen(
            service: fake,
            findInstalledArchive: (petId) => installed[petId],
            persistArchive: (archive) async {
              final petId =
                  archive.videoManifest?.metadata[kPetStoreMetadataPetId] ??
                  archive.id;
              installed[petId] = archive;
              persisted.add(archive);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('live2dStoreInstallButton_pet1')),
      );
      await tester.pumpAndSettle();

      expect(fake.installCalls, 1);
      expect(persisted, hasLength(1));
      final archive = persisted.single;
      expect(archive.id, 'pet_store_pet1');
      expect(archive.displayMode, 'video');
      expect(archive.name, '蓝毛小女仆');
      expect(archive.videoManifest, isNotNull);
      expect(archive.videoManifest!.id, 'pet1');
      // 安装后：安装按钮消失，变为「编辑动画」
      expect(
        find.byKey(const ValueKey('live2dStoreEditButton_pet1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('live2dStoreInstallButton_pet1')),
        findsNothing,
      );
    });

    testWidgets('已安装宠物重进商店直接显示编辑且不再安装', (tester) async {
      final fake = _FakePetStoreService(pets: _testPets);
      // 预置已安装档案（模拟再次进入商店）
      final installed = <String, Live2DArchive>{
        'pet1': Live2DArchive(
          id: 'pet_store_pet1',
          name: '蓝毛小女仆',
          modelLabel: '',
          modelDir: '',
          modelFile: '',
          agentId: null,
          displayMode: 'video',
          videoManifest: VideoPetManifest(
            id: 'pet1',
            name: '蓝毛小女仆',
            metadata: const {
              kPetStoreMetadataPetId: 'pet1',
              kPetStoreMetadataActionsUrl:
                  'http://127.0.0.1:8765/pets/pet1/actions.json',
            },
          ),
        ),
      };
      await tester.pumpWidget(
        _wrap(
          Live2DStoreScreen(
            service: fake,
            findInstalledArchive: (petId) => installed[petId],
            persistArchive: (archive) async => installed[archive.id] = archive,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // pet1 直接是编辑按钮，pet2 仍是安装按钮，未触发安装
      expect(
        find.byKey(const ValueKey('live2dStoreEditButton_pet1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('live2dStoreInstallButton_pet1')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('live2dStoreInstallButton_pet2')),
        findsOneWidget,
      );
      expect(fake.installCalls, 0);
    });

    testWidgets('目录加载失败显示错误并可重试', (tester) async {
      final fake = _FakePetStoreService(pets: _testPets, failPetsCount: 1);
      await tester.pumpWidget(_wrap(Live2DStoreScreen(service: fake)));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('live2dStorePetsError')),
        findsOneWidget,
      );
      // 重试后目录加载成功
      await tester.tap(find.text('app_retry'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('live2dStorePet_pet1')),
        findsOneWidget,
      );
      expect(fake.fetchPetsCalls, 2);
    });

    testWidgets('安装失败显示错误与重试，重试成功后变编辑', (tester) async {
      final fake = _FakePetStoreService(pets: _testPets, failInstallCount: 1);
      final persisted = <Live2DArchive>[];
      // 已装查询走持久化列表，模拟真实 plugin.upsert 后的再查询
      Live2DArchive? findInstalled(String petId) {
        for (final archive in persisted) {
          if (archive.videoManifest?.metadata[kPetStoreMetadataPetId] ==
                  petId ||
              archive.videoManifest?.id == petId) {
            return archive;
          }
        }
        return null;
      }

      await tester.pumpWidget(
        _wrap(
          Live2DStoreScreen(
            service: fake,
            findInstalledArchive: findInstalled,
            persistArchive: (archive) async => persisted.add(archive),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 第一次安装失败：出现错误提示与重试按钮
      await tester.tap(
        find.byKey(const ValueKey('live2dStoreInstallButton_pet1')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('live2dStoreRetryButton_pet1')),
        findsOneWidget,
      );
      expect(find.textContaining('live2d_storeInstallFailed'), findsWidgets);
      expect(persisted, isEmpty);

      // 重试成功：档案写入，按钮变编辑
      await tester.tap(
        find.byKey(const ValueKey('live2dStoreRetryButton_pet1')),
      );
      await tester.pumpAndSettle();
      expect(fake.installCalls, 2);
      expect(persisted, hasLength(1));
      expect(
        find.byKey(const ValueKey('live2dStoreEditButton_pet1')),
        findsOneWidget,
      );
    });
  });

  group('VideoPetEditorScreen 服务端动作', () {
    const serverActions = [
      VideoPetAnimation(
        id: 'srv1',
        name: '余额百万',
        category: '余额',
        sources: {'webp': 'srv1.webp'},
        spritesheet: _sheet,
      ),
      VideoPetAnimation(
        id: 'srv2',
        name: '啃玉米',
        category: '小动作',
        sources: {'webp': 'srv2.webp'},
        spritesheet: _sheet,
      ),
    ];

    VideoPetManifest buildManifest() => const VideoPetManifest(
      id: 'pet1',
      name: '蓝毛小女仆',
      animations: [
        VideoPetAnimation(
          id: 'idle',
          name: '待机',
          sources: {'webp': 'file:///pets/idle.webp'},
          spritesheet: _sheet,
        ),
      ],
      idleAnimationId: 'idle',
      metadata: {
        kPetStoreMetadataPetId: 'pet1',
        kPetStoreMetadataActionsUrl:
            'http://127.0.0.1:8765/pets/pet1/actions.json',
      },
    );

    Future<void> pumpEditor(
      WidgetTester tester, {
      required PetStoreService service,
      required VideoPetManifest Function() manifestOf,
      required void Function(VideoPetManifest? result) onClosed,
    }) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: DSThemeBridge(
            child: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    final result = await Navigator.of(context)
                        .push<VideoPetManifest>(
                          MaterialPageRoute(
                            builder: (_) => VideoPetEditorScreen(
                              manifest: manifestOf(),
                              baseUri: 'file:///pets/',
                              petStoreService: service,
                            ),
                          ),
                        );
                    onClosed(result);
                  },
                  child: const Text('打开编辑器'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开编辑器'));
      await tester.pumpAndSettle();
    }

    testWidgets('未下载动作融合本地列表与分类，下载后同行变 switch', (tester) async {
      final fake = _FakePetStoreService(actions: serverActions);
      var current = buildManifest();
      VideoPetManifest? firstSaveResult;
      var savedCount = 0;
      await pumpEditor(
        tester,
        service: fake,
        manifestOf: () => current,
        onClosed: (result) {
          if (result != null) {
            savedCount++;
          }
          firstSaveResult ??= result;
        },
      );

      // 融合列表：本地 idle 与未下载 srv1/srv2 同一列表展示
      expect(
        find.byKey(const ValueKey('videoPetAnimationItem_idle')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('videoPetAnimationItem_srv1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('videoPetAnimationItem_srv2')),
        findsOneWidget,
      );
      expect(find.text('余额百万'), findsOneWidget);
      expect(find.text('啃玉米'), findsOneWidget);

      // switch 替换：远程项行内无 DSSwitch、行尾是下载按钮；本地项有 switch
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('videoPetAnimationItem_srv1')),
          matching: find.byType(DSSwitch),
        ),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('videoPetServerAction_srv1')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('videoPetAnimationItem_idle')),
          matching: find.byType(DSSwitch),
        ),
        findsOneWidget,
      );

      // 分类并集：远程分类「余额」进入分类筛选 chips
      final balanceChip = find.descendant(
        of: find.byType(DSChip),
        matching: find.text('余额'),
      );
      expect(balanceChip, findsOneWidget);

      // 点「余额」分类：本地项与其它远程项被过滤，仅剩同分类的 srv1
      await tester.tap(balanceChip);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('videoPetAnimationItem_idle')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('videoPetAnimationItem_srv2')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('videoPetAnimationItem_srv1')),
        findsOneWidget,
      );

      // 回「全部」后搜索「啃」：本地与 srv1 均被过滤，搜索对远程项同样生效
      await tester.tap(find.text('全部'));
      await tester.pumpAndSettle();
      final searchField = find.descendant(
        of: find.byKey(const ValueKey('videoPetAnimationSearchInput')),
        matching: find.byType(EditableText),
      );
      await tester.enterText(searchField, '啃');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('videoPetAnimationItem_idle')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('videoPetAnimationItem_srv1')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('videoPetAnimationItem_srv2')),
        findsOneWidget,
      );
      await tester.enterText(searchField, '');
      await tester.pumpAndSettle();

      // 下载 srv1：下载按钮消失，同一行出现 DSSwitch（本地化 + 立即播放）
      await tester.tap(find.byKey(const ValueKey('videoPetServerAction_srv1')));
      await tester.pumpAndSettle();
      expect(fake.downloadCalls, 1);
      expect(
        find.byKey(const ValueKey('videoPetServerAction_srv1')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('videoPetAnimationItem_srv1')),
          matching: find.byType(DSSwitch),
        ),
        findsOneWidget,
      );

      // 保存：返回的 manifest 含新动作且源已解析为绝对地址
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(savedCount, 1);
      final firstSaved = firstSaveResult;
      expect(firstSaved, isNotNull);
      final downloaded = firstSaved!.animations
          .singleWhere((a) => a.id == 'srv1');
      expect(downloaded.sources['webp'], 'file:///pets/srv1.webp');

      // 用保存结果重进编辑器：srv1 是本地项（无下载按钮、有 switch），
      // srv2 仍为远程项可下载（列表视口有限，先搜索过滤再断言）
      current = firstSaved;
      await tester.tap(find.text('打开编辑器'));
      await tester.pumpAndSettle();
      final searchField2 = find.descendant(
        of: find.byKey(const ValueKey('videoPetAnimationSearchInput')),
        matching: find.byType(EditableText),
      );
      await tester.enterText(searchField2, '啃');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('videoPetServerAction_srv1')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('videoPetAnimationItem_srv1')),
          matching: find.byType(DSSwitch),
        ),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('videoPetServerAction_srv2')),
        findsOneWidget,
      );
    });

    testWidgets('下载失败提示错误且按钮可重试，成功后变 switch', (tester) async {
      final fake = _FakePetStoreService(
        actions: serverActions,
        failDownloadCount: 1,
      );
      await pumpEditor(
        tester,
        service: fake,
        manifestOf: buildManifest,
        onClosed: (_) {},
      );

      // 首次下载失败：错误提示 + 按钮恢复（可重试），未进入草稿
      await tester.tap(find.byKey(const ValueKey('videoPetServerAction_srv1')));
      await tester.pumpAndSettle();
      expect(fake.downloadCalls, 1);
      expect(
        find.textContaining('videoPet_serverDownloadFailed'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('videoPetServerAction_srv1')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('videoPetAnimationItem_srv1')),
          matching: find.byType(DSSwitch),
        ),
        findsNothing,
      );

      // 等待错误 SnackBar 自动消失，避免遮挡下载按钮
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      // 重试成功：按钮消失，同一行恢复本地 switch
      await tester.tap(find.byKey(const ValueKey('videoPetServerAction_srv1')));
      await tester.pumpAndSettle();
      expect(fake.downloadCalls, 2);
      expect(
        find.byKey(const ValueKey('videoPetServerAction_srv1')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('videoPetAnimationItem_srv1')),
          matching: find.byType(DSSwitch),
        ),
        findsOneWidget,
      );
    });

    testWidgets('取消编辑不把未保存的下载动作写回 manifest', (tester) async {
      final fake = _FakePetStoreService(actions: serverActions);
      final original = buildManifest();
      VideoPetManifest? closedWith;
      await pumpEditor(
        tester,
        service: fake,
        manifestOf: () => original,
        onClosed: (result) => closedWith = result,
      );

      // 下载一个服务端动作后直接返回（取消）
      await tester.tap(
        find.byKey(const ValueKey('videoPetServerAction_srv1')),
      );
      await tester.pumpAndSettle();
      expect(fake.downloadCalls, 1);
      await tester.tap(find.byType(DSIconButton).first);
      await tester.pumpAndSettle();

      // pop 无结果，原 manifest 不含下载动作（草稿隔离）
      expect(closedWith, isNull);
      expect(
        original.animations.where((a) => a.id == 'srv1'),
        isEmpty,
      );
    });

    testWidgets('一键下载全部服务端动作，全部变本地 switch', (tester) async {
      final fake = _FakePetStoreService(actions: serverActions);
      await pumpEditor(
        tester,
        service: fake,
        manifestOf: buildManifest,
        onClosed: (_) {},
      );

      // 批量下载入口出现在动画标题右侧
      expect(
        find.byKey(const ValueKey('videoPetServerDownloadAllButton')),
        findsOneWidget,
      );

      // 一键下载：两个远程动作均合入草稿（行内恢复 switch，按钮消失）
      await tester.tap(
        find.byKey(const ValueKey('videoPetServerDownloadAllButton')),
      );
      await tester.pumpAndSettle();
      expect(fake.downloadCalls, 2);
      expect(
        find.byKey(const ValueKey('videoPetServerAction_srv1')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('videoPetAnimationItem_srv1')),
          matching: find.byType(DSSwitch),
        ),
        findsOneWidget,
      );
      // 全部下载完成后批量入口消失
      expect(
        find.byKey(const ValueKey('videoPetServerDownloadAllButton')),
        findsNothing,
      );
    });

    testWidgets('服务端动作加载失败显示错误并可重试', (tester) async {
      final fake = _FakePetStoreService(
        actions: serverActions,
        failActionsCount: 1,
      );
      await pumpEditor(
        tester,
        service: fake,
        manifestOf: buildManifest,
        onClosed: (_) {},
      );

      // 首次加载失败：错误提示 + 重试按钮
      expect(
        find.byKey(const ValueKey('videoPetServerRetryButton')),
        findsOneWidget,
      );
      expect(
        find.textContaining('videoPet_serverLoadFailed'),
        findsOneWidget,
      );

      // 重试成功：动作芯片出现
      await tester.tap(
        find.byKey(const ValueKey('videoPetServerRetryButton')),
      );
      await tester.pumpAndSettle();
      expect(fake.fetchActionsCalls, 2);
      expect(
        find.byKey(const ValueKey('videoPetServerAction_srv1')),
        findsOneWidget,
      );
    });
  });
}
