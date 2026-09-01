[根目录](../../../CLAUDE.md) > [lib](../../) > [plugins](../) > **goods**

---

# 物品管理插件 (Goods Plugin) - 模块文档

## 模块职责

物品管理插件是 Aboutme 的核心资产管理模块，提供：

- **仓库管理**：创建和管理多个仓库（Warehouse），组织物品分类
- **物品记录管理**：创建、编辑、删除物品记录（支持多层级子物品）
- **图片存储**：支持为物品和仓库添加图片，使用相对路径存储
- **自定义字段**：为物品添加任意自定义字段（键值对）
- **标签系统**：为物品添加多个标签，便于分类和搜索
- **使用记录**：记录物品的使用历史，跟踪最后使用时间
- **统计功能**：物品总数量、总价值、未使用物品统计
- **搜索与筛选**：支持按仓库筛选、按名称搜索、按价格/最后使用时间排序
- **双视图模式**：网格视图和列表视图自由切换
- **事件系统**：广播物品的添加、删除事件

---

## 入口与启动

### 插件主类

**文件**: `goods_plugin.dart`

```dart
class GoodsPlugin extends BasePlugin {
    @override
    String get id => 'goods';

    @override
    Future<void> initialize() async {
        // 确保物品管理数据目录存在
        await storage.createDirectory('goods');

        // 加载仓库数据
        await _loadWarehouses();

        // 加载排序偏好
        await _loadSortPreferences();
    }

    @override
    Future<void> registerToApp(
        PluginManager pluginManager,
        ConfigManager configManager,
    ) async {
        // 插件已在 initialize() 中完成初始化
    // 这里可以添加额外的应用级注册逻辑
    }
}
```

### 主界面入口

**文件**: `screens/goods_main_screen.dart`

**路由**: 通过 `GoodsPlugin.buildMainView()` 返回 `GoodsMainView`，内部使用 `BottomNavigationBar` 切换两个界面：
- **仓库视图** (`WarehouseListScreen`): 显示所有仓库列表
- **物品视图** (`GoodsListScreen`): 显示所有仓库的所有物品

---

## 对外接口

### 核心 API

#### 实例获取

```dart
// 获取插件单例（通过 PluginManager）
static GoodsPlugin get instance;
```

#### 仓库管理接口

```dart
// 获取所有仓库列表
List<Warehouse> get warehouses;

// 根据 ID 获取仓库
Warehouse? getWarehouse(String id);

// 保存或更新仓库
Future<void> saveWarehouse(Warehouse warehouse);

// 删除仓库
Future<void> deleteWarehouse(String warehouseId);

// 清空仓库（删除所有物品）
Future<void> clearWarehouse(String warehouseId);
```

#### 物品管理接口

```dart
// 保存或更新物品
Future<void> saveGoodsItem(String warehouseId, GoodsItem item);

// 删除物品
Future<void> deleteGoodsItem(String warehouseId, String itemId);

// 在所有仓库中查找物品（支持递归查找子物品）
FindItemResult? findGoodsItemById(String itemId);

// 查找物品的父物品
FindItemResult? findParentGoodsItem(String itemId);
```

#### 统计接口

```dart
// 获取所有物品的总数量
int getTotalItemsCount();

// 获取所有物品的总价值
double getTotalItemsValue();

// 获取一个月未使用的物品数量
int getUnusedItemsCount();
```

#### 排序偏好接口

```dart
// 获取特定仓库的排序偏好
String getSortPreference(String warehouseId);

// 保存特定仓库的排序偏好
Future<void> saveSortPreference(String warehouseId, String sortBy);
```

#### 监听器接口

```dart
// 添加数据变更监听器
void addListener(Function() listener);

// 移除数据变更监听器
void removeListener(Function() listener);

// 通知所有监听器
void notifyListeners();
```

---

## 关键依赖与配置

### 外部依赖

- `image_picker`: 选择图片
- `uuid`: 生成唯一物品 ID
- `intl`: 日期格式化

### 插件依赖

- **Core Event System**: 消息事件广播
- **StorageManager**: 数据存储

### 存储路径

