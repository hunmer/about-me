[根目录](../../../CLAUDE.md) > [lib](../../) > [plugins](../) > **contact**

---

# 联系人插件 (Contact Plugin) - 模块文档

## 模块职责

联系人插件是 Aboutme 的人际关系管理模块，提供：

- **联系人管理**：创建、编辑、删除联系人信息
- **头像与图标**：支持自定义头像上传和图标选择
- **标签系统**：为联系人添加多个自定义标签
- **自定义字段**：灵活的键值对自定义信息
- **交互记录**：记录每次与联系人的互动（时间、内容、参与者）
- **筛选与排序**：按姓名、标签、日期范围、未联系天数等多维度筛选
- **视图模式**：支持列表视图和网格视图切换
- **统计功能**：总联系人数、最近联系人数
- **时间追踪**：自动更新最后联系时间

---

## 入口与启动

### 插件主类

**文件**: `contact_plugin.dart`

```dart
class ContactPlugin extends BasePlugin {
    @override
    String get id => 'contact';

    @override
    Color get color => Colors.deepPurple;

    @override
    IconData get icon => Icons.contacts;

    @override
    Future<void> initialize() async {
        _controller = ContactController(this);
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

**文件**: `screens/contact_main_view.dart`

**路由**: 通过 `ContactPlugin.buildMainView()` 返回 `ContactMainView`

---

## 对外接口

### 核心 API

#### 统计接口

```dart
// 获取总联系人数
int getTotalContactCount();

// 获取最近一个月内联系的人数
Future<int> getRecentlyContactedCount();

// 获取卡片统计数据
Future<Map<String, dynamic>> _getCardStats();
// 返回: {'totalContacts': int, 'recentContacts': int}
```

#### ContactController 控制器

**文件**: `controllers/contact_controller.dart`

```dart
// 联系人 CRUD 操作
Future<List<Contact>> getAllContacts();
Future<Contact> addContact(Contact contact);
Future<Contact> updateContact(Contact contact);
Future<void> deleteContact(String id);
Future<Contact?> getContact(String id);

// 交互记录管理
Future<List<InteractionRecord>> getAllInteractions();
Future<InteractionRecord> addInteraction(InteractionRecord interaction);
Future<void> deleteInteraction(String id);
Future<void> deleteInteractionsByContactId(String contactId);
Future<List<InteractionRecord>> getInteractionsByContactId(String contactId);
Future<int> getContactInteractionsCount(String contactId);

// 筛选与排序
Future<FilterConfig> getFilterConfig();
Future<void> saveFilterConfig(FilterConfig config);
Future<SortConfig> getSortConfig();
Future<void> saveSortConfig(SortConfig config);
Future<List<Contact>> getFilteredAndSortedContacts();

// 标签管理
Future<List<String>> getAllTags();

// 统计数据
Future<int> getRecentlyContactedCount();

// 初始化默认数据
Future<void> createDefaultContacts();
```

#### ContactUtils 工具类

**文件**: `utils/contact_utils.dart`

```dart
// 格式化电话号码 (11位手机号 -> 138-0013-8000)
static String formatPhoneNumber(String phone);

// 格式化日期 (yyyy-MM-dd)
static String formatDate(DateTime date);

// 格式化日期和时间 (yyyy-MM-dd HH:mm)
static String formatDateTime(DateTime dateTime);

// 获取自上次联系以来的时间描述 (如：3天前、1小时前)
static String getTimeSinceLastContact(DateTime lastContactTime);

// 验证中国手机号
static bool isValidPhoneNumber(String phone);

// 获取标签颜色 (预定义：家人/朋友/同事/客户/重要)
static Color getTagColor(String tag);

// 获取交互类型图标 (电话/见面/邮件/短信/视频)
static IconData getInteractionTypeIcon(String type);
```

---

## 关键依赖与配置

### 外部依赖

- `uuid`: 生成唯一联系人ID
- `path`: 路径处理
- `intl`: 日期格式化
- `timeago`: 相对时间显示（如"3天前"）

### 插件依赖

- **Core Event System**: 事件广播系统（未实现）
- **StorageManager**: 数据持久化
- **ImageUtils**: 图片处理工具
- **CircleIconPicker**: 图标选择器组件
- **ImagePickerDialog**: 图片选择器组件

### 存储路径

**根目录**: `contacts/`

**存储结构**:
```
contacts/
├── contacts.json                # 联系人数据文件
├── interactions                 # 交互记录数据文件
├── filter_config                # 筛选配置文件
├── sort_config                  # 排序配置文件
└── images/                      # 联系人头像存储目录
    ├── <uuid>.jpg
    └── ...
