import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';

import 'gallery_section.dart';

/// skribble 原生组件示例 · 输入与选择
class SkribbleInputsSection extends StatefulWidget {
  const SkribbleInputsSection({super.key});

  @override
  State<SkribbleInputsSection> createState() => _SkribbleInputsSectionState();
}

class _SkribbleInputsSectionState extends State<SkribbleInputsSection> {
  bool _check = true;
  bool? _checkTristate;
  String _radio = 'a';
  String? _combo;
  bool _choiceChip = false;
  bool _filterChip = false;
  final _searchCtrl = TextEditingController();
  final _inputCtrl = TextEditingController();
  DateTime? _date;
  String? _calendarDay;
  TimeOfDay? _time;
  Color _color = const Color(0xFF885CF6);

  static const _fruits = ['苹果 Apple', '香蕉 Banana', '樱桃 Cherry', '葡萄 Grape'];

  @override
  void dispose() {
    _searchCtrl.dispose();
    _inputCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      index: 'SK-2',
      title: 'skribble 输入选择',
      children: [
        DemoBlock(
          label: 'WiredInput / WiredTextArea',
          child: Column(
            children: [
              SizedBox(
                width: 280,
                child: WiredInput(
                  controller: _inputCtrl,
                  hintText: 'Type something…',
                  onChanged: (_) {},
                ),
              ),
              const SizedBox(height: 8),
              const SizedBox(
                width: 280,
                child: WiredTextArea(hintText: 'Multiline input…'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        DemoBlock(
          label: 'WiredSearchBar / WiredAutocomplete',
          child: Column(
            children: [
              SizedBox(
                width: 280,
                child: WiredSearchBar(
                  controller: _searchCtrl,
                  hintText: 'Search…',
                  onChanged: (_) {},
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 280,
                child: WiredAutocomplete(
                  options: _fruits,
                  displayStringForOption: (s) => s,
                  onSelected: (_) {},
                  hintText: 'Autocomplete…',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        DemoBlock(
          label: 'WiredCheckbox / WiredRadio',
          child: Column(
            children: [
              WiredCheckbox(
                value: _check,
                onChanged: (v) => setState(() => _check = v ?? false),
              ),
              const SizedBox(height: 8),
              WiredCheckbox(
                value: _checkTristate,
                onChanged: (v) => setState(() => _checkTristate = v),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final v in const ['a', 'b', 'c']) ...[
                    WiredRadio<String>(
                      value: v,
                      groupValue: _radio,
                      // 受控协议：返回 bool 表示接受
                      onChanged: (nv) {
                        setState(() => _radio = nv ?? 'a');
                        return true;
                      },
                    ),
                    const SizedBox(width: 12),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        DemoBlock(
          label: 'WiredCombo',
          child: WiredCombo<String>(
            value: _combo,
            items: const [
              DropdownMenuItem(value: 'flutter', child: Text('Flutter')),
              DropdownMenuItem(value: 'dart', child: Text('Dart')),
              DropdownMenuItem(value: 'skribble', child: Text('Skribble')),
            ],
            onChanged: (v) {
              setState(() => _combo = v);
              return true;
            },
          ),
        ),
        const SizedBox(height: 16),
        DemoBlock(
          label: 'Chip 家族：Chip/Choice/Filter/Input',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              const WiredChip(label: Text('Chip')),
              WiredChoiceChip(
                label: const Text('Choice'),
                selected: _choiceChip,
                onSelected: (v) => setState(() => _choiceChip = v),
              ),
              WiredFilterChip(
                label: const Text('Filter'),
                selected: _filterChip,
                onSelected: (v) => setState(() => _filterChip = v),
              ),
              WiredInputChip(label: const Text('Input'), onDeleted: () {}),
            ],
          ),
        ),
        const SizedBox(height: 16),
        DemoBlock(
          label:
              'WiredDatePicker（${_date != null ? _date!.toString().substring(0, 10) : '未选'}）',
          child: WiredDatePicker(
            initialDate: _date,
            onDateSelected: (d) => setState(() => _date = d),
          ),
        ),
        const SizedBox(height: 16),
        DemoBlock(
          label: 'WiredCalendar（${_calendarDay ?? 'yyyy-MM-dd 字符串协议'}）',
          // WiredCalendar 内部用 Expanded，需要 bounded 高度
          child: SizedBox(
            height: 420,
            child: WiredCalendar(
              selected: _calendarDay,
              onSelected: (day) => setState(() => _calendarDay = day),
            ),
          ),
        ),
        const SizedBox(height: 16),
        DemoBlock(
          label: 'WiredTimePicker（${_time?.format(context) ?? '未选'}）',
          child: WiredTimePicker(
            initialTime: _time,
            onTimeSelected: (t) => setState(() => _time = t),
          ),
        ),
        const SizedBox(height: 16),
        DemoBlock(
          label: 'WiredColorPicker',
          child: WiredColorPicker(
            selectedColor: _color,
            onColorChanged: (c) => setState(() => _color = c),
          ),
        ),
      ],
    );
  }
}
