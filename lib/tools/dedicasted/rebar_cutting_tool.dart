import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import 'tool_kit.dart';

const _diameters = [8, 10, 12, 14, 16, 18, 20, 22, 25, 28, 32];
const _categories = <List<String>>[
  ['foundation', 'فونداسیون'],
  ['column', 'ستون'],
  ['roof', 'سقف'],
  ['beam', 'تیر'],
  ['wall', 'دیوار'],
  ['other', 'سایر'],
];

class _Bar {
  final List<double> items;
  double remaining;
  _Bar(this.items, this.remaining);
}

class _DiaResult {
  final int diameter;
  final int piecesCount, barsNeeded;
  final double totalStockLength, totalUsedLength, totalWaste, wastePercent, totalWeight;
  final List<_Bar> bars;
  final List<double> oversized;
  _DiaResult(this.diameter, this.piecesCount, this.barsNeeded, this.totalStockLength, this.totalUsedLength,
      this.totalWaste, this.wastePercent, this.totalWeight, this.bars, this.oversized);
}

({List<_Bar> bars, List<double> oversized}) _optimize(List<double> pieceLengths, double stockLength) {
  final sorted = [...pieceLengths]..sort((a, b) => b.compareTo(a));
  final bars = <_Bar>[];
  final oversized = <double>[];
  for (final len in sorted) {
    if (len > stockLength) {
      oversized.add(len);
      continue;
    }
    var bestIdx = -1;
    var bestRemaining = double.infinity;
    for (var i = 0; i < bars.length; i++) {
      final bar = bars[i];
      if (bar.remaining >= len && bar.remaining - len < bestRemaining) {
        bestRemaining = bar.remaining - len;
        bestIdx = i;
      }
    }
    if (bestIdx != -1) {
      bars[bestIdx].items.add(len);
      bars[bestIdx].remaining -= len;
    } else {
      bars.add(_Bar([len], stockLength - len));
    }
  }
  return (bars: bars, oversized: oversized);
}

class _RowItem {
  final int id;
  final String category;
  final int diameter;
  final double cutLength;
  final int quantity;
  _RowItem(this.id, this.category, this.diameter, this.cutLength, this.quantity);
}

class RebarCuttingTool extends StatefulWidget {
  final String title, description;
  const RebarCuttingTool({super.key, required this.title, required this.description});
  @override
  State<RebarCuttingTool> createState() => _RebarCuttingToolState();
}

class _RebarCuttingToolState extends State<RebarCuttingTool> {
  final List<_RowItem> _rows = [];
  String _category = 'foundation';
  int _diameter = 12;
  final _cut = TextEditingController();
  final _qty = TextEditingController();
  final _stock = TextEditingController(text: '12');
  final _project = TextEditingController();
  List<_DiaResult>? _results;
  String _error = '';
  String _copyMsg = '';
  bool _exporting = false;

  @override
  void dispose() {
    for (final c in [_cut, _qty, _stock, _project]) {
      c.dispose();
    }
    super.dispose();
  }

  double get _stockLength => nv(_stock.text);

  void _addRow() {
    final len = nv(_cut.text);
    final qty = nv(_qty.text).truncate();
    if (len <= 0) {
      setState(() => _error = 'طول برش را درست وارد کنید.');
      return;
    }
    if (qty <= 0) {
      setState(() => _error = 'تعداد را درست وارد کنید.');
      return;
    }
    setState(() {
      _error = '';
      _rows.add(_RowItem(DateTime.now().millisecondsSinceEpoch, _category, _diameter, len, qty));
      _cut.clear();
      _qty.clear();
    });
  }