**根目录**: `goods/`

**存储结构**:
```
goods/
├── preferences.json                # 用户偏好配置（排序偏好）
├── warehouses.json                 # 仓库索引文件
├── warehouse/
│   ├── <warehouse_id>.json        # 具体仓库数据
│   └── ...
├── goods_images/                   # 物品图片目录
│   ├── <image_filename>
│   └── ...
└── warehouse_images/               # 仓库图片目录
    ├── <image_filename>
    └── ...
```

**仓库索引格式** (`warehouses.json`):
```json
{
  "warehouses": [
    "warehouse_uuid_1",
    "warehouse_uuid_2"
  ]
}
```

**仓库数据格式** (`warehouse/<warehouse_id>.json`):
```json
{
  "warehouse": {
    "id": "warehouse_uuid_1",
    "title": "客厅",
    "iconData": 58826,
    "iconColor": 4278190335,
    "imageUrl": "./goods/warehouse_images/image.jpg",
    "items": [
      {
        "id": "item_uuid_1",
        "title": "笔记本电脑",
        "imageUrl": "./goods/goods_images/laptop.jpg",
        "iconData": null,
        "iconColor": null,
        "tags": ["电子产品", "工作"],
        "purchaseDate": "2024-01-15T00:00:00.000Z",
        "purchasePrice": 8999.0,
        "usageRecords": [
          {
            "date": "2025-01-10T08:30:00.000Z",
            "note": "编写代码"
          }
        ],
        "customFields": [
          {
            "key": "品牌",
            "value": "Dell"
          },
          {
            "key": "型号",
            "value": "XPS 13"
          }
        ],
        "notes": "工作用笔记本电脑，性能良好",
        "subItems": []
      }
    ]
  }
}
```

**排序偏好格式** (`preferences.json`):
```json
{
  "warehouseSortPreferences": {
    "warehouse_uuid_1": "price",
    "warehouse_uuid_2": "lastUsed"
  }
}
```

---

## 数据模型

### Warehouse (仓库)

**文件**: `models/warehouse.dart`

```dart
class Warehouse {
  String id;                    // 唯一ID
  String title;                 // 仓库名称
  IconData icon;                // 图标
  Color iconColor;              // 图标颜色
  String? imageUrl;             // 图片URL（相对路径）
  List<GoodsItem> items;        // 物品列表

  // 获取图片绝对路径
  Future<String?> getImageUrl();

  Map<String, dynamic> toJson();
  factory Warehouse.fromJson(Map<String, dynamic> json);
  Warehouse copyWith({...});
}
```

**存储路径**: `goods/warehouse/<warehouse_id>.json`

**特性**:
- 图片使用相对路径存储（通过 `GoodsPathConstants` 工具类）
- 支持自定义图标和颜色
- 包含物品列表

### GoodsItem (物品)

**文件**: `models/goods_item.dart`

```dart
class GoodsItem {
  String id;                           // 唯一ID
  String title;                        // 物品名称
  String? imageUrl;                    // 图片URL（相对路径）
  IconData? icon;                      // 图标（可选）
  Color? iconColor;                    // 图标颜色（可选）
  List<String> tags;                   // 标签列表
  DateTime? purchaseDate;              // 购买日期
  double? purchasePrice;               // 购买价格
  List<UsageRecord> usageRecords;      // 使用记录列表
  List<CustomField> customFields;      // 自定义字段列表
  String? notes;                       // 备注
  List<GoodsItem> subItems;            // 子物品列表（支持多层级）

  // 计算总价格（包含子物品）
  double? get totalPrice;

  // 获取最后使用日期
  DateTime? get lastUsedDate;

  // 获取图片绝对路径
  Future<String?> getImageUrl();

  // 添加使用记录
  GoodsItem addUsageRecord(DateTime date, {String? note});

  Map<String, dynamic> toJson();
  factory GoodsItem.fromJson(Map<String, dynamic> json);
  GoodsItem copyWith({...});
}
```

**特性**:
- 支持多层级子物品结构（递归）
- 图片使用相对路径存储
- 自动计算总价格（包含子物品）
- 自动跟踪最后使用时间

