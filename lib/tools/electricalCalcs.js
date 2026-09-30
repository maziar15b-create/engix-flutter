export var electricalTools = [
  {
    id: "cable-size",
    name: "محاسبه کابل",
    description: "برآورد سطح مقطع کابل بر اساس جریان و طول",
    inputs: [
      { key: "current", label: "جریان (آمپر)" },
      { key: "length", label: "طول مسیر (متر)" },
      { key: "voltage", label: "ولتاژ (ولت)" }
    ],
    calculate: function (v) {
      var crossSection = (v.current * v.length) / (v.voltage * 0.5);
      return [
        { label: "سطح مقطع تقریبی کابل", value: crossSection.toFixed(2), unit: "میلی‌متر مربع" }
      ];
    }
  },
  {
    id: "voltage-drop",
    name: "افت ولتاژ",
    description: "محاسبه افت ولتاژ در طول کابل",
    inputs: [
      { key: "current", label: "جریان (آمپر)" },
      { key: "length", label: "طول مسیر (متر)" },
      { key: "crossSection", label: "سطح مقطع کابل (میلی‌متر مربع)" }
    ],
    calculate: function (v) {
      var resistivity = 0.0175;
      var drop = (2 * resistivity * v.length * v.current) / v.crossSection;
      return [
        { label: "افت ولتاژ", value: drop.toFixed(2), unit: "ولت" }
      ];
    }
  },
  {
    id: "fuse-rating",
    name: "فیوز",
    description: "برآورد آمپراژ فیوز مناسب بر اساس توان و ولتاژ",
    inputs: [
      { key: "power", label: "توان (وات)" },
      { key: "voltage", label: "ولتاژ (ولت)" }
    ],
    calculate: function (v) {
      var current = v.power / v.voltage;
      var fuseRating = current * 1.25;
      return [
        { label: "جریان مصرفی", value: current.toFixed(2), unit: "آمپر" },
        { label: "آمپراژ پیشنهادی فیوز", value: fuseRating.toFixed(1), unit: "آمپر" }
      ];
    }
  },
  {
    id: "electrical-panel",
    name: "تابلو برق",
    description: "برآورد تعداد مدار خروجی مورد نیاز تابلو برق",
    inputs: [
      { key: "totalLoad", label: "بار کل (وات)" },
      { key: "circuitCapacity", label: "ظرفیت هر مدار (وات)" }
    ],
    calculate: function (v) {
      var circuitCount = Math.ceil(v.totalLoad / v.circuitCapacity);
      return [
        { label: "تعداد مدار مورد نیاز", value: circuitCount, unit: "مدار" }
      ];
    }
  },
  {
    id: "lighting-calc",
    name: "روشنایی",
    description: "برآورد تعداد چراغ مورد نیاز بر اساس مساحت و لوکس مطلوب",
    inputs: [
      { key: "roomArea", label: "مساحت اتاق (متر مربع)" },
      { key: "requiredLux", label: "شدت روشنایی مطلوب (لوکس)" },
      { key: "lumensPerFixture", label: "لومن هر چراغ" }
    ],
    calculate: function (v) {
      var totalLumens = v.roomArea * v.requiredLux;
      var fixtureCount = Math.ceil(totalLumens / v.lumensPerFixture);
      return [
        { label: "تعداد چراغ مورد نیاز", value: fixtureCount, unit: "عدد" }
      ];
    }
  },
  {
    id: "grounding",
    name: "ارت",
    description: "برآورد مقاومت الکترود ارت (فرمول ساده میله‌ای)",
    inputs: [
      { key: "rodLength", label: "طول میله ارت (متر)" },
      { key: "soilResistivity", label: "مقاومت مخصوص خاک (اهم‌متر)" }
    ],
    calculate: function (v) {
      var resistance = v.soilResistivity / (2 * Math.PI * v.rodLength);
      return [
        { label: "مقاومت تقریبی ارت", value: resistance.toFixed(2), unit: "اهم" }
      ];
    }
  },
  {
    id: "motor-current",
    name: "موتور",
    description: "محاسبه جریان مصرفی موتور بر اساس توان و ولتاژ",
    inputs: [
      { key: "power", label: "توان موتور (کیلووات)" },
      { key: "voltage", label: "ولتاژ (ولت)" },
      { key: "efficiency", label: "راندمان (درصد، مثلاً ۸۵)" }
    ],
    calculate: function (v) {
      var powerWatts = v.power * 1000;
      var current = powerWatts / (v.voltage * (v.efficiency / 100));
      return [
        { label: "جریان مصرفی موتور", value: current.toFixed(2), unit: "آمپر" }
      ];
    }
  },
  {
    id: "generator-sizing",
    name: "ژنراتور",
    description: "برآورد ظرفیت ژنراتور مورد نیاز با ضریب اطمینان",
    inputs: [
      { key: "totalLoad", label: "بار کل (کیلووات)" },
      { key: "safetyFactor", label: "ضریب اطمینان (مثلاً ۱.۲۵)" }
    ],
    calculate: function (v) {
      var generatorSize = v.totalLoad * v.safetyFactor;
      return [
        { label: "ظرفیت پیشنهادی ژنراتور", value: generatorSize.toFixed(1), unit: "کیلووات" }
      ];
    }
  }
];
