import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'qto_templates.dart';
import 'tool_kit.dart';

const _shapes = <List<String>>[
  ['area', 'مساحت ساده (طول × عرض)', 'متر مربع'],
  ['wall', 'دیوار با کسر بازشو (طول × ارتفاع − بازشوها)', 'متر مربع'],
  ['volume', 'حجم (طول × عرض × ارتفاع)', 'متر مکعب'],
  ['length', 'طول خطی (لوله‌کشی، سیم‌کشی)', 'متر طول'],
  ['count', 'شمارشی (فقط تعداد × قیمت واحد)', 'عدد'],
];

String _shapeUnit(String s) {
  for (final x in _shapes) {
    if (x[0] == s) return x[2];
  }
  return '';
}

String _shapeLabel(String s) {
  for (final x in _shapes) {
    if (x[0] == s) return x[1];
  }
  return s;
}

class _Row {
  final String id;
  String shape;
  final TextEditingController description;
  final TextEditingController length;
  final TextEditingController width;
  final TextEditingController height;
  final TextEditingController openings;
  final TextEditingController quantity;
  final TextEditingController unitPrice;
  _Row({String? id, String name = '', this.shape = 'area'})
      : id = id ?? (Random().nextInt(1 << 30)).toRadixString(36) + DateTime.now().microsecondsSinceEpoch.toRadixString(36),
        description = TextEditingController(text: name),
        length = TextEditingController(),
        width = TextEditingController(),
        height = TextEditingController(),
        openings = TextEditingController(),
        quantity = TextEditingController(text: '1'),
        unitPrice = TextEditingController();

  void dispose() {
    for (final c in [description, length, width, height, openings, quantity, unitPrice]) {
      c.dispose();
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'description': description.text,
        'shape': shape,
        'length': length.text,
        'width': width.text,
        'height': height.text,
        'openings': openings.text,
        'quantity': quantity.text,
        'unitPrice': unitPrice.text,
      };

  static _Row fromJson(Map m) {
    final r = _Row(id: '${m['id'] ?? ''}'.isEmpty ? null : '${m['id']}', name: '${m['description'] ?? ''}', shape: '${m['shape'] ?? 'area'}');
    r.length.text = '${m['length'] ?? ''}';
    r.width.text = '${m['width'] ?? ''}';
    r.height.text = '${m['height'] ?? ''}';
    r.openings.text = '${m['openings'] ?? ''}';
    r.quantity.text = '${m['quantity'] ?? '1'}';
    r.unitPrice.text = '${m['unitPrice'] ?? ''}';
    return r;
  }

  double get amount {
    final qty = nv(quantity.text) == 0 ? 1.0 : nv(quantity.text);
    switch (shape) {
      case 'area':
        return nv(length.text) * nv(width.text) * qty;
      case 'wall':
        final gross = nv(length.text) * nv(height.text);
        final net = max(0.0, gross - nv(openings.text));
        return net * qty;
      case 'volume':
        return nv(length.text) * nv(width.text) * nv(height.text) * qty;
      case 'length':
        return nv(length.text) * qty;
      case 'count':
        return qty;
    }
    return 0;
  }

  double get cost => amount * nv(unitPrice.text);
}

class QuantityTakeoffTool extends StatefulWidget {
  final String title;
  const QuantityTakeoffTool({super.key, required this.title});
  @override
  State<QuantityTakeoffTool> createState() => _QuantityTakeoffToolState();
}

class _QuantityTakeoffToolState extends State<QuantityTakeoffTool> {
  final _title = TextEditingController();
  final List<_Row> _rows = [_Row()];

