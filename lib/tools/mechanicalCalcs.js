export var mechanicalTools = [
  {
    id: "cooler-capacity",
    name: "ظرفیت کولر",
    description: "برآورد ظرفیت کولر آبی/گازی مورد نیاز بر اساس حجم فضا",
    inputs: [
      { key: "roomArea", label: "مساحت فضا (متر مربع)" },
      { key: "ceilingHeight", label: "ارتفاع سقف (متر)" }
    ],
    calculate: function (v) {
      var volume = v.roomArea * v.ceilingHeight;
      var capacityCfm = volume * 10;
      return [
        { label: "ظرفیت پیشنهادی", value: capacityCfm.toFixed(0), unit: "فوت مکعب بر دقیقه (CFM)" }
      ];
    }
  },
  {
    id: "chiller-capacity",
    name: "چیلر",
    description: "برآورد ظرفیت چیلر بر اساس بار حرارتی ساختمان",
    inputs: [
      { key: "buildingArea", label: "مساحت ساختمان (متر مربع)" },
      { key: "coolingLoadPerM2", label: "بار سرمایشی هر متر مربع (وات، معمولاً ۱۰۰-۱۵۰)" }
    ],
    calculate: function (v) {
      var totalLoadWatts = v.buildingArea * v.coolingLoadPerM2;
      var tons = totalLoadWatts / 3517;
      return [
        { label: "بار سرمایشی کل", value: totalLoadWatts.toFixed(0), unit: "وات" },
        { label: "ظرفیت چیلر", value: tons.toFixed(2), unit: "تن تبرید" }
      ];
    }
  },
  {
    id: "boiler-capacity",
    name: "بویلر",
    description: "برآورد ظرفیت بویلر بر اساس بار حرارتی",
    inputs: [
      { key: "buildingArea", label: "مساحت ساختمان (متر مربع)" },
      { key: "heatingLoadPerM2", label: "بار حرارتی هر متر مربع (وات، معمولاً ۱۰۰-۱۵۰)" }
    ],
    calculate: function (v) {
      var totalLoadWatts = v.buildingArea * v.heatingLoadPerM2;
      var kcalPerHour = totalLoadWatts * 0.86;
      return [
        { label: "بار حرارتی کل", value: totalLoadWatts.toFixed(0), unit: "وات" },
        { label: "ظرفیت بویلر", value: kcalPerHour.toFixed(0), unit: "کیلوکالری بر ساعت" }
      ];
    }
  },
  {
    id: "pump-flow",
    name: "پمپ",
    description: "برآورد دبی پمپ مورد نیاز بر اساس حجم مخزن و زمان پرشدن",
    inputs: [
      { key: "tankVolume", label: "حجم مخزن (متر مکعب)" },
      { key: "fillTime", label: "زمان پر شدن مطلوب (ساعت)" }
    ],
    calculate: function (v) {
      var flowRate = v.tankVolume / v.fillTime;
      var flowRateLpm = (v.tankVolume * 1000) / (v.fillTime * 60);
      return [
        { label: "دبی مورد نیاز", value: flowRate.toFixed(2), unit: "متر مکعب بر ساعت" },
        { label: "دبی مورد نیاز", value: flowRateLpm.toFixed(1), unit: "لیتر بر دقیقه" }
      ];
    }
  },
  {
    id: "tank-volume",
    name: "مخزن",
    description: "محاسبه حجم مخزن استوانه‌ای یا مکعبی",
    inputs: [
      { key: "shape", label: "شکل (1 برای استوانه‌ای، 2 برای مکعبی)" },
      { key: "dim1", label: "قطر یا طول (متر)" },
      { key: "dim2", label: "عرض (متر، فقط برای مکعبی — استوانه صفر بگذارید)" },
      { key: "height", label: "ارتفاع (متر)" }
    ],
    calculate: function (v) {
      var volume;
      if (v.shape === 1) {
        var radius = v.dim1 / 2;
        volume = Math.PI * radius * radius * v.height;
      } else {
        volume = v.dim1 * v.dim2 * v.height;
      }
      return [
        { label: "حجم مخزن", value: volume.toFixed(2), unit: "متر مکعب" },
        { label: "حجم مخزن", value: (volume * 1000).toFixed(0), unit: "لیتر" }
      ];
    }
  },
  {
    id: "pipe-sizing",
    name: "لوله",
    description: "برآورد قطر لوله مورد نیاز بر اساس دبی و سرعت مجاز جریان",
    inputs: [
      { key: "flowRate", label: "دبی (لیتر بر ثانیه)" },
      { key: "velocity", label: "سرعت مجاز جریان (متر بر ثانیه، معمولاً ۱-۲)" }
    ],
    calculate: function (v) {
      var flowM3s = v.flowRate / 1000;
      var area = flowM3s / v.velocity;
      var diameter = Math.sqrt((4 * area) / Math.PI);
      return [
        { label: "قطر پیشنهادی لوله", value: (diameter * 1000).toFixed(1), unit: "میلی‌متر" }
      ];
    }
  },
  {
    id: "duct-sizing",
    name: "کانال",
    description: "برآورد سطح مقطع کانال هوا بر اساس دبی هوا و سرعت",
    inputs: [
      { key: "airFlow", label: "دبی هوا (متر مکعب بر ساعت)" },
      { key: "velocity", label: "سرعت هوا در کانال (متر بر ثانیه، معمولاً ۴-۸)" }
    ],
    calculate: function (v) {
      var airFlowM3s = v.airFlow / 3600;
      var area = airFlowM3s / v.velocity;
      return [
        { label: "سطح مقطع کانال", value: area.toFixed(3), unit: "متر مربع" },
        { label: "سطح مقطع کانال", value: (area * 10000).toFixed(0), unit: "سانتی‌متر مربع" }
      ];
    }
  },
  {
    id: "ventilation-rate",
    name: "تهویه",
    description: "برآورد نرخ تهویه مورد نیاز بر اساس تعداد نفرات و نوع فضا",
    inputs: [
      { key: "occupants", label: "تعداد نفرات" },
      { key: "airPerPerson", label: "هوای تازه مورد نیاز هر نفر (متر مکعب بر ساعت، معمولاً ۲۰-۳۰)" }
    ],
    calculate: function (v) {
      var totalAirFlow = v.occupants * v.airPerPerson;
      return [
        { label: "نرخ تهویه مورد نیاز", value: totalAirFlow.toFixed(0), unit: "متر مکعب بر ساعت" }
      ];
    }
  }
];