### UsageRecord (使用记录)

**文件**: `models/usage_record.dart`

```dart
class UsageRecord {
  DateTime date;         // 使用日期
  String? note;          // 备注（可选）

  Map<String, dynamic> toJson();
  factory UsageRecord.fromJson(Map<String, dynamic> json);
}
```

### CustomField (自定义字段)

**文件**: `models/custom_field.dart`

```dart
class CustomField {
  String key;            // 字段名
  String value;          // 字段值

  Map<String, dynamic> toJson();
  factory CustomField.fromJson(Map<String, dynamic> json);
}
```

### FindItemResult (物品查找结果)

**文件**: `models/find_item_result.dart`

```dart
class FindItemResult {
  GoodsItem item;        // 找到的物品
  String warehouseId;    // 物品所在仓库的ID

  FindItemResult({required this.item, required this.warehouseId});
}
```

**用途**: 在递归查找物品时，返回物品及其所属仓库信息

### GoodsPathConstants (路径常量)

**文件**: `models/path_constants.dart`

```dart
class GoodsPathConstants {
  static const String goodsImagesDir = 'goods/goods_images';
  static const String warehouseImagesDir = 'goods/warehouse_images';
  static const String relativePrefix = './';

  // 转换为相对路径
  static String toRelativePath(String? absolutePath);

  // 转换为绝对路径
  static String toAbsolutePath(String appDocPath, String? relativePath);

  // 清理路径中的多余斜杠
  static String cleanPath(String path);
}
```

**用途**: 统一处理图片路径的相对/绝对转换，确保跨平台兼容性

---

## 界面层结构

### 主要界面组件

| 组件 | 文件 | 职责 |
|------|------|------|
| `GoodsMainView` | `goods_plugin.dart` | 插件主视图容器（双Tab导航） |
| `GoodsMainScreen` | `screens/goods_main_screen.dart` | 主界面（包含底部导航） |
| `WarehouseListScreen` | `screens/warehouse_list_screen.dart` | 仓库列表界面 |
| `WarehouseDetailScreen` | `screens/warehouse_detail_screen.dart` | 仓库详情界面 |
| `GoodsListScreen` | `screens/goods_list_screen.dart` | 物品列表界面（跨仓库） |

### GoodsMainScreen 布局

**布局结构**:
```
Scaffold
├── body: IndexedStack
│   ├── [0] WarehouseListScreen (仓库视图)
│   └── [1] GoodsListScreen (物品视图)
└── BottomNavigationBar
    ├── 仓库
    └── 物品
```

### WarehouseListScreen (仓库列表)

**布局结构**:
```
Scaffold
├── AppBar
│   ├── 返回按钮
│   ├── 标题：所有仓库 (数量)
│   └── 添加按钮
└── GridView (响应式布局)
    ├── 宽屏：2列
    └── 窄屏：1列
    └── WarehouseCard (仓库卡片)
```

**关键特性**:
- 响应式布局（根据屏幕宽度调整列数）
- 点击仓库卡片进入仓库详情
- 添加按钮打开仓库表单

### WarehouseDetailScreen (仓库详情)

**布局结构**:
```
Scaffold
├── AppBar
│   ├── 返回按钮
│   ├── 标题：仓库名称
│   └── 更多按钮（编辑、清空、删除）
├── 排序选择器
└── 物品列表
    └── GoodsItemCard 或 GoodsItemListTile
```

**关键特性**:
- 支持按价格、最后使用时间排序
- 保存用户的排序偏好
- 点击物品打开编辑表单
- 支持清空仓库和删除仓库

### GoodsListScreen (物品列表)

**布局结构**:
```
Scaffold
├── AppBar
│   ├── 标题 / 搜索框（切换）
│   └── 操作按钮组
│       ├── 搜索按钮
│       ├── 仓库筛选按钮
│       ├── 视图切换按钮
│       └── 排序按钮
└── GridView / ListView（根据视图模式）
    └── GoodsItemCard 或 GoodsItemListTile
```

