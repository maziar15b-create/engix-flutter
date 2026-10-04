import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'tool_kit.dart';

// ───────────────────────── کنترل نامنظمی ─────────────────────────

FormBuilder _irregularity = (Vals v) {
  final dMax = v.n('driftMax'), dMin = v.n('driftMin');
  final tTh = v.n('torsionThreshold'), tEx = v.n('torsionExtremeThreshold');
  final avg = (dMax + dMin) / 2;
  final torsionRatio = avg > 0 ? dMax / avg : 0.0;
  final torsionIrr = torsionRatio > tTh;
  final torsionExt = torsionRatio > tEx;

  final kThis = v.n('stiffnessThis'), kAbove = v.n('stiffnessAbove'), kAvg3 = v.n('stiffnessAvg3Above');
  final sTh = v.n('softStoryThreshold'), sEx = v.n('softStoryExtremeThreshold'), sAvg = v.n('softStoryAvgThreshold');
  final rAbove = kAbove > 0 ? kThis / kAbove : 0.0;
  final rAvg3 = kAvg3 > 0 ? kThis / kAvg3 : 0.0;
  final softIrr = rAbove < sTh || rAvg3 < sAvg;
  final softExt = rAbove < sEx;

  final mThis = v.n('massThis'), mAdj = v.n('massAdjacent'), mTh = v.n('massThreshold');
  final massRatio = mAdj > 0 ? mThis / mAdj : 0.0;
  final massIrr = massRatio > mTh;

  final dThis = v.n('dimThis'), dAdj = v.n('dimAdjacent'), gTh = v.n('geomThreshold');
  final geomRatio = dAdj > 0 ? dThis / dAdj : 0.0;
  final geomIrr = geomRatio > gTh;

  final cThis = v.n('capacityThis'), cAbove = v.n('capacityAbove');
  final wTh = v.n('weakStoryThreshold'), wEx = v.n('weakStoryExtremeThreshold');
  final capRatio = cAbove > 0 ? cThis / cAbove : 0.0;
  final weakIrr = capRatio < wTh;
  final weakExt = capRatio < wEx;

  final anyIrr = torsionIrr || softIrr || massIrr || geomIrr || weakIrr;
  final anyExt = torsionExt || softExt || weakExt;

  return [
    const Note(
        '⚠️ کمک‌محاسبه است، نه جایگزین تحلیل کامل سازه. مقادیر (تغییرمکان، سختی طبقه، جرم، ابعاد، ظرفیت) باید از خروجی نرم‌افزار تحلیل سازه (مثل ETABS) یا محاسبات دستی قاب گرفته شود. اگر سازه هرکدام از انواع نامنظمی «شدید» را داشته باشد، معمولاً طبق آیین‌نامه تحلیل دینامیکی (نه استاتیکی معادل) الزامی می‌شود — این ابزار فقط تشخیص می‌دهد، الزامات ناشی از آن (مثل تحلیل دینامیکی) را اعمال نمی‌کند.'),
    Sec('۱) نامنظمی پیچشی (Torsional)', [
      const F('driftMax', 'بیشینه تغییرمکان نسبی (δmax)', unit: 'cm'),
      const F('driftMin', 'کمینه تغییرمکان نسبی (δmin)', unit: 'cm'),
      const F('torsionThreshold', 'حد نامنظمی (پیش‌فرض ۱.۲)'),
      const F('torsionExtremeThreshold', 'حد نامنظمی شدید (پیش‌فرض ۱.۴)'),
      R('نسبت δmax/δavg', fixed(torsionRatio, 2), warn: torsionIrr, hl: !torsionIrr),
      R('وضعیت', torsionExt ? 'نامنظمی پیچشی شدید' : (torsionIrr ? 'نامنظمی پیچشی' : 'منظم'), warn: torsionIrr),
    ]),
    Sec('۲) نرمی طبقه (Soft Story)', [
      const F('stiffnessThis', 'سختی این طبقه (Ki)', unit: 'ton/cm'),
      const F('stiffnessAbove', 'سختی طبقه بالا', unit: 'ton/cm'),
      const F('stiffnessAvg3Above', 'میانگین سختی ۳ طبقه بالا', unit: 'ton/cm'),
      const F('softStoryThreshold', 'حد (نسبت به بالا)'),
      const F('softStoryExtremeThreshold', 'حد شدید'),
      const F('softStoryAvgThreshold', 'حد (نسبت به میانگین ۳)'),
      R('نسبت Ki/K(بالا)', fixed(rAbove, 2), warn: rAbove < sTh),
      R('نسبت Ki/میانگین۳بالا', fixed(rAvg3, 2), warn: rAvg3 < sAvg),
      R('وضعیت', softExt ? 'طبقه نرم شدید' : (softIrr ? 'طبقه نرم' : 'منظم'), warn: softIrr),
    ]),
    Sec('۳) نامنظمی جرمی (Mass Irregularity)', [
      const F('massThis', 'جرم این طبقه', unit: 'ton'),
      const F('massAdjacent', 'جرم طبقه مجاور', unit: 'ton'),
      const F('massThreshold', 'حد نامنظمی (پیش‌فرض ۱.۵)'),
      R('نسبت جرم', fixed(massRatio, 2), warn: massIrr, hl: !massIrr),
      R('وضعیت', massIrr ? 'نامنظمی جرمی' : 'منظم', warn: massIrr),
    ]),
    Sec('۴) نامنظمی هندسی (تورفتگی/پاگرد)', [
      const F('dimThis', 'بعد افقی سیستم باربر جانبی این طبقه', unit: 'cm'),
      const F('dimAdjacent', 'بعد افقی طبقه مجاور', unit: 'cm'),
      const F('geomThreshold', 'حد نامنظمی (پیش‌فرض ۱.۳)'),
      R('نسبت ابعاد', fixed(geomRatio, 2), warn: geomIrr, hl: !geomIrr),
      R('وضعیت', geomIrr ? 'نامنظمی هندسی' : 'منظم', warn: geomIrr),
    ]),
    Sec('۵) طبقه ضعیف (Weak Story)', [
      const F('capacityThis', 'ظرفیت برشی این طبقه', unit: 'ton'),
      const F('capacityAbove', 'ظرفیت برشی طبقه بالا', unit: 'ton'),
      const F('weakStoryThreshold', 'حد نامنظمی (پیش‌فرض ۰.۸)'),
      const F('weakStoryExtremeThreshold', 'حد شدید (پیش‌فرض ۰.۶۵)'),
      R('نسبت ظرفیت', fixed(capRatio, 2), warn: weakIrr, hl: !weakIrr),
      R('وضعیت', weakExt ? 'طبقه ضعیف شدید' : (weakIrr ? 'طبقه ضعیف' : 'منظم'), warn: weakIrr),
    ]),
    Note(
        anyExt
            ? '⚠️ سازه حداقل یک نوع نامنظمی «شدید» دارد — الزامات ویژه آیین‌نامه (احتمالاً تحلیل دینامیکی) اعمال می‌شود'
            : (anyIrr ? '⚠️ سازه حداقل یک نوع نامنظمی دارد' : '✅ طبق این کنترل‌ها، سازه در این طبقه منظم است'),
        warn: anyIrr),
  ];
};