  @override
  void dispose() {
    _title.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _s() => setState(() {});

  void _addFromTemplate(QtoTemplate t) {
    setState(() {
      if (_rows.length == 1 && _rows[0].description.text.isEmpty && _rows[0].length.text.isEmpty) {
        _rows[0].dispose();
        _rows[0] = _Row(name: t.name, shape: t.shape);
      } else {
        _rows.add(_Row(name: t.name, shape: t.shape));
      }
    });
    Navigator.pop(context);
  }

  void _openTemplates() {
    var active = qtoCategories.first.id;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setM) {
        final items = qtoCategories.firstWhere((c) => c.id == active).items;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
                child: Row(children: [
                  const Expanded(child: Text('فهرست اقلام آماده', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('بستن')),
                ]),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final c in qtoCategories)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: GestureDetector(
                          onTap: () => setM(() => active = c.id),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: active == c.id ? const Color(0x33C50337) : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: active == c.id ? C.red : const Color(0x33FFFFFF)),
                            ),
                            child: Text('${c.icon} ${c.label}', style: const TextStyle(fontSize: 12)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(14),
                  children: [
                    for (final it in items)
                      InkWell(
                        onTap: () => _addFromTemplate(it),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: C.bg1,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0x1FC50337)),
                          ),
                          child: Row(children: [
                            Expanded(child: Text(it.name, style: const TextStyle(fontSize: 13.5))),
                            Text(_shapeUnit(it.shape), style: const TextStyle(fontSize: 11, color: C.muted)),
                          ]),
                        ),
                      ),
                  ],
                ),
              ),
            ]),
          ),
        );
      }),
    );
  }

  String _q(String s) => '"${s.replaceAll('"', '""')}"';

  Future<void> _exportCsv() async {
    final headers = ['ردیف', 'شرح', 'نوع', 'طول', 'عرض/ارتفاع', 'کسر بازشو', 'تعداد', 'مقدار', 'واحد', 'قیمت واحد', 'جمع هزینه'];
    final lines = <String>[headers.join(',')];
    var total = 0.0;
    for (var i = 0; i < _rows.length; i++) {
      final r = _rows[i];
      total += r.cost;
      final hw = r.shape == 'volume' ? r.width.text : (r.height.text.isNotEmpty ? r.height.text : r.width.text);
      lines.add([
        '${i + 1}',
        _q(r.description.text),
        _shapeLabel(r.shape),
        r.length.text,
        hw,
        r.openings.text,
        r.quantity.text.isEmpty ? '1' : r.quantity.text,
        fixed(r.amount, 2),
        _shapeUnit(r.shape),
        r.unitPrice.text,
        fixed(r.cost, 0),
      ].join(','));
    }
    lines.add('');
    lines.add(',,,,,,,,,جمع کل هزینه,${fixed(total, 0)}');
    final name = _title.text.trim().isEmpty ? 'متره-و-براورد' : _title.text.trim();
    await shareTextOut('$name.csv', '\uFEFF${lines.join('\n')}', mime: 'text/csv');
  }

  String _esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

  Future<void> _exportPrintable() async {
    final b = StringBuffer();
    b.write('<!DOCTYPE html><html lang="fa" dir="rtl"><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width, initial-scale=1"><title>متره و برآورد</title><style>'
        'body{font-family:Tahoma,Arial,sans-serif;margin:18px;color:#111}h1{font-size:18px;color:#7A0224}'
        'table{border-collapse:collapse;width:100%;font-size:12px}th{background:#f3f1ec;border:1px solid #ccc;padding:6px}'
        'td{border:1px solid #ddd;padding:6px}.t{font-weight:bold;background:#faf8f4}</style></head><body>');
    b.write('<h1>${_esc(_title.text.trim().isEmpty ? 'متره و برآورد' : _title.text.trim())}</h1>');
    b.write('<table><tr><th>ردیف</th><th>شرح</th><th>نوع</th><th>مقدار</th><th>واحد</th><th>قیمت واحد</th><th>جمع هزینه</th></tr>');
    var total = 0.0;
    final totals = <String, double>{};
    for (var i = 0; i < _rows.length; i++) {
      final r = _rows[i];
      total += r.cost;
      totals[_shapeUnit(r.shape)] = (totals[_shapeUnit(r.shape)] ?? 0) + r.amount;
      b.write('<tr><td>${i + 1}</td><td>${_esc(r.description.text)}</td><td>${_esc(_shapeLabel(r.shape))}</td>'
          '<td>${fixed(r.amount, 2)}</td><td>${_shapeUnit(r.shape)}</td><td>${_esc(r.unitPrice.text)}</td><td>${faNum(r.cost, maxFrac: 0)}</td></tr>');
    }
    b.write('</table><h3>جمع کل مقادیر</h3><table>');
    totals.forEach((u, a) => b.write('<tr><td>$u</td><td>${fixed(a, 2)}</td></tr>'));
    b.write('<tr class="t"><td>جمع کل هزینه</td><td>${faNum(total, maxFrac: 0)} تومان</td></tr></table></body></html>');
    await shareTextOut('متره-و-براورد.html', b.toString(), mime: 'text/html');
  }

  @override
  Widget build(BuildContext context) {
    final totalsByUnit = <String, double>{};
    var grand = 0.0;
    for (final r in _rows) {
      totalsByUnit[_shapeUnit(r.shape)] = (totalsByUnit[_shapeUnit(r.shape)] ?? 0) + r.amount;
      grand += r.cost;
    }
    return ToolPage(
      toolId: 'quantity-takeoff',
      title: widget.title,
      description: '',
      historyDefaultTitle: _title.text,
      onTitle: (t) => setState(() => _title.text = t),
      getData: () => {'rows': [for (final r in _rows) r.toJson()]},
      onLoad: (m) {
        if (m['rows'] is List) {
          setState(() {
            for (final r in _rows) {
              r.dispose();
            }
            _rows
              ..clear()
              ..addAll([for (final r in (m['rows'] as List)) _Row.fromJson(r as Map)]);
            if (_rows.isEmpty) _rows.add(_Row());
          });
        }
      },
      children: [
        TextField(controller: _title, decoration: const InputDecoration(hintText: 'عنوان برآورد (مثلاً: ساختمان مسکونی ۳ طبقه)')),
        const SizedBox(height: 10),
        OutlinedButton(
            onPressed: _openTemplates,
            child: const Text('📋 افزودن از فهرست اقلام آماده (سازه، برق، آب، گاز و...)')),
        const SizedBox(height: 10),
        for (var i = 0; i < _rows.length; i++) _rowCard(i),
        OutlinedButton(
            onPressed: () => setState(() => _rows.add(_Row())), child: const Text('+ افزودن ردیف خالی (سفارشی)')),
        const SizedBox(height: 12),
        ToolSection('جمع کل مقادیر', [
          for (final e in totalsByUnit.entries) ResultRow(e.key, fixed(e.value, 2)),
          ResultRow('جمع کل هزینه', '${faNum(grand, maxFrac: 0)} تومان', highlight: true),
        ]),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: _exportCsv, child: const Text('📊 خروجی اکسل (CSV)'))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton(onPressed: _exportPrintable, child: const Text('🖨 ذخیره PDF / چاپ'))),
        ]),
      ],
    );
  }

  Widget _rowCard(int i) {
    final r = _rows[i];
    final unit = _shapeUnit(r.shape);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: C.bg2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x2EC50337)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text('ردیف ${i + 1}', style: const TextStyle(fontSize: 12, color: C.muted))),
          if (_rows.length > 1)
            IconButton(
                onPressed: () => setState(() {
                      _rows[i].dispose();
                      _rows.removeAt(i);
                    }),
                icon: const Icon(Icons.delete_outline, size: 18, color: C.danger)),
        ]),
        TextField(
            controller: r.description,
            onChanged: (_) => _s(),
            decoration: const InputDecoration(hintText: 'شرح ردیف (مثلاً: دیوار اتاق خواب اول)')),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: r.shape,
          isExpanded: true,
          dropdownColor: C.bg2,
          items: [for (final s in _shapes) DropdownMenuItem(value: s[0], child: Text(s[1], overflow: TextOverflow.ellipsis))],
          onChanged: (v) => setState(() => r.shape = v ?? r.shape),
        ),
        const SizedBox(height: 8),
        if (r.shape == 'area' || r.shape == 'wall' || r.shape == 'volume')
          FieldGrid([
            NumInput(label: 'طول (متر)', controller: r.length, onChanged: _s),
            if (r.shape == 'area') NumInput(label: 'عرض (متر)', controller: r.width, onChanged: _s),
            if (r.shape == 'wall') NumInput(label: 'ارتفاع (متر)', controller: r.height, onChanged: _s),
            if (r.shape == 'volume') NumInput(label: 'عرض (متر)', controller: r.width, onChanged: _s),
            if (r.shape == 'volume') NumInput(label: 'ارتفاع (متر)', controller: r.height, onChanged: _s),
          ]),
        if (r.shape == 'length')
          Padding(padding: const EdgeInsets.only(bottom: 8), child: NumInput(label: 'طول کل (متر)', controller: r.length, onChanged: _s)),
        if (r.shape == 'wall')
          Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: NumInput(label: 'مجموع مساحت بازشوها — در/پنجره (متر مربع)', controller: r.openings, onChanged: _s)),
        FieldGrid([
          NumInput(label: r.shape == 'count' ? 'تعداد' : 'تعداد (تکرار این ردیف)', controller: r.quantity, onChanged: _s),
          NumInput(label: 'قیمت واحد (تومان / $unit)', controller: r.unitPrice, onChanged: _s),
        ]),
        Row(children: [
          Expanded(child: Text('مقدار: ${fixed(r.amount, 2)} $unit', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700))),
          Text(r.cost > 0 ? '${faNum(r.cost, maxFrac: 0)} تومان' : '',
              style: const TextStyle(fontSize: 12.5, color: C.redLight, fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }
}
