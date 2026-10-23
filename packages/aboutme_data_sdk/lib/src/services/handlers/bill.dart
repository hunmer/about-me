import 'dart:convert';

import '../../storage_errors.dart';
import '../plugin_data.dart';
import '../types.dart';
import '../utils.dart';

// Bill 插件专用处理器（移植自 nodejs handlers/bill.ts）。
//
// 数据格式：accounts.json 文件包含账户列表，每个账户有嵌套的 bills 数组
// 账户可能是 JSON 编码的字符串或 Map 对象

PluginHandlers createBillHandlers(PluginData data) {
  // 解码单个账户（兼容 JSON 编码字符串与 Map 两种格式；无法解析返回 null）
  Map<String, dynamic>? decodeAccount(dynamic a) {
    if (a is Map) return Map<String, dynamic>.from(a);
    if (a is String) {
      try {
        final decoded = jsonDecode(a);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        // JSON 解析失败 → null → 调用方按无效数据处理
      }
    }
    return null;
  }

  // 读取所有账户（包含嵌套的账单）
  Future<List<Map<String, dynamic>>> readAllAccounts() async {
    final accountsData = await data.read('bill', 'accounts.json');
    if (accountsData is! Map) return [];

    final accountsRaw = accountsData['accounts'];
    if (accountsRaw is! List) return [];

    final accounts = <Map<String, dynamic>>[];
    for (final a in accountsRaw) {
      final decoded = decodeAccount(a);
      if (decoded != null) {
        accounts.add(decoded);
      }
    }
    return accounts.where((a) => a.isNotEmpty).toList();
  }

  // 保存所有账户
  Future<void> saveAllAccounts(List<Map<String, dynamic>> accounts) {
    return data.write(
      'bill',
      'accounts.json',
      {'accounts': accounts.map((a) => jsonEncode(a)).toList()},
    );
  }

  // 读取所有订阅（subscriptions.json；缺文件视为空，结构损坏明确报错）
  Future<List<Map<String, dynamic>>> readAllSubscriptions() async {
    final raw = await data.read('bill', 'subscriptions.json');
    if (raw == null) return [];
    if (raw is! Map) {
      throw const StorageException(StorageErrorKind.invalidData, '订阅数据结构损坏');
    }
    final list = raw['subscriptions'];
    if (list == null) return [];
    if (list is! List || list.any((e) => e is! Map)) {
      throw const StorageException(StorageErrorKind.invalidData, '订阅数据结构损坏');
    }
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // 保存所有订阅（对象数组格式，与客户端 Subscription.toJson 字段一致）
  Future<void> saveAllSubscriptions(List<Map<String, dynamic>> subscriptions) {
    return data.write('bill', 'subscriptions.json', {
      'subscriptions': subscriptions,
    });
  }

  // 将客户端格式的账单转换为标准格式
  Map<String, dynamic> convertClientBillToDto(Map<String, dynamic> bill) {
    final amount = _numOrZero(bill['amount']);
    final type = amount >= 0 ? 'income' : 'expense';

    final defaults = <String, dynamic>{
      'id': _truthy(bill['id']) ? bill['id'] : generateUUID(),
      'accountId': _truthy(bill['accountId']) ? bill['accountId'] : '',
      'amount': amount.abs(),
      'type': type,
      'category': _truthy(bill['category']) ? bill['category'] : '其他',
      'description': _truthy(bill['description'])
          ? bill['description']
          : (_truthy(bill['note']) ? bill['note'] : ''),
      'date': _truthy(bill['date'])
          ? bill['date']
          : (_truthy(bill['createdAt'])
                ? bill['createdAt']
                : jsIsoDateTime(DateTime.now())),
      'createdAt': _truthy(bill['createdAt'])
          ? bill['createdAt']
          : jsIsoDateTime(DateTime.now()),
      'updatedAt': _truthy(bill['updatedAt'])
          ? bill['updatedAt']
          : jsIsoDateTime(DateTime.now()),
      'tags': _truthy(bill['tags'])
          ? bill['tags']
          : (_truthy(bill['tag']) ? [bill['tag']] : <dynamic>[]),
    };

    // ...bill 保留其他字段（bill 自身字段覆盖默认值，与 TS 展开顺序一致）
    return {...defaults, ...bill};
  }

  // 转换为 AccountDto（不包含账单列表）
  Map<String, dynamic> accountDto(Map<String, dynamic> a) {
    final dto = <String, dynamic>{};
    dto['id'] = a['id'];
    // name: a.name || a.title（两者皆空时不输出该键，与 JSON.stringify 丢弃 undefined 一致）
    if (_truthy(a['name'])) {
      dto['name'] = a['name'];
    } else if (_truthy(a['title'])) {
      dto['name'] = a['title'];
    }
    dto['balance'] = a['balance'] ?? a['totalAmount'] ?? 0;
    if (_truthy(a['icon'])) {
      dto['icon'] = a['icon'];
    } else if (_truthy(a['iconCodePoint'])) {
      dto['icon'] = a['iconCodePoint'].toString();
    }
    if (_truthy(a['color'])) {
      dto['color'] = a['color'];
    } else if (_truthy(a['backgroundColor'])) {
      final bg = a['backgroundColor'];
      final code = bg is num ? bg.toInt() : 0;
      dto['color'] = '#${code.toRadixString(16).padLeft(8, '0')}';
    }
    dto['createdAt'] = a['createdAt'];
    dto['updatedAt'] = a['updatedAt'];
    return dto;
  }

  // 获取账单列表（getBills 与 getBillsByAccount 共用逻辑，TS 中为避免 this 而复制了一份）
  Future<PluginResult> listBills(
    PluginData data,
    Map<String, dynamic> params,
  ) async {
    try {
      final accounts = await readAllAccounts();
      final accountId = params['accountId'];
      final allBills = <Map<String, dynamic>>[];

      for (final account in accounts) {
        if (_truthy(accountId) && account['id'] != accountId) continue;
        final bills = account['bills'];
        if (bills is! List) continue;
        allBills.addAll(
          bills
              .whereType<Map>()
              .map((b) => convertClientBillToDto(Map<String, dynamic>.from(b))),
        );
      }

      // 按日期排序（最新在前）
      allBills.sort((a, b) {
        final aDate = (a['date'] as String?) ?? '';
        final bDate = (b['date'] as String?) ?? '';
        return bDate.compareTo(aDate);
      });

      return PluginResult.success(
        createPaginatedResult(
          allBills,
          offset: params['offset'] as int?,
          count: params['count'] as int?,
        ),
      );
    } catch (e) {
      return PluginResult.failure('获取账单失败: $e');
    }
  }

  // 创建账单（createBill 与 createBillForAccount 共用逻辑）
  Future<PluginResult> createBillImpl(
    PluginData data,
    Map<String, dynamic> params,
  ) async {
    try {
      final accounts = await readAllAccounts();
      final accountIndex = accounts.indexWhere(
        (a) => a['id'] == params['accountId'],
      );

      if (accountIndex == -1) {
        return const PluginResult.failure('账户不存在', 'NOT_FOUND');
      }

      final now = jsIsoDateTime(DateTime.now());
      final newBill = <String, dynamic>{
        ...params,
        'id':
            params['id'] != null && params['id'].toString().isNotEmpty
            ? params['id']
            : generateUUID(),
        'createdAt': now,
        'updatedAt': now,
      };

      final account = accounts[accountIndex];
      final bills = account['bills'] is List
          ? account['bills'] as List
          : <dynamic>[];
      bills.add(newBill);
      account['bills'] = bills;

      // 更新账户余额
      final amount = _numOrZero(params['amount']);
      final currentBalance =
          _numOrNull(account['balance']) ??
          _numOrNull(account['totalAmount']) ??
          0;
      account['balance'] = currentBalance + amount;
      account['updatedAt'] = now;

      await saveAllAccounts(accounts);
      return PluginResult.success(convertClientBillToDto(newBill));
    } catch (e) {
      return PluginResult.failure('创建账单失败: $e');
    }
  }

  return {
    // 获取账户列表
    'getList': (data, params) async {
      try {
        final accounts = await readAllAccounts();
        final accountDtos = accounts.map(accountDto).toList();

        return PluginResult.success(
          createPaginatedResult(
            accountDtos,
            offset: params['offset'] as int?,
            count: params['count'] as int?,
          ),
        );
      } catch (e) {
        return PluginResult.failure('获取账户失败: $e');
      }
    },

    // 根据 ID 获取账户
    'getById': (data, params) async {
      try {
        final accounts = await readAllAccounts();
        final index = accounts.indexWhere((a) => a['id'] == params['id']);

        if (index == -1) {
          return const PluginResult.failure('账户不存在', 'NOT_FOUND');
        }

        return PluginResult.success(accountDto(accounts[index]));
      } catch (e) {
        return PluginResult.failure('获取账户失败: $e');
      }
    },

    // 创建账户
    'create': (data, params) async {
      try {
        final accounts = await readAllAccounts();
        final now = jsIsoDateTime(DateTime.now());

        final newAccount = <String, dynamic>{
          ...params,
          'id':
              params['id'] != null && params['id'].toString().isNotEmpty
              ? params['id']
              : generateUUID(),
          'bills': <dynamic>[],
          'createdAt': now,
          'updatedAt': now,
        };

        accounts.add(newAccount);
        await saveAllAccounts(accounts);

        return PluginResult.success(newAccount);
      } catch (e) {
        return PluginResult.failure('创建账户失败: $e');
      }
    },

    // 更新账户
    'update': (data, params) async {
      try {
        final accounts = await readAllAccounts();
        final index = accounts.indexWhere((a) => a['id'] == params['id']);

        if (index == -1) {
          return const PluginResult.failure('账户不存在', 'NOT_FOUND');
        }

        final updatedAccount = <String, dynamic>{
          ...accounts[index],
          ...params,
          'updatedAt': jsIsoDateTime(DateTime.now()),
        };
        accounts[index] = updatedAccount;

        await saveAllAccounts(accounts);
        return PluginResult.success(updatedAccount);
      } catch (e) {
        return PluginResult.failure('更新账户失败: $e');
      }
    },

    // 删除账户
    'delete': (data, params) async {
      try {
        final accounts = await readAllAccounts();
        final initialLength = accounts.length;
        final filtered = accounts
            .where((a) => a['id'] != params['id'])
            .toList();

        if (filtered.length == initialLength) {
          return const PluginResult.failure('账户不存在', 'NOT_FOUND');
        }

        await saveAllAccounts(filtered);
        return PluginResult.success({'id': params['id']});
      } catch (e) {
        return PluginResult.failure('删除账户失败: $e');
      }
    },

    // 获取账单列表
    'getBills': listBills,

    // 获取单个账单
    'getBillById': (data, params) async {
      try {
        final accounts = await readAllAccounts();

        for (final account in accounts) {
          final bills = account['bills'];
          if (bills is! List) continue;
          for (final b in bills) {
            if (b is Map && b['id'] == params['id']) {
              return PluginResult.success(
                convertClientBillToDto(Map<String, dynamic>.from(b)),
              );
            }
          }
        }

        return const PluginResult.failure('账单不存在', 'NOT_FOUND');
      } catch (e) {
        return PluginResult.failure('获取账单失败: $e');
      }
    },

    // 创建账单
    'createBill': createBillImpl,

    // 更新账单
    'updateBill': (data, params) async {
      try {
        final accounts = await readAllAccounts();

        for (var i = 0; i < accounts.length; i++) {
          final account = accounts[i];
          final bills = account['bills'];
          if (bills is! List) continue;

          var billIndex = -1;
          for (var j = 0; j < bills.length; j++) {
            final b = bills[j];
            if (b is Map && b['id'] == params['id']) {
              billIndex = j;
              break;
            }
          }

          if (billIndex != -1) {
            final oldBill = Map<String, dynamic>.from(bills[billIndex] as Map);
            final oldAmount = _numOrZero(oldBill['amount']);
            final newAmount = _numOrZero(params['amount']);

            final updatedBill = <String, dynamic>{
              ...oldBill,
              ...params,
              'updatedAt': jsIsoDateTime(DateTime.now()),
            };
            bills[billIndex] = updatedBill;
            account['bills'] = bills;

            // 更新账户余额
            final currentBalance =
                _numOrNull(account['balance']) ??
                _numOrNull(account['totalAmount']) ??
                0;
            account['balance'] = currentBalance - oldAmount + newAmount;
            account['updatedAt'] = jsIsoDateTime(DateTime.now());

            await saveAllAccounts(accounts);
            return PluginResult.success(convertClientBillToDto(updatedBill));
          }
        }

        return const PluginResult.failure('账单不存在', 'NOT_FOUND');
      } catch (e) {
        return PluginResult.failure('更新账单失败: $e');
      }
    },

    // 删除账单
    'deleteBill': (data, params) async {
      try {
        final accounts = await readAllAccounts();

        for (var i = 0; i < accounts.length; i++) {
          final account = accounts[i];
          final bills = account['bills'];
          if (bills is! List) continue;

          var billIndex = -1;
          for (var j = 0; j < bills.length; j++) {
            final b = bills[j];
            if (b is Map && b['id'] == params['id']) {
              billIndex = j;
              break;
            }
          }

          if (billIndex != -1) {
            final oldBill = bills[billIndex] as Map;
            final oldAmount = _numOrZero(oldBill['amount']);

            bills.removeAt(billIndex);
            account['bills'] = bills;

            // 更新账户余额
            final currentBalance =
                _numOrNull(account['balance']) ??
                _numOrNull(account['totalAmount']) ??
                0;
            account['balance'] = currentBalance - oldAmount;
            account['updatedAt'] = jsIsoDateTime(DateTime.now());

            await saveAllAccounts(accounts);
            return PluginResult.success({'id': params['id']});
          }
        }

        return const PluginResult.failure('账单不存在', 'NOT_FOUND');
      } catch (e) {
        return PluginResult.failure('删除账单失败: $e');
      }
    },

    // 按账户获取账单
    'getBillsByAccount': listBills,

    // 为账户创建账单
    'createBillForAccount': createBillImpl,

    // 获取统计
    'getStats': (data, params) async {
      try {
        final accounts = await readAllAccounts();
        num totalIncome = 0;
        num totalExpense = 0;
        var billCount = 0;

        for (final account in accounts) {
          final bills = account['bills'];
          if (bills is! List) continue;
          for (final bill in bills) {
            if (bill is! Map) continue;
            final amount = _numOrZero(bill['amount']);

            if (amount >= 0) {
              totalIncome += amount;
            } else {
              totalExpense += amount.abs();
            }
            billCount++;
          }
        }

        return PluginResult.success({
          'totalIncome': totalIncome,
          'totalExpense': totalExpense,
          'balance': totalIncome - totalExpense,
          'billCount': billCount,
          'accountCount': accounts.length,
        });
      } catch (e) {
        return PluginResult.failure('获取统计失败: $e');
      }
    },

    // 获取账户完整数据（含内嵌账单原样字段；getList 返回的是 DTO，不含账单）
    'getAccountsWithBills': (data, params) async {
      try {
        final accounts = await readAllAccounts();
        return PluginResult.success(
          createPaginatedResult(
            accounts,
            offset: params['offset'] as int?,
            count: params['count'] as int? ?? accounts.length,
          ),
        );
      } catch (e) {
        return PluginResult.failure('获取账户失败: $e');
      }
    },

    // 整表保存账户（客户端内存态全量回写，落盘保持 JSON 字符串数组格式）
    'saveAccounts': (data, params) async {
      try {
        final raw = params['accounts'];
        if (raw is! List) {
          return const PluginResult.failure('accounts 必须为数组', 'INVALID_PARAMS');
        }
        final accounts = <Map<String, dynamic>>[];
        for (final item in raw) {
          final account = decodeAccount(item);
          if (account == null || account.isEmpty) {
            return const PluginResult.failure('账户格式非法', 'INVALID_PARAMS');
          }
          accounts.add(account);
        }
        await saveAllAccounts(accounts);
        return PluginResult.success({'count': accounts.length});
      } catch (e) {
        return PluginResult.failure('保存账户失败: $e');
      }
    },

    // 获取订阅列表
    'getSubscriptions': (data, params) async {
      try {
        final subscriptions = await readAllSubscriptions();
        return PluginResult.success(
          createPaginatedResult(
            subscriptions,
            offset: params['offset'] as int?,
            count: params['count'] as int? ?? subscriptions.length,
          ),
        );
      } on StorageException catch (e) {
        return PluginResult.failure(e.message, 'CORRUPT_DATA');
      } catch (e) {
        return PluginResult.failure('获取订阅失败: $e');
      }
    },

    // 创建订阅（字段与客户端 Subscription.toJson 一致）
    'createSubscription': (data, params) async {
      try {
        if (params['name'] is! String ||
            (params['name'] as String).trim().isEmpty) {
          return const PluginResult.failure(
            '订阅名称必须为非空字符串',
            'INVALID_PARAMS',
          );
        }
        if (params['days'] is! int || (params['days'] as int) <= 0) {
          return const PluginResult.failure(
            'days 必须为正整数',
            'INVALID_PARAMS',
          );
        }
        if (params['totalAmount'] is! num) {
          return const PluginResult.failure(
            'totalAmount 必须为数值',
            'INVALID_PARAMS',
          );
        }
        if (params['startDate'] is! String ||
            DateTime.tryParse(params['startDate'] as String) == null) {
          return const PluginResult.failure(
            'startDate 必须为 ISO 日期',
            'INVALID_PARAMS',
          );
        }

        final subscriptions = await readAllSubscriptions();
        final id =
            params['id'] != null && params['id'].toString().isNotEmpty
            ? params['id']
            : generateUUID();
        if (subscriptions.any((s) => s['id'] == id)) {
          return const PluginResult.failure('订阅已存在', 'CONFLICT');
        }

        final now = jsIsoDateTime(DateTime.now());
        final subscription = <String, dynamic>{
          ...params,
          'id': id,
          'createdAt': _truthy(params['createdAt'])
              ? params['createdAt']
              : now,
          'updatedAt': now,
        };

        subscriptions.add(subscription);
        await saveAllSubscriptions(subscriptions);
        return PluginResult.success(subscription);
      } on StorageException catch (e) {
        return PluginResult.failure(e.message, 'CORRUPT_DATA');
      } catch (e) {
        return PluginResult.failure('创建订阅失败: $e');
      }
    },

    // 更新订阅（合并保留未传字段；终止订阅 = isActive: false）
    'updateSubscription': (data, params) async {
      try {
        final subscriptions = await readAllSubscriptions();
        final index = subscriptions.indexWhere((s) => s['id'] == params['id']);

        if (index == -1) {
          return const PluginResult.failure('订阅不存在', 'NOT_FOUND');
        }

        final updated = <String, dynamic>{
          ...subscriptions[index],
          ...params,
          'updatedAt': jsIsoDateTime(DateTime.now()),
        };
        subscriptions[index] = updated;

        await saveAllSubscriptions(subscriptions);
        return PluginResult.success(updated);
      } on StorageException catch (e) {
        return PluginResult.failure(e.message, 'CORRUPT_DATA');
      } catch (e) {
        return PluginResult.failure('更新订阅失败: $e');
      }
    },

    // 删除订阅（不影响已生成的账单）
    'deleteSubscription': (data, params) async {
      try {
        final subscriptions = await readAllSubscriptions();
        final filtered = subscriptions
            .where((s) => s['id'] != params['id'])
            .toList();

        if (filtered.length == subscriptions.length) {
          return const PluginResult.failure('订阅不存在', 'NOT_FOUND');
        }

        await saveAllSubscriptions(filtered);
        return PluginResult.success({'id': params['id']});
      } on StorageException catch (e) {
        return PluginResult.failure(e.message, 'CORRUPT_DATA');
      } catch (e) {
        return PluginResult.failure('删除订阅失败: $e');
      }
    },
  };
}

/// 模拟 JS `(x as number) || 0`：非数值/空值按 0 处理。
num _numOrZero(dynamic v) {
  if (v is num) return v;
  final parsed = num.tryParse(v?.toString() ?? '');
  return parsed ?? 0;
}

/// 模拟 JS `(x as number) ?? (y as number) ?? 0` 回退链：
/// 无法解析时返回 null 以便继续回退到下一候选值。
num? _numOrNull(dynamic v) {
  if (v is num) return v;
  return num.tryParse(v?.toString() ?? '');
}

/// 模拟 JS 真值判断（null/false/0/''/NaN 为假，其余为真）。
bool _truthy(dynamic v) {
  if (v == null) return false;
  if (v is bool) return v;
  if (v is num) return v != 0 && !v.isNaN;
  if (v is String) return v.isNotEmpty;
  return true; // List/Map 对象在 JS 中为真
}