**关键特性**:
- 搜索功能：按物品名称搜索
- 仓库筛选：支持筛选特定仓库的物品
- 视图模式切换：网格视图 / 列表视图
- 排序选项：默认排序、按价格、按最后使用时间
- 响应式布局

### 表单组件

| 组件 | 文件 | 职责 |
|------|------|------|
| `WarehouseForm` | `widgets/warehouse_form.dart` | 仓库创建/编辑表单 |
| `GoodsItemForm` | `widgets/goods_item_form/goods_item_form.dart` | 物品表单容器 |
| `GoodsItemFormPage` | `widgets/goods_item_form/goods_item_form_page.dart` | 物品表单页面（TabView） |
| `BasicInfoTab` | `widgets/goods_item_form/widgets/basic_info_tab.dart` | 基本信息标签页 |
| `UsageRecordsTab` | `widgets/goods_item_form/widgets/usage_records_tab.dart` | 使用记录标签页 |
| `SubItemsTab` | `widgets/goods_item_form/widgets/sub_items_tab.dart` | 子物品标签页 |

### GoodsItemForm 布局

**TabView 结构**:
```
TabBarView
├── [0] 基本信息
│   ├── 图片选择器
│   ├── 物品名称
│   ├── 购买日期
│   ├── 购买价格
│   ├── 标签输入
│   ├── 自定义字段列表
│   └── 备注
├── [1] 使用记录
│   ├── 使用记录列表
│   └── 添加按钮
└── [2] 子物品
    ├── 子物品列表
    └── 添加按钮
```

**表单控制器**: `FormController` (文件: `widgets/goods_item_form/controllers/form_controller.dart`)

---

## 事件系统

### 事件类型

**文件**: `goods_plugin.dart`

| 事件名 | 事件类 | 触发时机 | 参数 |
|-------|--------|---------|------|
| `goods_item_added` | `GoodsItemAddedEventArgs` | 新建物品时 | `GoodsItem item, String warehouseId` |
| `goods_item_deleted` | `GoodsItemDeletedEventArgs` | 删除物品时 | `String itemId, String warehouseId` |

### 事件类定义

```dart
// 物品相关事件的基类
abstract class GoodsEventArgs extends EventArgs {
  final String warehouseId;
  GoodsEventArgs(super.eventName, this.warehouseId);
}

// 物品添加事件参数
class GoodsItemAddedEventArgs extends GoodsEventArgs {
  final GoodsItem item;
  GoodsItemAddedEventArgs(this.item, String warehouseId)
    : super('goods_item_added', warehouseId);
}

// 物品删除事件参数
class GoodsItemDeletedEventArgs extends GoodsEventArgs {
  final String itemId;
  GoodsItemDeletedEventArgs(this.itemId, String warehouseId)
    : super('goods_item_deleted', warehouseId);
}
```

### 事件广播示例

```dart
// 在 GoodsPlugin.saveGoodsItem() 中
if (!updated) {
  warehouse.items.add(item);
  // 广播物品添加事件
  EventManager.instance.broadcast(
    'goods_item_added',
    GoodsItemAddedEventArgs(item, warehouseId),
  );
}

// 在 GoodsPlugin.deleteGoodsItem() 中
EventManager.instance.broadcast(
  'goods_item_deleted',
  GoodsItemDeletedEventArgs(itemId, warehouseId),
);
```

---

## 卡片视图

插件在主页提供卡片视图，展示：

**布局**:
```
┌─────────────────────────────┐
│ 📦 物品                    │
├─────────────────────────────┤
│  物品总数    │   物品总价值 │
│     120     │   ¥58,888    │
├─────────────────────────────┤
│      一个月未使用           │
│          15                 │
│  (显示红色警告)              │
└─────────────────────────────┘
```

**实现**: `goods_plugin.dart` 中的 `buildCardView()` 方法

**数据来源**:
- 物品总数: `getTotalItemsCount()`
- 物品总价值: `getTotalItemsValue()`
- 一个月未使用: `getUnusedItemsCount()`

---

## 国际化

### 支持语言

- 简体中文 (zh)
- 英语 (en)

### 本地化文件

