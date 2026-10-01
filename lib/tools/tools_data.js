import 'dart:math' as math;

class ToolInput {
  final String key;
  final String label;
  const ToolInput(this.key, this.label);
}

class ToolResult {
  final String label;
  final String value;
  final String unit;
  const ToolResult(this.label, this.value, [this.unit = '']);
}

class ToolDef {
  final String id;
  final String name;
  final String description;
  final String category;
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

String fx(double x, int digits) {
  if (!x.isFinite) return 'نامعتبر';
  return x.toStringAsFixed(digits);
}

String money(double x) {
  if (!x.isFinite) return 'نامعتبر';
  final s = x.round().abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return (x < 0 ? '-' : '') + b.toString();
}

const catGeneral = 'عمومی';
const catCivil = 'عمران';
const catElectrical = 'برق';

const toolCategories = <List<String>>[
  [catCivil, 'ابزارهای عمران'],
  [catElectrical, 'برق'],
  [catGeneral, 'عمومی'],
];

final List<ToolDef> allTools = <ToolDef>[
  // ───────── عمران ─────────
  ToolDef(
    id: 'concrete-volume',
    name: 'حجم بتن',
    description: 'محاسبه حجم بتن مورد نیاز بر اساس ابعاد',
    category: catCivil,
    inputs: const [
      ToolInput('length', 'طول (متر)'),
      ToolInput('width', 'عرض (متر)'),
      ToolInput('height', 'ارتفاع/ضخامت (متر)'),
    ],
    calc: (v) => [
      ToolResult('حجم بتن', fx(v['length']! * v['width']! * v['height']!, 2),
          'متر مکعب'),
    ],
  ),
  ToolDef(
    id: 'rebar-weight',
    name: 'وزن میلگرد',
    description: 'محاسبه وزن میلگرد بر اساس قطر و طول',
    category: catCivil,
    inputs: const [
      ToolInput('diameter', 'قطر میلگرد (میلی‌متر)'),
      ToolInput('length', 'طول کل (متر)'),
    ],
    calc: (v) {
      final wpm = (v['diameter']! * v['diameter']!) / 162;
      return [
        ToolResult('وزن هر متر', fx(wpm, 3), 'کیلوگرم'),
        ToolResult('وزن کل', fx(wpm * v['length']!, 2), 'کیلوگرم'),
      ];
    },
  ),
  ToolDef(
    id: 'rebar-count',
    name: 'تعداد میلگرد',
    description: 'تعداد میلگرد در یک طول مشخص به همراه وزن کل',
    category: catCivil,
    inputs: const [
      ToolInput('totalLength', 'طول کل عضو (متر)'),
      ToolInput('spacing', 'فاصله میلگردها (سانتی‌متر)'),
      ToolInput('barLength', 'طول هر میلگرد (متر)'),
      ToolInput('diameter', 'قطر میلگرد (میلی‌متر)'),
      ToolInput('steelGrade', 'رده فولاد (1=A1 ساده، 2=A2، 3=A3 آجدار)'),
    ],
    calc: (v) {
      final spacingM = v['spacing']! / 100;
      final count = (v['totalLength']! / spacingM).floor() + 1;
      final wpm = (v['diameter']! * v['diameter']!) / 162;
      final total = wpm * v['barLength']! * count;
      final grade = v['steelGrade']!.round();
      const labels = {1: 'A1 (ساده)', 2: 'A2 (آجدار)', 3: 'A3 (آجدار)'};
      return [
        ToolResult('تعداد میلگرد', '$count', 'عدد'),
        ToolResult('رده فولاد', labels[grade] ?? 'رده $grade'),
        ToolResult('وزن هر متر', fx(wpm, 3), 'کیلوگرم'),
        ToolResult('وزن کل', fx(total, 2), 'کیلوگرم'),
      ];
    },
  ),
  ToolDef(
    id: 'formwork-area',
    name: 'قالب‌بندی',
    description: 'محاسبه سطح قالب‌بندی مورد نیاز',
    category: catCivil,
    inputs: const [
      ToolInput('length', 'طول (متر)'),
      ToolInput('height', 'ارتفاع (متر)'),
      ToolInput('sides', 'تعداد وجه (معمولاً ۲ یا ۴)'),
    ],
    calc: (v) => [
      ToolResult('سطح قالب‌بندی',
          fx(v['length']! * v['height']! * v['sides']!, 2), 'متر مربع'),
    ],
  ),
  ToolDef(
    id: 'column-volume',
    name: 'ستون',
    description: 'محاسبه حجم بتن ستون',
    category: catCivil,
    inputs: const [
      ToolInput('width', 'عرض مقطع (متر)'),
      ToolInput('depth', 'عمق مقطع (متر)'),
      ToolInput('height', 'ارتفاع ستون (متر)'),
      ToolInput('count', 'تعداد ستون'),
    ],
    calc: (v) {
      final single = v['width']! * v['depth']! * v['height']!;
      return [
        ToolResult('حجم هر ستون', fx(single, 3), 'متر مکعب'),
        ToolResult('حجم کل', fx(single * v['count']!, 2), 'متر مکعب'),
      ];
    },
  ),
  ToolDef(
    id: 'beam-volume',
    name: 'تیر',
    description: 'محاسبه حجم بتن تیر',
    category: catCivil,
    inputs: const [
      ToolInput('width', 'عرض مقطع (متر)'),
      ToolInput('height', 'ارتفاع مقطع (متر)'),
      ToolInput('length', 'طول تیر (متر)'),
      ToolInput('count', 'تعداد تیر'),
    ],
    calc: (v) {
      final single = v['width']! * v['height']! * v['length']!;
      return [
        ToolResult('حجم هر تیر', fx(single, 3), 'متر مکعب'),
        ToolResult('حجم کل', fx(single * v['count']!, 2), 'متر مکعب'),
      ];
    },
  ),
  ToolDef(
    id: 'roof-volume',
    name: 'سقف',
    description: 'محاسبه حجم بتن سقف بر اساس مساحت و ضخامت',
    category: catCivil,
    inputs: const [
      ToolInput('area', 'مساحت سقف (متر مربع)'),
      ToolInput('thickness', 'ضخامت سقف (سانتی‌متر)'),
    ],
    calc: (v) => [
      ToolResult(
          'حجم بتن سقف', fx(v['area']! * (v['thickness']! / 100), 2), 'متر مکعب'),
    ],
  ),
  ToolDef(
    id: 'wall-volume',
    name: 'دیوار',
    description: 'محاسبه حجم بتن یا مصالح دیوار',
    category: catCivil,
    inputs: const [
      ToolInput('length', 'طول دیوار (متر)'),
      ToolInput('height', 'ارتفاع دیوار (متر)'),
      ToolInput('thickness', 'ضخامت دیوار (سانتی‌متر)'),
    ],
    calc: (v) => [
      ToolResult(
          'حجم دیوار',
          fx(v['length']! * v['height']! * (v['thickness']! / 100), 2),
          'متر مکعب'),
    ],
  ),
  ToolDef(
    id: 'foundation-volume',
    name: 'فونداسیون',
    description: 'محاسبه حجم بتن فونداسیون نواری یا منفرد',
    category: catCivil,
    inputs: const [
      ToolInput('length', 'طول (متر)'),
      ToolInput('width', 'عرض (متر)'),
      ToolInput('depth', 'عمق (متر)'),
    ],
    calc: (v) => [
      ToolResult('حجم فونداسیون',
          fx(v['length']! * v['width']! * v['depth']!, 2), 'متر مکعب'),
    ],
  ),
  ToolDef(
    id: 'excavation-volume',
    name: 'خاکبرداری',
    description: 'محاسبه حجم خاکبرداری بر اساس ابعاد گودال',
    category: catCivil,
    inputs: const [
      ToolInput('length', 'طول (متر)'),
      ToolInput('width', 'عرض (متر)'),
      ToolInput('depth', 'عمق (متر)'),
    ],
    calc: (v) => [
      ToolResult('حجم خاکبرداری',
          fx(v['length']! * v['width']! * v['depth']!, 2), 'متر مکعب'),
    ],
  ),
  ToolDef(
    id: 'pit-excavation',
    name: 'گودبرداری',
    description: 'محاسبه حجم گودبرداری با احتساب شیب دیواره',
    category: catCivil,
    inputs: const [
      ToolInput('length', 'طول کف گود (متر)'),
      ToolInput('width', 'عرض کف گود (متر)'),
      ToolInput('depth', 'عمق گود (متر)'),
      ToolInput('slope', 'شیب دیواره (مثلاً 0.5 برای هر متر عمق)'),
    ],
    calc: (v) {
      final topL = v['length']! + 2 * v['depth']! * v['slope']!;
      final topW = v['width']! + 2 * v['depth']! * v['slope']!;
      final avgL = (v['length']! + topL) / 2;
      final avgW = (v['width']! + topW) / 2;
      return [
        ToolResult('حجم گودبرداری', fx(avgL * avgW * v['depth']!, 2), 'متر مکعب'),
      ];
    },
  ),
  ToolDef(
    id: 'backfill-volume',
    name: 'خاکریزی',
    description: 'حجم خاک لازم برای خاکریزی با احتساب ضریب تراکم',
    category: catCivil,
    inputs: const [
      ToolInput('length', 'طول (متر)'),
      ToolInput('width', 'عرض (متر)'),
      ToolInput('height', 'ارتفاع خاکریز متراکم‌شده (متر)'),
      ToolInput('compactionFactor', 'ضریب تراکم (معمولاً 1.15 تا 1.3)'),
    ],
    calc: (v) {
      final compacted = v['length']! * v['width']! * v['height']!;
      return [
        ToolResult('حجم خاکریز متراکم‌شده (نهایی)', fx(compacted, 2), 'متر مکعب'),
        ToolResult('حجم خاک شل موردنیاز',
            fx(compacted * v['compactionFactor']!, 2), 'متر مکعب'),
      ];
    },
  ),
  ToolDef(
    id: 'material-estimate',
    name: 'برآورد مصالح',
    description: 'برآورد سیمان، ماسه و شن بر اساس حجم بتن (نسبت 1:2:4)',
    category: catCivil,
    inputs: const [ToolInput('concreteVolume', 'حجم بتن (متر مکعب)')],
    calc: (v) {
      final c = v['concreteVolume']!;
      return [
        ToolResult('سیمان', fx(c * 6.5, 1), 'کیسه (۵۰ کیلویی)'),
        ToolResult('ماسه', fx(c * 0.44, 2), 'متر مکعب'),
        ToolResult('شن', fx(c * 0.88, 2), 'متر مکعب'),
      ];
    },
  ),
  ToolDef(
    id: 'cost-estimate',
    name: 'برآورد هزینه',
    description: 'برآورد هزینه کل بر اساس مقدار و قیمت واحد',
    category: catCivil,
    inputs: const [
      ToolInput('quantity', 'مقدار'),
      ToolInput('unitPrice', 'قیمت واحد (تومان)'),
    ],
    calc: (v) => [
      ToolResult('هزینه کل', money(v['quantity']! * v['unitPrice']!), 'تومان'),
    ],
  ),

  // ───────── برق ─────────
  ToolDef(
    id: 'cable-size',
    name: 'محاسبه کابل',
    description: 'برآورد سطح مقطع کابل بر اساس جریان و طول',
    category: catElectrical,
    inputs: const [
      ToolInput('current', 'جریان (آمپر)'),
      ToolInput('length', 'طول مسیر (متر)'),
      ToolInput('voltage', 'ولتاژ (ولت)'),
    ],
    calc: (v) => [
      ToolResult('سطح مقطع تقریبی کابل',
          fx((v['current']! * v['length']!) / (v['voltage']! * 0.5), 2),
          'میلی‌متر مربع'),
    ],
  ),
  ToolDef(
    id: 'voltage-drop',
    name: 'افت ولتاژ',
    description: 'محاسبه افت ولتاژ در طول کابل',
    category: catElectrical,
    inputs: const [
      ToolInput('current', 'جریان (آمپر)'),
      ToolInput('length', 'طول مسیر (متر)'),
      ToolInput('crossSection', 'سطح مقطع کابل (میلی‌متر مربع)'),
    ],
    calc: (v) => [
      ToolResult(
          'افت ولتاژ',
          fx((2 * 0.0175 * v['length']! * v['current']!) / v['crossSection']!,
              2),
          'ولت'),
    ],
  ),
  ToolDef(
    id: 'fuse-rating',
    name: 'فیوز',
    description: 'آمپراژ فیوز مناسب بر اساس توان و ولتاژ',
    category: catElectrical,
    inputs: const [
      ToolInput('power', 'توان (وات)'),
      ToolInput('voltage', 'ولتاژ (ولت)'),
    ],
    calc: (v) {
      final i = v['power']! / v['voltage']!;
      return [
        ToolResult('جریان مصرفی', fx(i, 2), 'آمپر'),
        ToolResult('آمپراژ پیشنهادی فیوز', fx(i * 1.25, 1), 'آمپر'),
      ];
    },
  ),
  ToolDef(
    id: 'electrical-panel',
    name: 'تابلو برق',
    description: 'تعداد مدار خروجی مورد نیاز تابلو برق',
    category: catElectrical,
    inputs: const [
      ToolInput('totalLoad', 'بار کل (وات)'),
      ToolInput('circuitCapacity', 'ظرفیت هر مدار (وات)'),
    ],
    calc: (v) {
      final n = v['totalLoad']! / v['circuitCapacity']!;
      return [
        ToolResult('تعداد مدار مورد نیاز', n.isFinite ? '${n.ceil()}' : 'نامعتبر',
            'مدار'),
      ];
    },
  ),
  ToolDef(
    id: 'lighting-calc',
    name: 'روشنایی',
    description: 'تعداد چراغ مورد نیاز بر اساس مساحت و لوکس مطلوب',
    category: catElectrical,
    inputs: const [
      ToolInput('roomArea', 'مساحت اتاق (متر مربع)'),
      ToolInput('requiredLux', 'شدت روشنایی مطلوب (لوکس)'),
      ToolInput('lumensPerFixture', 'لومن هر چراغ'),
    ],
    calc: (v) {
      final n =
          (v['roomArea']! * v['requiredLux']!) / v['lumensPerFixture']!;
      return [
        ToolResult(
            'تعداد چراغ مورد نیاز', n.isFinite ? '${n.ceil()}' : 'نامعتبر', 'عدد'),
      ];
    },
  ),
  ToolDef(
    id: 'grounding',
    name: 'ارت',
    description: 'برآورد مقاومت الکترود ارت (فرمول ساده میله‌ای)',
    category: catElectrical,
    inputs: const [
      ToolInput('rodLength', 'طول میله ارت (متر)'),
      ToolInput('soilResistivity', 'مقاومت مخصوص خاک (اهم‌متر)'),
    ],
    calc: (v) => [
      ToolResult(
          'مقاومت تقریبی ارت',
          fx(v['soilResistivity']! / (2 * math.pi * v['rodLength']!), 2),
          'اهم'),
    ],
  ),
  ToolDef(
    id: 'motor-current',
    name: 'موتور',
    description: 'جریان مصرفی موتور بر اساس توان و ولتاژ',
    category: catElectrical,
    inputs: const [
      ToolInput('power', 'توان موتور (کیلووات)'),
      ToolInput('voltage', 'ولتاژ (ولت)'),
      ToolInput('efficiency', 'راندمان (درصد، مثلاً 85)'),
    ],
    calc: (v) => [
      ToolResult(
          'جریان مصرفی موتور',
          fx((v['power']! * 1000) / (v['voltage']! * (v['efficiency']! / 100)),
              2),
          'آمپر'),
    ],
  ),
  ToolDef(
    id: 'generator-sizing',
    name: 'ژنراتور',
    description: 'ظرفیت ژنراتور مورد نیاز با ضریب اطمینان',
    category: catElectrical,
    inputs: const [
      ToolInput('totalLoad', 'بار کل (کیلووات)'),
      ToolInput('safetyFactor', 'ضریب اطمینان (مثلاً 1.25)'),
    ],
    calc: (v) => [
      ToolResult('ظرفیت پیشنهادی ژنراتور',
          fx(v['totalLoad']! * v['safetyFactor']!, 1), 'کیلووات'),
    ],
  ),

  // ───────── عمومی ─────────
  ToolDef(
    id: 'unit-converter-length',
    name: 'تبدیل واحد طول',
    description: 'تبدیل بین متر، سانتی‌متر، اینچ و فوت',
    category: catGeneral,
    inputs: const [
      ToolInput('value', 'مقدار'),
      ToolInput('fromUnit', 'واحد مبدأ (1=متر، 2=سانتی‌متر، 3=اینچ، 4=فوت)'),
    ],
    calc: (v) {
      final from = v['fromUnit']!.round();
      double meters;
      if (from == 1) {
        meters = v['value']!;
      } else if (from == 2) {
        meters = v['value']! / 100;
      } else if (from == 3) {
        meters = v['value']! * 0.0254;
      } else {
        meters = v['value']! * 0.3048;
      }
      return [
        ToolResult('متر', fx(meters, 4), 'm'),
        ToolResult('سانتی‌متر', fx(meters * 100, 2), 'cm'),
        ToolResult('اینچ', fx(meters / 0.0254, 2), 'in'),
        ToolResult('فوت', fx(meters / 0.3048, 2), 'ft'),
      ];
    },
  ),
  ToolDef(
    id: 'unit-converter-area',
    name: 'تبدیل واحد مساحت',
    description: 'تبدیل بین متر مربع، هکتار و جریب',
    category: catGeneral,
    inputs: const [ToolInput('value', 'مقدار (متر مربع)')],
    calc: (v) => [
      ToolResult('متر مربع', fx(v['value']!, 2), 'm²'),
      ToolResult('هکتار', fx(v['value']! / 10000, 4), 'ha'),
      ToolResult('جریب', fx(v['value']! / 1000, 3), 'جریب'),
    ],
  ),
  ToolDef(
    id: 'financial-calculator',
    name: 'ماشین حساب مالی',
    description: 'قسط ماهانه وام بر اساس مبلغ، نرخ سود و مدت',
    category: catGeneral,
    inputs: const [
      ToolInput('principal', 'مبلغ وام (تومان)'),
      ToolInput('annualRate', 'نرخ سود سالانه (درصد)'),
      ToolInput('months', 'مدت بازپرداخت (ماه)'),
    ],
    calc: (v) {
      final months = v['months']!;
      final r = v['annualRate']! / 100 / 12;
      double installment;
      if (r == 0) {
        installment = v['principal']! / months;
      } else {
        final p = math.pow(1 + r, months).toDouble();
        installment = (v['principal']! * r * p) / (p - 1);
      }
      return [
        ToolResult('قسط ماهانه', money(installment), 'تومان'),
        ToolResult('مجموع بازپرداخت', money(installment * months), 'تومان'),
      ];
    },
  ),
  ToolDef(
    id: 'basic-calculator',
    name: 'ماشین حساب',
    description: 'چهار عمل اصلی روی دو عدد',
    category: catGeneral,
    inputs: const [
      ToolInput('a', 'عدد اول'),
      ToolInput('operator', 'عملگر (1=جمع، 2=تفریق، 3=ضرب، 4=تقسیم)'),
      ToolInput('b', 'عدد دوم'),
    ],
    calc: (v) {
      final op = v['operator']!.round();
      final a = v['a']!;
      final b = v['b']!;
      double r;
      if (op == 1) {
        r = a + b;
      } else if (op == 2) {
        r = a - b;
      } else if (op == 3) {
        r = a * b;
      } else {
        r = b != 0 ? a / b : double.nan;
      }
      return [
        ToolResult('نتیجه', r.isNaN ? 'نامعتبر (تقسیم بر صفر)' : '$r'),
      ];
    },
  ),
];