  void _calculate() {
    if (_rows.isEmpty) {
      setState(() => _error = 'حداقل یک ردیف میلگرد اضافه کنید.');
      return;
    }
    final stockLength = _stockLength;
    final byDia = <int, List<double>>{};
    for (final r in _rows) {
      final l = byDia.putIfAbsent(r.diameter, () => []);
      for (var i = 0; i < r.quantity; i++) {
        l.add(r.cutLength);
      }
    }
    final keys = byDia.keys.toList()..sort();
    final out = <_DiaResult>[];
    for (final d in keys) {
      final pieces = byDia[d]!;
      final o = _optimize(pieces, stockLength);
      final totalStock = o.bars.length * stockLength;
      final overSum = o.oversized.fold<double>(0, (s, p) => s + p);
      final used = pieces.fold<double>(0, (s, p) => s + p) - overSum;
      final waste = totalStock - used;
      final wastePct = totalStock > 0 ? (waste / totalStock) * 100 : 0.0;
      final wpm = (d * d) / 162;
      final weight = (used + overSum) * wpm;
      out.add(_DiaResult(d, pieces.length, o.bars.length, totalStock, used, waste, wastePct, weight, o.bars, o.oversized));
    }
    setState(() {
      _error = '';
      _results = out;
    });
  }

  void _reset() => setState(() {
        _rows.clear();
        _results = null;
        _error = '';
        _copyMsg = '';
      });

