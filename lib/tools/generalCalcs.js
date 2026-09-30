export var generalTools = [
  {
    id: "unit-converter-full",
    name: "مبدل واحد",
    description: "تبدیل بین واحدهای طول، سطح، حجم، وزن، فشار، دما و بیشتر",
    custom: true
  },
  {
    id: "concrete-volume",
    name: "حجم بتن (سریع)",
    description: "محاسبه سریع حجم بتن از روی طول، عرض و ارتفاع",
    custom: true
  },
  {
    id: "unit-converter-length",
    name: "تبدیل واحد طول",
    description: "تبدیل بین متر، سانتی‌متر، اینچ و فوت",
    inputs: [
      { key: "value", label: "مقدار" },
      { key: "fromUnit", label: "واحد مبدأ (1=متر, 2=سانتی‌متر, 3=اینچ, 4=فوت)" }
    ],
    calculate: function (v) {
      var meters;
      if (v.fromUnit === 1) meters = v.value;
      else if (v.fromUnit === 2) meters = v.value / 100;
      else if (v.fromUnit === 3) meters = v.value * 0.0254;
      else meters = v.value * 0.3048;

      return [
        { label: "متر", value: meters.toFixed(4), unit: "m" },
        { label: "سانتی‌متر", value: (meters * 100).toFixed(2), unit: "cm" },
        { label: "اینچ", value: (meters / 0.0254).toFixed(2), unit: "in" },
        { label: "فوت", value: (meters / 0.3048).toFixed(2), unit: "ft" }
      ];
    }
  },
  {
    id: "unit-converter-area",
    name: "تبدیل واحد مساحت",
    description: "تبدیل بین متر مربع، هکتار و جریب",
    inputs: [
      { key: "value", label: "مقدار (متر مربع)" }
    ],
    calculate: function (v) {
      var sqm = v.value;
      return [
        { label: "متر مربع", value: sqm.toFixed(2), unit: "m²" },
        { label: "هکتار", value: (sqm / 10000).toFixed(4), unit: "ha" },
        { label: "جریب", value: (sqm / 1000).toFixed(3), unit: "جریب" }
      ];
    }
  },
  {
    id: "project-calendar",
    name: "تقویم پروژه",
    description: "محاسبه تاریخ پایان پروژه بر اساس تاریخ شروع و مدت زمان",
    inputs: [
      { key: "durationDays", label: "مدت زمان پروژه (روز)" }
    ],
    calculate: function (v) {
      var startDate = new Date();
      var endDate = new Date(startDate.getTime() + v.durationDays * 24 * 60 * 60 * 1000);
      return [
        { label: "تاریخ شروع (میلادی)", value: startDate.toLocaleDateString("fa-IR"), unit: "" },
        { label: "تاریخ پایان (میلادی)", value: endDate.toLocaleDateString("fa-IR"), unit: "" }
      ];
    }
  },
  {
    id: "financial-calculator",
    name: "ماشین حساب مالی",
    description: "محاسبه قسط ماهانه وام بر اساس مبلغ، نرخ سود و مدت",
    inputs: [
      { key: "principal", label: "مبلغ وام (تومان)" },
      { key: "annualRate", label: "نرخ سود سالانه (درصد)" },
      { key: "months", label: "مدت بازپرداخت (ماه)" }
    ],
    calculate: function (v) {
      var monthlyRate = v.annualRate / 100 / 12;
      var installment;
      if (monthlyRate === 0) {
        installment = v.principal / v.months;
      } else {
        var pow = Math.pow(1 + monthlyRate, v.months);
        installment = (v.principal * monthlyRate * pow) / (pow - 1);
      }
      var totalPayment = installment * v.months;
      return [
        { label: "قسط ماهانه", value: Math.round(installment).toLocaleString("fa-IR"), unit: "تومان" },
        { label: "مجموع بازپرداخت", value: Math.round(totalPayment).toLocaleString("fa-IR"), unit: "تومان" }
      ];
    }
  },
  {
    id: "basic-calculator",
    name: "ماشین حساب",
    description: "چهار عمل اصلی روی دو عدد",
    inputs: [
      { key: "a", label: "عدد اول" },
      { key: "operator", label: "عملگر (1=جمع, 2=تفریق, 3=ضرب, 4=تقسیم)" },
      { key: "b", label: "عدد دوم" }
    ],
    calculate: function (v) {
      var result;
      if (v.operator === 1) result = v.a + v.b;
      else if (v.operator === 2) result = v.a - v.b;
      else if (v.operator === 3) result = v.a * v.b;
      else result = v.b !== 0 ? v.a / v.b : NaN;

      return [
        { label: "نتیجه", value: isNaN(result) ? "نامعتبر (تقسیم بر صفر)" : result.toString(), unit: "" }
      ];
    }
  }
];