FormTool irregularityTool(String title) => FormTool(
    toolId: 'irregularity-check',
    title: title,
    description: '',
    defaults: const {
      'driftMax': '1.8', 'driftMin': '1', 'torsionThreshold': '1.2', 'torsionExtremeThreshold': '1.4',
      'stiffnessThis': '800', 'stiffnessAbove': '1200', 'stiffnessAvg3Above': '1150',
      'softStoryThreshold': '0.7', 'softStoryExtremeThreshold': '0.6', 'softStoryAvgThreshold': '0.8',
      'massThis': '220', 'massAdjacent': '140', 'massThreshold': '1.5',
      'dimThis': '1200', 'dimAdjacent': '900', 'geomThreshold': '1.3',
      'capacityThis': '85', 'capacityAbove': '120', 'weakStoryThreshold': '0.8', 'weakStoryExtremeThreshold': '0.65',
    },
    builder: _irregularity);

// ───────────────────────── توزیع زلزله + دریفت ─────────────────────────

const _cdOptions = <List<dynamic>>[
  ['concrete_ordinary_frame', 'قاب خمشی بتنی معمولی', 4.5],
  ['concrete_intermediate_frame', 'قاب خمشی بتنی متوسط', 5.0],
  ['concrete_special_frame', 'قاب خمشی بتنی ویژه', 5.5],
  ['concrete_ordinary_wall', 'دیوار برشی بتنی معمولی', 4.0],
  ['concrete_special_wall', 'دیوار برشی بتنی ویژه', 6.0],
  ['steel_special_frame', 'قاب خمشی فولادی ویژه', 5.5],
  ['steel_braced_special', 'مهاربندی هم‌محور فولادی ویژه', 5.0],
];

