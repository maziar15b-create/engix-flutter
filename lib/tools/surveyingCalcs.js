export var surveyingTools = [
  {
    id: "slope-percent",
    name: "شیب زمین",
    description: "محاسبه درصد و زاویه شیب بر اساس اختلاف ارتفاع و فاصله افقی",
    inputs: [
      { key: "rise", label: "اختلاف ارتفاع (متر)" },
      { key: "run", label: "فاصله افقی (متر)" }
    ],
    calculate: function (v) {
      var percent = (v.rise / v.run) * 100;
      var degrees = Math.atan(v.rise / v.run) * (180 / Math.PI);
      return [
        { label: "درصد شیب", value: percent.toFixed(2), unit: "%" },
        { label: "زاویه شیب", value: degrees.toFixed(2), unit: "درجه" }
      ];
    }
  },
  {
    id: "slope-to-horizontal-distance",
    name: "فاصله افقی از فاصله شیب‌دار",
    description: "تبدیل فاصله اندازه‌گیری‌شده روی شیب به فاصله افقی واقعی",
    inputs: [
      { key: "slopeDistance", label: "فاصله شیب‌دار اندازه‌گیری‌شده (متر)" },
      { key: "verticalAngle", label: "زاویه قائم (درجه)" }
    ],
    calculate: function (v) {
      var rad = (v.verticalAngle * Math.PI) / 180;
      var horizontal = v.slopeDistance * Math.cos(rad);
      var vertical = v.slopeDistance * Math.sin(rad);
      return [
        { label: "فاصله افقی", value: horizontal.toFixed(3), unit: "متر" },
        { label: "اختلاف ارتفاع", value: vertical.toFixed(3), unit: "متر" }
      ];
    }
  },
  {
    id: "earthwork-volume",
    name: "حجم خاکبرداری/خاکریزی",
    description: "برآورد حجم خاک بین دو مقطع به روش منشوری (average end area)",
    inputs: [
      { key: "areaStart", label: "مساحت مقطع ابتدایی (متر مربع)" },
      { key: "areaEnd", label: "مساحت مقطع انتهایی (متر مربع)" },
      { key: "distance", label: "فاصله بین دو مقطع (متر)" }
    ],
    calculate: function (v) {
      var volume = ((v.areaStart + v.areaEnd) / 2) * v.distance;
      return [
        { label: "حجم خاک", value: volume.toFixed(2), unit: "متر مکعب" }
      ];
    }
  },
  {
    id: "rectangular-land-area",
    name: "مساحت زمین مستطیلی",
    description: "محاسبه مساحت و محیط یک قطعه زمین مستطیلی از روی طول اضلاع",
    inputs: [
      { key: "length", label: "طول (متر)" },
      { key: "width", label: "عرض (متر)" }
    ],
    calculate: function (v) {
      var area = v.length * v.width;
      var perimeter = 2 * (v.length + v.width);
      return [
        { label: "مساحت", value: area.toFixed(2), unit: "متر مربع" },
        { label: "محیط", value: perimeter.toFixed(2), unit: "متر" }
      ];
    }
  },
  {
    id: "bearing-to-azimuth",
    name: "تبدیل امتداد به آزیموت",
    description: "تبدیل زاویه امتداد (بیرینگ، مثلاً N45E) به آزیموت (۰ تا ۳۶۰ درجه)",
    inputs: [
      { key: "quadrant", label: "جهت (1: شمال‌شرقی، 2: جنوب‌شرقی، 3: جنوب‌غربی، 4: شمال‌غربی)" },
      { key: "angle", label: "زاویه امتداد نسبت به شمال/جنوب (درجه)" }
    ],
    calculate: function (v) {
      var azimuth;
      if (v.quadrant === 1) azimuth = v.angle;
      else if (v.quadrant === 2) azimuth = 180 - v.angle;
      else if (v.quadrant === 3) azimuth = 180 + v.angle;
      else azimuth = 360 - v.angle;
      return [
        { label: "آزیموت", value: azimuth.toFixed(2), unit: "درجه" }
      ];
    }
  },
  {
    id: "contour-interval-estimate",
    name: "برآورد تعداد منحنی میزان",
    description: "برآورد تعداد خطوط منحنی میزان بین دو ارتفاع بر اساس فاصله قائم منحنی‌ها",
    inputs: [
      { key: "elevationMin", label: "کمترین ارتفاع (متر)" },
      { key: "elevationMax", label: "بیشترین ارتفاع (متر)" },
      { key: "interval", label: "فاصله قائم منحنی‌ها (متر، معمولاً ۱ یا ۲)" }
    ],
    calculate: function (v) {
      var count = Math.floor((v.elevationMax - v.elevationMin) / v.interval);
      return [
        { label: "تعداد منحنی میزان", value: count.toFixed(0), unit: "خط" }
      ];
    }
  }
];