```

**联系人数据格式** (`contacts.json`):
```json
[
  {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "name": "张三",
    "avatar": "contacts/images/avatar1.jpg",
    "icon": 58964,
    "iconColor": 4280391411,
    "phone": "13800138000",
    "address": "北京市海淀区",
    "notes": "重要客户",
    "tags": ["家人", "朋友"],
    "customFields": {
      "公司": "北京科技有限公司",
      "职位": "技术总监"
    },
    "createdTime": "2025-01-15T08:00:00.000Z",
    "lastContactTime": "2025-01-20T10:30:00.000Z"
  }
]
```

**交互记录格式** (`interactions`):
```json
[
  {
    "id": "660e8400-e29b-41d4-a716-446655440001",
    "contactId": "550e8400-e29b-41d4-a716-446655440000",
    "date": "2025-01-20T10:30:00.000Z",
    "notes": "讨论了项目进度，下周一提交方案",
    "participants": ["770e8400-e29b-41d4-a716-446655440002"]
  }
]
```

---

## 数据模型

### Contact (联系人)

**文件**: `models/contact_model.dart`

```dart
class Contact {
  String id;                        // 唯一ID (UUID v4)
  String name;                      // 姓名 (必填)
  String? avatar;                   // 头像路径 (可选)
  IconData icon;                    // 默认图标 (当无头像时显示)
  Color iconColor;                  // 图标背景颜色
  String phone;                     // 电话号码
  String? address;                  // 地址 (可选)
  String? notes;                    // 备注 (可选)
  List<String> tags;                // 标签列表
  Map<String, String> customFields; // 自定义字段 (键值对)
  DateTime createdTime;             // 创建时间
  DateTime lastContactTime;         // 最后联系时间

  Map<String, dynamic> toJson();
  factory Contact.fromJson(Map json);
  factory Contact.empty();
  Contact copyWith({...});
}
```

**特殊说明**:
- `icon`: 存储为 `IconData.codePoint`（整数）
- `iconColor`: 存储为 `Color.value`（整数）
- `lastContactTime`: 添加交互记录时自动更新

### InteractionRecord (交互记录)

**文件**: `models/interaction_record_model.dart`

```dart
class InteractionRecord {
  String id;                    // 唯一ID (UUID v4)
  String contactId;             // 关联的联系人ID
  DateTime date;                // 交互日期和时间
  String notes;                 // 交互内容描述
  List<String> participants;    // 其他参与者的联系人ID列表

  Map<String, dynamic> toJson();
  factory InteractionRecord.fromJson(Map<String, dynamic> json);
  factory InteractionRecord.empty();
  InteractionRecord copyWith({...});
}
```

**级联删除**: 删除联系人时，所有相关的交互记录会自动删除

### FilterConfig (筛选配置)

**文件**: `models/filter_sort_config.dart`

```dart
class FilterConfig {
  String? nameKeyword;          // 姓名关键词 (模糊匹配)
  DateTime? startDate;          // 创建日期范围开始
  DateTime? endDate;            // 创建日期范围结束
  int? uncontactedDays;         // 未联系天数 (>=N天未联系)
  List<String> selectedTags;    // 选中的标签 (OR逻辑)

  Map<String, dynamic> toJson();
  factory FilterConfig.fromJson(Map<String, dynamic> json);
}
```

### SortConfig (排序配置)

**文件**: `models/filter_sort_config.dart`

```dart
enum SortType { name, createdTime, lastContactTime, contactCount }

class SortConfig {
  SortType type;                // 排序类型
  bool isReverse;               // 是否反向排序