class _Story {
  int id;
  String name;
  double height;
  double weight;
  _Story(this.id, this.name, this.height, this.weight);
}

class _DriftStory {
  int id;
  String name;
  final TextEditingController height;
  final TextEditingController disp;
  _DriftStory(this.id, this.name, String h, String d)
      : height = TextEditingController(text: h),
        disp = TextEditingController(text: d);
}

class SeismicDistributionTool extends StatefulWidget {
  final String title;
  const SeismicDistributionTool({super.key, required this.title});
  @override
  State<SeismicDistributionTool> createState() => _SeismicDistributionToolState();
}

class _SeismicDistributionToolState extends State<SeismicDistributionTool> {
  final _baseShear = TextEditingController(text: '120');
  final _period = TextEditingController(text: '0.6');
  final _newH = TextEditingController();
  final _newW = TextEditingController();
  final _cd = TextEditingController(text: '5');
  final _imp = TextEditingController(text: '1');
  final _allow = TextEditingController(text: '0.02');
  String _cdPick = '';

  final List<_Story> _stories = [
    _Story(1, 'طبقه ۱', 320, 250),
    _Story(2, 'طبقه ۲', 300, 250),
    _Story(3, 'طبقه ۳', 300, 250),
    _Story(4, 'بام', 300, 200),
  ];
  final List<_DriftStory> _drift = [
    _DriftStory(1, 'طبقه ۱', '320', '0.8'),
    _DriftStory(2, 'طبقه ۲', '300', '0.9'),
    _DriftStory(3, 'طبقه ۳', '300', '0.7'),
    _DriftStory(4, 'بام', '300', '0.5'),
  ];

  @override
  void dispose() {
    for (final c in [_baseShear, _period, _newH, _newW, _cd, _imp, _allow]) {
      c.dispose();
    }
    for (final d in _drift) {
      d.height.dispose();
      d.disp.dispose();
    }
    super.dispose();
  }

  void _s() => setState(() {});

  void _addStory() {
    final h = nv(_newH.text), w = nv(_newW.text);
    if (h <= 0 || w <= 0) return;
    setState(() {
      _stories.add(_Story(DateTime.now().millisecondsSinceEpoch, 'طبقه ${_stories.length + 1}', h, w));
      _newH.clear();
      _newW.clear();
    });
  }

  Map<String, dynamic> _data() => {
        'baseShear': _baseShear.text,
        'period': _period.text,
        'stories': [
          for (final s in _stories) {'id': s.id, 'name': s.name, 'height': s.height, 'weight': s.weight}
        ],
        'Cd': _cd.text,
        'importanceI': _imp.text,
        'allowableRatio': _allow.text,
        'driftStories': [
          for (final d in _drift)
            {'id': d.id, 'name': d.name, 'height': nv(d.height.text), 'elasticDisp': nv(d.disp.text)}
        ],
      };

