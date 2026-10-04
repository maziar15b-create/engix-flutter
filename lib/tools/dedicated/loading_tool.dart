import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'tool_kit.dart';

class _Live {
  final String id, label;
  double value;
  _Live(this.id, this.label, this.value);
}

const _rOptions = <List<dynamic>>[
  ['concrete_ordinary_frame', 'قاب خمشی بتنی معمولی', 5.0],
  ['concrete_intermediate_frame', 'قاب خمشی بتنی متوسط', 6.0],
  ['concrete_special_frame', 'قاب خمشی بتنی ویژه', 8.0],
  ['concrete_ordinary_wall', 'دیوار برشی بتنی معمولی', 4.0],
  ['concrete_special_wall', 'دیوار برشی بتنی ویژه', 7.0],
  ['steel_ordinary_frame', 'قاب خمشی فولادی معمولی', 5.0],
  ['steel_special_frame', 'قاب خمشی فولادی ویژه', 7.5],
  ['steel_braced_ordinary', 'مهاربندی هم‌محور فولادی معمولی', 5.0],
  ['steel_braced_special', 'مهاربندی هم‌محور فولادی ویژه', 7.0],
];

List<_Live> _defaultLive() => [
      _Live('residential', 'مسکونی / اتاق خواب', 200),
      _Live('office_no_partition', 'اداری بدون پارتیشن', 200),
      _Live('office_partition', 'اداری با پارتیشن', 250),
      _Live('corridor_public', 'راهرو و پله (عمومی)', 400),
      _Live('balcony', 'بالکن', 350),
      _Live('assembly_fixed', 'اجتماعات با صندلی ثابت', 350),
      _Live('assembly_free', 'اجتماعات بدون صندلی ثابت', 500),
      _Live('parking_light', 'پارکینگ (خودرو سبک)', 300),
      _Live('storage_light', 'انبار سبک', 600),
      _Live('roof_inaccessible', 'بام غیرقابل‌دسترس (فقط تعمیر)', 150),
      _Live('roof_accessible', 'بام قابل‌دسترس', 200),
      _Live('mechanical_room', 'موتورخانه / تجهیزات', 500),
    ];

class _Layer {
  int id;
  String name;
  double weight;
  _Layer(this.id, this.name, this.weight);
}

class LoadingCalculatorTool extends StatefulWidget {
  final String title;
  const LoadingCalculatorTool({super.key, required this.title});
  @override
  State<LoadingCalculatorTool> createState() => _LoadingCalculatorToolState();
}

class _LoadingCalculatorToolState extends State<LoadingCalculatorTool> {
  final List<_Layer> _layers = [
    _Layer(1, 'کف‌سازی (سرامیک+ملات)', 150),
    _Layer(2, 'دیوار جداکننده (سربار)', 100),
  ];
  final _layerName = TextEditingController();
  final _layerWeight = TextEditingController();
  final _selfWeight = TextEditingController();
  List<_Live> _live = _defaultLive();
  String _liveId = 'residential';
  final _liveValue = TextEditingController(text: '200');
  final _d1 = TextEditingController(text: '1.4');
  final _d2 = TextEditingController(text: '1.2');
  final _l2 = TextEditingController(text: '1.6');
  final _a = TextEditingController(text: '0.3');
  final _b = TextEditingController(text: '2.5');
  final _i = TextEditingController(text: '1');
  final _r = TextEditingController(text: '5');
  final _livePct = TextEditingController(text: '20');
  final _area = TextEditingController();
  String _rPick = '';

  @override
  void dispose() {
    for (final c in [_layerName, _layerWeight, _selfWeight, _liveValue, _d1, _d2, _l2, _a, _b, _i, _r, _livePct, _area]) {
      c.dispose();
    }
    super.dispose();
  }

  void _s() => setState(() {});

  _Live get _selected => _live.firstWhere((l) => l.id == _liveId, orElse: () => _live.first);

  void _addLayer() {
    final w = nv(_layerWeight.text);
    if (_layerName.text.trim().isEmpty || w <= 0) return;
    setState(() {
      _layers.add(_Layer(DateTime.now().millisecondsSinceEpoch, _layerName.text.trim(), w));
      _layerName.clear();
      _layerWeight.clear();
    });
  }