  Map<String, dynamic> toJson();
  factory SortConfig.fromJson(Map<String, dynamic> json);
}
```

**排序类型说明**:
- `name`: 按姓名字母顺序
- `createdTime`: 按创建时间
- `lastContactTime`: 按最后联系时间
- `contactCount`: 按交互记录数量（实现中存在异步问题）

---

## 界面层结构

### 主要界面组件

| 组件 | 文件 | 职责 |
|------|------|------|
| `ContactMainView` | `screens/contact_main_view.dart` | 插件主视图容器（字母分组 + 索引条 + FAB 新建） |
| `ContactDetailScreen` | `screens/contact_detail_screen.dart` | 联系人详情页（弧形 header 头像/标签/基本信息 + 事件记录/自定义字段编辑） |
| `ContactListTile` | `widgets/contact_list_tile.dart` | 联系人列表行（手绘头像+姓名+组织，字母分组列表用） |
| `ContactCard` | `widgets/contact_card.dart` | 联系人卡片组件（支持列表/网格视图） |
| `ContactForm` | `widgets/contact_form.dart` | 联系人基础信息编辑表单（事件/自定义字段已移至详情页） |
| `InteractionForm` | `widgets/interaction_form.dart` | 交互记录表单 |
| `ContactSelector` | `widgets/contact_selector.dart` | 联系人选择器（用于选择参与者） |

> 筛选已融合进导航栏多条件过滤栏（`multiFilterItems`），独立 FilterDialog 已移除

### ContactMainView 布局

**布局结构**:
```
Scaffold
├── AppBar
│   ├── 标题 (联系人)
│   ├── 筛选按钮 (filter_list)
│   ├── 排序按钮 (sort)
│   └── 视图切换按钮 (list/grid_view)
├── FutureBuilder<List<Contact>>
│   ├── GridView (网格视图，默认)
│   │   └── ContactCard (2列网格)
│   └── ListView (列表视图)
│       └── ContactCard (单列列表)
└── FloatingActionButton (添加联系人)
```

**关键特性**:
- 双视图模式切换（网格/列表）
- 点击卡片进入编辑界面
- 支持实时筛选和排序
- 空状态提示（无联系人时显示）
- 禁止在未来日期创建联系人

### ContactForm 表单

**文件**: `widgets/contact_form.dart`

**核心组件**: 全屏 Scaffold 表单，使用 TabBar 分为两个标签页

**布局结构**:
```
DefaultTabController (2个标签页)
├── TabBar
│   ├── 基本信息
│   └── 记录
└── TabBarView
    ├── 基本信息表单
    │   ├── 头像上传 (ImagePickerDialog)
    │   ├── 图标选择器 (CircleIconPicker)
    │   ├── 姓名 (必填)
    │   ├── 电话
    │   ├── 地址
    │   ├── 备注
    │   ├── 标签管理 (Chip + 添加对话框)
    │   └── 自定义字段 (键值对列表)
    └── 交互记录列表
        ├── ListView.builder (历史记录)
        └── FloatingActionButton (添加记录)
```

**功能**:
- 支持头像上传和裁剪（1:1比例）
- 图标和颜色自定义
- 标签动态添加/删除
- 自定义字段动态添加/删除
- 交互记录内嵌管理
- 表单验证（姓名必填）

**验证规则**:
- 姓名不能为空
- 保存时验证表单完整性

### ContactCard 组件

**文件**: `widgets/contact_card.dart`

**显示模式**:

1. **网格视图** (默认):
```
┌─────────────────┐
│   [头像/图标]   │
│      张三       │
│  13800138000    │
│  [家人][朋友]   │
│  最后联系: 3天前 │
└─────────────────┘
```

2. **列表视图**:
```
┌──────────────────────────────────┐
│ [头像] 张三                      │
│        13800138000               │
│        北京市海淀区              │
└──────────────────────────────────┘
```

**特性**:
- 头像优先显示（本地图片或网络图片）
- 无头像时显示自定义图标
- 使用 `timeago` 库显示相对时间
- 标签以 Chip 形式显示
- 支持点击事件

### InteractionForm 表单

**文件**: `widgets/interaction_form.dart`

**功能**:
- 日期和时间选择器（独立选择）
- 交互内容多行输入
- 参与者选择器（可选择多个联系人）
- 参与者以 Chip 显示，支持删除
- 排除当前联系人（不能作为参与者）

**布局**:
```
Dialog (400px宽度)
├── 标题 (添加/编辑联系记录)
├── 日期选择器 (DatePicker)
├── 时间选择器 (TimePicker)
├── 内容输入框 (多行)
├── 参与者列表 (ContactSelector)
│   └── Chip (可删除)
└── 操作按钮
    ├── 取消
    └── 保存