| 文件 | 语言 |
|------|------|
| `l10n/goods_localizations.dart` | 本地化接口 |
| `l10n/goods_localizations_zh.dart` | 中文翻译 |
| `l10n/goods_localizations_en.dart` | 英文翻译 |

### 关键字符串

```dart
abstract class GoodsLocalizations {
  String get name;                          // 插件名称
  String get allWarehouses;                 // 所有仓库
  String get allItems;                      // 所有物品
  String get searchGoods;                   // 搜索物品
  String get filter;                        // 筛选
  String get viewAsGrid;                    // 网格视图
  String get viewAsList;                    // 列表视图
  String get defaultSort;                   // 默认排序
  String get sortByPrice;                   // 按价格排序
  String get sortByLastUsedTime;            // 按最后使用时间排序
  String get addItem;                       // 添加物品
  String get editItem;                      // 编辑物品
  String get deleteProduct;                 // 删除物品
  String get confirmDeleteItem;             // 确认删除物品
  String get productName;                   // 物品名称
  String get enterProductName;              // 请输入物品名称
  String get price;                         // 价格
  String get enterPrice;                    // 请输入价格
  String get tag;                           // 标签
  String get addTag;                        // 添加标签
  String get customFields;                  // 自定义字段
  String get addCustomField;                // 添加自定义字段
  String get fieldName;                     // 字段名称
  String get fieldValue;                    // 字段值
  String get usageRecords;                  // 使用记录
  String get addUsageRecord;                // 添加使用记录
  String get subItems;                      // 子物品
  String get addSubItem;                    // 添加子物品
  String get basicInfo;                     // 基本信息
  String get editWarehouse;                 // 编辑仓库
  String get clearWarehouse;                // 清空仓库
  String get deleteWarehouse;               // 删除仓库
  String get confirmClearWarehouse;         // 确认清空仓库
  String get confirmDeleteWarehouse;        // 确认删除仓库
  String get warehouseName;                 // 仓库名称
  String get totalQuantity;                 // 物品总数
  String get totalValue;                    // 物品总价值
  String get oneMonthUnused;                // 一个月未使用
}
```

---

## 测试与质量

### 当前状态
- **单元测试**: 无
- **集成测试**: 无
- **已知问题**: 无明显问题

### 测试建议

1. **高优先级**:
   - `GoodsPlugin.saveGoodsItem()` - 测试递归更新逻辑
   - `GoodsPlugin.findGoodsItemById()` - 测试递归查找逻辑
   - `GoodsPlugin.deleteGoodsItem()` - 测试递归删除逻辑
   - `GoodsPathConstants` - 测试路径转换逻辑
   - 仓库和物品的保存和加载 - 测试数据持久化

2. **中优先级**:
   - 事件广播 - 测试事件是否正确触发
   - 子物品递归操作 - 测试多层级子物品
   - 图片路径处理 - 测试跨平台路径兼容性
   - 统计功能 - 测试计算准确性

3. **低优先级**:
   - UI 交互逻辑
   - 国际化字符串完整性
   - 视图模式切换
   - 卡片视图统计展示

---

## 常见问题 (FAQ)

### Q1: 如何添加自定义字段？

在物品表单的"基本信息"标签页中：
1. 滚动到自定义字段部分
2. 点击"添加自定义字段"按钮
3. 输入字段名称和字段值
4. 点击确认

自定义字段存储在 `GoodsItem.customFields` 中。

### Q2: 如何管理子物品？

在物品表单的"子物品"标签页中：
1. 点击"添加子物品"按钮
2. 填写子物品信息
3. 子物品支持多层级嵌套

子物品的价格会自动累加到父物品的 `totalPrice` 中。

### Q3: 图片如何存储？

- **存储位置**: 应用数据目录下的 `goods/goods_images/` 或 `goods/warehouse_images/`
- **存储格式**: 使用相对路径（如: `./goods/goods_images/image.jpg`）
- **路径转换**: 通过 `GoodsPathConstants` 工具类自动处理
- **读取时**: 调用 `getImageUrl()` 方法获取绝对路径

### Q4: 如何搜索和筛选物品？

