export var asphaltTools = [
  {
    id: "asphalt-volume-weight",
    name: "آسفالت",
    description: "محاسبه حجم و وزن آسفالت موردنیاز برای یک سطح",
    inputs: [
      { key: "length", label: "طول (متر)" },
      { key: "width", label: "عرض (متر)" },
      { key: "thickness", label: "ضخامت آسفالت (سانتی‌متر، معمولاً ۴-۷)" },
      { key: "density", label: "وزن مخصوص آسفالت (کیلوگرم بر متر مکعب، معمولاً ۲۳۵۰)" }
    ],
    calculate: function (v) {
      var area = v.length * v.width;
      var volume = area * (v.thickness / 100);
      var weightKg = volume * v.density;
      var weightTon = weightKg / 1000;
      return [
        { label: "مساحت", value: area.toFixed(2), unit: "متر مربع" },
        { label: "حجم آسفالت", value: volume.toFixed(2), unit: "متر مکعب" },
        { label: "وزن آسفالت", value: weightTon.toFixed(2), unit: "تن" }
      ];
    }
  },
  {
    id: "asphalt-layers",
    name: "آسفالت دو لایه (بیندر و توپکا)",
    description: "محاسبه جداگانه وزن لایه بیندر و لایه رویه (توپکا)",
    inputs: [
      { key: "area", label: "مساحت (متر مربع)" },
      { key: "binderThickness", label: "ضخامت لایه بیندر (سانتی‌متر، معمولاً ۵)" },
      { key: "surfaceThickness", label: "ضخامت لایه توپکا/رویه (سانتی‌متر، معمولاً ۴)" }
    ],
    calculate: function (v) {
      var density = 2350;
      var binderWeight = (v.area * (v.binderThickness / 100) * density) / 1000;
      var surfaceWeight = (v.area * (v.surfaceThickness / 100) * density) / 1000;
      return [
        { label: "وزن لایه بیندر", value: binderWeight.toFixed(2), unit: "تن" },
        { label: "وزن لایه توپکا (رویه)", value: surfaceWeight.toFixed(2), unit: "تن" },
        { label: "وزن کل آسفالت", value: (binderWeight + surfaceWeight).toFixed(2), unit: "تن" }
      ];
    }
  }
];
