export var civilTools = [
  {
    id: "rebar-cutting-optimizer",
    name: "لیست‌وفر میلگرد (بهینه‌سازی برش)",
    description: "محاسبه دقیق تعداد شاخه، چیدمان برش و کمترین پرت برای فونداسیون، ستون، سقف و سایر اعضا",
    custom: true
  },
  {
    id: "concrete-volume",
    name: "حجم بتن",
    description: "محاسبه حجم بتن مورد نیاز بر اساس ابعاد",
    inputs: [
      { key: "length", label: "طول (متر)" },
      { key: "width", label: "عرض (متر)" },
      { key: "height", label: "ارتفاع/ضخامت (متر)" }
    ],
    calculate: function (v) {
      var volume = v.length * v.width * v.height;
      return [
        { label: "حجم بتن", value: volume.toFixed(2), unit: "متر مکعب" }
      ];
    }
  },
  {
    id: "rebar-weight",
    name: "وزن میلگرد",
    description: "محاسبه وزن میلگرد بر اساس قطر و طول",
    inputs: [
      { key: "diameter", label: "قطر میلگرد (میلی‌متر)" },
      { key: "length", label: "طول کل (متر)" }
    ],
    calculate: function (v) {
      var weightPerMeter = (v.diameter * v.diameter) / 162;
      var totalWeight = weightPerMeter * v.length;
      return [
        { label: "وزن هر متر", value: weightPerMeter.toFixed(3), unit: "کیلوگرم" },
        { label: "وزن کل", value: totalWeight.toFixed(2), unit: "کیلوگرم" }
      ];
    }
  },
  {
    id: "rebar-count",
    name: "تعداد میلگرد",
    description: "محاسبه تعداد میلگرد مورد نیاز در یک طول مشخص، به همراه وزن کل بر اساس قطر و رده فولاد",
    inputs: [
      { key: "totalLength", label: "طول کل عضو (متر)" },
      { key: "spacing", label: "فاصله میلگردها (سانتی‌متر)" },
      { key: "barLength", label: "طول هر میلگرد (متر) — مثلاً طول تیر/ستون" },
      { key: "diameter", label: "قطر میلگرد (میلی‌متر) — مثلاً 8, 10, 12, 14, 16, 18, 20, 22, 25" },
      { key: "steelGrade", label: "رده فولاد (بنویس: 1 برای A1 ساده، 2 برای A2، 3 برای A3 آجدار)" }
    ],
    calculate: function (v) {
      var spacingMeters = v.spacing / 100;
      var count = Math.floor(v.totalLength / spacingMeters) + 1;
      var weightPerMeter = (v.diameter * v.diameter) / 162;
      var totalWeight = weightPerMeter * v.barLength * count;
      var gradeLabels = { 1: "A1 (ساده)", 2: "A2 (آجدار)", 3: "A3 (آجدار)" };
      var gradeLabel = gradeLabels[v.steelGrade] || ("رده " + v.steelGrade);
      return [
        { label: "تعداد میلگرد", value: count, unit: "عدد" },
        { label: "رده فولاد", value: gradeLabel, unit: "" },
        { label: "وزن هر متر", value: weightPerMeter.toFixed(3), unit: "کیلوگرم" },
        { label: "وزن کل", value: totalWeight.toFixed(2), unit: "کیلوگرم" }
      ];
    }
  },
  {
    id: "formwork-area",
    name: "قالب‌بندی",
    description: "محاسبه سطح قالب‌بندی مورد نیاز",
    inputs: [
      { key: "length", label: "طول (متر)" },
      { key: "height", label: "ارتفاع (متر)" },
      { key: "sides", label: "تعداد وجه (معمولاً ۲ یا ۴)" }
    ],
    calculate: function (v) {
      var area = v.length * v.height * v.sides;
      return [
        { label: "سطح قالب‌بندی", value: area.toFixed(2), unit: "متر مربع" }
      ];
    }
  },
  {
    id: "column-volume",
    name: "ستون",
    description: "محاسبه حجم بتن ستون",
    inputs: [
      { key: "width", label: "عرض مقطع (متر)" },
      { key: "depth", label: "عمق مقطع (متر)" },
      { key: "height", label: "ارتفاع ستون (متر)" },
      { key: "count", label: "تعداد ستون" }
    ],
    calculate: function (v) {
      var singleVolume = v.width * v.depth * v.height;
      var totalVolume = singleVolume * v.count;
      return [
        { label: "حجم هر ستون", value: singleVolume.toFixed(3), unit: "متر مکعب" },
        { label: "حجم کل", value: totalVolume.toFixed(2), unit: "متر مکعب" }
      ];
    }
  },
  {
    id: "beam-volume",
    name: "تیر",
    description: "محاسبه حجم بتن تیر",
    inputs: [
      { key: "width", label: "عرض مقطع (متر)" },
      { key: "height", label: "ارتفاع مقطع (متر)" },
      { key: "length", label: "طول تیر (متر)" },
      { key: "count", label: "تعداد تیر" }
    ],
    calculate: function (v) {
      var singleVolume = v.width * v.height * v.length;
      var totalVolume = singleVolume * v.count;
      return [
        { label: "حجم هر تیر", value: singleVolume.toFixed(3), unit: "متر مکعب" },
        { label: "حجم کل", value: totalVolume.toFixed(2), unit: "متر مکعب" }
      ];
    }
  },
  {
    id: "roof-volume",
    name: "سقف",
    description: "محاسبه حجم بتن سقف بر اساس مساحت و ضخامت",
    inputs: [
      { key: "area", label: "مساحت سقف (متر مربع)" },
      { key: "thickness", label: "ضخامت سقف (سانتی‌متر)" }
    ],
    calculate: function (v) {
      var thicknessMeters = v.thickness / 100;
      var volume = v.area * thicknessMeters;
      return [
        { label: "حجم بتن سقف", value: volume.toFixed(2), unit: "متر مکعب" }
      ];
    }
  },
  {
    id: "wall-volume",
    name: "دیوار",
    description: "محاسبه حجم بتن یا مصالح دیوار",
    inputs: [
      { key: "length", label: "طول دیوار (متر)" },
      { key: "height", label: "ارتفاع دیوار (متر)" },
      { key: "thickness", label: "ضخامت دیوار (سانتی‌متر)" }
    ],
    calculate: function (v) {
      var thicknessMeters = v.thickness / 100;
      var volume = v.length * v.height * thicknessMeters;
      return [
        { label: "حجم دیوار", value: volume.toFixed(2), unit: "متر مکعب" }
      ];
    }
  },
  {
    id: "foundation-volume",
    name: "فونداسیون",
    description: "محاسبه حجم بتن فونداسیون نواری یا منفرد",
    inputs: [
      { key: "length", label: "طول (متر)" },
      { key: "width", label: "عرض (متر)" },
      { key: "depth", label: "عمق (متر)" }
    ],
    calculate: function (v) {
      var volume = v.length * v.width * v.depth;
      return [
        { label: "حجم فونداسیون", value: volume.toFixed(2), unit: "متر مکعب" }
      ];
    }
  },
  {
    id: "excavation-volume",
    name: "خاکبرداری",
    description: "محاسبه حجم خاکبرداری بر اساس ابعاد گودال",
    inputs: [
      { key: "length", label: "طول (متر)" },
      { key: "width", label: "عرض (متر)" },
      { key: "depth", label: "عمق (متر)" }
    ],
    calculate: function (v) {
      var volume = v.length * v.width * v.depth;
      return [
        { label: "حجم خاکبرداری", value: volume.toFixed(2), unit: "متر مکعب" }
      ];
    }
  },
  {
    id: "pit-excavation",
    name: "گودبرداری",
    description: "محاسبه حجم گودبرداری با احتساب شیب دیواره",
    inputs: [
      { key: "length", label: "طول کف گود (متر)" },
      { key: "width", label: "عرض کف گود (متر)" },
      { key: "depth", label: "عمق گود (متر)" },
      { key: "slope", label: "شیب دیواره (مثلاً ۰.۵ برای هر متر عمق)" }
    ],
    calculate: function (v) {
      var topLength = v.length + 2 * v.depth * v.slope;
      var topWidth = v.width + 2 * v.depth * v.slope;
      var avgLength = (v.length + topLength) / 2;
      var avgWidth = (v.width + topWidth) / 2;
      var volume = avgLength * avgWidth * v.depth;
      return [
        { label: "حجم گودبرداری", value: volume.toFixed(2), unit: "متر مکعب" }
      ];
    }
  },
  {
    id: "backfill-volume",
    name: "خاکریزی",
    description: "محاسبه حجم خاک لازم برای خاکریزی/تراکم، با احتساب ضریب تراکم (نسبت حجم خاک شل به خاک متراکم‌شده)",
    inputs: [
      { key: "length", label: "طول (متر)" },
      { key: "width", label: "عرض (متر)" },
      { key: "height", label: "ارتفاع/ضخامت خاکریز متراکم‌شده (متر)" },
      { key: "compactionFactor", label: "ضریب تراکم (معمولاً بین ۱.۱۵ تا ۱.۳)" }
    ],
    calculate: function (v) {
      var compactedVolume = v.length * v.width * v.height;
      var looseVolumeNeeded = compactedVolume * v.compactionFactor;
      return [
        { label: "حجم خاکریز متراکم‌شده (نهایی)", value: compactedVolume.toFixed(2), unit: "متر مکعب" },
        { label: "حجم خاک شل موردنیاز (قبل از تراکم)", value: looseVolumeNeeded.toFixed(2), unit: "متر مکعب" }
      ];
    }
  },
  {
    id: "material-estimate",
    name: "برآورد مصالح",
    description: "برآورد سیمان، ماسه و شن بر اساس حجم بتن (نسبت 1:2:4)",
    inputs: [
      { key: "concreteVolume", label: "حجم بتن (متر مکعب)" }
    ],
    calculate: function (v) {
      var cementBags = v.concreteVolume * 6.5;
      var sandVolume = v.concreteVolume * 0.44;
      var gravelVolume = v.concreteVolume * 0.88;
      return [
        { label: "سیمان", value: cementBags.toFixed(1), unit: "کیسه (۵۰ کیلویی)" },
        { label: "ماسه", value: sandVolume.toFixed(2), unit: "متر مکعب" },
        { label: "شن", value: gravelVolume.toFixed(2), unit: "متر مکعب" }
      ];
    }
  },
  {
    id: "cost-estimate",
    name: "برآورد هزینه",
    description: "برآورد هزینه کل بر اساس مقدار و قیمت واحد",
    inputs: [
      { key: "quantity", label: "مقدار" },
      { key: "unitPrice", label: "قیمت واحد (تومان)" }
    ],
    calculate: function (v) {
      var total = v.quantity * v.unitPrice;
      return [
        { label: "هزینه کل", value: total.toLocaleString("fa-IR"), unit: "تومان" }
      ];
    }
  },
  {
    id: "quantity-takeoff",
    name: "متره و برآورد",
    description: "ثبت چندردیفیِ اقلام (مساحت، دیوار با کسر بازشو، حجم، شمارشی)، محاسبه‌ی خودکار مقدار و هزینه‌ی هر ردیف، جمع کل، و خروجی اکسل/PDF",
    custom: true
  },
  {
    id: "rebar-shop-drawing",
    name: "جدول خم آرماتور (شاپ‌درائینگ)",
    description: "محاسبه‌ی طول برش میلگرد راست، خم‌دار و خاموط بر اساس ضوابط متداول ACI 318 (کسر خم، طول قلاب)، به‌همراه وزن کل و خروجی اکسل",
    custom: true
  },
  {
    id: "lean-concrete-rubble",
    name: "بتن مگر و سنگ لاشه زیر فونداسیون",
    description: "محاسبه‌ی حجم بتن مگر و سنگ لاشه بر اساس نوع فونداسیون (نواری، منفرد، گسترده)، با احتساب حاشیه‌ی اضافه و درصد خلل‌وفرج سنگ",
    custom: true
  },
  {
    id: "progress-payment",
    name: "صورت وضعیت",
    description: "محاسبه‌ی کارکرد هر دوره، کسر حسن‌انجام‌کار، بیمه، بازپرداخت پیش‌پرداخت، مالیات بر ارزش افزوده و مبلغ خالص قابل‌پرداخت",
    custom: true
  },
  {
    id: "overhead-coefficients",
    name: "ضرایب بالاسری و تجهیز کارگاه",
    description: "اعمال ضریب بالاسری، ضریب منطقه‌ای و درصد تجهیز/برچیدن کارگاه روی برآورد اولیه پیمان",
    custom: true
  },
  {
    id: "price-adjustment",
    name: "تعدیل (بر اساس شاخص قیمت)",
    description: "محاسبه‌ی ساده‌شده‌ی مبلغ تعدیل هر دوره بر اساس نسبت شاخص دوره تعدیل به دوره پایه",
    custom: true
  },
  {
    id: "delay-penalty",
    name: "جریمه تاخیر پیمان",
    description: "محاسبه‌ی جریمه‌ی روزانه‌ی تاخیر غیرمجاز نسبت به مبلغ پیمان، با اعمال سقف مجاز",
    custom: true
  }
];