在"物品"视图中：
- **搜索**: 点击搜索按钮，输入物品名称
- **筛选**: 点击筛选按钮，选择特定仓库
- **排序**: 点击排序按钮，选择排序方式

### Q5: 如何跟踪物品的使用情况？

在物品表单的"使用记录"标签页中：
1. 点击"添加使用记录"按钮
2. 选择使用日期
3. 输入可选的备注
4. 最后使用时间会自动显示在物品卡片上

系统会根据最后使用时间统计"一个月未使用"的物品数量。

### Q6: 如何导出物品数据？

当前未实现导出功能，建议添加：

```dart
Future<File> exportGoodsToJson() async {
  final allWarehouses = warehouses.map((w) => w.toJson()).toList();
  final jsonData = {
    'exportDate': DateTime.now().toIso8601String(),
    'warehouses': allWarehouses,
  };

  final file = File('goods_export_${DateTime.now().millisecondsSinceEpoch}.json');
  await file.writeAsString(jsonEncode(jsonData));
  return file;
}
```

### Q7: 物品的 ID 如何生成？

物品和仓库的 ID 使用 UUID 生成（通过 `uuid` 包）：

```dart
import 'package:uuid/uuid.dart';

final uuid = Uuid();
final id = uuid.v4();  // 生成唯一ID
```

---

## 目录结构

```
goods/
├── goods_plugin.dart                                 # 插件主类 + 事件定义
├── models/
│   ├── warehouse.dart                                # 仓库模型
│   ├── goods_item.dart                               # 物品模型
│   ├── usage_record.dart                             # 使用记录模型
│   ├── custom_field.dart                             # 自定义字段模型
│   ├── find_item_result.dart                         # 物品查找结果
│   └── path_constants.dart                           # 路径常量和工具
├── screens/
│   ├── goods_main_screen.dart                        # 主界面（双Tab导航）
│   ├── warehouse_list_screen.dart                    # 仓库列表界面
│   ├── warehouse_detail_screen.dart                  # 仓库详情界面
│   └── goods_list_screen.dart                        # 物品列表界面（跨仓库）
├── widgets/
│   ├── warehouse_card.dart                           # 仓库卡片组件
│   ├── warehouse_form.dart                           # 仓库表单组件
│   ├── goods_item_card.dart                          # 物品卡片组件（网格）
│   ├── goods_item_list_tile.dart                     # 物品列表项（列表）
│   ├── goods_item_selector_dialog.dart               # 物品选择对话框
│   └── goods_item_form/
│       ├── index.dart                                # 表单入口文件
│       ├── goods_item_form.dart                      # 表单容器
│       ├── goods_item_form_page.dart                 # 表单页面（TabView）
│       ├── custom_fields_list.dart                   # 自定义字段列表
│       ├── usage_records_list.dart                   # 使用记录列表
│       ├── tag_input_field.dart                      # 标签输入字段
│       ├── add_tag_dialog.dart                       # 添加标签对话框
│       ├── controllers/
│       │   └── form_controller.dart                  # 表单控制器
│       └── widgets/
│           ├── basic_info_tab.dart                   # 基本信息标签页
│           ├── usage_records_tab.dart                # 使用记录标签页
│           └── sub_items_tab.dart                    # 子物品标签页
└── l10n/
    ├── goods_localizations.dart                      # 国际化接口
    ├── goods_localizations_zh.dart                   # 中文翻译
    └── goods_localizations_en.dart                   # 英文翻译
```

---

## 关键实现细节

### 递归查找物品

```dart
// 在所有仓库中查找指定ID的物品
FindItemResult? findGoodsItemById(String itemId) {
  for (final warehouse in _warehouses) {
    // 首先在仓库的顶级物品中查找
    final item = _findItemRecursively(warehouse.items, itemId);
    if (item != null) {
      return FindItemResult(item: item, warehouseId: warehouse.id);
    }
  }
  return null;
}

// 递归查找物品及其子物品
GoodsItem? _findItemRecursively(List<GoodsItem> items, String itemId) {
  for (final item in items) {
    if (item.id == itemId) {
      return item;
    }

    // 递归查找子物品
    if (item.subItems.isNotEmpty) {
      final result = _findItemRecursively(item.subItems, itemId);
      if (result != null) {
        return result;
      }
    }
  }
  return null;
}
```

