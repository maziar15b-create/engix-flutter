export var mechanicalEngTools = [
  {
    id: "shaft-power-torque",
    name: "توان و گشتاور شفت",
    description: "محاسبه گشتاور شفت بر اساس توان و دور موتور (RPM)",
    inputs: [
      { key: "power", label: "توان (کیلووات)" },
      { key: "rpm", label: "دور موتور (RPM)" }
    ],
    calculate: function (v) {
      var powerWatts = v.power * 1000;
      var omega = (2 * Math.PI * v.rpm) / 60;
      var torque = powerWatts / omega;
      return [
        { label: "گشتاور", value: torque.toFixed(2), unit: "نیوتن‌متر (N.m)" }
      ];
    }
  },
  {
    id: "shaft-torsional-stress",
    name: "تنش پیچشی شفت",
    description: "محاسبه تنش برشی ناشی از پیچش در یک شفت توپر دایره‌ای",
    inputs: [
      { key: "torque", label: "گشتاور اعمالی (نیوتن‌متر)" },
      { key: "diameter", label: "قطر شفت (میلی‌متر)" }
    ],
    calculate: function (v) {
      var r = v.diameter / 2 / 1000;
      var J = (Math.PI * Math.pow(v.diameter / 1000, 4)) / 32;
      var stress = (v.torque * r) / J;
      return [
        { label: "تنش برشی", value: (stress / 1e6).toFixed(2), unit: "مگاپاسکال (MPa)" }
      ];
    }
  },
  {
    id: "gear-ratio",
    name: "نسبت چرخ‌دنده",
    description: "محاسبه نسبت دنده و دور خروجی بر اساس تعداد دندانه‌ها",
    inputs: [
      { key: "teethDriver", label: "تعداد دندانه چرخ‌دنده محرک" },
      { key: "teethDriven", label: "تعداد دندانه چرخ‌دنده متحرک" },
      { key: "inputRpm", label: "دور ورودی (RPM)" }
    ],
    calculate: function (v) {
      var ratio = v.teethDriven / v.teethDriver;
      var outputRpm = v.inputRpm / ratio;
      return [
        { label: "نسبت دنده", value: ratio.toFixed(3), unit: ":1" },
        { label: "دور خروجی", value: outputRpm.toFixed(1), unit: "RPM" }
      ];
    }
  },
  {
    id: "spring-force",
    name: "فنر",
    description: "محاسبه نیروی فنر بر اساس ضریب سختی و میزان تغییر طول",
    inputs: [
      { key: "stiffness", label: "ضریب سختی فنر (نیوتن بر میلی‌متر)" },
      { key: "deflection", label: "میزان تغییر طول (میلی‌متر)" }
    ],
    calculate: function (v) {
      var force = v.stiffness * v.deflection;
      var energy = 0.5 * v.stiffness * 1000 * Math.pow(v.deflection / 1000, 2);
      return [
        { label: "نیروی فنر", value: force.toFixed(2), unit: "نیوتن" },
        { label: "انرژی ذخیره‌شده", value: energy.toFixed(3), unit: "ژول" }
      ];
    }
  },
  {
    id: "belt-speed",
    name: "سرعت تسمه",
    description: "محاسبه سرعت خطی تسمه بر اساس قطر پولی و دور موتور",
    inputs: [
      { key: "pulleyDiameter", label: "قطر پولی (میلی‌متر)" },
      { key: "rpm", label: "دور موتور (RPM)" }
    ],
    calculate: function (v) {
      var speedMmPerMin = Math.PI * v.pulleyDiameter * v.rpm;
      var speedMPerS = speedMmPerMin / 1000 / 60;
      return [
        { label: "سرعت خطی تسمه", value: speedMPerS.toFixed(2), unit: "متر بر ثانیه" }
      ];
    }
  },
  {
    id: "bolt-preload",
    name: "پیچ و مهره",
    description: "برآورد نیروی پیش‌بار پیچ بر اساس گشتاور بستن",
    inputs: [
      { key: "torque", label: "گشتاور بستن (نیوتن‌متر)" },
      { key: "diameter", label: "قطر اسمی پیچ (میلی‌متر)" },
      { key: "kFactor", label: "ضریب اصطکاک K (معمولاً حدود ۰.۲)" }
    ],
    calculate: function (v) {
      var preload = v.torque / (v.kFactor * (v.diameter / 1000));
      return [
        { label: "نیروی پیش‌بار پیچ", value: (preload / 1000).toFixed(2), unit: "کیلونیوتن (kN)" }
      ];
    }
  }
];