```

### 多条件过滤栏（融合 wrapper multiFilterItems）

**文件**: `screens/contact_main_view.dart` 的 `_buildFilterItems()`

**筛选维度**（通过 `FilterItem` + `FilterBuilders` 构建，`_applyMultiFilters` 持久化为 `FilterConfig`）:
- **姓名关键词**（`keyword`）: `FilterType.input` + `buildKeywordFilter`
- **创建日期范围**（`createdRange`）: `FilterType.dateRange` + `buildDateRangeFilter`
- **未联系天数**（`uncontacted`）: 单选 7/30/90 天（`buildSingleChoiceFilter`）
- **标签**（`tag`）: `FilterType.tagsMultiple` 多选（OR 逻辑）

**数据链路**: 过滤栏回调 → `_persistFilterConfig` 写入 `FilterConfig` → `getFilteredAndSortedContacts()` 消费；页面加载时 `_loadInitialFilters` 回显已存配置

---

## 控制器层

### ContactController

**文件**: `controllers/contact_controller.dart`

**核心职责**:
- 联系人 CRUD 操作
- 交互记录管理
- 筛选与排序逻辑
- 自动更新最后联系时间
- 路径规范化处理（Windows/Unix兼容）

**重要方法**:

```dart
// 智能筛选和排序
Future<List<Contact>> getFilteredAndSortedContacts() async {
  final contacts = await getAllContacts();
  final filterConfig = await getFilterConfig();
  final sortConfig = await getSortConfig();

  // 应用筛选
  var filteredContacts = contacts.where((contact) {
    // 姓名关键词筛选
    if (filterConfig.nameKeyword != null &&
        !contact.name.toLowerCase().contains(
          filterConfig.nameKeyword!.toLowerCase()
        )) {
      return false;
    }

    // 创建日期范围筛选
    if (filterConfig.startDate != null &&
        contact.createdTime.isBefore(filterConfig.startDate!)) {
      return false;
    }
    if (filterConfig.endDate != null &&
        contact.createdTime.isAfter(
          filterConfig.endDate!.add(const Duration(days: 1))
        )) {
      return false;
    }

    // 未联系天数筛选
    if (filterConfig.uncontactedDays != null) {
      final daysSinceLastContact =
        DateTime.now().difference(contact.lastContactTime).inDays;
      if (daysSinceLastContact < filterConfig.uncontactedDays!) {
        return false;
      }
    }

    // 标签筛选 (OR逻辑)
    if (filterConfig.selectedTags.isNotEmpty &&
        !filterConfig.selectedTags.any((tag) => contact.tags.contains(tag))) {
      return false;
    }

    return true;
  }).toList();

  // 应用排序
  filteredContacts.sort((a, b) {
    int compareResult;
    switch (sortConfig.type) {
      case SortType.name:
        compareResult = a.name.compareTo(b.name);
        break;
      case SortType.createdTime:
        compareResult = a.createdTime.compareTo(b.createdTime);
        break;
      case SortType.lastContactTime:
        compareResult = a.lastContactTime.compareTo(b.lastContactTime);
        break;
      case SortType.contactCount:
        // TODO: 异步问题，需要重构
        compareResult = 0;
        break;
    }
    return sortConfig.isReverse ? -compareResult : compareResult;
  });

  return filteredContacts;
}

// 自动更新最后联系时间
Future<InteractionRecord> addInteraction(
  InteractionRecord interaction,
) async {
  final interactions = await getAllInteractions();
  interactions.add(interaction);
  await saveAllInteractions(interactions);

  // 更新联系人的最后联系时间
  final contact = await getContact(interaction.contactId);
  if (contact != null) {
    final updatedContact = contact.copyWith(
      lastContactTime: interaction.date,
    );
    await updateContact(updatedContact);
  }

  return interaction;
}
```

**路径规范化**:
```dart
String _normalizePath(String filePath) {
  return filePath.replaceAll('/', path.separator);
}