**原理**: 深度优先搜索（DFS），遍历所有仓库和所有层级的子物品

### 递归更新物品

```dart
// 递归更新物品及其子物品
bool _updateItemRecursively(List<GoodsItem> items, GoodsItem updatedItem) {
  // 在当前层级查找
  for (var i = 0; i < items.length; i++) {
    if (items[i].id == updatedItem.id) {
      items[i] = updatedItem;
      return true;
    }

    // 递归查找子物品
    if (items[i].subItems.isNotEmpty) {
      if (_updateItemRecursively(items[i].subItems, updatedItem)) {
        return true;
      }
    }
  }
  return false;
}
```

**原因**: 支持多层级子物品结构，需要递归更新

### 递归删除物品

```dart
// 递归删除物品及其子物品
bool _deleteItemRecursively(List<GoodsItem> items, String itemId) {
  // 直接从当前层级删除
  int initialLength = items.length;
  items.removeWhere((item) => item.id == itemId);
  if (items.length < initialLength) {
    return true;
  }

  // 递归查找子物品
  for (var item in items) {
    if (item.subItems.isNotEmpty) {
      if (_deleteItemRecursively(item.subItems, itemId)) {
        return true;
      }
    }
  }
  return false;
}
```

**原理**: 深度优先删除，支持删除任意层级的子物品

### 图片路径处理

```dart
// 在 GoodsItem 类中
String? _imageUrl;

// 设置图片URL，如果是绝对路径则转换为相对路径
set imageUrl(String? value) {
  _imageUrl = value == "" ? "" : GoodsPathConstants.toRelativePath(value);
}

// 获取图片URL，如果是相对路径则转换为绝对路径
Future<String?> getImageUrl() async {
  if (_imageUrl == null || _imageUrl == "") return null;
  final appDir = await StorageManager.getApplicationDocumentsDirectory();
  return GoodsPathConstants.cleanPath(
    GoodsPathConstants.toAbsolutePath(appDir.path, _imageUrl),
  );
}
```

**目的**:
- 存储时使用相对路径，确保跨设备兼容性
- 读取时转换为绝对路径，方便使用
- 清理多余斜杠，避免路径错误

### 排序偏好持久化

```dart
// 用于存储用户的排序偏好
final Map<String, String> _warehouseSortPreferences = {};

// 保存特定仓库的排序偏好
Future<void> saveSortPreference(String warehouseId, String sortBy) async {
  _warehouseSortPreferences[warehouseId] = sortBy;
  await storage.write('goods/preferences', {
    'warehouseSortPreferences': _warehouseSortPreferences,
  });
}
```

**原因**: 每个仓库可能有不同的排序需求，需要单独保存

### 总价格计算（包含子物品）

```dart
// 在 GoodsItem 类中
double? get totalPrice {
  if (purchasePrice == null) return null;
  double total = purchasePrice!;
  for (var subItem in subItems) {
    if (subItem.totalPrice != null) {
      total += subItem.totalPrice!;
    }
  }
  return total;
}
```

**原理**: 递归累加子物品价格，支持多层级

---

## 依赖关系

### 核心依赖

- **BasePlugin**: 插件基类
- **StorageManager**: 数据持久化
- **EventManager**: 事件广播系统
- **PluginManager**: 插件管理器
- **ConfigManager**: 配置管理器

### 第三方包依赖

- `uuid: ^4.0.0` - UUID生成
- `image_picker: ^1.0.0` - 图片选择
- `intl: ^0.18.0` - 日期格式化

### 其他插件依赖

- 无直接插件依赖

---

## 变更记录 (Changelog)

- **2025-11-13**: 初始化物品管理插件文档，识别 28 个文件、5 个数据模型、2 个事件类型、核心功能包括仓库管理、物品管理、多层级子物品、自定义字段、使用记录跟踪

---

**上级目录**: [返回插件目录](../../../CLAUDE.md#模块索引) | [返回根文档](../../../CLAUDE.md)
