export var architectureTools = [
  {
    id: "design-regulations",
    name: "ضوابط طراحی",
    description: "بررسی کلی رعایت حداقل‌های متداول طراحی بر اساس مساحت زمین",
    inputs: [
      { key: "landArea", label: "مساحت زمین (متر مربع)" },
      { key: "buildingArea", label: "مساحت زیربنا (متر مربع)" }
    ],
    calculate: function (v) {
      var ratio = (v.buildingArea / v.landArea) * 100;
      return [
        { label: "نسبت زیربنا به زمین", value: ratio.toFixed(1), unit: "درصد" }
      ];
    }
  },
  {
    id: "occupancy-area",
    name: "سطح اشغال",
    description: "محاسبه درصد سطح اشغال ساختمان در زمین",
    inputs: [
      { key: "landArea", label: "مساحت زمین (متر مربع)" },
      { key: "footprintArea", label: "مساحت اشغال طبقه همکف (متر مربع)" }
    ],
    calculate: function (v) {
      var occupancy = (v.footprintArea / v.landArea) * 100;
      return [
        { label: "سطح اشغال", value: occupancy.toFixed(1), unit: "درصد" }
      ];
    }
  },
  {
    id: "density",
    name: "تراکم",
    description: "محاسبه تراکم ساختمانی (نسبت کل زیربنا به مساحت زمین)",
    inputs: [
      { key: "landArea", label: "مساحت زمین (متر مربع)" },
      { key: "totalBuiltArea", label: "کل زیربنای مجاز (متر مربع)" }
    ],
    calculate: function (v) {
      var density = (v.totalBuiltArea / v.landArea) * 100;
      return [
        { label: "تراکم ساختمانی", value: density.toFixed(0), unit: "درصد" }
      ];
    }
  },
  {
    id: "daylighting",
    name: "نورگیری",
    description: "محاسبه حداقل سطح پنجره لازم بر اساس مساحت اتاق (قاعده تقریبی ۱ به ۶)",
    inputs: [
      { key: "roomArea", label: "مساحت اتاق (متر مربع)" }
    ],
    calculate: function (v) {
      var minWindowArea = v.roomArea / 6;
      return [
        { label: "حداقل سطح پنجره", value: minWindowArea.toFixed(2), unit: "متر مربع" }
      ];
    }
  },
  {
    id: "parking-count",
    name: "پارکینگ",
    description: "برآورد تعداد پارکینگ مورد نیاز بر اساس تعداد واحد",
    inputs: [
      { key: "unitCount", label: "تعداد واحد مسکونی" },
      { key: "ratio", label: "نسبت پارکینگ به واحد (مثلاً ۱ یا ۱.۲۵)" }
    ],
    calculate: function (v) {
      var parkingCount = Math.ceil(v.unitCount * v.ratio);
      return [
        { label: "تعداد پارکینگ مورد نیاز", value: parkingCount, unit: "واحد" }
      ];
    }
  },
  {
    id: "ramp-slope",
    name: "شیب رمپ",
    description: "محاسبه شیب رمپ پارکینگ بر اساس اختلاف ارتفاع و طول",
    inputs: [
      { key: "heightDiff", label: "اختلاف ارتفاع (متر)" },
      { key: "rampLength", label: "طول رمپ (متر)" }
    ],
    calculate: function (v) {
      var slope = (v.heightDiff / v.rampLength) * 100;
      return [
        { label: "شیب رمپ", value: slope.toFixed(1), unit: "درصد" }
      ];
    }
  },
  {
    id: "scale-conversion",
    name: "مقیاس",
    description: "تبدیل ابعاد واقعی به ابعاد روی نقشه بر اساس مقیاس",
    inputs: [
      { key: "realLength", label: "طول واقعی (متر)" },
      { key: "scaleDenominator", label: "مخرج مقیاس (مثلاً برای ۱:۱۰۰ عدد ۱۰۰ را وارد کنید)" }
    ],
    calculate: function (v) {
      var drawingLengthCm = (v.realLength * 100) / v.scaleDenominator;
      return [
        { label: "طول روی نقشه", value: drawingLengthCm.toFixed(2), unit: "سانتی‌متر" }
      ];
    }
  },
  {
    id: "preliminary-design",
    name: "طراحی اولیه",
    description: "برآورد اولیه تعداد اتاق قابل جانمایی بر اساس مساحت",
    inputs: [
      { key: "totalArea", label: "مساحت کل (متر مربع)" },
      { key: "avgRoomArea", label: "میانگین مساحت هر اتاق (متر مربع)" }
    ],
    calculate: function (v) {
      var roomCount = Math.floor(v.totalArea / v.avgRoomArea);
      return [
        { label: "تعداد اتاق قابل جانمایی", value: roomCount, unit: "اتاق" }
      ];
    }
  }
];
