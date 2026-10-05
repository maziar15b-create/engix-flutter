import 'dart:math';

import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'tool_kit.dart';

const _diameters = [6, 8, 10, 12, 14, 16, 18, 20, 22, 25, 28, 32];
const _bendAngles = [45, 90, 135, 180];
const _barTypes = <List<String>>[
  ['straight', 'میلگرد راست'],
  ['bent', 'میلگرد خم‌دار (طولی/L یا U یا Z شکل)'],
  ['stirrup', 'خاموت (بسته/مستطیلی)'],
];
const _hookTypes = <List<String>>[
  ['135', 'قلاب لرزه‌ای ۱۳۵ درجه (خاموت)'],
  ['90', 'قلاب ۹۰ درجه'],
  ['none', 'بدون قلاب'],
];
const _members = <List<String>>[
  ['foundation', 'فونداسیون'],
  ['column', 'ستون'],
  ['beam', 'تیر'],
  ['roof', 'سقف'],
  ['wall', 'دیوار'],
];
const _typeLabels = {'straight': 'راست', 'bent': 'خم‌دار', 'stirrup': 'خاموت'};

double _wpm(int d) => (d * d) / 162;

class _Coeffs {
  double deduct45 = 0.5, deduct90 = 2, deduct135 = 2.5, deduct180 = 3;
  double hook135Factor = 6, hook135MinMm = 75, hook90Factor = 12;
  double stockLengthM = 12, lapFactor = 40;

  Map<String, dynamic> toJson() => {
        'deduct45': deduct45,
        'deduct90': deduct90,
        'deduct135': deduct135,
        'deduct180': deduct180,
        'hook135Factor': hook135Factor,
        'hook135MinMm': hook135MinMm,
        'hook90Factor': hook90Factor,
        'stockLengthM': stockLengthM,
        'lapFactor': lapFactor,
      };

  void load(Map m) {
    double g(String k, double d) => m[k] is num ? (m[k] as num).toDouble() : d;
    deduct45 = g('deduct45', deduct45);
    deduct90 = g('deduct90', deduct90);
    deduct135 = g('deduct135', deduct135);
    deduct180 = g('deduct180', deduct180);
    hook135Factor = g('hook135Factor', hook135Factor);
    hook135MinMm = g('hook135MinMm', hook135MinMm);
    hook90Factor = g('hook90Factor', hook90Factor);
    stockLengthM = g('stockLengthM', stockLengthM);
    lapFactor = g('lapFactor', lapFactor);
  }

  double bendDeduction(int angle) {
    switch (angle) {
      case 45:
        return deduct45;
      case 90:
        return deduct90;
      case 135:
        return deduct135;
      case 180:
        return deduct180;
    }
    return deduct90;
  }
}

class _Row {
  final String id;
  final TextEditingController mark = TextEditingController();
  String member = 'foundation';
  int diameter = 12;
  String barType = 'straight';
  final TextEditingController length = TextEditingController();
  final TextEditingController segments = TextEditingController();
  final List<int> bends = [];
  final TextEditingController width = TextEditingController();
  final TextEditingController height = TextEditingController();
  final TextEditingController cover = TextEditingController(text: '3');
  String hookType = '135';
  final TextEditingController quantity = TextEditingController(text: '1');