ContactController(this.plugin) {
  contactsKey = _normalizePath('contacts/contacts.json');
  interactionsKey = _normalizePath('contacts/interactions');
  filterConfigKey = _normalizePath('contacts/filter_config');
  sortConfigKey = _normalizePath('contacts/sort_config');
}
```

---

## 事件系统

### 当前状态
联系人插件**未实现事件系统**，但预留了事件接口设计。

### 建议的事件类型

**文件**: `contact_plugin.dart` (待实现)

| 事件名 | 触发时机 | 参数 |
|-------|---------|------|
| `contact_created` | 新建联系人时 | `Contact contact` |
| `contact_updated` | 更新联系人时 | `Contact contact` |
| `contact_deleted` | 删除联系人时 | `String contactId, String name` |
| `interaction_created` | 添加交互记录时 | `InteractionRecord interaction` |
| `interaction_deleted` | 删除交互记录时 | `String interactionId` |

### 事件广播示例（待实现）

```dart
// 在 ContactController 中
Future<Contact> addContact(Contact contact) async {
  final contacts = await getAllContacts();
  contacts.add(contact);
  await saveAllContacts(contacts);

  // 广播事件
  EventManager.instance.broadcast(
    'contact_created',
    ContactCreatedEventArgs(contact),
  );

  return contact;
}
```

---

## 卡片视图

插件在主页提供卡片视图，展示：

**布局**:
```
┌─────────────────────────────┐
│ 👤 联系人                   │
├─────────────────────────────┤
│  联系人总数  │  最近联系人   │
│     15      │       8       │
└─────────────────────────────┘
```

**实现**: `contact_plugin.dart` 中的 `buildCardView()` 方法，UI 位于 `widgets/contact_plugin_card.dart`

**数据来源**:
- 联系人总数: `_controller.getAllContacts().length`
- 最近联系人数: `_controller.getRecentlyContactedCount()` (最近30天)

---

## 国际化

### 支持语言

- 简体中文 (zh)
- 英语 (en)

### 本地化文件

| 文件 | 语言 |
|------|------|
| `l10n/contact_localizations.dart` | 本地化接口 |
| `l10n/contact_localizations_zh.dart` | 中文翻译 |
| `l10n/contact_localizations_en.dart` | 英文翻译 |

### 关键字符串

```dart
abstract class ContactLocalizations {
  String get name;                          // 插件名称
  String get contacts;                      // 联系人
  String get totalContacts;                 // 联系人总数
  String get recentContacts;                // 最近联系人
  String get addContact;                    // 添加联系人
  String get editContact;                   // 编辑联系人
  String get deleteContact;                 // 删除联系人
  String get confirmDelete;                 // 确认删除
  String get deleteConfirmMessage;          // 删除确认消息
  String get noContacts;                    // 无联系人提示

  // 表单字段
  String get nameLabel;                     // 姓名
  String get phoneLabel;                    // 电话
  String get addressLabel;                  // 地址
  String get notesLabel;                    // 备注
  String get nameRequiredError;             // 姓名必填错误
  String get basicInfoTab;                  // 基本信息标签
  String get recordsTab;                    // 记录标签

  // 标签和自定义字段
  String get tags;                          // 标签
  String get addTag;                        // 添加标签
  String get addTagTooltip;                 // 添加标签提示
  String get addCustomField;                // 添加自定义字段
  String get addCustomFieldTooltip;         // 添加自定义字段提示
  String get deleteFieldTooltip;            // 删除字段提示

  // 筛选和排序
  String get filter;                        // 筛选
  String get sortBy;                        // 排序方式
  String get nameKeyword;                   // 姓名关键字
  String get dateRange;                     // 日期范围
  String get startDate;                     // 开始日期
  String get endDate;                       // 结束日期
  String get uncontactedDays;               // 未联系天数
  String get days;                          // 天
  String get noLimit;                       // 无限制
  String get reset;                         // 重置

  // 排序类型
  String get createdTime;                   // 创建时间
  String get lastContactTime;               // 最后联系时间
  String get contactCount;                  // 联系次数

  // 交互记录
  String get addInteractionRecord;          // 添加联系记录
  String get editInteractionRecord;         // 编辑联系记录
  String get dateLabel;                     // 日期
  String get timeLabel;                     // 时间
  String get notes;                         // 备注
  String get notesHint;                     // 备注提示
  String get otherParticipants;             // 其他参与者
  String get addParticipantTooltip;         // 添加参与者提示

