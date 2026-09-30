export var foundationTools = [
  {
    id: "foundation-isolated",
    name: "پی منفرد",
    description: "محاسبه حجم و وزن بتن برای پی منفرد (تکی، زیر ستون)",
    inputs: [
      { key: "length", label: "طول پی (متر)" },
      { key: "width", label: "عرض پی (متر)" },
      { key: "depth", label: "ارتفاع پی (متر)" },
      { key: "count", label: "تعداد پی (عدد)" }
    ],
    calculate: function (v) {
      var volumeOne = v.length * v.width * v.depth;
      var totalVolume = volumeOne * (v.count || 1);
      var totalWeight = totalVolume * 2400;
      return [
        { label: "حجم بتن هر پی", value: volumeOne.toFixed(2), unit: "متر مکعب" },
        { label: "حجم کل بتن", value: totalVolume.toFixed(2), unit: "متر مکعب" },
        { label: "وزن کل بتن", value: totalWeight.toFixed(0), unit: "کیلوگرم" }
      ];
    }
  },
  {
    id: "foundation-strip",
    name: "پی نواری",
    description: "محاسبه حجم و وزن بتن برای پی نواری (زیر دیوار یا ردیف ستون‌ها)",
    inputs: [
      { key: "totalLength", label: "طول کل نوار پی (متر)" },
      { key: "width", label: "عرض پی (متر)" },
      { key: "depth", label: "ارتفاع پی (متر)" }
    ],
    calculate: function (v) {
      var volume = v.totalLength * v.width * v.depth;
      var weight = volume * 2400;
      return [
        { label: "حجم بتن", value: volume.toFixed(2), unit: "متر مکعب" },
        { label: "وزن بتن", value: weight.toFixed(0), unit: "کیلوگرم" }
      ];
    }
  },
  {
    id: "foundation-raft",
    name: "پی گسترده",
    description: "محاسبه حجم و وزن بتن برای پی گسترده (رادیه ژنرال / مت)",
    inputs: [
      { key: "area", label: "مساحت کل زیربنا (متر مربع)" },
      { key: "thickness", label: "ضخامت پی (متر)" }
    ],
    calculate: function (v) {
      var volume = v.area * v.thickness;
      var weight = volume * 2400;
      return [
        { label: "حجم بتن", value: volume.toFixed(2), unit: "متر مکعب" },
        { label: "وزن بتن", value: weight.toFixed(0), unit: "کیلوگرم" }
      ];
    }
  }
];
