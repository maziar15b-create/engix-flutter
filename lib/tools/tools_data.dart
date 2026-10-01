import 'dart:math';

class ToolInput {
  final String key, label;
  const ToolInput(this.key, this.label);
}

class ToolResult {
  final String label, value, unit;
  const ToolResult(this.label, this.value, [this.unit = '']);
}

class ToolDef {
  final String id, name, description, category;
  final List<ToolInput> inputs;
  final List<ToolResult> Function(Map<String, double> v) calc;
  const ToolDef({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.inputs,
    required this.calc,
  });
}

/// [کلید دسته، عنوان نمایشی]
const List<List<String>> toolCategories = [
  ['general', 'عمومی'],
  ['civil', 'عمران'],
  ['asphalt', 'آسفالت'],
];

String _f(double x, [int d = 2]) => x.toStringAsFixed(d);

String _group(double x) {
  final s = x.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0 && s[i - 1] != '-') b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

final List<ToolDef> allTools = [
  ToolDef(
    id: 'concrete-volume',
    name: 'حجم بتن (سریع)',
    description: 'محاسبه سریع حجم بتن از روی طول، عرض و ارتفاع',
    category: 'civil',
    inputs: const [
      ToolInput('length', 'طول (متر)'),
      ToolInput('width', 'عرض (متر)'),
      ToolInput('height', 'ارتفاع (متر)'),
      ToolInput('waste', 'درصد پرت (مثلاً ۵)'),
    ],
    calc: (v) {
      final vol = v['length']! * v['width']! * v['height']!;
      final total = vol * (1 + v['waste']! / 100);
      return [
        ToolResult('حجم خالص', _f(vol), 'متر مکعب'),
        ToolResult('حجم با پرت', _f(total), 'متر مکعب'),
      ];
    },
  ),
  ToolDef(
    id: 'rebar-weight',
    name: 'وزن میلگرد',
    description: 'وزن میلگرد بر اساس قطر، طول و تعداد',
    category: 'civil',
    inputs: const [
      ToolInput('d', 'قطر (میلی‌متر)'),
      ToolInput('length', 'طول هر شاخه (متر)'),
      ToolInput('count', 'تعداد'),
    ],
    calc: (v) {
      final perM = pow(v['d']!, 2) / 162; // کیلوگرم بر متر
      return [
        ToolResult('وزن هر متر', _f(perM, 3), 'کیلوگرم'),
        ToolResult('وزن کل', _f(perM * v['length']! * v['count']!), 'کیلوگرم'),
      ];
    },
  ),
  ToolDef(
    id: 'unit-converter-length',
    name: 'تبدیل واحد طول',
    description: 'تبدیل بین متر، سانتی‌متر، اینچ و فوت',
    category: 'general',
    inputs: const [
      ToolInput('value', 'مقدار'),
      ToolInput('fromUnit', 'واحد مبدأ (1=متر, 2=سانتی‌متر, 3=اینچ, 4=فوت)'),
    ],
    calc: (v) {
      final u = v['fromUnit']!.round();
      final x = v['value']!;
      final m = u == 1 ? x : u == 2 ? x / 100 : u == 3 ? x * 0.0254 : x * 0.3048;
      return [
        ToolResult('متر', _f(m, 4), 'm'),
        ToolResult('سانتی‌متر', _f(m * 100), 'cm'),
        ToolResult('اینچ', _f(m / 0.0254), 'in'),
        ToolResult('فوت', _f(m / 0.3048), 'ft'),
      ];
    },
  ),
  ToolDef(
    id: 'unit-converter-area',
    name: 'تبدیل واحد مساحت',
    description: 'تبدیل متر مربع به هکتار',
    category: 'general',
    inputs: const [ToolInput('value', 'مقدار (متر مربع)')],
    calc: (v) => [
      ToolResult('متر مربع', _f(v['value']!), 'm²'),
      ToolResult('هکتار', _f(v['value']! / 10000, 4), 'ha'),
    ],
  ),
  ToolDef(
    id: 'financial-calculator',
    name: 'ماشین حساب مالی',
    description: 'قسط ماهانه‌ی وام بر اساس مبلغ، نرخ سود و مدت',
    category: 'general',
    inputs: const [
      ToolInput('principal', 'مبلغ وام (تومان)'),
      ToolInput('annualRate', 'نرخ سود سالانه (درصد)'),
      ToolInput('months', 'مدت بازپرداخت (ماه)'),
    ],
    calc: (v) {
      final r = v['annualRate']! / 100 / 12;
      final n = v['months']!;
      final p = v['principal']!;
      double inst;
      if (r == 0) {
        inst = p / n;
      } else {
        final k = pow(1 + r, n);
        inst = p * r * k / (k - 1);
      }
      return [
        ToolResult('قسط ماهانه', _group(inst), 'تومان'),
        ToolResult('مجموع بازپرداخت', _group(inst * n), 'تومان'),
      ];
    },
  ),
  ToolDef(
    id: 'asphalt-volume-weight',
    name: 'آسفالت',
    description: 'حجم و وزن آسفالت موردنیاز برای یک سطح',
    category: 'asphalt',
    inputs: const [
      ToolInput('length', 'طول (متر)'),
      ToolInput('width', 'عرض (متر)'),
      ToolInput('thickness', 'ضخامت (سانتی‌متر، معمولاً ۴ تا ۷)'),
      ToolInput('density', 'وزن مخصوص (کیلوگرم بر متر مکعب، معمولاً ۲۳۵۰)'),
    ],
    calc: (v) {
      final area = v['length']! * v['width']!;
      final vol = area * v['thickness']! / 100;
      return [
        ToolResult('مساحت', _f(area), 'متر مربع'),
        ToolResult('حجم آسفالت', _f(vol), 'متر مکعب'),
        ToolResult('وزن آسفالت', _f(vol * v['density']! / 1000), 'تن'),
      ];
    },
  ),
  ToolDef(
    id: 'asphalt-layers',
    name: 'آسفالت دو لایه (بیندر و توپکا)',
    description: 'وزن جداگانه‌ی لایه‌ی بیندر و لایه‌ی رویه (توپکا)',
    category: 'asphalt',
    inputs: const [
      ToolInput('area', 'مساحت (متر مربع)'),
      ToolInput('binder', 'ضخامت بیندر (سانتی‌متر، معمولاً ۵)'),
      ToolInput('surface', 'ضخامت توپکا (سانتی‌متر، معمولاً ۴)'),
    ],
    calc: (v) {
      const density = 2350;
      final b = v['area']! * v['binder']! / 100 * density / 1000;
      final s = v['area']! * v['surface']! / 100 * density / 1000;
      return [
        ToolResult('وزن لایه بیندر', _f(b), 'تن'),
        ToolResult('وزن لایه توپکا', _f(s), 'تن'),
        ToolResult('وزن کل', _f(b + s), 'تن'),
      ];
    },
  ),
];