  void _load(Map<String, dynamic> m) {
    setState(() {
      if (m['baseShear'] != null) _baseShear.text = '${m['baseShear']}';
      if (m['period'] != null) _period.text = '${m['period']}';
      if (m['Cd'] != null) _cd.text = '${m['Cd']}';
      if (m['importanceI'] != null) _imp.text = '${m['importanceI']}';
      if (m['allowableRatio'] != null) _allow.text = '${m['allowableRatio']}';
      if (m['stories'] is List) {
        _stories
          ..clear()
          ..addAll([
            for (final s in (m['stories'] as List))
              _Story((s['id'] as num?)?.toInt() ?? 0, '${s['name']}', nv('${s['height']}'), nv('${s['weight']}'))
          ]);
      }
      if (m['driftStories'] is List) {
        for (final d in _drift) {
          d.height.dispose();
          d.disp.dispose();
        }
        _drift
          ..clear()
          ..addAll([
            for (final s in (m['driftStories'] as List))
              _DriftStory((s['id'] as num?)?.toInt() ?? 0, '${s['name']}', '${s['height']}', '${s['elasticDisp']}')
          ]);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final baseShear = nv(_baseShear.text);
    final period = nv(_period.text);

    final cum = <double>[];
    var running = 0.0;
    for (final s in _stories) {
      running += s.height;
      cum.add(running);
    }
    var sumWiHi = 0.0;
    for (var i = 0; i < _stories.length; i++) {
      sumWiHi += _stories[i].weight * cum[i];
    }
    final ft = period > 0.7 ? min(0.07 * period * baseShear, 0.25 * baseShear) : 0.0;
    final vMinusFt = baseShear - ft;
    final fx = <double>[];
    for (var i = 0; i < _stories.length; i++) {
      var f = sumWiHi > 0 ? (vMinusFt * _stories[i].weight * cum[i]) / sumWiHi : 0.0;
      if (i == _stories.length - 1) f += ft;
      fx.add(f);
    }
    final shear = List<double>.filled(_stories.length, 0);
    var run2 = 0.0;
    for (var i = fx.length - 1; i >= 0; i--) {
      run2 += fx[i];
      shear[i] = run2;
    }

    final cd = nv(_cd.text), imp = nv(_imp.text), allow = nv(_allow.text);
    var prevCum = 0.0;
    final driftRows = <({String name, double drift, double ratio, bool ok})>[];
    for (final d in _drift) {
      final designDisp = (cd * nv(d.disp.text)) / imp;
      final storyDrift = designDisp - prevCum;
      final h = nv(d.height.text);
      final ratio = h > 0 ? storyDrift / h : 0.0;
      prevCum = designDisp;
      driftRows.add((name: d.name, drift: storyDrift, ratio: ratio, ok: ratio <= allow));
    }

    return ToolPage(
      toolId: 'seismic-distribution',
      title: widget.title,
      description: '',
      getData: _data,
      onLoad: _load,
      children: [
        const NoticeBox(
            '⚠️ توزیع نیروی زلزله طبق فرمول استاندارد ۲۸۰۰ محاسبه می‌شود. برای کنترل دریفت، جابجایی‌های الاستیک هر طبقه (خروجی نرم‌افزار تحلیل سازه مثل ایتبس) را وارد کنید — این ابزار خودش تحلیل سازه انجام نمی‌دهد، فقط کنترل نهایی طبق مقادیر واردشده را انجام می‌دهد. ضرایب پیش‌فرض قابل‌ویرایش‌اند و باید با آخرین ویرایش رسمی آیین‌نامه تطبیق داده شوند.'),
        ToolSection('۱) توزیع نیروی زلزله در ارتفاع', [
          FieldGrid([
            NumInput(label: 'برش پایه V', unit: 'ton', controller: _baseShear, onChanged: _s),
            NumInput(label: 'دوره تناوب اصلی T', unit: 'ثانیه', controller: _period, onChanged: _s),
          ]),
          ResultRow('نیروی اضافی بام (Ft)', fixed(ft, 2), unit: 'ton'),
          const SizedBox(height: 6),
          const Text('طبقات (از پایین به بالا):', style: TextStyle(fontSize: 12, color: C.soft)),
          for (var i = 0; i < _stories.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Expanded(
                    child: Text(
                        '${_stories[i].name} — ارتفاع ${plain(_stories[i].height)}cm — وزن ${plain(_stories[i].weight)}ton',
                        style: const TextStyle(fontSize: 12.5))),
                TextButton(
                    onPressed: () => setState(() => _stories.removeAt(i)),
                    child: const Text('حذف', style: TextStyle(color: C.danger))),
              ]),
            ),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: _newH,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(hintText: 'ارتفاع طبقه (cm)'))),
            const SizedBox(width: 8),
            Expanded(
                child: TextField(
                    controller: _newW,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(hintText: 'وزن طبقه (ton)'))),
          ]),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _addStory, child: const Text('افزودن طبقه')),
          const SizedBox(height: 10),
          const Text('نتایج توزیع:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: C.soft)),
          for (var i = 0; i < _stories.length; i++) ...[
            const SizedBox(height: 6),
            Text('${_stories[i].name} (ارتفاع تجمعی ${plain(cum[i])}cm)',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
            ResultRow('نیروی جانبی طبقه (Fx)', fixed(fx[i], 2), unit: 'ton'),
            ResultRow('برش طبقه (Vx)', fixed(shear[i], 2), unit: 'ton', highlight: true),
          ],
        ]),
        ToolSection('۲) کنترل دریفت طبقات', [
          FieldGrid([
            NumInput(label: 'ضریب بزرگ‌نمایی Cd', controller: _cd, onChanged: _s),
            NumInput(label: 'ضریب اهمیت I', controller: _imp, onChanged: _s),
            NumInput(label: 'نسبت دریفت مجاز', controller: _allow, onChanged: _s),
          ]),
          const Text('یا از سیستم‌های رایج، Cd را انتخاب کن:', style: TextStyle(fontSize: 11.5, color: C.soft)),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            value: _cdPick.isEmpty ? '' : _cdPick,
            isExpanded: true,
            dropdownColor: C.bg2,
            items: [
              const DropdownMenuItem(value: '', child: Text('— انتخاب سیستم سازه‌ای —')),
              for (final o in _cdOptions)
                DropdownMenuItem(value: o[0] as String, child: Text('${o[1]} (Cd=${plain(o[2] as double)})', overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() {
              _cdPick = v ?? '';
              for (final o in _cdOptions) {
                if (o[0] == v) _cd.text = plain(o[2] as double);
              }
            }),
          ),
          const SizedBox(height: 12),
          const Text('جابجایی الاستیک هر طبقه (از خروجی نرم‌افزار تحلیل):',
              style: TextStyle(fontSize: 12, color: C.soft)),
          const SizedBox(height: 6),
          for (final d in _drift)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d.name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Row(children: [
                  Expanded(child: NumInput(label: 'ارتفاع (cm)', controller: d.height, onChanged: _s)),
                  const SizedBox(width: 10),
                  Expanded(child: NumInput(label: 'جابجایی الاستیک δxe (cm)', controller: d.disp, onChanged: _s)),
                ]),
              ]),
            ),
          const SizedBox(height: 6),
          const Text('نتایج کنترل دریفت:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: C.soft)),
          for (final r in driftRows) ...[
            const SizedBox(height: 6),
            Text(r.name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
            ResultRow('دریفت نسبی این طبقه', fixed(r.drift, 2), unit: 'cm'),
            ResultRow('نسبت دریفت (Δ/h)', fixed(r.ratio * 100, 2), unit: '%', warn: !r.ok, highlight: r.ok),
            if (!r.ok) Note('⚠ از حد مجاز (${fixed(allow * 100, 1)}%) بیشتر است.').asWidget(),
          ],
        ]),
      ],
    );
  }
}

extension on Note {
  Widget asWidget() => NoticeBox(text, color: warn ? const Color(0xFFFBBF24) : const Color(0xFF4ADE80));
}