  // 其他
  String get upload;                        // 上传
  String get save;                          // 保存
  String get cancel;                        // 取消
  String get saveFirstMessage;              // 请先保存联系人
  String get saveFailedMessage;             // 保存失败消息
  String get formValidationMessage;         // 表单验证消息
  String get errorMessage;                  // 错误消息
}
```

---

## 测试与质量

### 当前状态
- **单元测试**: 无
- **集成测试**: 无
- **已知问题**:
  - `contactCount` 排序存在异步问题
  - 未实现事件系统

### 测试建议

1. **高优先级**:
   - `ContactController.getFilteredAndSortedContacts()` - 测试复杂筛选逻辑
   - `ContactController.addInteraction()` - 测试最后联系时间自动更新
   - `Contact.fromJson()` / `toJson()` - 测试数据序列化
   - 删除联系人时级联删除交互记录
   - 路径规范化逻辑（Windows/Unix兼容性）

2. **中优先级**:
   - 标签管理 - 测试添加/删除标签
   - 自定义字段管理 - 测试键值对操作
   - 筛选逻辑 - 测试各种筛选条件组合
   - 排序逻辑 - 测试四种排序方式
   - 头像上传和显示

3. **低优先级**:
   - UI 交互逻辑
   - 国际化字符串完整性
   - 视图模式切换
   - 卡片视图统计展示

---

## 常见问题 (FAQ)

### Q1: 如何添加新的排序方式？

1. 在 `filter_sort_config.dart` 中扩展 `SortType` 枚举：
```dart
enum SortType {
  name,
  createdTime,
  lastContactTime,
  contactCount,
  birthday, // 新增
}
```

2. 在 `ContactController.getFilteredAndSortedContacts()` 中添加排序逻辑：
```dart
case SortType.birthday:
  compareResult = (a.customFields['生日'] ?? '')
    .compareTo(b.customFields['生日'] ?? '');
  break;
```

3. 在 `contact_plugin.dart` 的 `_getSortTypeName()` 中添加名称映射。

### Q2: 如何修改头像存储位置？

在 `ContactForm` 中修改 `ImagePickerDialog` 的 `saveDirectory` 参数：

```dart
ImagePickerDialog(
  saveDirectory: 'contacts/avatars', // 修改为新路径
  enableCrop: true,
  cropAspectRatio: 1 / 1,
)
```

### Q3: 如何实现按生日提醒功能？

1. 在 `Contact` 模型中添加生日字段：
```dart
DateTime? birthday;
```

2. 创建后台任务检查即将到来的生日：
```dart
Future<List<Contact>> getUpcomingBirthdays(int daysAhead) async {
  final contacts = await getAllContacts();
  final now = DateTime.now();

  return contacts.where((contact) {
    if (contact.birthday == null) return false;

    final nextBirthday = DateTime(
      now.year,
      contact.birthday!.month,
      contact.birthday!.day,
    );

    final diff = nextBirthday.difference(now).inDays;
    return diff >= 0 && diff <= daysAhead;
  }).toList();
}
```

3. 集成本地通知插件（如 `flutter_local_notifications`）推送提醒。

### Q4: 交互记录的参与者有什么用？

参与者功能用于记录多人互动场景，例如：
- **场景**: 与张三和李四一起开会
- **记录**: 在张三的交互记录中，添加参与者李四
- **效果**: 李四的最后联系时间也会更新（当前未实现，需扩展）

**建议扩展**:
```dart
Future<InteractionRecord> addInteraction(
  InteractionRecord interaction,
) async {
  // ... 现有逻辑 ...

  // 更新所有参与者的最后联系时间
  for (final participantId in interaction.participants) {
    final participant = await getContact(participantId);
    if (participant != null) {
      await updateContact(
        participant.copyWith(lastContactTime: interaction.date),
      );
    }
  }

  return interaction;
}
```

### Q5: 如何导出联系人数据？

当前未实现导出功能，建议添加：

```dart
Future<String> exportContactsToVCard() async {
  final contacts = await getAllContacts();
  final buffer = StringBuffer();

  for (final contact in contacts) {
    buffer.writeln('BEGIN:VCARD');
    buffer.writeln('VERSION:3.0');
    buffer.writeln('FN:${contact.name}');
    buffer.writeln('TEL:${contact.phone}');
    if (contact.address != null) {
      buffer.writeln('ADR:${contact.address}');
    }
    if (contact.notes != null) {
      buffer.writeln('NOTE:${contact.notes}');
    }
    buffer.writeln('END:VCARD');
  }

  return buffer.toString();
}
```

### Q6: 筛选中的"未联系天数"如何计算？

通过比较当前时间与 `lastContactTime` 的差值：

```dart
final daysSinceLastContact =
  DateTime.now().difference(contact.lastContactTime).inDays;

