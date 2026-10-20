import 'package:aboutme/widgets/run_receipt_printer.dart';
import 'package:aboutme/widgets/thermal_printer.dart';
import 'package:flutter/material.dart';

/// 热敏打印账单组件示例页
class RunReceiptPrinterExample extends StatelessWidget {
  const RunReceiptPrinterExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('热敏打印账单'),
        actions: [
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const _CustomContentExample(),
              ),
            ),
            child: const Text('自定义内容'),
          ),
        ],
      ),
      body: const SafeArea(child: RunReceiptPrinter()),
    );
  }
}

/// 通用 ThermalPrinter + 外部参数化内容的最小用法示例
class _CustomContentExample extends StatelessWidget {
  const _CustomContentExample();

  @override
  Widget build(BuildContext context) {
    const mono = TextStyle(fontFamily: 'monospace', color: Color(0xFF141414));
    return Scaffold(
      appBar: AppBar(title: const Text('自定义打印内容')),
      body: const SafeArea(
        child: ThermalPrinter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(22, 26, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'MY RECEIPT',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111111),
                  ),
                ),
                SizedBox(height: 12),
                ReceiptDivider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('COFFEE', style: mono),
                    Text('¥ 28.00', style: mono),
                  ],
                ),
                SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('BAGEL', style: mono),
                    Text('¥ 15.00', style: mono),
                  ],
                ),
                ReceiptDivider(),
                Text(
                  'THANK YOU!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111111),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