  String _summaryText() {
    final proj = _project.text.trim();
    final lines = <String>[
      'خلاصه لیستوفر میلگرد${proj.isNotEmpty ? ' - $proj' : ''}',
      'طول شاخه: ${plain(_stockLength)} متر',
      '―――――――――――――――――',
    ];
    var gw = 0.0;
    var gb = 0;
    for (final r in _results!) {
      gw += r.totalWeight;
      gb += r.barsNeeded;
      lines.add(
          'Ø${r.diameter} | ${r.barsNeeded} شاخه | مصرف ${fixed(r.totalUsedLength, 1)}m | پرت ${fixed(r.wastePercent, 1)}% | وزن ${fixed(r.totalWeight, 1)}kg');
      if (r.oversized.isNotEmpty) lines.add('  ⚠ ${r.oversized.length} قطعه نیاز به وصله دارد');
    }
    lines.add('―――――――――――――――――');
    lines.add('جمع کل شاخه: $gb عدد');
    lines.add('جمع کل وزن: ${fixed(gw, 1)} کیلوگرم');
    lines.add('تاریخ: ${jalaliToday()}');
    return lines.join('\n');
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _summaryText()));
    setState(() => _copyMsg = 'کپی شد ✅');
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _copyMsg = '');
    });
  }

  Future<void> _excel() async {
    setState(() => _exporting = true);
    try {
      final stockLength = _stockLength;
      final proj = _project.text.trim();
      final ex = Excel.createExcel();
      final def = ex.getDefaultSheet();
      final sum = ex['خلاصه'];
      sum.appendRow([TextCellValue('لیستوفر میلگرد${proj.isNotEmpty ? ' - $proj' : ''}')]);
      sum.appendRow([TextCellValue('طول شاخه (متر)'), DoubleCellValue(stockLength)]);
      sum.appendRow([TextCellValue('تاریخ'), TextCellValue(jalaliToday())]);
      sum.appendRow([]);
      sum.appendRow([
        for (final h in ['قطر (mm)', 'تعداد قطعه', 'تعداد شاخه', 'مصرف (m)', 'پرت (m)', 'درصد پرت', 'وزن (kg)']) TextCellValue(h)
      ]);
      var gb = 0;
      var gw = 0.0;
      for (final r in _results!) {
        gb += r.barsNeeded;
        gw += r.totalWeight;
        sum.appendRow([
          IntCellValue(r.diameter),
          IntCellValue(r.piecesCount),
          IntCellValue(r.barsNeeded),
          DoubleCellValue(double.parse(fixed(r.totalUsedLength, 2))),
          DoubleCellValue(double.parse(fixed(r.totalWaste, 2))),
          TextCellValue('${plain(double.parse(fixed(r.wastePercent, 1)))}%'),
          DoubleCellValue(double.parse(fixed(r.totalWeight, 1))),
        ]);
      }
      sum.appendRow([]);
      sum.appendRow([TextCellValue('جمع کل شاخه'), IntCellValue(gb)]);
      sum.appendRow([TextCellValue('جمع کل وزن (kg)'), DoubleCellValue(double.parse(fixed(gw, 1)))]);

      final pat = ex['الگوی برش'];
      pat.appendRow([for (final h in ['قطر (mm)', 'شماره شاخه', 'قطعات (متر)', 'طول مصرف‌شده', 'پرت این شاخه']) TextCellValue(h)]);
      for (final r in _results!) {
        for (var i = 0; i < r.bars.length; i++) {
          final bar = r.bars[i];
          pat.appendRow([
            IntCellValue(r.diameter),
            IntCellValue(i + 1),
            TextCellValue(bar.items.map((e) => fixed(e, 2)).join(' + ')),
            DoubleCellValue(double.parse(fixed(stockLength - bar.remaining, 2))),
            DoubleCellValue(double.parse(fixed(bar.remaining, 2))),
          ]);
        }
        if (r.oversized.isNotEmpty) {
          pat.appendRow([
            IntCellValue(r.diameter),
            TextCellValue('نیاز به وصله'),
            TextCellValue(r.oversized.map((e) => fixed(e, 2)).join('، ')),
            TextCellValue('-'),
            TextCellValue('-'),
          ]);
        }
      }
      if (def != null) ex.delete(def);
      final bytes = ex.encode();
      if (bytes == null) throw Exception('encode failed');
      await shareBytesOut('listofer-${proj.isEmpty ? 'khorooji' : proj.replaceAll(RegExp(r'[^\w\u0600-\u06FF-]'), '_')}.xlsx', bytes);
    } catch (e) {
      if (mounted) setState(() => _error = 'خطا در ساخت فایل اکسل: $e');
    }
    if (mounted) setState(() => _exporting = false);
  }

  Widget _chip(String label, bool active, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: active ? const Color(0x33C50337) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? C.red : const Color(0x33FFFFFF)),
          ),
          child: Text(label,
              style: TextStyle(fontSize: 12, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? C.redLight : C.soft)),
        ),
      );

  String _catLabel(String v) => _categories.firstWhere((c) => c[0] == v, orElse: () => ['', ''])[1];

  @override
  Widget build(BuildContext context) {
    final stockLength = _stockLength;
    return ToolPage(
      toolId: 'rebar-cutting-optimizer',
      title: widget.title,
      description: widget.description,
      historyDefaultTitle: _project.text,
      getData: () => {
        'rows': [
          for (final r in _rows)
            {'id': r.id, 'category': r.category, 'diameter': r.diameter, 'cutLength': r.cutLength, 'quantity': r.quantity}
        ],
        'category': _category,
        'diameter': _diameter,
        'cutLength': _cut.text,
        'quantity': _qty.text,
        'stockLength': nv(_stock.text),
        'projectName': _project.text,
      },
      onLoad: (m) => setState(() {
        if (m['rows'] is List) {
          _rows
            ..clear()
            ..addAll([
              for (final r in (m['rows'] as List))
                _RowItem((r['id'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch, '${r['category']}',
                    (r['diameter'] as num).toInt(), (r['cutLength'] as num).toDouble(), (r['quantity'] as num).toInt())
            ]);
        }
        if (m['category'] != null) _category = '${m['category']}';
        if (m['diameter'] != null) _diameter = (m['diameter'] as num).toInt();
        if (m['cutLength'] != null) _cut.text = '${m['cutLength']}';
        if (m['quantity'] != null) _qty.text = '${m['quantity']}';
        if (m['stockLength'] != null) _stock.text = '${m['stockLength']}';
        if (m['projectName'] != null) _project.text = '${m['projectName']}';
        _results = null;
      }),
      children: [
        ToolSection('طول شاخه استاندارد', [
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in [6, 9, 12]) _chip('$s متری', stockLength == s, () => setState(() => _stock.text = '$s')),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: _stock,
            onChanged: (_) => setState(() {}),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: 'طول دلخواه (متر)'),
          ),
        ]),
        ToolSection('افزودن ردیف میلگرد', [
          const Text('مصرف در', style: TextStyle(fontSize: 11.5, color: C.soft)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in _categories) _chip(c[1], _category == c[0], () => setState(() => _category = c[0])),
          ]),
          const SizedBox(height: 12),
          const Text('قطر میلگرد (میلی‌متر)', style: TextStyle(fontSize: 11.5, color: C.soft)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final d in _diameters) _chip('Ø$d', _diameter == d, () => setState(() => _diameter = d)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: _cut,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(hintText: 'طول برش (متر) مثلاً 3.4'))),
            const SizedBox(width: 8),
            Expanded(
                child: TextField(
                    controller: _qty,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'تعداد مثلاً 48'))),
          ]),
          const SizedBox(height: 10),
          FilledButton(onPressed: _addRow, child: const Text('افزودن به لیست')),
        ]),
        if (_rows.isNotEmpty)
          ToolSection('ردیف‌های ثبت‌شده (${_rows.length})', [
            for (final r in _rows)
              Row(children: [
                Expanded(
                    child: Text('${_catLabel(r.category)} · Ø${r.diameter} · ${plain(r.cutLength)}m × ${r.quantity}',
                        style: const TextStyle(fontSize: 12.5))),
                TextButton(
                    onPressed: () => setState(() => _rows.remove(r)),
                    child: const Text('حذف', style: TextStyle(color: C.danger))),
              ]),
          ]),
        ToolSection('نام پروژه (برای خروجی - اختیاری)', [
          TextField(controller: _project, decoration: const InputDecoration(hintText: 'مثلاً: پروژه احمدی')),
        ]),
        if (_error.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error, style: const TextStyle(color: C.danger, fontSize: 12.5))),
        Row(children: [
          Expanded(child: FilledButton(onPressed: _calculate, child: const Text('محاسبه بهینه برش'))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton(onPressed: _reset, child: const Text('پاک کردن همه'))),
        ]),
        const SizedBox(height: 12),
        if (_results != null)
          ToolSection('خروجی', [
            Row(children: [
              Expanded(
                  child: FilledButton(
                      onPressed: _exporting ? null : _excel,
                      child: Text(_exporting ? 'در حال ساخت...' : 'دانلود فایل اکسل کامل'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton(onPressed: _copy, child: const Text('کپی خلاصه متنی'))),
            ]),
            if (_copyMsg.isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 8), child: Text(_copyMsg, style: const TextStyle(color: Color(0xFF4ADE80), fontSize: 12.5))),
          ]),
        if (_results != null)
          for (final res in _results!)
            ToolSection('میلگرد Ø${res.diameter}', [
              ResultRow('تعداد قطعه موردنیاز', '${res.piecesCount}', unit: 'عدد'),
              ResultRow('تعداد شاخه لازم', '${res.barsNeeded}', unit: 'شاخه'),
              ResultRow('طول کل شاخه‌ها', fixed(res.totalStockLength, 1), unit: 'متر'),
              ResultRow('طول مصرف‌شده', fixed(res.totalUsedLength, 2), unit: 'متر'),
              ResultRow('پرت', '${fixed(res.totalWaste, 2)} (${fixed(res.wastePercent, 1)}%)', unit: 'متر'),
              ResultRow('وزن کل تقریبی', fixed(res.totalWeight, 1), unit: 'کیلوگرم'),
              if (res.oversized.isNotEmpty)
                NoticeBox(
                    '⚠ ${res.oversized.length} قطعه بلندتر از طول شاخه استاندارد است و نیاز به وصله/سفارش شاخه بلندتر دارد: ${res.oversized.map((o) => fixed(o, 2)).join('، ')} متر'),
              const SizedBox(height: 4),
              const Text('الگوی برش هر شاخه:', style: TextStyle(fontSize: 12, color: C.soft)),
              const SizedBox(height: 4),
              for (var i = 0; i < res.bars.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                      'شاخه ${i + 1}: ${res.bars[i].items.map((e) => fixed(e, 2)).join(' + ')} = ${fixed(stockLength - res.bars[i].remaining, 2)}m از ${plain(stockLength)}m (پرت: ${fixed(res.bars[i].remaining, 2)}m)',
                      style: const TextStyle(fontSize: 12)),
                ),
            ]),
      ],
    );
  }
}