  Map<String, dynamic> _data() => {
        'deadLayers': [
          for (final l in _layers) {'id': l.id, 'name': l.name, 'weight': l.weight}
        ],
        'selfWeight': _selfWeight.text,
        'liveLoads': [
          for (final l in _live) {'id': l.id, 'label': l.label, 'value': l.value}
        ],
        'selectedLiveId': _liveId,
        'dCoef1': _d1.text,
        'dCoef2': _d2.text,
        'lCoef2': _l2.text,
        'seismicA': _a.text,
        'seismicB': _b.text,
        'seismicI': _i.text,
        'seismicR': _r.text,
        'liveLoadSeismicPercent': _livePct.text,
        'totalFloorArea': _area.text,
      };

  void _load(Map<String, dynamic> m) {
    setState(() {
      if (m['deadLayers'] is List) {
        _layers
          ..clear()
          ..addAll([
            for (final l in (m['deadLayers'] as List))
              _Layer((l['id'] as num?)?.toInt() ?? 0, '${l['name']}', nv('${l['weight']}'))
          ]);
      }
      if (m['selfWeight'] != null) _selfWeight.text = '${m['selfWeight']}';
      if (m['liveLoads'] is List) {
        final loaded = [
          for (final l in (m['liveLoads'] as List)) _Live('${l['id']}', '${l['label']}', nv('${l['value']}'))
        ];
        if (loaded.isNotEmpty) _live = loaded;
      }
      if (m['selectedLiveId'] != null) _liveId = '${m['selectedLiveId']}';
      if (!_live.any((l) => l.id == _liveId)) _liveId = _live.first.id;
      _liveValue.text = plain(_selected.value);
      if (m['dCoef1'] != null) _d1.text = '${m['dCoef1']}';
      if (m['dCoef2'] != null) _d2.text = '${m['dCoef2']}';
      if (m['lCoef2'] != null) _l2.text = '${m['lCoef2']}';
      if (m['seismicA'] != null) _a.text = '${m['seismicA']}';
      if (m['seismicB'] != null) _b.text = '${m['seismicB']}';
      if (m['seismicI'] != null) _i.text = '${m['seismicI']}';
      if (m['seismicR'] != null) _r.text = '${m['seismicR']}';
      if (m['liveLoadSeismicPercent'] != null) _livePct.text = '${m['liveLoadSeismicPercent']}';
      if (m['totalFloorArea'] != null) _area.text = '${m['totalFloorArea']}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final deadFromLayers = _layers.fold<double>(0, (s, l) => s + l.weight);
    final totalDead = deadFromLayers + nv(_selfWeight.text);
    final liveLoad = _selected.value;

    final dC1 = nv(_d1.text), dC2 = nv(_d2.text), lC2 = nv(_l2.text);
    final combo1 = dC1 * totalDead;
    final combo2 = dC2 * totalDead + lC2 * liveLoad;
    final governing = combo1 > combo2 ? combo1 : combo2;

    final sA = nv(_a.text), sB = nv(_b.text), sI = nv(_i.text), sR = nv(_r.text);
    final pct = nv(_livePct.text);
    final wPerArea = totalDead + (liveLoad * (pct / 100));
    final area = nv(_area.text);
    final totalW = wPerArea * area;
    final coef = sR > 0 ? (sA * sB * sI) / sR : 0.0;
    final baseShear = coef * totalW;

    return ToolPage(
      toolId: 'loading-combination-calculator',
      title: widget.title,
      description: '',
      getData: _data,
      onLoad: _load,
      children: [
        const NoticeBox(
            '⚠️ این ابزار صرفاً یک کمک‌محاسبه است و جایگزین محاسبات و مهر مهندس محاسب دارای پروانه نیست. مقادیر پیش‌فرض بار زنده و ضرایب لرزه‌ای، مقادیر رایج و قابل‌ویرایش‌اند — پیش از استفاده‌ی نهایی، حتماً با آخرین ویرایش رسمی مبحث ۶، مبحث ۹ و استاندارد ۲۸۰۰ تطبیق دهید.'),
        ToolSection('۱) بار مرده (Dead Load)', [
          NumInput(label: 'وزن سازه‌ای (سقف/تیر و...)', unit: 'کیلوگرم بر مترمربع', controller: _selfWeight, onChanged: _s),
          const SizedBox(height: 10),
          const Text('لایه‌های تمام‌شده و اجزای دیگر:', style: TextStyle(fontSize: 12, color: C.soft)),
          for (var i = 0; i < _layers.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                Expanded(
                    child: Text('${_layers[i].name} — ${plain(_layers[i].weight)} kg/m²',
                        style: const TextStyle(fontSize: 12.5))),
                TextButton(
                    onPressed: () => setState(() => _layers.removeAt(i)),
                    child: const Text('حذف', style: TextStyle(color: C.danger))),
              ]),
            ),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
                flex: 2,
                child: TextField(
                    controller: _layerName, decoration: const InputDecoration(hintText: 'نام لایه (مثلاً کف‌سازی)'))),
            const SizedBox(width: 8),
            Expanded(
                child: TextField(
                    controller: _layerWeight,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(hintText: 'kg/m²'))),
          ]),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _addLayer, child: const Text('افزودن لایه')),
          const SizedBox(height: 8),
          ResultRow('جمع بار مرده (D)', fixed(totalDead, 0), unit: 'kg/m²', highlight: true),
        ]),
        ToolSection('۲) بار زنده (Live Load) — مبحث ۶', [
          const Text('نوع کاربری را انتخاب کن، یا عدد را ویرایش کن:', style: TextStyle(fontSize: 12, color: C.soft)),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            value: _liveId,
            isExpanded: true,
            dropdownColor: C.bg2,
            items: [
              for (final l in _live)
                DropdownMenuItem(value: l.id, child: Text('${l.label} — ${plain(l.value)} kg/m²', overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() {
              _liveId = v ?? _liveId;
              _liveValue.text = plain(_selected.value);
            }),
          ),
          const SizedBox(height: 10),
          NumInput(
              label: 'مقدار ${_selected.label} (kg/m²)',
              controller: _liveValue,
              onChanged: () => setState(() => _selected.value = nv(_liveValue.text))),
          const SizedBox(height: 8),
          ResultRow('بار زنده انتخابی (L)', fixed(liveLoad, 0), unit: 'kg/m²', highlight: true),
        ]),
        ToolSection('۳) ترکیب بار (حالت حدی نهایی — مبحث ۹)', [
          FieldGrid([
            NumInput(label: 'ضریب D (حالت ۱)', controller: _d1, onChanged: _s),
            NumInput(label: 'ضریب D (حالت ۲)', controller: _d2, onChanged: _s),
            NumInput(label: 'ضریب L (حالت ۲)', controller: _l2, onChanged: _s),
          ]),
          ResultRow('${plain(dC1)}D', fixed(combo1, 0), unit: 'kg/m²'),
          ResultRow('${plain(dC2)}D + ${plain(lC2)}L', fixed(combo2, 0), unit: 'kg/m²'),
          ResultRow('بار طرح حاکم (بیشینه)', fixed(governing, 0), unit: 'kg/m²', highlight: true),
        ]),
        ToolSection('۴) برش پایه لرزه‌ای (استاندارد ۲۸۰۰)', [
          FieldGrid([
            NumInput(label: 'A — شتاب مبنای طرح', controller: _a, onChanged: _s),
            NumInput(label: 'B — ضریب بازتاب طیفی', controller: _b, onChanged: _s),
            NumInput(label: 'I — ضریب اهمیت', controller: _i, onChanged: _s),
            NumInput(label: 'R — ضریب رفتار', controller: _r, onChanged: _s),
          ]),
          const Text('یا از سیستم‌های رایج، ضریب R را انتخاب کن:', style: TextStyle(fontSize: 11.5, color: C.soft)),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            value: _rPick,
            isExpanded: true,
            dropdownColor: C.bg2,
            items: [
              const DropdownMenuItem(value: '', child: Text('— انتخاب سیستم سازه‌ای —')),
              for (final o in _rOptions)
                DropdownMenuItem(value: o[0] as String, child: Text('${o[1]} (R=${plain(o[2] as double)})', overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() {
              _rPick = v ?? '';
              for (final o in _rOptions) {
                if (o[0] == v) _r.text = plain(o[2] as double);
              }
            }),
          ),
          const SizedBox(height: 10),
          FieldGrid([
            NumInput(label: 'درصد بار زنده مؤثر در وزن لرزه‌ای', controller: _livePct, onChanged: _s),
            NumInput(label: 'مساحت کل ساختمان (مترمربع)', controller: _area, onChanged: _s),
          ]),
          ResultRow("وزن لرزه‌ای هر مترمربع (W')", fixed(wPerArea, 0), unit: 'kg/m²'),
          ResultRow('ضریب زلزله (C = ABI/R)', fixed(coef, 3)),
          if (area > 0) ...[
            ResultRow('وزن کل لرزه‌ای ساختمان (W)', fixed(totalW, 0), unit: 'kg'),
            ResultRow('برش پایه (V = C × W)', fixed(baseShear, 0), unit: 'kg', highlight: true),
          ],
          if (area == 0)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('برای محاسبه‌ی برش پایه‌ی کل ساختمان، مساحت کل رو وارد کن.',
                  style: TextStyle(fontSize: 12, color: C.muted)),
            ),
        ]),
      ],
    );
  }
}
