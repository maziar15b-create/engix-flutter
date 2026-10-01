import 'dart:math';

// این فایل از روی ابزارهای فرمولی نسخه‌ی وب (lib/tools/*Calcs.js) ساخته شده است.
// ابزارهای دارای صفحه‌ی اختصاصی (طراحی تیر، ستون، متره و...) در این فایل نیستند.

class ToolInput {
  final String key, label;
  const ToolInput(this.key, this.label);
}

class ToolResult {
  final String label, value, unit;
  ToolResult({required this.label, required dynamic value, this.unit = ''})
      : value = value.toString();
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

extension _NumFmt on num {
  String toFixed(int d) => toStringAsFixed(d);

  String toLocaleString(String _) {
    final s = round().abs().toString();
    final b = StringBuffer(isNegative ? '-' : '');
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }
}

const double STEEL_DENSITY = 7850; // کیلوگرم بر متر مکعب

// وزن استاندارد تیرآهن IPE (کیلوگرم بر متر)
const Map<int, double> IPE_WEIGHTS = {
  80: 6.0, 100: 8.1, 120: 10.4, 140: 12.9, 160: 15.8, 180: 18.8,
  200: 22.4, 220: 26.2, 240: 30.7, 270: 36.1, 300: 42.2, 330: 49.1,
  360: 57.1, 400: 66.3, 450: 77.6, 500: 90.7, 550: 106, 600: 122,
};

// وزن استاندارد ناودانی UNP (کیلوگرم بر متر)
const Map<int, double> UNP_WEIGHTS = {
  50: 5.59, 65: 7.09, 80: 8.64, 100: 10.6, 120: 13.4, 140: 16.0,
  160: 18.8, 180: 22.0, 200: 25.3, 220: 29.4, 240: 33.2, 260: 37.9,
  280: 41.8, 300: 46.2,
};

/// [کلید دسته، عنوان نمایشی]
const List<List<String>> toolCategories = [
  ['civil', 'ابزارهای عمران'],
  ['architecture', 'معماری'],
  ['electrical', 'برق'],
  ['installations', 'تأسیسات'],
  ['mechanical', 'مکانیک'],
  ['surveying', 'نقشه‌برداری'],
  ['general', 'ابزارهای عمومی'],
];

final List<ToolDef> allTools = [
  ToolDef(
    id: "concrete-volume",
    name: "حجم بتن",
    description: "محاسبه حجم بتن مورد نیاز بر اساس ابعاد",
    category: "civil",
    inputs: const [
      ToolInput("length", "طول (متر)"),
      ToolInput("width", "عرض (متر)"),
      ToolInput("height", "ارتفاع/ضخامت (متر)"),
    ],
    calc: (v) {
      var volume = v['length']! * v['width']! * v['height']!;
      return [
        ToolResult(label: "حجم بتن", value: volume.toFixed(2), unit: "متر مکعب")
      ];
    },
  ),
  ToolDef(
    id: "rebar-weight",
    name: "وزن میلگرد",
    description: "محاسبه وزن میلگرد بر اساس قطر و طول",
    category: "civil",
    inputs: const [
      ToolInput("diameter", "قطر میلگرد (میلی‌متر)"),
      ToolInput("length", "طول کل (متر)"),
    ],
    calc: (v) {
      var weightPerMeter = (v['diameter']! * v['diameter']!) / 162;
      var totalWeight = weightPerMeter * v['length']!;
      return [
        ToolResult(label: "وزن هر متر", value: weightPerMeter.toFixed(3), unit: "کیلوگرم"),
        ToolResult(label: "وزن کل", value: totalWeight.toFixed(2), unit: "کیلوگرم")
      ];
    },
  ),
  ToolDef(
    id: "rebar-count",
    name: "تعداد میلگرد",
    description: "محاسبه تعداد میلگرد مورد نیاز در یک طول مشخص، به همراه وزن کل بر اساس قطر و رده فولاد",
    category: "civil",
    inputs: const [
      ToolInput("totalLength", "طول کل عضو (متر)"),
      ToolInput("spacing", "فاصله میلگردها (سانتی‌متر)"),
      ToolInput("barLength", "طول هر میلگرد (متر) — مثلاً طول تیر/ستون"),
      ToolInput("diameter", "قطر میلگرد (میلی‌متر) — مثلاً 8, 10, 12, 14, 16, 18, 20, 22, 25"),
      ToolInput("steelGrade", "رده فولاد (بنویس: 1 برای A1 ساده، 2 برای A2، 3 برای A3 آجدار)"),
    ],
    calc: (v) {
      var spacingMeters = v['spacing']! / 100;
      var count = (v['totalLength']! / spacingMeters).floor() + 1;
      var weightPerMeter = (v['diameter']! * v['diameter']!) / 162;
      var totalWeight = weightPerMeter * v['barLength']! * count;
      var g = v['steelGrade']!.round();
      var gradeLabel = g == 1 ? "A1 (ساده)" : g == 2 ? "A2 (آجدار)" : g == 3 ? "A3 (آجدار)" : "رده $g";
      return [
        ToolResult(label: "تعداد میلگرد", value: count, unit: "عدد"),
        ToolResult(label: "رده فولاد", value: gradeLabel, unit: ""),
        ToolResult(label: "وزن هر متر", value: weightPerMeter.toFixed(3), unit: "کیلوگرم"),
        ToolResult(label: "وزن کل", value: totalWeight.toFixed(2), unit: "کیلوگرم")
      ];
    },
  ),
  ToolDef(
    id: "formwork-area",
    name: "قالب‌بندی",
    description: "محاسبه سطح قالب‌بندی مورد نیاز",
    category: "civil",
    inputs: const [
      ToolInput("length", "طول (متر)"),
      ToolInput("height", "ارتفاع (متر)"),
      ToolInput("sides", "تعداد وجه (معمولاً ۲ یا ۴)"),
    ],
    calc: (v) {
      var area = v['length']! * v['height']! * v['sides']!;
      return [
        ToolResult(label: "سطح قالب‌بندی", value: area.toFixed(2), unit: "متر مربع")
      ];
    },
  ),
  ToolDef(
    id: "column-volume",
    name: "ستون",
    description: "محاسبه حجم بتن ستون",
    category: "civil",
    inputs: const [
      ToolInput("width", "عرض مقطع (متر)"),
      ToolInput("depth", "عمق مقطع (متر)"),
      ToolInput("height", "ارتفاع ستون (متر)"),
      ToolInput("count", "تعداد ستون"),
    ],
    calc: (v) {
      var singleVolume = v['width']! * v['depth']! * v['height']!;
      var totalVolume = singleVolume * v['count']!;
      return [
        ToolResult(label: "حجم هر ستون", value: singleVolume.toFixed(3), unit: "متر مکعب"),
        ToolResult(label: "حجم کل", value: totalVolume.toFixed(2), unit: "متر مکعب")
      ];
    },
  ),
  ToolDef(
    id: "beam-volume",
    name: "تیر",
    description: "محاسبه حجم بتن تیر",
    category: "civil",
    inputs: const [
      ToolInput("width", "عرض مقطع (متر)"),
      ToolInput("height", "ارتفاع مقطع (متر)"),
      ToolInput("length", "طول تیر (متر)"),
      ToolInput("count", "تعداد تیر"),
    ],
    calc: (v) {
      var singleVolume = v['width']! * v['height']! * v['length']!;
      var totalVolume = singleVolume * v['count']!;
      return [
        ToolResult(label: "حجم هر تیر", value: singleVolume.toFixed(3), unit: "متر مکعب"),
        ToolResult(label: "حجم کل", value: totalVolume.toFixed(2), unit: "متر مکعب")
      ];
    },
  ),
  ToolDef(
    id: "roof-volume",
    name: "سقف",
    description: "محاسبه حجم بتن سقف بر اساس مساحت و ضخامت",
    category: "civil",
    inputs: const [
      ToolInput("area", "مساحت سقف (متر مربع)"),
      ToolInput("thickness", "ضخامت سقف (سانتی‌متر)"),
    ],
    calc: (v) {
      var thicknessMeters = v['thickness']! / 100;
      var volume = v['area']! * thicknessMeters;
      return [
        ToolResult(label: "حجم بتن سقف", value: volume.toFixed(2), unit: "متر مکعب")
      ];
    },
  ),
  ToolDef(
    id: "wall-volume",
    name: "دیوار",
    description: "محاسبه حجم بتن یا مصالح دیوار",
    category: "civil",
    inputs: const [
      ToolInput("length", "طول دیوار (متر)"),
      ToolInput("height", "ارتفاع دیوار (متر)"),
      ToolInput("thickness", "ضخامت دیوار (سانتی‌متر)"),
    ],
    calc: (v) {
      var thicknessMeters = v['thickness']! / 100;
      var volume = v['length']! * v['height']! * thicknessMeters;
      return [
        ToolResult(label: "حجم دیوار", value: volume.toFixed(2), unit: "متر مکعب")
      ];
    },
  ),
  ToolDef(
    id: "foundation-volume",
    name: "فونداسیون",
    description: "محاسبه حجم بتن فونداسیون نواری یا منفرد",
    category: "civil",
    inputs: const [
      ToolInput("length", "طول (متر)"),
      ToolInput("width", "عرض (متر)"),
      ToolInput("depth", "عمق (متر)"),
    ],
    calc: (v) {
      var volume = v['length']! * v['width']! * v['depth']!;
      return [
        ToolResult(label: "حجم فونداسیون", value: volume.toFixed(2), unit: "متر مکعب")
      ];
    },
  ),
  ToolDef(
    id: "excavation-volume",
    name: "خاکبرداری",
    description: "محاسبه حجم خاکبرداری بر اساس ابعاد گودال",
    category: "civil",
    inputs: const [
      ToolInput("length", "طول (متر)"),
      ToolInput("width", "عرض (متر)"),
      ToolInput("depth", "عمق (متر)"),
    ],
    calc: (v) {
      var volume = v['length']! * v['width']! * v['depth']!;
      return [
        ToolResult(label: "حجم خاکبرداری", value: volume.toFixed(2), unit: "متر مکعب")
      ];
    },
  ),
  ToolDef(
    id: "pit-excavation",
    name: "گودبرداری",
    description: "محاسبه حجم گودبرداری با احتساب شیب دیواره",
    category: "civil",
    inputs: const [
      ToolInput("length", "طول کف گود (متر)"),
      ToolInput("width", "عرض کف گود (متر)"),
      ToolInput("depth", "عمق گود (متر)"),
      ToolInput("slope", "شیب دیواره (مثلاً ۰.۵ برای هر متر عمق)"),
    ],
    calc: (v) {
      var topLength = v['length']! + 2 * v['depth']! * v['slope']!;
      var topWidth = v['width']! + 2 * v['depth']! * v['slope']!;
      var avgLength = (v['length']! + topLength) / 2;
      var avgWidth = (v['width']! + topWidth) / 2;
      var volume = avgLength * avgWidth * v['depth']!;
      return [
        ToolResult(label: "حجم گودبرداری", value: volume.toFixed(2), unit: "متر مکعب")
      ];
    },
  ),
  ToolDef(
    id: "backfill-volume",
    name: "خاکریزی",
    description: "محاسبه حجم خاک لازم برای خاکریزی/تراکم، با احتساب ضریب تراکم (نسبت حجم خاک شل به خاک متراکم‌شده)",
    category: "civil",
    inputs: const [
      ToolInput("length", "طول (متر)"),
      ToolInput("width", "عرض (متر)"),
      ToolInput("height", "ارتفاع/ضخامت خاکریز متراکم‌شده (متر)"),
      ToolInput("compactionFactor", "ضریب تراکم (معمولاً بین ۱.۱۵ تا ۱.۳)"),
    ],
    calc: (v) {
      var compactedVolume = v['length']! * v['width']! * v['height']!;
      var looseVolumeNeeded = compactedVolume * v['compactionFactor']!;
      return [
        ToolResult(label: "حجم خاکریز متراکم‌شده (نهایی)", value: compactedVolume.toFixed(2), unit: "متر مکعب"),
        ToolResult(label: "حجم خاک شل موردنیاز (قبل از تراکم)", value: looseVolumeNeeded.toFixed(2), unit: "متر مکعب")
      ];
    },
  ),
  ToolDef(
    id: "material-estimate",
    name: "برآورد مصالح",
    description: "برآورد سیمان، ماسه و شن بر اساس حجم بتن (نسبت 1:2:4)",
    category: "civil",
    inputs: const [
      ToolInput("concreteVolume", "حجم بتن (متر مکعب)"),
    ],
    calc: (v) {
      var cementBags = v['concreteVolume']! * 6.5;
      var sandVolume = v['concreteVolume']! * 0.44;
      var gravelVolume = v['concreteVolume']! * 0.88;
      return [
        ToolResult(label: "سیمان", value: cementBags.toFixed(1), unit: "کیسه (۵۰ کیلویی)"),
        ToolResult(label: "ماسه", value: sandVolume.toFixed(2), unit: "متر مکعب"),
        ToolResult(label: "شن", value: gravelVolume.toFixed(2), unit: "متر مکعب")
      ];
    },
  ),
  ToolDef(
    id: "cost-estimate",
    name: "برآورد هزینه",
    description: "برآورد هزینه کل بر اساس مقدار و قیمت واحد",
    category: "civil",
    inputs: const [
      ToolInput("quantity", "مقدار"),
      ToolInput("unitPrice", "قیمت واحد (تومان)"),
    ],
    calc: (v) {
      var total = v['quantity']! * v['unitPrice']!;
      return [
        ToolResult(label: "هزینه کل", value: total.toLocaleString("fa-IR"), unit: "تومان")
      ];
    },
  ),
  ToolDef(
    id: "foundation-isolated",
    name: "پی منفرد",
    description: "محاسبه حجم و وزن بتن برای پی منفرد (تکی، زیر ستون)",
    category: "civil",
    inputs: const [
      ToolInput("length", "طول پی (متر)"),
      ToolInput("width", "عرض پی (متر)"),
      ToolInput("depth", "ارتفاع پی (متر)"),
      ToolInput("count", "تعداد پی (عدد)"),
    ],
    calc: (v) {
      var volumeOne = v['length']! * v['width']! * v['depth']!;
      var totalVolume = volumeOne * v['count']!;
      var totalWeight = totalVolume * 2400;
      return [
        ToolResult(label: "حجم بتن هر پی", value: volumeOne.toFixed(2), unit: "متر مکعب"),
        ToolResult(label: "حجم کل بتن", value: totalVolume.toFixed(2), unit: "متر مکعب"),
        ToolResult(label: "وزن کل بتن", value: totalWeight.toFixed(0), unit: "کیلوگرم")
      ];
    },
  ),
  ToolDef(
    id: "foundation-strip",
    name: "پی نواری",
    description: "محاسبه حجم و وزن بتن برای پی نواری (زیر دیوار یا ردیف ستون‌ها)",
    category: "civil",
    inputs: const [
      ToolInput("totalLength", "طول کل نوار پی (متر)"),
      ToolInput("width", "عرض پی (متر)"),
      ToolInput("depth", "ارتفاع پی (متر)"),
    ],
    calc: (v) {
      var volume = v['totalLength']! * v['width']! * v['depth']!;
      var weight = volume * 2400;
      return [
        ToolResult(label: "حجم بتن", value: volume.toFixed(2), unit: "متر مکعب"),
        ToolResult(label: "وزن بتن", value: weight.toFixed(0), unit: "کیلوگرم")
      ];
    },
  ),
  ToolDef(
    id: "foundation-raft",
    name: "پی گسترده",
    description: "محاسبه حجم و وزن بتن برای پی گسترده (رادیه ژنرال / مت)",
    category: "civil",
    inputs: const [
      ToolInput("area", "مساحت کل زیربنا (متر مربع)"),
      ToolInput("thickness", "ضخامت پی (متر)"),
    ],
    calc: (v) {
      var volume = v['area']! * v['thickness']!;
      var weight = volume * 2400;
      return [
        ToolResult(label: "حجم بتن", value: volume.toFixed(2), unit: "متر مکعب"),
        ToolResult(label: "وزن بتن", value: weight.toFixed(0), unit: "کیلوگرم")
      ];
    },
  ),
  ToolDef(
    id: "roof-joist-block",
    name: "سقف تیرچه بلوک",
    description: "برآورد تعداد تیرچه، بلوک و حجم بتن پوششی برای سقف تیرچه بلوک",
    category: "civil",
    inputs: const [
      ToolInput("span", "دهانه سقف (متر)"),
      ToolInput("width", "عرض سقف (متر)"),
      ToolInput("spacing", "فاصله محور تیرچه‌ها (سانتی‌متر، معمولاً ۵۰)"),
      ToolInput("toppingThickness", "ضخامت بتن پوششی (سانتی‌متر، معمولاً ۵)"),
    ],
    calc: (v) {
      var joistsCount = (v['width']! / (v['spacing']! / 100)).ceil() + 1;
      var totalJoistLength = joistsCount * v['span']!;
      var area = v['span']! * v['width']!;
      var blocksCount = (area * 8).ceil(); // برآورد تقریبی: ۸ بلوک استاندارد در هر متر مربع
      var toppingVolume = area * (v['toppingThickness']! / 100);
      return [
        ToolResult(label: "تعداد تیرچه", value: joistsCount.toFixed(0), unit: "عدد"),
        ToolResult(label: "طول کل تیرچه", value: totalJoistLength.toFixed(1), unit: "متر"),
        ToolResult(label: "تعداد بلوک (تقریبی)", value: blocksCount.toFixed(0), unit: "عدد"),
        ToolResult(label: "حجم بتن پوششی", value: toppingVolume.toFixed(2), unit: "متر مکعب")
      ];
    },
  ),
  ToolDef(
    id: "roof-composite-deck",
    name: "سقف عرشه فولادی کامپوزیت",
    description: "برآورد وزن ورق عرشه فولادی و حجم بتن سقف کامپوزیت",
    category: "civil",
    inputs: const [
      ToolInput("area", "مساحت سقف (متر مربع)"),
      ToolInput("slabThickness", "ضخامت کل دال (سانتی‌متر، معمولاً ۱۲-۱۵)"),
      ToolInput("deckWeightPerM2", "وزن ورق عرشه (کیلوگرم بر متر مربع، معمولاً ۱۰-۱۲)"),
    ],
    calc: (v) {
      var concreteVolume = v['area']! * (v['slabThickness']! / 100) * 0.75; // ۰.۷۵ ضریب کاهش به‌خاطر حجم اشغال‌شده توسط موج عرشه
      var concreteWeight = concreteVolume * 2400;
      var deckWeight = v['area']! * v['deckWeightPerM2']!;
      return [
        ToolResult(label: "حجم بتن (تقریبی)", value: concreteVolume.toFixed(2), unit: "متر مکعب"),
        ToolResult(label: "وزن بتن", value: concreteWeight.toFixed(0), unit: "کیلوگرم"),
        ToolResult(label: "وزن ورق عرشه فولادی", value: deckWeight.toFixed(0), unit: "کیلوگرم")
      ];
    },
  ),
  ToolDef(
    id: "roof-waffle",
    name: "سقف وافل",
    description: "برآورد حجم بتن سقف وافل بر اساس ضخامت موثر",
    category: "civil",
    inputs: const [
      ToolInput("area", "مساحت سقف (متر مربع)"),
      ToolInput("effectiveThickness", "ضخامت موثر معادل (سانتی‌متر — طبق محاسبات سازه)"),
    ],
    calc: (v) {
      var volume = v['area']! * (v['effectiveThickness']! / 100);
      var weight = volume * 2400;
      return [
        ToolResult(label: "حجم بتن", value: volume.toFixed(2), unit: "متر مکعب"),
        ToolResult(label: "وزن بتن", value: weight.toFixed(0), unit: "کیلوگرم")
      ];
    },
  ),
  ToolDef(
    id: "roof-solid-slab",
    name: "سقف دال بتنی توپر",
    description: "محاسبه حجم و وزن بتن برای سقف دال بتنی مسطح (بدون تیرچه)",
    category: "civil",
    inputs: const [
      ToolInput("length", "طول (متر)"),
      ToolInput("width", "عرض (متر)"),
      ToolInput("thickness", "ضخامت دال (سانتی‌متر)"),
    ],
    calc: (v) {
      var volume = v['length']! * v['width']! * (v['thickness']! / 100);
      var weight = volume * 2400;
      return [
        ToolResult(label: "حجم بتن", value: volume.toFixed(2), unit: "متر مکعب"),
        ToolResult(label: "وزن بتن", value: weight.toFixed(0), unit: "کیلوگرم")
      ];
    },
  ),
  ToolDef(
    id: "roof-jack-arch",
    name: "سقف طاق ضربی",
    description: "برآورد تعداد آجر/تیرآهن موردنیاز برای سقف طاق ضربی سنتی",
    category: "civil",
    inputs: const [
      ToolInput("area", "مساحت سقف (متر مربع)"),
      ToolInput("beamSpacing", "فاصله تیرآهن‌ها (سانتی‌متر، معمولاً ۸۰-۱۰۰)"),
      ToolInput("span", "دهانه سقف (متر)"),
    ],
    calc: (v) {
      var beamsCount = ((v['area']! / v['span']!) / (v['beamSpacing']! / 100)).ceil() + 1;
      var tilesCount = (v['area']! * 14).ceil(); // برآورد تقریبی ۱۴ آجر طاق‌ضربی در هر متر مربع
      return [
        ToolResult(label: "تعداد تیرآهن موردنیاز", value: beamsCount.toFixed(0), unit: "عدد"),
        ToolResult(label: "تعداد آجر طاق‌ضربی (تقریبی)", value: tilesCount.toFixed(0), unit: "عدد")
      ];
    },
  ),
  ToolDef(
    id: "asphalt-volume-weight",
    name: "آسفالت",
    description: "محاسبه حجم و وزن آسفالت موردنیاز برای یک سطح",
    category: "civil",
    inputs: const [
      ToolInput("length", "طول (متر)"),
      ToolInput("width", "عرض (متر)"),
      ToolInput("thickness", "ضخامت آسفالت (سانتی‌متر، معمولاً ۴-۷)"),
      ToolInput("density", "وزن مخصوص آسفالت (کیلوگرم بر متر مکعب، معمولاً ۲۳۵۰)"),
    ],
    calc: (v) {
      var area = v['length']! * v['width']!;
      var volume = area * (v['thickness']! / 100);
      var weightKg = volume * v['density']!;
      var weightTon = weightKg / 1000;
      return [
        ToolResult(label: "مساحت", value: area.toFixed(2), unit: "متر مربع"),
        ToolResult(label: "حجم آسفالت", value: volume.toFixed(2), unit: "متر مکعب"),
        ToolResult(label: "وزن آسفالت", value: weightTon.toFixed(2), unit: "تن")
      ];
    },
  ),
  ToolDef(
    id: "asphalt-layers",
    name: "آسفالت دو لایه (بیندر و توپکا)",
    description: "محاسبه جداگانه وزن لایه بیندر و لایه رویه (توپکا)",
    category: "civil",
    inputs: const [
      ToolInput("area", "مساحت (متر مربع)"),
      ToolInput("binderThickness", "ضخامت لایه بیندر (سانتی‌متر، معمولاً ۵)"),
      ToolInput("surfaceThickness", "ضخامت لایه توپکا/رویه (سانتی‌متر، معمولاً ۴)"),
    ],
    calc: (v) {
      num density = 2350;
      var binderWeight = (v['area']! * (v['binderThickness']! / 100) * density) / 1000;
      var surfaceWeight = (v['area']! * (v['surfaceThickness']! / 100) * density) / 1000;
      return [
        ToolResult(label: "وزن لایه بیندر", value: binderWeight.toFixed(2), unit: "تن"),
        ToolResult(label: "وزن لایه توپکا (رویه)", value: surfaceWeight.toFixed(2), unit: "تن"),
        ToolResult(label: "وزن کل آسفالت", value: (binderWeight + surfaceWeight).toFixed(2), unit: "تن")
      ];
    },
  ),
  ToolDef(
    id: "steel-angle-weight",
    name: "نبشی",
    description: "محاسبه وزن هر متر طول نبشی (پروفیل L) بر اساس ابعاد بال و ضخامت",
    category: "civil",
    inputs: const [
      ToolInput("leg", "طول بال (میلی‌متر، مثلاً برای نبشی 5×50×50 عدد ۵۰)"),
      ToolInput("thickness", "ضخامت (میلی‌متر، مثلاً برای نبشی 5×50×50 عدد ۵)"),
    ],
    calc: (v) {
      var areaMm2 = v['thickness']! * (2 * v['leg']! - v['thickness']!);
      var weightPerMeter = (areaMm2 * STEEL_DENSITY) / 1e6;
      return [
        ToolResult(label: "سطح مقطع", value: areaMm2.toFixed(1), unit: "میلی‌متر مربع"),
        ToolResult(label: "وزن هر متر طول", value: weightPerMeter.toFixed(2), unit: "کیلوگرم بر متر")
      ];
    },
  ),
  ToolDef(
    id: "steel-box-weight",
    name: "قوطی",
    description: "محاسبه وزن هر متر طول قوطی (پروفیل مربعی/مستطیلی) بر اساس ابعاد و ضخامت",
    category: "civil",
    inputs: const [
      ToolInput("sideA", "ضلع اول (میلی‌متر)"),
      ToolInput("sideB", "ضلع دوم (میلی‌متر — برای قوطی مربعی برابر ضلع اول بگذارید)"),
      ToolInput("thickness", "ضخامت جدار (میلی‌متر)"),
    ],
    calc: (v) {
      var areaMm2 = 2 * v['thickness']! * (v['sideA']! + v['sideB']! - 2 * v['thickness']!);
      var weightPerMeter = (areaMm2 * STEEL_DENSITY) / 1e6;
      return [
        ToolResult(label: "سطح مقطع", value: areaMm2.toFixed(1), unit: "میلی‌متر مربع"),
        ToolResult(label: "وزن هر متر طول", value: weightPerMeter.toFixed(2), unit: "کیلوگرم بر متر")
      ];
    },
  ),
  ToolDef(
    id: "steel-ibeam-weight",
    name: "تیرآهن (IPE)",
    description: "وزن دقیق تیرآهن بر اساس جدول استاندارد IPE (کیلوگرم بر متر)",
    category: "civil",
    inputs: const [
      ToolInput("size", "سایز تیرآهن (فقط عدد را وارد کنید، مثلاً برای IPE140 عدد ۱۴۰)"),
      ToolInput("length", "طول کل موردنیاز (متر)"),
    ],
    calc: (v) {
      var weightPerMeter = IPE_WEIGHTS[(v['size']!).round()];
      if (weightPerMeter == null) {
        return [
          ToolResult(label: "نتیجه", value: "سایز واردشده در جدول استاندارد IPE یافت نشد", unit: "")
        ];
      }
      var totalWeight = weightPerMeter * v['length']!;
      return [
        ToolResult(label: "وزن هر متر طول (استاندارد)", value: weightPerMeter.toFixed(2), unit: "کیلوگرم بر متر"),
        ToolResult(label: "وزن کل", value: totalWeight.toFixed(1), unit: "کیلوگرم")
      ];
    },
  ),
  ToolDef(
    id: "steel-channel-weight",
    name: "ناودانی",
    description: "وزن دقیق ناودانی بر اساس جدول استاندارد UNP (کیلوگرم بر متر)",
    category: "civil",
    inputs: const [
      ToolInput("size", "سایز ناودانی (فقط عدد را وارد کنید، مثلاً برای UNP100 عدد ۱۰۰)"),
      ToolInput("length", "طول کل موردنیاز (متر)"),
    ],
    calc: (v) {
      var weightPerMeter = UNP_WEIGHTS[(v['size']!).round()];
      if (weightPerMeter == null) {
        return [
          ToolResult(label: "نتیجه", value: "سایز واردشده در جدول استاندارد UNP یافت نشد", unit: "")
        ];
      }
      var totalWeight = weightPerMeter * v['length']!;
      return [
        ToolResult(label: "وزن هر متر طول (استاندارد)", value: weightPerMeter.toFixed(2), unit: "کیلوگرم بر متر"),
        ToolResult(label: "وزن کل", value: totalWeight.toFixed(1), unit: "کیلوگرم")
      ];
    },
  ),
  ToolDef(
    id: "lsf-wall-studs",
    name: "استاد و رانر دیوار LSF",
    description: "برآورد تعداد استاد و طول رانر موردنیاز برای یک دیوار سازه سبک فولادی (LSF)",
    category: "civil",
    inputs: const [
      ToolInput("wallLength", "طول دیوار (متر)"),
      ToolInput("wallHeight", "ارتفاع دیوار (متر)"),
      ToolInput("spacing", "فاصله محور استادها (سانتی‌متر، معمولاً ۴۰ یا ۶۰)"),
    ],
    calc: (v) {
      var studsCount = (v['wallLength']! / (v['spacing']! / 100)).ceil() + 1;
      var studsTotalLength = studsCount * v['wallHeight']!;
      var trackTotalLength = 2 * v['wallLength']!; // رانر بالا + رانر پایین
      return [
        ToolResult(label: "تعداد استاد", value: studsCount.toFixed(0), unit: "عدد"),
        ToolResult(label: "طول کل استاد", value: studsTotalLength.toFixed(1), unit: "متر"),
        ToolResult(label: "طول کل رانر (بالا و پایین)", value: trackTotalLength.toFixed(1), unit: "متر")
      ];
    },
  ),
  ToolDef(
    id: "lsf-sheathing",
    name: "روکش دیوار LSF (OSB/سیمانی)",
    description: "برآورد تعداد ورق روکش موردنیاز برای پوشش یک یا دو طرف دیوار LSF",
    category: "civil",
    inputs: const [
      ToolInput("wallArea", "مساحت دیوار (متر مربع)"),
      ToolInput("sheetArea", "مساحت هر ورق (متر مربع، برای ورق ۱۲۲×۲۴۴ عدد ۲.۹۸)"),
      ToolInput("sides", "تعداد وجه پوشش‌داده‌شده (۱ یا ۲)"),
    ],
    calc: (v) {
      var totalArea = v['wallArea']! * v['sides']!;
      var sheetsCount = (totalArea / v['sheetArea']!).ceil();
      return [
        ToolResult(label: "مساحت کل پوشش", value: totalArea.toFixed(2), unit: "متر مربع"),
        ToolResult(label: "تعداد ورق موردنیاز", value: sheetsCount.toFixed(0), unit: "عدد")
      ];
    },
  ),
  ToolDef(
    id: "lsf-screw-count",
    name: "پیچ سازه LSF",
    description: "برآورد تعداد پیچ خودکار موردنیاز بر اساس مساحت روکش (بر پایه تراکم متوسط پیچ)",
    category: "civil",
    inputs: const [
      ToolInput("sheathingArea", "مساحت کل روکش (متر مربع)"),
      ToolInput("screwsPerM2", "تراکم پیچ (عدد بر متر مربع، معمولاً ۱۲-۱۶)"),
    ],
    calc: (v) {
      var totalScrews = (v['sheathingArea']! * v['screwsPerM2']!).ceil();
      return [
        ToolResult(label: "تعداد پیچ موردنیاز (تقریبی)", value: totalScrews.toFixed(0), unit: "عدد")
      ];
    },
  ),
  ToolDef(
    id: "design-regulations",
    name: "ضوابط طراحی",
    description: "بررسی کلی رعایت حداقل‌های متداول طراحی بر اساس مساحت زمین",
    category: "architecture",
    inputs: const [
      ToolInput("landArea", "مساحت زمین (متر مربع)"),
      ToolInput("buildingArea", "مساحت زیربنا (متر مربع)"),
    ],
    calc: (v) {
      var ratio = (v['buildingArea']! / v['landArea']!) * 100;
      return [
        ToolResult(label: "نسبت زیربنا به زمین", value: ratio.toFixed(1), unit: "درصد")
      ];
    },
  ),
  ToolDef(
    id: "occupancy-area",
    name: "سطح اشغال",
    description: "محاسبه درصد سطح اشغال ساختمان در زمین",
    category: "architecture",
    inputs: const [
      ToolInput("landArea", "مساحت زمین (متر مربع)"),
      ToolInput("footprintArea", "مساحت اشغال طبقه همکف (متر مربع)"),
    ],
    calc: (v) {
      var occupancy = (v['footprintArea']! / v['landArea']!) * 100;
      return [
        ToolResult(label: "سطح اشغال", value: occupancy.toFixed(1), unit: "درصد")
      ];
    },
  ),
  ToolDef(
    id: "density",
    name: "تراکم",
    description: "محاسبه تراکم ساختمانی (نسبت کل زیربنا به مساحت زمین)",
    category: "architecture",
    inputs: const [
      ToolInput("landArea", "مساحت زمین (متر مربع)"),
      ToolInput("totalBuiltArea", "کل زیربنای مجاز (متر مربع)"),
    ],
    calc: (v) {
      var density = (v['totalBuiltArea']! / v['landArea']!) * 100;
      return [
        ToolResult(label: "تراکم ساختمانی", value: density.toFixed(0), unit: "درصد")
      ];
    },
  ),
  ToolDef(
    id: "daylighting",
    name: "نورگیری",
    description: "محاسبه حداقل سطح پنجره لازم بر اساس مساحت اتاق (قاعده تقریبی ۱ به ۶)",
    category: "architecture",
    inputs: const [
      ToolInput("roomArea", "مساحت اتاق (متر مربع)"),
    ],
    calc: (v) {
      var minWindowArea = v['roomArea']! / 6;
      return [
        ToolResult(label: "حداقل سطح پنجره", value: minWindowArea.toFixed(2), unit: "متر مربع")
      ];
    },
  ),
  ToolDef(
    id: "parking-count",
    name: "پارکینگ",
    description: "برآورد تعداد پارکینگ مورد نیاز بر اساس تعداد واحد",
    category: "architecture",
    inputs: const [
      ToolInput("unitCount", "تعداد واحد مسکونی"),
      ToolInput("ratio", "نسبت پارکینگ به واحد (مثلاً ۱ یا ۱.۲۵)"),
    ],
    calc: (v) {
      var parkingCount = (v['unitCount']! * v['ratio']!).ceil();
      return [
        ToolResult(label: "تعداد پارکینگ مورد نیاز", value: parkingCount, unit: "واحد")
      ];
    },
  ),
  ToolDef(
    id: "ramp-slope",
    name: "شیب رمپ",
    description: "محاسبه شیب رمپ پارکینگ بر اساس اختلاف ارتفاع و طول",
    category: "architecture",
    inputs: const [
      ToolInput("heightDiff", "اختلاف ارتفاع (متر)"),
      ToolInput("rampLength", "طول رمپ (متر)"),
    ],
    calc: (v) {
      var slope = (v['heightDiff']! / v['rampLength']!) * 100;
      return [
        ToolResult(label: "شیب رمپ", value: slope.toFixed(1), unit: "درصد")
      ];
    },
  ),
  ToolDef(
    id: "scale-conversion",
    name: "مقیاس",
    description: "تبدیل ابعاد واقعی به ابعاد روی نقشه بر اساس مقیاس",
    category: "architecture",
    inputs: const [
      ToolInput("realLength", "طول واقعی (متر)"),
      ToolInput("scaleDenominator", "مخرج مقیاس (مثلاً برای ۱:۱۰۰ عدد ۱۰۰ را وارد کنید)"),
    ],
    calc: (v) {
      var drawingLengthCm = (v['realLength']! * 100) / v['scaleDenominator']!;
      return [
        ToolResult(label: "طول روی نقشه", value: drawingLengthCm.toFixed(2), unit: "سانتی‌متر")
      ];
    },
  ),
  ToolDef(
    id: "preliminary-design",
    name: "طراحی اولیه",
    description: "برآورد اولیه تعداد اتاق قابل جانمایی بر اساس مساحت",
    category: "architecture",
    inputs: const [
      ToolInput("totalArea", "مساحت کل (متر مربع)"),
      ToolInput("avgRoomArea", "میانگین مساحت هر اتاق (متر مربع)"),
    ],
    calc: (v) {
      var roomCount = (v['totalArea']! / v['avgRoomArea']!).floor();
      return [
        ToolResult(label: "تعداد اتاق قابل جانمایی", value: roomCount, unit: "اتاق")
      ];
    },
  ),
  ToolDef(
    id: "cable-size",
    name: "محاسبه کابل",
    description: "برآورد سطح مقطع کابل بر اساس جریان و طول",
    category: "electrical",
    inputs: const [
      ToolInput("current", "جریان (آمپر)"),
      ToolInput("length", "طول مسیر (متر)"),
      ToolInput("voltage", "ولتاژ (ولت)"),
    ],
    calc: (v) {
      var crossSection = (v['current']! * v['length']!) / (v['voltage']! * 0.5);
      return [
        ToolResult(label: "سطح مقطع تقریبی کابل", value: crossSection.toFixed(2), unit: "میلی‌متر مربع")
      ];
    },
  ),
  ToolDef(
    id: "voltage-drop",
    name: "افت ولتاژ",
    description: "محاسبه افت ولتاژ در طول کابل",
    category: "electrical",
    inputs: const [
      ToolInput("current", "جریان (آمپر)"),
      ToolInput("length", "طول مسیر (متر)"),
      ToolInput("crossSection", "سطح مقطع کابل (میلی‌متر مربع)"),
    ],
    calc: (v) {
      var resistivity = 0.0175;
      var drop = (2 * resistivity * v['length']! * v['current']!) / v['crossSection']!;
      return [
        ToolResult(label: "افت ولتاژ", value: drop.toFixed(2), unit: "ولت")
      ];
    },
  ),
  ToolDef(
    id: "fuse-rating",
    name: "فیوز",
    description: "برآورد آمپراژ فیوز مناسب بر اساس توان و ولتاژ",
    category: "electrical",
    inputs: const [
      ToolInput("power", "توان (وات)"),
      ToolInput("voltage", "ولتاژ (ولت)"),
    ],
    calc: (v) {
      var current = v['power']! / v['voltage']!;
      var fuseRating = current * 1.25;
      return [
        ToolResult(label: "جریان مصرفی", value: current.toFixed(2), unit: "آمپر"),
        ToolResult(label: "آمپراژ پیشنهادی فیوز", value: fuseRating.toFixed(1), unit: "آمپر")
      ];
    },
  ),
  ToolDef(
    id: "electrical-panel",
    name: "تابلو برق",
    description: "برآورد تعداد مدار خروجی مورد نیاز تابلو برق",
    category: "electrical",
    inputs: const [
      ToolInput("totalLoad", "بار کل (وات)"),
      ToolInput("circuitCapacity", "ظرفیت هر مدار (وات)"),
    ],
    calc: (v) {
      var circuitCount = (v['totalLoad']! / v['circuitCapacity']!).ceil();
      return [
        ToolResult(label: "تعداد مدار مورد نیاز", value: circuitCount, unit: "مدار")
      ];
    },
  ),
  ToolDef(
    id: "lighting-calc",
    name: "روشنایی",
    description: "برآورد تعداد چراغ مورد نیاز بر اساس مساحت و لوکس مطلوب",
    category: "electrical",
    inputs: const [
      ToolInput("roomArea", "مساحت اتاق (متر مربع)"),
      ToolInput("requiredLux", "شدت روشنایی مطلوب (لوکس)"),
      ToolInput("lumensPerFixture", "لومن هر چراغ"),
    ],
    calc: (v) {
      var totalLumens = v['roomArea']! * v['requiredLux']!;
      var fixtureCount = (totalLumens / v['lumensPerFixture']!).ceil();
      return [
        ToolResult(label: "تعداد چراغ مورد نیاز", value: fixtureCount, unit: "عدد")
      ];
    },
  ),
  ToolDef(
    id: "grounding",
    name: "ارت",
    description: "برآورد مقاومت الکترود ارت (فرمول ساده میله‌ای)",
    category: "electrical",
    inputs: const [
      ToolInput("rodLength", "طول میله ارت (متر)"),
      ToolInput("soilResistivity", "مقاومت مخصوص خاک (اهم‌متر)"),
    ],
    calc: (v) {
      var resistance = v['soilResistivity']! / (2 * pi * v['rodLength']!);
      return [
        ToolResult(label: "مقاومت تقریبی ارت", value: resistance.toFixed(2), unit: "اهم")
      ];
    },
  ),
  ToolDef(
    id: "motor-current",
    name: "موتور",
    description: "محاسبه جریان مصرفی موتور بر اساس توان و ولتاژ",
    category: "electrical",
    inputs: const [
      ToolInput("power", "توان موتور (کیلووات)"),
      ToolInput("voltage", "ولتاژ (ولت)"),
      ToolInput("efficiency", "راندمان (درصد، مثلاً ۸۵)"),
    ],
    calc: (v) {
      var powerWatts = v['power']! * 1000;
      var current = powerWatts / (v['voltage']! * (v['efficiency']! / 100));
      return [
        ToolResult(label: "جریان مصرفی موتور", value: current.toFixed(2), unit: "آمپر")
      ];
    },
  ),
  ToolDef(
    id: "generator-sizing",
    name: "ژنراتور",
    description: "برآورد ظرفیت ژنراتور مورد نیاز با ضریب اطمینان",
    category: "electrical",
    inputs: const [
      ToolInput("totalLoad", "بار کل (کیلووات)"),
      ToolInput("safetyFactor", "ضریب اطمینان (مثلاً ۱.۲۵)"),
    ],
    calc: (v) {
      var generatorSize = v['totalLoad']! * v['safetyFactor']!;
      return [
        ToolResult(label: "ظرفیت پیشنهادی ژنراتور", value: generatorSize.toFixed(1), unit: "کیلووات")
      ];
    },
  ),
  ToolDef(
    id: "cooler-capacity",
    name: "ظرفیت کولر",
    description: "برآورد ظرفیت کولر آبی/گازی مورد نیاز بر اساس حجم فضا",
    category: "installations",
    inputs: const [
      ToolInput("roomArea", "مساحت فضا (متر مربع)"),
      ToolInput("ceilingHeight", "ارتفاع سقف (متر)"),
    ],
    calc: (v) {
      var volume = v['roomArea']! * v['ceilingHeight']!;
      var capacityCfm = volume * 10;
      return [
        ToolResult(label: "ظرفیت پیشنهادی", value: capacityCfm.toFixed(0), unit: "فوت مکعب بر دقیقه (CFM)")
      ];
    },
  ),
  ToolDef(
    id: "chiller-capacity",
    name: "چیلر",
    description: "برآورد ظرفیت چیلر بر اساس بار حرارتی ساختمان",
    category: "installations",
    inputs: const [
      ToolInput("buildingArea", "مساحت ساختمان (متر مربع)"),
      ToolInput("coolingLoadPerM2", "بار سرمایشی هر متر مربع (وات، معمولاً ۱۰۰-۱۵۰)"),
    ],
    calc: (v) {
      var totalLoadWatts = v['buildingArea']! * v['coolingLoadPerM2']!;
      var tons = totalLoadWatts / 3517;
      return [
        ToolResult(label: "بار سرمایشی کل", value: totalLoadWatts.toFixed(0), unit: "وات"),
        ToolResult(label: "ظرفیت چیلر", value: tons.toFixed(2), unit: "تن تبرید")
      ];
    },
  ),
  ToolDef(
    id: "boiler-capacity",
    name: "بویلر",
    description: "برآورد ظرفیت بویلر بر اساس بار حرارتی",
    category: "installations",
    inputs: const [
      ToolInput("buildingArea", "مساحت ساختمان (متر مربع)"),
      ToolInput("heatingLoadPerM2", "بار حرارتی هر متر مربع (وات، معمولاً ۱۰۰-۱۵۰)"),
    ],
    calc: (v) {
      var totalLoadWatts = v['buildingArea']! * v['heatingLoadPerM2']!;
      var kcalPerHour = totalLoadWatts * 0.86;
      return [
        ToolResult(label: "بار حرارتی کل", value: totalLoadWatts.toFixed(0), unit: "وات"),
        ToolResult(label: "ظرفیت بویلر", value: kcalPerHour.toFixed(0), unit: "کیلوکالری بر ساعت")
      ];
    },
  ),
  ToolDef(
    id: "pump-flow",
    name: "پمپ",
    description: "برآورد دبی پمپ مورد نیاز بر اساس حجم مخزن و زمان پرشدن",
    category: "installations",
    inputs: const [
      ToolInput("tankVolume", "حجم مخزن (متر مکعب)"),
      ToolInput("fillTime", "زمان پر شدن مطلوب (ساعت)"),
    ],
    calc: (v) {
      var flowRate = v['tankVolume']! / v['fillTime']!;
      var flowRateLpm = (v['tankVolume']! * 1000) / (v['fillTime']! * 60);
      return [
        ToolResult(label: "دبی مورد نیاز", value: flowRate.toFixed(2), unit: "متر مکعب بر ساعت"),
        ToolResult(label: "دبی مورد نیاز", value: flowRateLpm.toFixed(1), unit: "لیتر بر دقیقه")
      ];
    },
  ),
  ToolDef(
    id: "tank-volume",
    name: "مخزن",
    description: "محاسبه حجم مخزن استوانه‌ای یا مکعبی",
    category: "installations",
    inputs: const [
      ToolInput("shape", "شکل (1 برای استوانه‌ای، 2 برای مکعبی)"),
      ToolInput("dim1", "قطر یا طول (متر)"),
      ToolInput("dim2", "عرض (متر، فقط برای مکعبی — استوانه صفر بگذارید)"),
      ToolInput("height", "ارتفاع (متر)"),
    ],
    calc: (v) {
      var volume;
      if (v['shape']! == 1) {
        var radius = v['dim1']! / 2;
        volume = pi * radius * radius * v['height']!;
      } else {
        volume = v['dim1']! * v['dim2']! * v['height']!;
      }
      return [
        ToolResult(label: "حجم مخزن", value: volume.toFixed(2), unit: "متر مکعب"),
        ToolResult(label: "حجم مخزن", value: (volume * 1000).toFixed(0), unit: "لیتر")
      ];
    },
  ),
  ToolDef(
    id: "pipe-sizing",
    name: "لوله",
    description: "برآورد قطر لوله مورد نیاز بر اساس دبی و سرعت مجاز جریان",
    category: "installations",
    inputs: const [
      ToolInput("flowRate", "دبی (لیتر بر ثانیه)"),
      ToolInput("velocity", "سرعت مجاز جریان (متر بر ثانیه، معمولاً ۱-۲)"),
    ],
    calc: (v) {
      var flowM3s = v['flowRate']! / 1000;
      var area = flowM3s / v['velocity']!;
      var diameter = sqrt((4 * area) / pi);
      return [
        ToolResult(label: "قطر پیشنهادی لوله", value: (diameter * 1000).toFixed(1), unit: "میلی‌متر")
      ];
    },
  ),
  ToolDef(
    id: "duct-sizing",
    name: "کانال",
    description: "برآورد سطح مقطع کانال هوا بر اساس دبی هوا و سرعت",
    category: "installations",
    inputs: const [
      ToolInput("airFlow", "دبی هوا (متر مکعب بر ساعت)"),
      ToolInput("velocity", "سرعت هوا در کانال (متر بر ثانیه، معمولاً ۴-۸)"),
    ],
    calc: (v) {
      var airFlowM3s = v['airFlow']! / 3600;
      var area = airFlowM3s / v['velocity']!;
      return [
        ToolResult(label: "سطح مقطع کانال", value: area.toFixed(3), unit: "متر مربع"),
        ToolResult(label: "سطح مقطع کانال", value: (area * 10000).toFixed(0), unit: "سانتی‌متر مربع")
      ];
    },
  ),
  ToolDef(
    id: "ventilation-rate",
    name: "تهویه",
    description: "برآورد نرخ تهویه مورد نیاز بر اساس تعداد نفرات و نوع فضا",
    category: "installations",
    inputs: const [
      ToolInput("occupants", "تعداد نفرات"),
      ToolInput("airPerPerson", "هوای تازه مورد نیاز هر نفر (متر مکعب بر ساعت، معمولاً ۲۰-۳۰)"),
    ],
    calc: (v) {
      var totalAirFlow = v['occupants']! * v['airPerPerson']!;
      return [
        ToolResult(label: "نرخ تهویه مورد نیاز", value: totalAirFlow.toFixed(0), unit: "متر مکعب بر ساعت")
      ];
    },
  ),
  ToolDef(
    id: "shaft-power-torque",
    name: "توان و گشتاور شفت",
    description: "محاسبه گشتاور شفت بر اساس توان و دور موتور (RPM)",
    category: "mechanical",
    inputs: const [
      ToolInput("power", "توان (کیلووات)"),
      ToolInput("rpm", "دور موتور (RPM)"),
    ],
    calc: (v) {
      var powerWatts = v['power']! * 1000;
      var omega = (2 * pi * v['rpm']!) / 60;
      var torque = powerWatts / omega;
      return [
        ToolResult(label: "گشتاور", value: torque.toFixed(2), unit: "نیوتن‌متر (N.m)")
      ];
    },
  ),
  ToolDef(
    id: "shaft-torsional-stress",
    name: "تنش پیچشی شفت",
    description: "محاسبه تنش برشی ناشی از پیچش در یک شفت توپر دایره‌ای",
    category: "mechanical",
    inputs: const [
      ToolInput("torque", "گشتاور اعمالی (نیوتن‌متر)"),
      ToolInput("diameter", "قطر شفت (میلی‌متر)"),
    ],
    calc: (v) {
      var r = v['diameter']! / 2 / 1000;
      var J = (pi * pow(v['diameter']! / 1000, 4)) / 32;
      var stress = (v['torque']! * r) / J;
      return [
        ToolResult(label: "تنش برشی", value: (stress / 1e6).toFixed(2), unit: "مگاپاسکال (MPa)")
      ];
    },
  ),
  ToolDef(
    id: "gear-ratio",
    name: "نسبت چرخ‌دنده",
    description: "محاسبه نسبت دنده و دور خروجی بر اساس تعداد دندانه‌ها",
    category: "mechanical",
    inputs: const [
      ToolInput("teethDriver", "تعداد دندانه چرخ‌دنده محرک"),
      ToolInput("teethDriven", "تعداد دندانه چرخ‌دنده متحرک"),
      ToolInput("inputRpm", "دور ورودی (RPM)"),
    ],
    calc: (v) {
      var ratio = v['teethDriven']! / v['teethDriver']!;
      var outputRpm = v['inputRpm']! / ratio;
      return [
        ToolResult(label: "نسبت دنده", value: ratio.toFixed(3), unit: ":1"),
        ToolResult(label: "دور خروجی", value: outputRpm.toFixed(1), unit: "RPM")
      ];
    },
  ),
  ToolDef(
    id: "spring-force",
    name: "فنر",
    description: "محاسبه نیروی فنر بر اساس ضریب سختی و میزان تغییر طول",
    category: "mechanical",
    inputs: const [
      ToolInput("stiffness", "ضریب سختی فنر (نیوتن بر میلی‌متر)"),
      ToolInput("deflection", "میزان تغییر طول (میلی‌متر)"),
    ],
    calc: (v) {
      var force = v['stiffness']! * v['deflection']!;
      var energy = 0.5 * v['stiffness']! * 1000 * pow(v['deflection']! / 1000, 2);
      return [
        ToolResult(label: "نیروی فنر", value: force.toFixed(2), unit: "نیوتن"),
        ToolResult(label: "انرژی ذخیره‌شده", value: energy.toFixed(3), unit: "ژول")
      ];
    },
  ),
  ToolDef(
    id: "belt-speed",
    name: "سرعت تسمه",
    description: "محاسبه سرعت خطی تسمه بر اساس قطر پولی و دور موتور",
    category: "mechanical",
    inputs: const [
      ToolInput("pulleyDiameter", "قطر پولی (میلی‌متر)"),
      ToolInput("rpm", "دور موتور (RPM)"),
    ],
    calc: (v) {
      var speedMmPerMin = pi * v['pulleyDiameter']! * v['rpm']!;
      var speedMPerS = speedMmPerMin / 1000 / 60;
      return [
        ToolResult(label: "سرعت خطی تسمه", value: speedMPerS.toFixed(2), unit: "متر بر ثانیه")
      ];
    },
  ),
  ToolDef(
    id: "bolt-preload",
    name: "پیچ و مهره",
    description: "برآورد نیروی پیش‌بار پیچ بر اساس گشتاور بستن",
    category: "mechanical",
    inputs: const [
      ToolInput("torque", "گشتاور بستن (نیوتن‌متر)"),
      ToolInput("diameter", "قطر اسمی پیچ (میلی‌متر)"),
      ToolInput("kFactor", "ضریب اصطکاک K (معمولاً حدود ۰.۲)"),
    ],
    calc: (v) {
      var preload = v['torque']! / (v['kFactor']! * (v['diameter']! / 1000));
      return [
        ToolResult(label: "نیروی پیش‌بار پیچ", value: (preload / 1000).toFixed(2), unit: "کیلونیوتن (kN)")
      ];
    },
  ),
  ToolDef(
    id: "slope-percent",
    name: "شیب زمین",
    description: "محاسبه درصد و زاویه شیب بر اساس اختلاف ارتفاع و فاصله افقی",
    category: "surveying",
    inputs: const [
      ToolInput("rise", "اختلاف ارتفاع (متر)"),
      ToolInput("run", "فاصله افقی (متر)"),
    ],
    calc: (v) {
      var percent = (v['rise']! / v['run']!) * 100;
      var degrees = atan(v['rise']! / v['run']!) * (180 / pi);
      return [
        ToolResult(label: "درصد شیب", value: percent.toFixed(2), unit: "%"),
        ToolResult(label: "زاویه شیب", value: degrees.toFixed(2), unit: "درجه")
      ];
    },
  ),
  ToolDef(
    id: "slope-to-horizontal-distance",
    name: "فاصله افقی از فاصله شیب‌دار",
    description: "تبدیل فاصله اندازه‌گیری‌شده روی شیب به فاصله افقی واقعی",
    category: "surveying",
    inputs: const [
      ToolInput("slopeDistance", "فاصله شیب‌دار اندازه‌گیری‌شده (متر)"),
      ToolInput("verticalAngle", "زاویه قائم (درجه)"),
    ],
    calc: (v) {
      var rad = (v['verticalAngle']! * pi) / 180;
      var horizontal = v['slopeDistance']! * cos(rad);
      var vertical = v['slopeDistance']! * sin(rad);
      return [
        ToolResult(label: "فاصله افقی", value: horizontal.toFixed(3), unit: "متر"),
        ToolResult(label: "اختلاف ارتفاع", value: vertical.toFixed(3), unit: "متر")
      ];
    },
  ),
  ToolDef(
    id: "earthwork-volume",
    name: "حجم خاکبرداری/خاکریزی",
    description: "برآورد حجم خاک بین دو مقطع به روش منشوری (average end area)",
    category: "surveying",
    inputs: const [
      ToolInput("areaStart", "مساحت مقطع ابتدایی (متر مربع)"),
      ToolInput("areaEnd", "مساحت مقطع انتهایی (متر مربع)"),
      ToolInput("distance", "فاصله بین دو مقطع (متر)"),
    ],
    calc: (v) {
      var volume = ((v['areaStart']! + v['areaEnd']!) / 2) * v['distance']!;
      return [
        ToolResult(label: "حجم خاک", value: volume.toFixed(2), unit: "متر مکعب")
      ];
    },
  ),
  ToolDef(
    id: "rectangular-land-area",
    name: "مساحت زمین مستطیلی",
    description: "محاسبه مساحت و محیط یک قطعه زمین مستطیلی از روی طول اضلاع",
    category: "surveying",
    inputs: const [
      ToolInput("length", "طول (متر)"),
      ToolInput("width", "عرض (متر)"),
    ],
    calc: (v) {
      var area = v['length']! * v['width']!;
      var perimeter = 2 * (v['length']! + v['width']!);
      return [
        ToolResult(label: "مساحت", value: area.toFixed(2), unit: "متر مربع"),
        ToolResult(label: "محیط", value: perimeter.toFixed(2), unit: "متر")
      ];
    },
  ),
  ToolDef(
    id: "bearing-to-azimuth",
    name: "تبدیل امتداد به آزیموت",
    description: "تبدیل زاویه امتداد (بیرینگ، مثلاً N45E) به آزیموت (۰ تا ۳۶۰ درجه)",
    category: "surveying",
    inputs: const [
      ToolInput("quadrant", "جهت (1: شمال‌شرقی، 2: جنوب‌شرقی، 3: جنوب‌غربی، 4: شمال‌غربی)"),
      ToolInput("angle", "زاویه امتداد نسبت به شمال/جنوب (درجه)"),
    ],
    calc: (v) {
      var azimuth;
      if (v['quadrant']! == 1) azimuth = v['angle']!;
      else if (v['quadrant']! == 2) azimuth = 180 - v['angle']!;
      else if (v['quadrant']! == 3) azimuth = 180 + v['angle']!;
      else azimuth = 360 - v['angle']!;
      return [
        ToolResult(label: "آزیموت", value: azimuth.toFixed(2), unit: "درجه")
      ];
    },
  ),
  ToolDef(
    id: "contour-interval-estimate",
    name: "برآورد تعداد منحنی میزان",
    description: "برآورد تعداد خطوط منحنی میزان بین دو ارتفاع بر اساس فاصله قائم منحنی‌ها",
    category: "surveying",
    inputs: const [
      ToolInput("elevationMin", "کمترین ارتفاع (متر)"),
      ToolInput("elevationMax", "بیشترین ارتفاع (متر)"),
      ToolInput("interval", "فاصله قائم منحنی‌ها (متر، معمولاً ۱ یا ۲)"),
    ],
    calc: (v) {
      var count = ((v['elevationMax']! - v['elevationMin']!) / v['interval']!).floor();
      return [
        ToolResult(label: "تعداد منحنی میزان", value: count.toFixed(0), unit: "خط")
      ];
    },
  ),
  ToolDef(
    id: "unit-converter-length",
    name: "تبدیل واحد طول",
    description: "تبدیل بین متر، سانتی‌متر، اینچ و فوت",
    category: "general",
    inputs: const [
      ToolInput("value", "مقدار"),
      ToolInput("fromUnit", "واحد مبدأ (1=متر, 2=سانتی‌متر, 3=اینچ, 4=فوت)"),
    ],
    calc: (v) {
      var meters;
      if (v['fromUnit']! == 1) meters = v['value']!;
      else if (v['fromUnit']! == 2) meters = v['value']! / 100;
      else if (v['fromUnit']! == 3) meters = v['value']! * 0.0254;
      else meters = v['value']! * 0.3048;

      return [
        ToolResult(label: "متر", value: meters.toFixed(4), unit: "m"),
        ToolResult(label: "سانتی‌متر", value: (meters * 100).toFixed(2), unit: "cm"),
        ToolResult(label: "اینچ", value: (meters / 0.0254).toFixed(2), unit: "in"),
        ToolResult(label: "فوت", value: (meters / 0.3048).toFixed(2), unit: "ft")
      ];
    },
  ),
  ToolDef(
    id: "unit-converter-area",
    name: "تبدیل واحد مساحت",
    description: "تبدیل بین متر مربع، هکتار و جریب",
    category: "general",
    inputs: const [
      ToolInput("value", "مقدار (متر مربع)"),
    ],
    calc: (v) {
      var sqm = v['value']!;
      return [
        ToolResult(label: "متر مربع", value: sqm.toFixed(2), unit: "m²"),
        ToolResult(label: "هکتار", value: (sqm / 10000).toFixed(4), unit: "ha"),
        ToolResult(label: "جریب", value: (sqm / 1000).toFixed(3), unit: "جریب")
      ];
    },
  ),
  ToolDef(
    id: "project-calendar",
    name: "تقویم پروژه",
    description: "محاسبه تاریخ پایان پروژه بر اساس تاریخ شروع و مدت زمان",
    category: "general",
    inputs: const [
      ToolInput("durationDays", "مدت زمان پروژه (روز)"),
    ],
    calc: (v) {
      var start = DateTime.now();
      var end = start.add(Duration(days: v['durationDays']!.round()));
      String fmt(DateTime d) => '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
      return [
        ToolResult(label: "تاریخ شروع (میلادی)", value: fmt(start), unit: ""),
        ToolResult(label: "تاریخ پایان (میلادی)", value: fmt(end), unit: "")
      ];
    },
  ),
  ToolDef(
    id: "financial-calculator",
    name: "ماشین حساب مالی",
    description: "محاسبه قسط ماهانه وام بر اساس مبلغ، نرخ سود و مدت",
    category: "general",
    inputs: const [
      ToolInput("principal", "مبلغ وام (تومان)"),
      ToolInput("annualRate", "نرخ سود سالانه (درصد)"),
      ToolInput("months", "مدت بازپرداخت (ماه)"),
    ],
    calc: (v) {
      var monthlyRate = v['annualRate']! / 100 / 12;
      var installment;
      if (monthlyRate == 0) {
        installment = v['principal']! / v['months']!;
      } else {
        var powK = pow(1 + monthlyRate, v['months']!);
        installment = (v['principal']! * monthlyRate * powK) / (powK - 1);
      }
      var totalPayment = installment * v['months']!;
      return [
        ToolResult(label: "قسط ماهانه", value: (installment).round().toLocaleString("fa-IR"), unit: "تومان"),
        ToolResult(label: "مجموع بازپرداخت", value: (totalPayment).round().toLocaleString("fa-IR"), unit: "تومان")
      ];
    },
  ),
  ToolDef(
    id: "basic-calculator",
    name: "ماشین حساب",
    description: "چهار عمل اصلی روی دو عدد",
    category: "general",
    inputs: const [
      ToolInput("a", "عدد اول"),
      ToolInput("operator", "عملگر (1=جمع, 2=تفریق, 3=ضرب, 4=تقسیم)"),
      ToolInput("b", "عدد دوم"),
    ],
    calc: (v) {
      var result;
      if (v['operator']! == 1) result = v['a']! + v['b']!;
      else if (v['operator']! == 2) result = v['a']! - v['b']!;
      else if (v['operator']! == 3) result = v['a']! * v['b']!;
      else result = v['b']! != 0 ? v['a']! / v['b']! : double.nan;

      return [
        ToolResult(label: "نتیجه", value: (result).isNaN ? "نامعتبر (تقسیم بر صفر)" : result.toString(), unit: "")
      ];
    },
  ),
];