if (daysSinceLastContact < filterConfig.uncontactedDays!) {
  return false; // 不符合筛选条件
}
```

例如：设置"未联系天数 >= 30天"，则只显示30天或更久未联系的人。

---

## 目录结构

```
contact/
├── contact_plugin.dart                      # 插件主类（生命周期、JS API 注册、watchOS 数据）
├── contact_js_api.dart                      # JS API 实现（part of contact_plugin.dart）
├── contact_data_selectors.dart              # 数据选择器（part of contact_plugin.dart）
├── screens/
│   ├── contact_main_view.dart               # 插件主视图（搜索、多条件过滤、字母分组列表）
│   ├── contact_detail_screen.dart           # 联系人详情页（头像/标签/基本信息 + 事件/字段编辑）
│   └── contact_records_screen.dart          # 交互记录界面
├── models/
│   ├── contact_model.dart                   # 联系人模型
│   ├── interaction_record_model.dart        # 交互记录模型
│   └── filter_sort_config.dart              # 筛选和排序配置模型
├── controllers/
│   └── contact_controller.dart              # 联系人控制器（核心业务逻辑）
├── widgets/
│   ├── contact_plugin_card.dart             # 首页卡片视图（统计信息）
│   ├── contact_card.dart                    # 联系人卡片组件（双视图）
│   ├── contact_form.dart                    # 联系人表单（创建/编辑）
│   ├── interaction_form.dart                # 交互记录表单
│   ├── filter_dialog.dart                   # 筛选对话框
│   └── contact_selector.dart                # 联系人选择器（多选）
├── utils/
│   └── contact_utils.dart                   # 工具类（格式化、验证）
└── l10n/
    ├── contact_localizations.dart           # 国际化接口
    ├── contact_localizations_zh.dart        # 中文翻译
    └── contact_localizations_en.dart        # 英文翻译
```

---

## 关键实现细节

### 路径规范化机制

使用 `path` 包确保跨平台兼容性：

```dart
String _normalizePath(String filePath) {
  return filePath.replaceAll('/', path.separator);
}

ContactController(this.plugin) {
  // Windows: contacts\contacts.json
  // Unix:    contacts/contacts.json
  contactsKey = _normalizePath('contacts/contacts.json');
}
```

**原因**: Windows 使用反斜杠 `\`，Unix/Linux 使用正斜杠 `/`。

### 头像显示优先级

```dart
Widget _buildAvatar({required double size}) {
  if (contact.avatar != null && contact.avatar!.isNotEmpty) {
    // 1. 优先显示头像
    return FutureBuilder<String>(
      future: contact.avatar!.startsWith('http')
          ? Future.value(contact.avatar!)
          : ImageUtils.getAbsolutePath(contact.avatar),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return contact.avatar!.startsWith('http')
              ? Image.network(snapshot.data!) // 网络图片
              : Image.file(File(snapshot.data!)); // 本地图片
        }
        return _buildIconAvatar(size); // 加载失败显示图标
      },
    );
  }
  // 2. 无头像时显示自定义图标
  return _buildIconAvatar(size);
}

Widget _buildIconAvatar(double size) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: contact.iconColor,
    ),
    child: Icon(contact.icon, color: Colors.white, size: size * 0.5),
  );
}
```

### 最后联系时间自动更新

```dart
Future<InteractionRecord> addInteraction(
  InteractionRecord interaction,
) async {
  // 1. 保存交互记录
  final interactions = await getAllInteractions();
  interactions.add(interaction);
  await saveAllInteractions(interactions);

  // 2. 自动更新联系人的最后联系时间
  final contact = await getContact(interaction.contactId);
  if (contact != null) {
    final updatedContact = contact.copyWith(
      lastContactTime: interaction.date,
    );
    await updateContact(updatedContact);
  }

  return interaction;
}
```

**设计要点**:
- 添加交互记录时，自动同步 `lastContactTime`
- 确保"最近联系人"统计准确
- 支持"未联系天数"筛选功能

### 级联删除机制

```dart
Future<void> deleteContact(String id) async {
  // 1. 删除联系人
  final contacts = await getAllContacts();
  contacts.removeWhere((c) => c.id == id);
  await saveAllContacts(contacts);

  // 2. 级联删除相关的交互记录
  await deleteInteractionsByContactId(id);
}

Future<void> deleteInteractionsByContactId(String contactId) async {
  final interactions = await getAllInteractions();
  interactions.removeWhere((i) => i.contactId == contactId);
  await saveAllInteractions(interactions);
}
```

**原因**: 保持数据一致性，避免孤立的交互记录。

### 异步排序问题

**当前实现的问题**:
```dart
case SortType.contactCount:
  compareResult = 0; // 默认值
  getInteractionsByContactId(a.id).then((aInteractions) {
    getInteractionsByContactId(b.id).then((bInteractions) {
      compareResult = aInteractions.length.compareTo(
        bInteractions.length,
      );
    });
  });
  break;
