export var roofTools = [
  {
    id: "roof-joist-block",
    name: "سقف تیرچه بلوک",
    description: "برآورد تعداد تیرچه، بلوک و حجم بتن پوششی برای سقف تیرچه بلوک",
    inputs: [
      { key: "span", label: "دهانه سقف (متر)" },
      { key: "width", label: "عرض سقف (متر)" },
      { key: "spacing", label: "فاصله محور تیرچه‌ها (سانتی‌متر، معمولاً ۵۰)" },
      { key: "toppingThickness", label: "ضخامت بتن پوششی (سانتی‌متر، معمولاً ۵)" }
    ],
    calculate: function (v) {
      var joistsCount = Math.ceil(v.width / (v.spacing / 100)) + 1;
      var totalJoistLength = joistsCount * v.span;
      var area = v.span * v.width;
      var blocksCount = Math.ceil(area * 8); // برآورد تقریبی: ۸ بلوک استاندارد در هر متر مربع
      var toppingVolume = area * (v.toppingThickness / 100);
      return [
        { label: "تعداد تیرچه", value: joistsCount.toFixed(0), unit: "عدد" },
        { label: "طول کل تیرچه", value: totalJoistLength.toFixed(1), unit: "متر" },
        { label: "تعداد بلوک (تقریبی)", value: blocksCount.toFixed(0), unit: "عدد" },
        { label: "حجم بتن پوششی", value: toppingVolume.toFixed(2), unit: "متر مکعب" }
      ];
    }
  },
  {
    id: "roof-composite-deck",
    name: "سقف عرشه فولادی کامپوزیت",
    description: "برآورد وزن ورق عرشه فولادی و حجم بتن سقف کامپوزیت",
    inputs: [
      { key: "area", label: "مساحت سقف (متر مربع)" },
      { key: "slabThickness", label: "ضخامت کل دال (سانتی‌متر، معمولاً ۱۲-۱۵)" },
      { key: "deckWeightPerM2", label: "وزن ورق عرشه (کیلوگرم بر متر مربع، معمولاً ۱۰-۱۲)" }
    ],
    calculate: function (v) {
      var concreteVolume = v.area * (v.slabThickness / 100) * 0.75; // ۰.۷۵ ضریب کاهش به‌خاطر حجم اشغال‌شده توسط موج عرشه
      var concreteWeight = concreteVolume * 2400;
      var deckWeight = v.area * v.deckWeightPerM2;
      return [
        { label: "حجم بتن (تقریبی)", value: concreteVolume.toFixed(2), unit: "متر مکعب" },
        { label: "وزن بتن", value: concreteWeight.toFixed(0), unit: "کیلوگرم" },
        { label: "وزن ورق عرشه فولادی", value: deckWeight.toFixed(0), unit: "کیلوگرم" }
      ];
    }
  },
  {
    id: "roof-waffle",
    name: "سقف وافل",
    description: "برآورد حجم بتن سقف وافل بر اساس ضخامت موثر",
    inputs: [
      { key: "area", label: "مساحت سقف (متر مربع)" },
      { key: "effectiveThickness", label: "ضخامت موثر معادل (سانتی‌متر — طبق محاسبات سازه)" }
    ],
    calculate: function (v) {
      var volume = v.area * (v.effectiveThickness / 100);
      var weight = volume * 2400;
      return [
        { label: "حجم بتن", value: volume.toFixed(2), unit: "متر مکعب" },
        { label: "وزن بتن", value: weight.toFixed(0), unit: "کیلوگرم" }
      ];
    }
  },
  {
    id: "roof-solid-slab",
    name: "سقف دال بتنی توپر",
    description: "محاسبه حجم و وزن بتن برای سقف دال بتنی مسطح (بدون تیرچه)",
    inputs: [
      { key: "length", label: "طول (متر)" },
      { key: "width", label: "عرض (متر)" },
      { key: "thickness", label: "ضخامت دال (سانتی‌متر)" }
    ],
    calculate: function (v) {
      var volume = v.length * v.width * (v.thickness / 100);
      var weight = volume * 2400;
      return [
        { label: "حجم بتن", value: volume.toFixed(2), unit: "متر مکعب" },
        { label: "وزن بتن", value: weight.toFixed(0), unit: "کیلوگرم" }
      ];
    }
  },
  {
    id: "roof-jack-arch",
    name: "سقف طاق ضربی",
    description: "برآورد تعداد آجر/تیرآهن موردنیاز برای سقف طاق ضربی سنتی",
    inputs: [
      { key: "area", label: "مساحت سقف (متر مربع)" },
      { key: "beamSpacing", label: "فاصله تیرآهن‌ها (سانتی‌متر، معمولاً ۸۰-۱۰۰)" },
      { key: "span", label: "دهانه سقف (متر)" }
    ],
    calculate: function (v) {
      var beamsCount = Math.ceil((v.area / v.span) / (v.beamSpacing / 100)) + 1;
      var tilesCount = Math.ceil(v.area * 14); // برآورد تقریبی ۱۴ آجر طاق‌ضربی در هر متر مربع
      return [
        { label: "تعداد تیرآهن موردنیاز", value: beamsCount.toFixed(0), unit: "عدد" },
        { label: "تعداد آجر طاق‌ضربی (تقریبی)", value: tilesCount.toFixed(0), unit: "عدد" }
      ];
    }
  }
];
