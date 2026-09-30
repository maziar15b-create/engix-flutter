export var lsfTools = [
  {
    id: "lsf-wall-studs",
    name: "استاد و رانر دیوار LSF",
    description: "برآورد تعداد استاد و طول رانر موردنیاز برای یک دیوار سازه سبک فولادی (LSF)",
    inputs: [
      { key: "wallLength", label: "طول دیوار (متر)" },
      { key: "wallHeight", label: "ارتفاع دیوار (متر)" },
      { key: "spacing", label: "فاصله محور استادها (سانتی‌متر، معمولاً ۴۰ یا ۶۰)" }
    ],
    calculate: function (v) {
      var studsCount = Math.ceil(v.wallLength / (v.spacing / 100)) + 1;
      var studsTotalLength = studsCount * v.wallHeight;
      var trackTotalLength = 2 * v.wallLength; // رانر بالا + رانر پایین
      return [
        { label: "تعداد استاد", value: studsCount.toFixed(0), unit: "عدد" },
        { label: "طول کل استاد", value: studsTotalLength.toFixed(1), unit: "متر" },
        { label: "طول کل رانر (بالا و پایین)", value: trackTotalLength.toFixed(1), unit: "متر" }
      ];
    }
  },
  {
    id: "lsf-sheathing",
    name: "روکش دیوار LSF (OSB/سیمانی)",
    description: "برآورد تعداد ورق روکش موردنیاز برای پوشش یک یا دو طرف دیوار LSF",
    inputs: [
      { key: "wallArea", label: "مساحت دیوار (متر مربع)" },
      { key: "sheetArea", label: "مساحت هر ورق (متر مربع، برای ورق ۱۲۲×۲۴۴ عدد ۲.۹۸)" },
      { key: "sides", label: "تعداد وجه پوشش‌داده‌شده (۱ یا ۲)" }
    ],
    calculate: function (v) {
      var totalArea = v.wallArea * v.sides;
      var sheetsCount = Math.ceil(totalArea / v.sheetArea);
      return [
        { label: "مساحت کل پوشش", value: totalArea.toFixed(2), unit: "متر مربع" },
        { label: "تعداد ورق موردنیاز", value: sheetsCount.toFixed(0), unit: "عدد" }
      ];
    }
  },
  {
    id: "lsf-screw-count",
    name: "پیچ سازه LSF",
    description: "برآورد تعداد پیچ خودکار موردنیاز بر اساس مساحت روکش (بر پایه تراکم متوسط پیچ)",
    inputs: [
      { key: "sheathingArea", label: "مساحت کل روکش (متر مربع)" },
      { key: "screwsPerM2", label: "تراکم پیچ (عدد بر متر مربع، معمولاً ۱۲-۱۶)" }
    ],
    calculate: function (v) {
      var totalScrews = Math.ceil(v.sheathingArea * v.screwsPerM2);
      return [
        { label: "تعداد پیچ موردنیاز (تقریبی)", value: totalScrews.toFixed(0), unit: "عدد" }
      ];
    }
  }
];