```

**问题分析**:
- `sort()` 是同步方法，但获取交互记录是异步的
- `compareResult` 总是返回 0，排序无效

**建议修复**:
```dart
Future<List<Contact>> getFilteredAndSortedContacts() async {
  // ... 筛选逻辑 ...

  // 如果需要按联系次数排序，先预加载所有交互记录
  if (sortConfig.type == SortType.contactCount) {
    final interactionCounts = <String, int>{};
    for (final contact in filteredContacts) {
      final interactions = await getInteractionsByContactId(contact.id);
      interactionCounts[contact.id] = interactions.length;
    }

    filteredContacts.sort((a, b) {
      final countA = interactionCounts[a.id] ?? 0;
      final countB = interactionCounts[b.id] ?? 0;
      return sortConfig.isReverse
        ? countB.compareTo(countA)
        : countA.compareTo(countB);
    });
  } else {
    // 其他排序方式（同步）
    filteredContacts.sort((a, b) { /* ... */ });
  }

  return filteredContacts;
}
```

---

## 依赖关系

### 核心依赖

- **BasePlugin**: 插件基类
- **StorageManager**: 数据持久化
- **PluginManager**: 插件管理器
- **ConfigManager**: 配置管理器

### 第三方包依赖

- `uuid: ^4.0.0` - UUID生成
- `path: ^1.8.0` - 路径处理
- `intl: ^0.18.0` - 日期格式化
- `timeago: ^3.0.0` - 相对时间显示

### 内部依赖

- `ImageUtils` - 图片路径处理
- `CircleIconPicker` - 图标选择器组件
- `ImagePickerDialog` - 图片选择器组件

---

## 性能优化建议

### 1. 筛选性能优化

当联系人数量较大时，筛选操作可能成为性能瓶颈：

```dart
// 建议：使用索引加速
class ContactController {
  Map<String, List<Contact>> _tagIndex = {}; // 标签索引

  void _rebuildTagIndex() {
    _tagIndex.clear();
    for (final contact in _contacts) {
      for (final tag in contact.tags) {
        _tagIndex.putIfAbsent(tag, () => []).add(contact);
      }
    }
  }

  Future<List<Contact>> getFilteredContacts() async {
    List<Contact> candidates = await getAllContacts();

    // 先用标签索引缩小范围
    if (filter.selectedTags.isNotEmpty) {
      final Set<Contact> taggedContacts = {};
      for (final tag in filter.selectedTags) {
        taggedContacts.addAll(_tagIndex[tag] ?? []);
      }
      candidates = taggedContacts.toList();
    }

    // 再进行详细过滤
    return candidates.where((contact) { /* ... */ }).toList();
  }
}
```

### 2. 交互记录加载优化

避免在列表视图中重复加载交互记录：

```dart
// 当前实现：每次渲染卡片都会加载
Future<int> getContactInteractionsCount(String contactId) async {
  final interactions = await getInteractionsByContactId(contactId);
  return interactions.length;
}

// 优化：使用缓存
class ContactController {
  Map<String, int> _interactionCountCache = {};

  Future<void> _rebuildInteractionCountCache() async {
    _interactionCountCache.clear();
    final interactions = await getAllInteractions();
    for (final interaction in interactions) {
      _interactionCountCache[interaction.contactId] =
        (_interactionCountCache[interaction.contactId] ?? 0) + 1;
    }
  }

  int getContactInteractionsCount(String contactId) {
    return _interactionCountCache[contactId] ?? 0;
  }
}
```

### 3. 大列表渲染优化

使用 `ListView.builder` 和 `GridView.builder` 而非 `ListView` 和 `GridView`：

```dart
// 当前实现已采用 builder 模式，这是正确的做法
GridView.builder(
  itemCount: contacts.length,
  itemBuilder: (context, index) {
    return ContactCard(
      contact: contacts[index],
      onTap: () => _addOrEditContact(contacts[index]),
    );
  },
)
```

---

## 变更记录 (Changelog)

- **2025-11-13**: 初始化联系人插件文档，识别 13 个文件、3 个数据模型、5 个小部件、筛选与排序系统、交互记录管理、双视图模式

---

**上级目录**: [返回插件目录](../../../CLAUDE.md#模块索引) | [返回根文档](../../../CLAUDE.md)