  _Row() : id = Random().nextInt(1 << 30).toRadixString(36) + DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  void dispose() {
    for (final c in [mark, length, segments, width, height, cover, quantity]) {
      c.dispose();
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'mark': mark.text,
        'member': member,
        'diameter': diameter,
        'barType': barType,
        'length': length.text,
        'segments': segments.text,
        'bends': [for (final b in bends) {'id': '$b-${bends.indexOf(b)}', 'angle': b}],
        'width': width.text,
        'height': height.text,
        'cover': cover.text,
        'hookType': hookType,
        'quantity': quantity.text,
      };

  static _Row fromJson(Map m) {
    final r = _Row();
    r.mark.text = '${m['mark'] ?? ''}';
    r.member = '${m['member'] ?? 'foundation'}';
    r.diameter = (m['diameter'] as num?)?.toInt() ?? 12;
    r.barType = '${m['barType'] ?? 'straight'}';
    r.length.text = '${m['length'] ?? ''}';
    r.segments.text = '${m['segments'] ?? ''}';
    if (m['bends'] is List) {
      for (final b in (m['bends'] as List)) {
        r.bends.add((b['angle'] as num?)?.toInt() ?? 90);
      }
    }
    r.width.text = '${m['width'] ?? ''}';
    r.height.text = '${m['height'] ?? ''}';
    r.cover.text = '${m['cover'] ?? '3'}';
    r.hookType = '${m['hookType'] ?? '135'}';
    r.quantity.text = '${m['quantity'] ?? '1'}';
    return r;
  }

  double cutLengthMm(_Coeffs c) {
    final d = diameter.toDouble();
    switch (barType) {
      case 'straight':
        return nv(length.text) * 1000;
      case 'bent':
        final segs = segments.text.split(',').map((s) => nv(s)).where((n) => n > 0).toList();
        final sumMm = segs.fold<double>(0, (s, v) => s + v) * 1000;
        final deduction = bends.fold<double>(0, (s, a) => s + c.bendDeduction(a) * d);
        return max(0.0, sumMm - deduction);
      case 'stirrup':
        final a = nv(width.text) * 10 - 2 * nv(cover.text) * 10;
        final b = nv(height.text) * 10 - 2 * nv(cover.text) * 10;
        final perimeter = 2 * (a + b);
        final cornerDeduction = 4 * c.deduct90 * d;
        var hookExt = 0.0;
        if (hookType == '135') {
          hookExt = max(c.hook135Factor * d, c.hook135MinMm);
        } else if (hookType == '90') {
          hookExt = c.hook90Factor * d;
        }
        return max(0.0, perimeter - cornerDeduction + 2 * hookExt);
    }
    return 0;
  }
}

class _Lap {
  final bool needed;
  final int spliceCount;
  final double lapLengthM, extraLengthM, totalWithLapM;
  _Lap(this.needed, this.spliceCount, this.lapLengthM, this.extraLengthM, this.totalWithLapM);
}

_Lap _lap(double cutM, int d, _Coeffs c) {
  final stock = c.stockLengthM == 0 ? 12.0 : c.stockLengthM;
  if (cutM <= stock || stock <= 0) return _Lap(false, 0, 0, 0, cutM);
  final splices = (cutM / stock).ceil() - 1;
  final lapM = (c.lapFactor * d) / 1000;
  final extra = splices * lapM;
  return _Lap(true, splices, lapM, extra, cutM + extra);
}

class RebarShopDrawingTool extends StatefulWidget {
  final String title;
  const RebarShopDrawingTool({super.key, required this.title});
  @override
  State<RebarShopDrawingTool> createState() => _RebarShopDrawingToolState();
}

class _RebarShopDrawingToolState extends State<RebarShopDrawingTool> {
  final _title = TextEditingController();
  final List<_Row> _rows = [_Row()];
  final _Coeffs _coeffs = _Coeffs();

