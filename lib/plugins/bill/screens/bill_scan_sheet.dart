import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/agent_chat/services/native_tool_agent_service.dart';
import 'package:aboutme/plugins/openai/services/request_service.dart';

import '../bill_plugin.dart';
import '../models/bill.dart';

import 'package:shared_models/shared_models.dart';
/// 拍照记账识别弹层内容（配合 [SmoothBottomSheet] 使用）：
/// 打开即用默认识图能力分析 [imageFile]，展示识别出的账单
/// 多选列表（默认全选），确认后批量保存为账单
class BillScanSheet extends StatefulWidget {
  final BillPlugin billPlugin;
  final String accountId;
  final File imageFile;

  const BillScanSheet({
    super.key,
    required this.billPlugin,
    required this.accountId,
    required this.imageFile,
  });

  @override
  State<BillScanSheet> createState() => _BillScanSheetState();
}

class _BillScanSheetState extends State<BillScanSheet> {
  /// 识别结果条目：{title, amount, isExpense, category, note, date}
  List<Map<String, dynamic>> _items = [];
  final Set<int> _selected = {};
  bool _loading = true;
  String? _error;

  /// 保存进行中：禁用确认按钮，防重复点击产生并发保存
  bool _saving = false;

  /// 识别 prompt：注入当前时间（模型无时间信息时回退用），日期精确到分钟。
  /// 覆盖票据、支付/转账记录、电商/外卖订单列表等消费记录场景
  String get _prompt {
    final now = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
    return '你是记账助手。从图片中提取每一笔收支。图片可以是收据/发票/小票、'
        '支付或转账记录截图、账单月报，也可以是电商购物订单列表'
        '（淘宝/拼多多/京东/美团等订单页，每个订单记一笔）、'
        '外卖/打车/充值等消费记录。'
        '只输出 JSON 数组，不要输出任何解释或代码块标记，每个元素格式：'
        '{"title":"事项名称","amount":12.5,"isExpense":true,'
        '"category":"餐饮","note":"备注或空串","date":"2026-01-01 12:30"}。\n'
        'amount 规则：优先取实付金额；先用后付/待付款/待收货的订单'
        '取应付金额照常记录，不要因当前实付显示 0 而跳过；'
        '多件商品按订单合计或单价×数量计算；收入（退款/工资/转账入账）'
        'isExpense 为 false。\n'
        'date 精确到分钟，格式 yyyy-MM-dd HH:mm：有完整时间按图片识别；'
        '只有日期没有时间时用该日期加当前时间的时分；完全没有时间信息时'
        '用当前时间 $now。\n'
        'category 只能取：餐饮、购物、交通、日用、娱乐、医疗、教育、住房、'
        '工资、奖金、投资、其他。没有识别到任何收支时输出 []。';
  }

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  Future<void> _analyze() async {
    try {
      final agent = await NativeToolAgentService.resolveDefaultImageAgent();
      if (!mounted) return;
      if (agent == null) {
        setState(() {
          _loading = false;
          _error = 'bill_scanNoModel'.tr;
        });
        return;
      }
      final content = await RequestService.chat(
        _prompt,
        agent,
        imageFile: widget.imageFile,
        // 订单列表等场景条目多，放宽输出上限避免 JSON 被截断
        maxTokens: 4000,
      );
      debugPrint('[BillScan] 模型原始返回(${content.length}字符): $content');
      final items = _parseItems(content);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _items = items;
        // 默认全选
        _selected.addAll(Iterable<int>.generate(items.length));
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '${'bill_scanFailed'.tr}: $e';
        });
      }
    }
  }

  /// 从模型回复中提取 JSON 数组（容忍代码块围栏与前后缀文本）
  List<Map<String, dynamic>> _parseItems(String text) {
    final start = text.indexOf('[');
    final end = text.lastIndexOf(']');
    if (start < 0 || end <= start) return [];
    try {
      final decoded = jsonDecode(text.substring(start, end + 1));
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .where((m) => ((m['amount'] as num?)?.toDouble() ?? 0) > 0)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// 解析模型返回的日期（yyyy-MM-dd HH:mm；容忍斜杠分隔符），
  /// 无效时回退当前时间
  DateTime _parseDate(String? raw) {
    final s = raw?.trim();
    if (s == null || s.isEmpty) return DateTime.now();
    return tryParseIsoDateTime(s.replaceAll('/', '-')) ?? DateTime.now();
  }

  Future<void> _confirm() async {
    if (_saving) return;
    setState(() => _saving = true);

    final bills = <Bill>[];
    for (final i in _selected) {
      final item = _items[i];
      final amount = (item['amount'] as num?)?.toDouble() ?? 0;
      if (amount <= 0) continue;
      final isExpense = item['isExpense'] as bool? ?? true;
      final category = (item['category'] as String?)?.trim() ?? '';
      final title =
          (item['title'] as String?)?.trim().isNotEmpty == true
          ? item['title'] as String
          : (category.isEmpty ? '未分类' : category);
      bills.add(
        Bill(
          id: const Uuid().v4(),
          title: title,
          amount: isExpense ? -amount : amount,
          accountId: widget.accountId,
          category: category.isEmpty ? '其他' : category,
          date: _parseDate(item['date'] as String?),
          tag: category.isEmpty ? null : category,
          note: item['note'] as String? ?? '',
        ),
      );
    }
    if (bills.isEmpty) {
      if (mounted) setState(() => _saving = false);
      return;
    }

    // 逐笔保存：单笔失败不中断其余
    var saved = 0;
    Object? lastError;
    for (final bill in bills) {
      try {
        await widget.billPlugin.controller.saveBill(bill);
        saved++;
      } catch (e) {
        lastError = e;
        debugPrint('[BillScan] 保存账单失败: $e');
      }
    }
    debugPrint('[BillScan] 保存完成: $saved/${bills.length} 笔, mounted=$mounted');

    if (!mounted) return;
    // 先关弹层再提示：Toast 异常不阻塞弹层关闭
    Navigator.of(context).pop();
    if (saved > 0) {
      Toast.success('bill_scanAdded'.trParams({'count': '$saved'}));
    }
    if (lastError != null) {
      Toast.error('${'bill_billSaveFailed'.tr}: $lastError');
    }
  }

  @override
  Widget build(BuildContext context) {
    // DS 组件（DSCheckbox 等）依赖 AppTheme 祖先，sheet 内自包桥
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          final screenHeight = MediaQuery.sizeOf(context).height;

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: theme.spacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: theme.spacing.md),
                _buildHeader(theme),
                SizedBox(height: theme.spacing.md),
                if (_loading)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: theme.spacing.xl),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const DSLoadingDots(),
                          SizedBox(height: theme.spacing.md),
                          Text(
                            'bill_scanAnalyzing'.tr,
                            style: DsTypography.body.copyWith(
                              color: theme.textSub,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_error != null)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: theme.spacing.xl),
                    child: Center(
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: DsTypography.body.copyWith(color: theme.danger),
                      ),
                    ),
                  )
                else if (_items.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: theme.spacing.xl),
                    child: Center(
                      child: Text(
                        'bill_scanNoItems'.tr,
                        style: DsTypography.body.copyWith(color: theme.textSub),
                      ),
                    ),
                  )
                else ...[
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: screenHeight * 0.5,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _items.length,
                      separatorBuilder:
                          (_, _) => SizedBox(height: theme.spacing.xs),
                      itemBuilder: (context, index) => _buildItemTile(
                        theme,
                        index,
                      ),
                    ),
                  ),
                  SizedBox(height: theme.spacing.md),
                  DSButton(
                    label: _saving
                        ? 'bill_scanSaving'.tr
                        : 'bill_scanAddSelected'.trParams({
                            'count': '${_selected.length}',
                          }),
                    size: DSButtonSize.lg,
                    onPressed:
                        (_selected.isEmpty || _saving) ? null : _confirm,
                  ),
                ],
                SafeArea(
                  top: false,
                  child: SizedBox(height: theme.spacing.md),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 标题行：标题 + 识别图片缩略图
  Widget _buildHeader(AppThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'bill_scanTitle'.tr,
            style: DsTypography.title.copyWith(
              color: theme.text,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ClipRRect(
          borderRadius: theme.radii.sm,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Image.file(
              widget.imageFile,
              fit: BoxFit.cover,
              errorBuilder:
                  (_, _, _) => Container(
                    color: theme.stroke,
                    child: Center(
                      child: DsIcon(
                        DsIconKind.image,
                        size: 18,
                        color: theme.textSub,
                      ),
                    ),
                  ),
            ),
          ),
        ),
      ],
    );
  }

  /// 识别结果行：勾选框 + 标题/分类/备注 + 金额（支出红/收入绿）
  Widget _buildItemTile(AppThemeData theme, int index) {
    final item = _items[index];
    final isExpense = item['isExpense'] as bool? ?? true;
    final amount = (item['amount'] as num?)?.toDouble() ?? 0;
    final category = (item['category'] as String?) ?? '';
    final note = (item['note'] as String?)?.trim() ?? '';
    final selected = _selected.contains(index);

    return GestureDetector(
      onTap: () => setState(() {
        _selected.contains(index) ? _selected.remove(index) : _selected.add(index);
      }),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.sm,
          vertical: theme.spacing.xs,
        ),
        decoration: BoxDecoration(
          color: theme.surfaceAlt.withValues(alpha: 0.5),
          borderRadius: theme.radii.md,
        ),
        child: Row(
          children: [
            DSCheckbox(
              value: selected,
              onChanged:
                  (_) => setState(() {
                    _selected.contains(index)
                        ? _selected.remove(index)
                        : _selected.add(index);
                  }),
            ),
            SizedBox(width: theme.spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (item['title'] as String?)?.trim().isNotEmpty == true
                        ? item['title'] as String
                        : (category.isEmpty ? '未分类' : category),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DsTypography.body.copyWith(color: theme.text),
                  ),
                  Builder(
                    builder: (context) {
                      final dateText = DateFormat(
                        'yyyy-MM-dd HH:mm',
                      ).format(_parseDate(item['date'] as String?));
                      return Text(
                        note.isEmpty ? dateText : '$dateText · $note',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DsTypography.caption.copyWith(
                          color: theme.textSub,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            if (category.isNotEmpty) ...[
              DSChip(label: category, selected: false),
              SizedBox(width: theme.spacing.sm),
            ],
            Text(
              '${isExpense ? '-' : '+'}¥${amount.toStringAsFixed(2)}',
              style: DsTypography.body.copyWith(
                fontWeight: FontWeight.bold,
                color: isExpense ? theme.danger : Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
