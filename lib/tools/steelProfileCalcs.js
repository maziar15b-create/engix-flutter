var STEEL_DENSITY = 7850; // کیلوگرم بر متر مکعب

// جدول وزن استاندارد تیرآهن IPE (کیلوگرم بر متر) — مطابق استاندارد DIN 1025 / یورونرم ۱۹-۵۷،
// همان مبنایی که تیرآهن‌های تولید داخل ایران هم بر اساس آن عرضه می‌شوند
var IPE_WEIGHTS = {
  80: 6.0, 100: 8.1, 120: 10.4, 140: 12.9, 160: 15.8, 180: 18.8,
  200: 22.4, 220: 26.2, 240: 30.7, 270: 36.1, 300: 42.2, 330: 49.1,
  360: 57.1, 400: 66.3, 450: 77.6, 500: 90.7, 550: 106, 600: 122
};

// جدول وزن استاندارد ناودانی UNP (کیلوگرم بر متر) — مطابق استاندارد DIN 1026
var UNP_WEIGHTS = {
  50: 5.59, 65: 7.09, 80: 8.64, 100: 10.6, 120: 13.4, 140: 16.0,
  160: 18.8, 180: 22.0, 200: 25.3, 220: 29.4, 240: 33.2, 260: 37.9,
  280: 41.8, 300: 46.2
};

export var steelProfileTools = [
  {
    id: "steel-angle-weight",
    name: "نبشی",
    description: "محاسبه وزن هر متر طول نبشی (پروفیل L) بر اساس ابعاد بال و ضخامت",
    inputs: [
      { key: "leg", label: "طول بال (میلی‌متر، مثلاً برای نبشی 5×50×50 عدد ۵۰)" },
      { key: "thickness", label: "ضخامت (میلی‌متر، مثلاً برای نبشی 5×50×50 عدد ۵)" }
    ],
    calculate: function (v) {
      var areaMm2 = v.thickness * (2 * v.leg - v.thickness);
      var weightPerMeter = (areaMm2 * STEEL_DENSITY) / 1e6;
      return [
        { label: "سطح مقطع", value: areaMm2.toFixed(1), unit: "میلی‌متر مربع" },
        { label: "وزن هر متر طول", value: weightPerMeter.toFixed(2), unit: "کیلوگرم بر متر" }
      ];
    }
  },
  {
    id: "steel-box-weight",
    name: "قوطی",
    description: "محاسبه وزن هر متر طول قوطی (پروفیل مربعی/مستطیلی) بر اساس ابعاد و ضخامت",
    inputs: [
      { key: "sideA", label: "ضلع اول (میلی‌متر)" },
      { key: "sideB", label: "ضلع دوم (میلی‌متر — برای قوطی مربعی برابر ضلع اول بگذارید)" },
      { key: "thickness", label: "ضخامت جدار (میلی‌متر)" }
    ],
    calculate: function (v) {
      var areaMm2 = 2 * v.thickness * (v.sideA + v.sideB - 2 * v.thickness);
      var weightPerMeter = (areaMm2 * STEEL_DENSITY) / 1e6;
      return [
        { label: "سطح مقطع", value: areaMm2.toFixed(1), unit: "میلی‌متر مربع" },
        { label: "وزن هر متر طول", value: weightPerMeter.toFixed(2), unit: "کیلوگرم بر متر" }
      ];
    }
  },
  {
    id: "steel-ibeam-weight",
    name: "تیرآهن (IPE)",
    description: "وزن دقیق تیرآهن بر اساس جدول استاندارد IPE (کیلوگرم بر متر)",
    inputs: [
      { key: "size", label: "سایز تیرآهن (فقط عدد را وارد کنید، مثلاً برای IPE140 عدد ۱۴۰)" },
      { key: "length", label: "طول کل موردنیاز (متر)" }
    ],
    calculate: function (v) {
      var weightPerMeter = IPE_WEIGHTS[Math.round(v.size)];
      if (!weightPerMeter) {
        return [
          { label: "نتیجه", value: "سایز واردشده در جدول استاندارد IPE یافت نشد", unit: "" }
        ];
      }
      var totalWeight = weightPerMeter * (v.length || 0);
      return [
        { label: "وزن هر متر طول (استاندارد)", value: weightPerMeter.toFixed(2), unit: "کیلوگرم بر متر" },
        { label: "وزن کل", value: totalWeight.toFixed(1), unit: "کیلوگرم" }
      ];
    }
  },
  {
    id: "steel-channel-weight",
    name: "ناودانی",
    description: "وزن دقیق ناودانی بر اساس جدول استاندارد UNP (کیلوگرم بر متر)",
    inputs: [
      { key: "size", label: "سایز ناودانی (فقط عدد را وارد کنید، مثلاً برای UNP100 عدد ۱۰۰)" },
      { key: "length", label: "طول کل موردنیاز (متر)" }
    ],
    calculate: function (v) {
      var weightPerMeter = UNP_WEIGHTS[Math.round(v.size)];
      if (!weightPerMeter) {
        return [
          { label: "نتیجه", value: "سایز واردشده در جدول استاندارد UNP یافت نشد", unit: "" }
        ];
      }
      var totalWeight = weightPerMeter * (v.length || 0);
      return [
        { label: "وزن هر متر طول (استاندارد)", value: weightPerMeter.toFixed(2), unit: "کیلوگرم بر متر" },
        { label: "وزن کل", value: totalWeight.toFixed(1), unit: "کیلوگرم" }
      ];
    }
  }
];