  @override
  void dispose() {
    _title.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _s() => setState(() {});

  ({double cutM, _Lap lap, double finalM, double totalM, double weight}) _calc(_Row r) {
    final cutM = r.cutLengthMm(_coeffs) / 1000;
    final lap = r.barType != 'stirrup' ? _lap(cutM, r.diameter, _coeffs) : _Lap(false, 0, 0, 0, cutM);
    final finalM = lap.totalWithLapM;
    final qty = nv(r.quantity.text) == 0 ? 1.0 : nv(r.quantity.text);
    final total = finalM * qty;
    return (cutM: cutM, lap: lap, finalM: finalM, totalM: total, weight: total * _wpm(r.diameter));
  }

  Future<void> _exportExcel() async {
    try {
      final ex = Excel.createExcel();
      final def = ex.getDefaultSheet();
      final sh = ex['جدول خم آرماتور'];
      sh.appendRow([TextCellValue(_title.text.trim().isEmpty ? 'جدول خم آرماتور (Bar Bending Schedule)' : _title.text.trim())]);
      sh.appendRow([]);
      sh.appendRow([
        for (final h in ['نشانه', 'عضو', 'قطر (mm)', 'نوع', 'طول برش (m)', 'اورلب (m)', 'تعداد', 'طول کل (m)', 'وزن کل (kg)'])
          TextCellValue(h)
      ]);
      var grand = 0.0;
      for (final r in _rows) {
        final c = _calc(r);
        grand += c.weight;
        final memberLabel = _members.firstWhere((m) => m[0] == r.member, orElse: () => [r.member, r.member])[1];
        sh.appendRow([
          TextCellValue(r.mark.text.isEmpty ? '-' : r.mark.text),
          TextCellValue(memberLabel),
          IntCellValue(r.diameter),
          TextCellValue(_typeLabels[r.barType] ?? r.barType),
          DoubleCellValue(double.parse(fixed(c.cutM, 3))),
          DoubleCellValue(c.lap.needed ? double.parse(fixed(c.lap.extraLengthM, 3)) : 0),
          TextCellValue(r.quantity.text),
          DoubleCellValue(double.parse(fixed(c.totalM, 2))),
          DoubleCellValue(double.parse(fixed(c.weight, 2))),
        ]);
      }
      sh.appendRow([]);
      sh.appendRow([TextCellValue('جمع کل وزن (kg)'), DoubleCellValue(double.parse(fixed(grand, 1)))]);
      if (def != null) ex.delete(def);
      final bytes = ex.encode();
      if (bytes == null) throw Exception('encode failed');
      final name = _title.text.trim().isEmpty ? 'shop-drawing' : _title.text.trim().replaceAll(RegExp(r'[^\w\u0600-\u06FF-]'), '_');
      await shareBytesOut('$name.xlsx', bytes);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطا در ساخت فایل اکسل: $e')));
    }
  }

  void _openSettings() {
    final ctl = <String, TextEditingController>{
      'deduct45': TextEditingController(text: plain(_coeffs.deduct45)),
      'deduct90': TextEditingController(text: plain(_coeffs.deduct90)),
      'deduct135': TextEditingController(text: plain(_coeffs.deduct135)),
      'deduct180': TextEditingController(text: plain(_coeffs.deduct180)),
      'hook135Factor': TextEditingController(text: plain(_coeffs.hook135Factor)),
      'hook135MinMm': TextEditingController(text: plain(_coeffs.hook135MinMm)),
      'hook90Factor': TextEditingController(text: plain(_coeffs.hook90Factor)),
      'stockLengthM': TextEditingController(text: plain(_coeffs.stockLengthM)),
      'lapFactor': TextEditingController(text: plain(_coeffs.lapFactor)),
    };
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        void apply() {
          setState(() {
            _coeffs.deduct45 = nv(ctl['deduct45']!.text);
            _coeffs.deduct90 = nv(ctl['deduct90']!.text);
            _coeffs.deduct135 = nv(ctl['deduct135']!.text);
            _coeffs.deduct180 = nv(ctl['deduct180']!.text);
            _coeffs.hook135Factor = nv(ctl['hook135Factor']!.text);
            _coeffs.hook135MinMm = nv(ctl['hook135MinMm']!.text);
            _coeffs.hook90Factor = nv(ctl['hook90Factor']!.text);
            _coeffs.stockLengthM = nv(ctl['stockLengthM']!.text);
            _coeffs.lapFactor = nv(ctl['lapFactor']!.text);
          });
        }

        Widget f(String label, String key) => NumInput(label: label, controller: ctl[key]!, onChanged: apply);
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('ضرایب محاسباتی (پیش‌فرض ACI 318)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                const Text('کسر خم به ازای هر زاویه (× قطر)', style: TextStyle(fontSize: 12, color: C.soft)),
                const SizedBox(height: 6),
                FieldGrid([f('خم ۴۵ درجه', 'deduct45'), f('خم ۹۰ درجه', 'deduct90'), f('خم ۱۳۵ درجه', 'deduct135'), f('خم ۱۸۰ درجه', 'deduct180')]),
                f('ضریب طول قلاب ۱۳۵ درجه (× قطر)', 'hook135Factor'),
                const SizedBox(height: 10),
                f('حداقل طول قلاب ۱۳۵ درجه (mm)', 'hook135MinMm'),
                const SizedBox(height: 10),
                f('ضریب طول قلاب ۹۰ درجه (× قطر)', 'hook90Factor'),
                const SizedBox(height: 14),
                const Text('اورلب / همپوشانی', style: TextStyle(fontSize: 12, color: C.soft)),
                const SizedBox(height: 6),
                f('طول استاندارد شاخه‌ی بازار (متر)', 'stockLengthM'),
                const SizedBox(height: 10),
                f('ضریب طول اورلب (× قطر) — پیش‌فرض رده B', 'lapFactor'),
                const SizedBox(height: 14),
                const Text(
                    'مقادیر پیش‌فرض بر اساس ضوابط متداول ACI 318 هستند. اگر پروژه‌ی شما آیین‌نامه‌ی دیگری را الزام می‌کند، این ضرایب را متناسب با آن اصلاح کنید. این ابزار برای برآورد و پیش‌نویس شاپ‌درائینگ است؛ نقشه‌ی نهایی باید توسط مهندس ناظر تأیید شود.',
                    style: TextStyle(fontSize: 11.5, color: C.muted, height: 1.8)),
                const SizedBox(height: 12),
                FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('باشه')),
              ]),
            ),
          ),
        );
      },
    ).whenComplete(() {
      for (final c in ctl.values) {
        c.dispose();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final totals = <int, ({double length, double weight})>{};
    var grand = 0.0;
    final calcs = [for (final r in _rows) _calc(r)];
    for (var i = 0; i < _rows.length; i++) {
      final c = calcs[i];
      final cur = totals[_rows[i].diameter];
      totals[_rows[i].diameter] = (length: (cur?.length ?? 0) + c.totalM, weight: (cur?.weight ?? 0) + c.weight);
      grand += c.weight;
    }
    return ToolPage(
      toolId: 'rebar-shop-drawing',
      title: widget.title,
      description: '',
      historyDefaultTitle: _title.text,
      onTitle: (t) => setState(() => _title.text = t),
      getData: () => {
        'title': _title.text,
        'rows': [for (final r in _rows) r.toJson()],
        'coeffs': _coeffs.toJson(),
      },
      onLoad: (m) => setState(() {
        if (m['title'] != null) _title.text = '${m['title']}';
        if (m['rows'] is List) {
          for (final r in _rows) {
            r.dispose();
          }
          _rows
            ..clear()
            ..addAll([for (final r in (m['rows'] as List)) _Row.fromJson(r as Map)]);
          if (_rows.isEmpty) _rows.add(_Row());
        }
        if (m['coeffs'] is Map) _coeffs.load(m['coeffs'] as Map);
      }),
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
              onPressed: _openSettings, icon: const Icon(Icons.tune, size: 18), label: const Text('تنظیمات ضرایب')),
        ),
        const Text(
            'محاسبه‌ی طول برش، خم‌ها، اورلب و وزن آرماتور بر اساس ضوابط متداول ACI 318 — قابل تنظیم دستی برای انطباق با آیین‌نامه‌ی پروژه.',
            style: TextStyle(fontSize: 12.5, color: C.soft, height: 1.8)),
        const SizedBox(height: 10),
        TextField(controller: _title, decoration: const InputDecoration(hintText: 'عنوان جدول (مثلاً: ستون‌های طبقه همکف)')),
        const SizedBox(height: 10),
        for (var i = 0; i < _rows.length; i++) _rowCard(i, calcs[i]),
        OutlinedButton(onPressed: () => setState(() => _rows.add(_Row())), child: const Text('+ افزودن ردیف')),
        const SizedBox(height: 12),
        ToolSection('جمع کل به تفکیک قطر', [
          for (final e in (totals.entries.toList()..sort((a, b) => a.key.compareTo(b.key))))
            ResultRow('Ø${e.key} — ${fixed(e.value.length, 1)} متر', '${fixed(e.value.weight, 2)} kg'),
          ResultRow('جمع کل وزن', '${fixed(grand, 2)} کیلوگرم', highlight: true),
        ]),
        OutlinedButton(onPressed: _exportExcel, child: const Text('📊 خروجی اکسل')),
      ],
    );
  }

  Widget _rowCard(int i, ({double cutM, _Lap lap, double finalM, double totalM, double weight}) c) {
    final r = _rows[i];
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
        Row(children: [
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('نشانه (مثلاً S1)', style: TextStyle(fontSize: 11.5, color: C.soft)),
            const SizedBox(height: 4),
            TextField(controller: r.mark, onChanged: (_) => _s()),
          ])),
          const SizedBox(width: 10),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('عضو', style: TextStyle(fontSize: 11.5, color: C.soft)),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              value: r.member,
              isExpanded: true,
              dropdownColor: C.bg2,
              items: [for (final m in _members) DropdownMenuItem(value: m[0], child: Text(m[1]))],
              onChanged: (v) => setState(() => r.member = v ?? r.member),
            ),
          ])),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('قطر (mm)', style: TextStyle(fontSize: 11.5, color: C.soft)),
            const SizedBox(height: 4),
            DropdownButtonFormField<int>(
              value: r.diameter,
              isExpanded: true,
              dropdownColor: C.bg2,
              items: [for (final d in _diameters) DropdownMenuItem(value: d, child: Text('Ø$d'))],
              onChanged: (v) => setState(() => r.diameter = v ?? r.diameter),
            ),
          ])),
          const SizedBox(width: 10),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('نوع میلگرد', style: TextStyle(fontSize: 11.5, color: C.soft)),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              value: r.barType,
              isExpanded: true,
              dropdownColor: C.bg2,
              items: [for (final t in _barTypes) DropdownMenuItem(value: t[0], child: Text(t[1], overflow: TextOverflow.ellipsis))],
              onChanged: (v) => setState(() => r.barType = v ?? r.barType),
            ),
          ])),
        ]),
        const SizedBox(height: 10),
        if (r.barType == 'straight') NumInput(label: 'طول (متر)', controller: r.length, onChanged: _s),
        if (r.barType == 'bent') ...[
          NumInput(label: 'طول قطعات مستقیم، با کاما جدا کنید (متر) — مثلاً: 1.2, 0.8, 1.2', controller: r.segments, onChanged: _s),
          const SizedBox(height: 10),
          const Text('خم‌ها', style: TextStyle(fontSize: 12, color: C.soft)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton(onPressed: () => setState(() => r.bends..clear()..add(90)), child: const Text('یک‌سر خم')),
            OutlinedButton(onPressed: () => setState(() => r.bends..clear()..addAll([90, 90])), child: const Text('دو‌سر خم')),
            OutlinedButton(onPressed: () => setState(() => r.bends.add(90)), child: const Text('+ افزودن خم')),
          ]),
          for (var b = 0; b < r.bends.length; b++)
            Row(children: [
              Text('خم ${b + 1}:', style: const TextStyle(fontSize: 12.5)),
              const SizedBox(width: 10),
              SizedBox(
                width: 130,
                child: DropdownButtonFormField<int>(
                  value: r.bends[b],
                  dropdownColor: C.bg2,
                  items: [for (final a in _bendAngles) DropdownMenuItem(value: a, child: Text('$a درجه'))],
                  onChanged: (v) => setState(() => r.bends[b] = v ?? r.bends[b]),
                ),
              ),
              IconButton(onPressed: () => setState(() => r.bends.removeAt(b)), icon: const Icon(Icons.close, size: 16, color: C.danger)),
            ]),
        ],
        if (r.barType == 'stirrup') ...[
          FieldGrid([
            NumInput(label: 'عرض مقطع (cm)', controller: r.width, onChanged: _s),
            NumInput(label: 'ارتفاع مقطع (cm)', controller: r.height, onChanged: _s),
            NumInput(label: 'کاور/پوشش بتن (cm)', controller: r.cover, onChanged: _s),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('نوع قلاب', style: TextStyle(fontSize: 11.5, color: C.soft)),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: r.hookType,
                isExpanded: true,
                dropdownColor: C.bg2,
                items: [for (final h in _hookTypes) DropdownMenuItem(value: h[0], child: Text(h[1], overflow: TextOverflow.ellipsis))],
                onChanged: (v) => setState(() => r.hookType = v ?? r.hookType),
              ),
            ]),
          ]),
        ],
        const SizedBox(height: 4),
        NumInput(label: 'تعداد', controller: r.quantity, onChanged: _s),
        if (c.lap.needed) ...[
          const SizedBox(height: 8),
          NoticeBox(
              '⚠️ طول این شاخه از طول استاندارد شاخه‌ی بازار (${plain(_coeffs.stockLengthM)} متر) بیشتر است. نیاز به ${c.lap.spliceCount} وصله (اورلب) به طول ${fixed(c.lap.lapLengthM, 2)} متر هرکدام دارد (جمعاً ${fixed(c.lap.extraLengthM, 2)} متر اضافه).'),
        ],
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: Text('طول برش هر شاخه: ${fixed(c.finalM, 3)} متر', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700))),
          Text(c.weight > 0 ? '${fixed(c.weight, 2)} kg' : '', style: const TextStyle(fontSize: 12.5, color: C.redLight, fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }
}
