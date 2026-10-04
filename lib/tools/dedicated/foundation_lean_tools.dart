import 'dart:math';

import 'tool_kit.dart';

FormBuilder _foundation = (Vals v) {
  final type = v.s('footingType');
  final fc = v.n('fc'), fy = v.n('fy'), qa = v.n('qa');
  final vcOne = v.n('vcCoefOneWay'), vcPunch = v.n('vcCoefPunch');
  final phiS = v.n('phiShear'), phiF = v.n('phiFlexure');
  final pService = v.n('Pservice'), pu = v.n('Pu');
  final colW = v.n('colWidth'), colD = v.n('colDepth');
  final fL = v.n('footingL'), fB = v.n('footingB'), fH = v.n('footingH');
  final soilCover = v.n('soilCover');

  final area = fL * fB;
  final areaM2 = area / 10000;
  final actualP = areaM2 > 0 ? (pService * 1000) / area : 0.0;
  final pressureOk = actualP <= qa;
  final d = fH - soilCover;
  final puKg = pu * 1000;
  final netUlt = area > 0 ? puKg / area : 0.0;
  final bo = 2 * (colW + d) + 2 * (colD + d);
  final vcPunchV = vcPunch * sqrt(fc) * bo * d;
  final phiVcPunch = phiS * vcPunchV;
  final punchInside = (colW + d) * (colD + d);
  final vuPunch = netUlt * (area - punchInside);
  final punchOk = vuPunch <= phiVcPunch;
  final critOne = max(0.0, (fL - colW) / 2 - d);
  final vuOne = netUlt * critOne * fB;
  final vcOneV = vcOne * sqrt(fc) * fB * d;
  final phiVcOne = phiS * vcOneV;
  final oneOk = vuOne <= phiVcOne;
  final cant = max(0.0, (fL - colW) / 2);
  final mu = (netUlt * fB * pow(cant, 2)) / 2;
  final rn = d > 0 ? mu / (phiF * fB * d * d) : 0.0;
  final under = 1 - (2 * rn) / (0.85 * fc);
  final rho = under >= 0 ? (0.85 * fc / fy) * (1 - sqrt(under)) : 0.0;
  const rhoMin = 0.0018;
  final asF = max(rho, rhoMin) * fB * d;

  final stripW = v.n('stripWidth'), stripT = v.n('stripThickness');
  final wService = v.n('wallLoadService'), wUlt = v.n('wallLoadUlt'), wallW = v.n('wallWidth');
  final dStrip = stripT - soilCover;
  final pStrip = stripW > 0 ? (wService * 1000) / (stripW * 100) : 0.0;
  final pStripOk = pStrip <= qa;
  final netStrip = stripW > 0 ? (wUlt * 1000) / (stripW * 100) : 0.0;
  final cantStrip = max(0.0, (stripW - wallW) / 2);
  final muStrip = (netStrip * 100 * pow(cantStrip, 2)) / 2;
  final rnStrip = dStrip > 0 ? muStrip / (phiF * 100 * dStrip * dStrip) : 0.0;
  final underS = 1 - (2 * rnStrip) / (0.85 * fc);
  final rhoStrip = underS >= 0 ? (0.85 * fc / fy) * (1 - sqrt(underS)) : 0.0;
  final asStrip = max(rhoStrip, rhoMin) * 100 * dStrip;
  final vuStrip = netStrip * 100 * max(0.0, cantStrip - dStrip);
  final vcStrip = vcOne * sqrt(fc) * 100 * dStrip;
  final phiVcStrip = phiS * vcStrip;
  final stripShearOk = vuStrip <= phiVcStrip;

  final matLoad = v.n('matTotalLoad'), matArea = v.n('matArea'), matT = v.n('matThickness');
  final matP = matArea > 0 ? (matLoad * 1000) / (matArea * 10000) : 0.0;
  final matOk = matP <= qa;
  final dMat = matT - soilCover;

  return [
    const Note(
        '⚠️ کمک‌محاسبه است، نه جایگزین محاسبات مهندس محاسب و گزارش مکانیک خاک. ظرفیت باربری مجاز خاک (qa) باید از گزارش رسمی ژئوتکنیک پروژه گرفته شود. برای پی گسترده، توزیع دقیق فشار و لنگر معمولاً نیازمند تحلیل اندرکنش خاک-سازه (نرم‌افزار SAFE یا مشابه) است — بخش «پی گسترده» این ابزار فقط کنترل میانگین فشار می‌دهد.'),
    Sec('نوع پی و مصالح', [
      const S('footingType', 'نوع پی', [['isolated', 'پی منفرد'], ['strip', 'پی نواری'], ['mat', 'پی گسترده']]),
      const F('qa', 'ظرفیت باربری مجاز خاک (qa)', unit: 'kg/cm²'),
      const F('soilCover', 'پوشش بتن روی خاک', unit: 'cm'),
      const F('fc', "fc'", unit: 'kg/cm²'),
      const F('fy', 'fy', unit: 'kg/cm²'),
    ]),
    if (type == 'isolated') ...[
      Sec('بار ستون و ابعاد', [
        const F('Pservice', 'بار سرویس ستون (D+L)', unit: 'ton'),
        const F('Pu', 'بار نهایی ستون (Pu)', unit: 'ton'),
        const F('colWidth', 'عرض ستون', unit: 'cm'),
        const F('colDepth', 'عمق ستون', unit: 'cm'),
        const F('footingL', 'طول پی (L)', unit: 'cm'),
        const F('footingB', 'عرض پی (B)', unit: 'cm'),
        const F('footingH', 'ارتفاع پی (H)', unit: 'cm'),
      ]),
      Sec('کنترل فشار خاک', [
        R('مساحت پی', fixed(areaM2, 2), unit: 'm²'),
        R('فشار واقعی (سرویس)', fixed(actualP, 2), unit: 'kg/cm²', warn: !pressureOk),
        R('ظرفیت مجاز (qa)', fixed(qa, 2), unit: 'kg/cm²'),
        if (!pressureOk) const Note('⚠ فشار از ظرفیت مجاز خاک بیشتر است — ابعاد پی را بزرگ‌تر کنید.'),
      ]),
      Sec('کنترل برش پانچ (دوطرفه)', [
        const F('vcCoefPunch', 'ضریب Vc پانچ'),
        const F('phiShear', 'φ برشی'),
        R('عمق موثر (d)', fixed(d, 1), unit: 'cm'),
        R('پیرامون بحرانی (bo)', fixed(bo, 0), unit: 'cm'),
        R('مقاومت برشی بتن (Vc)', fixed(vcPunchV / 1000, 1), unit: 'ton'),
        R('φVc', fixed(phiVcPunch / 1000, 1), unit: 'ton'),
        R('Vu (پانچ)', fixed(vuPunch / 1000, 1), unit: 'ton', warn: !punchOk, hl: punchOk),
        if (!punchOk) const Note('⚠ کفایت نمی‌کند — ارتفاع پی یا ابعاد ستون را افزایش دهید.'),
      ]),
      Sec('کنترل برش یک‌طرفه', [
        const F('vcCoefOneWay', 'ضریب Vc یک‌طرفه'),
        R('طول بحرانی از وجه ستون', fixed(critOne, 1), unit: 'cm'),
        R('Vu (یک‌طرفه)', fixed(vuOne / 1000, 1), unit: 'ton', warn: !oneOk),
        R('φVc (یک‌طرفه)', fixed(phiVcOne / 1000, 1), unit: 'ton'),
      ]),
      Sec('طراحی خمشی', [
        const F('phiFlexure', 'φ خمشی'),
        R('لنگر طراحی در وجه ستون', fixed(mu / 100000, 2), unit: 'ton.m'),
        R('ρ مورد نیاز', fixed(rho, 5)),
        R('سطح میلگرد لازم (As)', fixed(asF, 2), unit: 'cm² (بر عرض کل پی)', hl: true),
      ]),
    ],
    if (type == 'strip') ...[
      Sec('بار دیوار/ردیف ستون و ابعاد', [
        const F('wallLoadService', 'بار خطی سرویس', unit: 'ton/m'),
        const F('wallLoadUlt', 'بار خطی نهایی', unit: 'ton/m'),
        const F('wallWidth', 'عرض دیوار/پی روی آن', unit: 'cm'),
        const F('stripWidth', 'عرض پی نواری', unit: 'cm'),
        const F('stripThickness', 'ضخامت پی نواری', unit: 'cm'),
      ]),
      Sec('کنترل فشار خاک', [
        R('فشار واقعی (سرویس)', fixed(pStrip, 2), unit: 'kg/cm²', warn: !pStripOk),
        R('ظرفیت مجاز (qa)', fixed(qa, 2), unit: 'kg/cm²'),
      ]),
      Sec('طراحی خمشی و برشی (بر متر طول)', [
        R('عمق موثر (d)', fixed(dStrip, 1), unit: 'cm'),
        R('لنگر طراحی', fixed(muStrip / 100000, 2), unit: 'ton.m/m'),
        R('سطح میلگرد لازم (As)', fixed(asStrip, 2), unit: 'cm²/m', hl: true),
        R('Vu یک‌طرفه', fixed(vuStrip / 1000, 1), unit: 'ton/m', warn: !stripShearOk),
        R('φVc', fixed(phiVcStrip / 1000, 1), unit: 'ton/m'),
      ]),
    ],
    if (type == 'mat')
      Sec('پی گسترده — کنترل میانگین فشار', [
        const F('matTotalLoad', 'کل بار سرویس ساختمان', unit: 'ton'),
        const F('matArea', 'مساحت کل پی', unit: 'm²'),
        const F('matThickness', 'ضخامت پی', unit: 'cm'),
        R('عمق موثر (d)', fixed(dMat, 1), unit: 'cm'),
        R('میانگین فشار خاک', fixed(matP, 2), unit: 'kg/cm²', warn: !matOk),
        R('ظرفیت مجاز (qa)', fixed(qa, 2), unit: 'kg/cm²'),
        if (!matOk) const Note('⚠ میانگین فشار از ظرفیت مجاز بیشتر است — مساحت پی یا ظرفیت خاک باید بازبینی شود.'),
        const Note(
            'این فقط یک کنترل میانگین است. توزیع واقعی فشار زیر پی گسترده معمولاً غیریکنواخت است (خصوصاً نزدیک لبه‌ها و زیر ستون‌های پرفشار) و طراحی نهایی خمشی/برشی باید با مدل اندرکنش خاک-سازه انجام شود.',
            warn: false),
      ]),
  ];
};

FormTool foundationTool(String title) => FormTool(
    toolId: 'foundation-design',
    title: title,
    description: '',
    defaults: const {
      'footingType': 'isolated', 'fc': '250', 'fy': '4000', 'qa': '2', 'vcCoefOneWay': '0.53', 'vcCoefPunch': '1.06',
      'phiShear': '0.75', 'phiFlexure': '0.9', 'Pservice': '60', 'Pu': '80', 'colWidth': '40', 'colDepth': '40',
      'footingL': '220', 'footingB': '220', 'footingH': '50', 'soilCover': '7.5', 'stripWidth': '150',
      'stripThickness': '50', 'wallLoadService': '20', 'wallLoadUlt': '28', 'wallWidth': '30',
      'matTotalLoad': '2500', 'matArea': '1000', 'matThickness': '80',
    },
    builder: _foundation);

// ───────────────────────── بتن مگر و سنگ لاشه ─────────────────────────

FormBuilder _lean = (Vals v) {
  final type = v.s('type');
  final marginM = v.n('margin') / 100;
  var area = 0.0;
  if (type == 'strip') {
    final w = v.n('stripWidth') + 2 * marginM;
    area = v.n('stripTotalLength') * w;
  } else if (type == 'isolated') {
    final l = v.n('padLength') + 2 * marginM;
    final w = v.n('padWidth') + 2 * marginM;
    final cnt = v.n('padCount');
    area = l * w * (cnt == 0 ? 1 : cnt);
  } else if (type == 'mat') {
    final l = v.n('matLength') + 2 * marginM;
    final w = v.n('matWidth') + 2 * marginM;
    area = l * w;
  }
  final leanVol = area * (v.n('leanThickness') / 100);
  final rubbleVol = area * (v.n('rubbleThickness') / 100);
  final voidsFill = rubbleVol * (v.n('voidsPercent') / 100);
  final cementBags = leanVol * 6.5;
  final sand = leanVol * 0.44;
  final gravel = leanVol * 0.88;
  return [
    const Note('محاسبه‌ی حجم بتن مگر و سنگ لاشه بر اساس نوع فونداسیون، با احتساب حاشیه‌ی اضافه و خلل‌وفرج سنگ.',
        warn: false),
    Sec('نوع فونداسیون', [
      const S('type', 'نوع فونداسیون', [
        ['strip', 'نواری (زیر دیوار یا ردیف ستون)'],
        ['isolated', 'منفرد (زیر ستون تکی)'],
        ['mat', 'گسترده (زیر کل ساختمان)'],
      ]),
      if (type == 'strip') ...[
        const F('stripTotalLength', 'مجموع طول نوارها (متر) — جمع همه‌ی دیوارها یا ردیف‌های ستون'),
        const F('stripWidth', 'عرض نوار فونداسیون (متر)'),
      ],
      if (type == 'isolated') ...[
        const F('padLength', 'طول هر پی (متر)'),
        const F('padWidth', 'عرض هر پی (متر)'),
        const F('padCount', 'تعداد پی‌های منفرد'),
      ],
      if (type == 'mat') ...[
        const F('matLength', 'طول کل ساختمان (متر)'),
        const F('matWidth', 'عرض کل ساختمان (متر)'),
      ],
    ]),
    Sec('پارامترهای مشترک', [
      const F('margin', 'حاشیه‌ی اضافه هر طرف (سانتی‌متر) — معمولاً ۱۰'),
      const F('leanThickness', 'ضخامت بتن مگر (سانتی‌متر) — معمولاً ۵ تا ۱۰'),
      const F('rubbleThickness', 'ضخامت سنگ لاشه (سانتی‌متر) — معمولاً ۲۰ تا ۳۰'),
      const F('voidsPercent', 'درصد خلل‌وفرج سنگ لاشه (٪) — معمولاً ۳۰ تا ۴۰'),
    ]),
    Sec('نتیجه', [
      R('مساحت مؤثر (با حاشیه)', fixed(area, 2), unit: 'متر مربع'),
      R('حجم بتن مگر', fixed(leanVol, 2), unit: 'متر مکعب'),
      R('حجم سنگ لاشه', fixed(rubbleVol, 2), unit: 'متر مکعب'),
      R('حجم ماسه/شن پرکننده خلل‌وفرج', fixed(voidsFill, 2), unit: 'متر مکعب'),
    ]),
    Sec('مصالح بتن مگر (نسبت ۱:۲:۴)', [
      R('سیمان', fixed(cementBags, 1), unit: 'کیسه (۵۰ کیلویی)'),
      R('ماسه', fixed(sand, 2), unit: 'متر مکعب'),
      R('شن', fixed(gravel, 2), unit: 'متر مکعب'),
    ]),
  ];
};

FormTool leanConcreteTool(String title) => FormTool(
    toolId: 'lean-concrete-rubble',
    title: title,
    description: '',
    defaults: const {
      'type': 'strip', 'stripTotalLength': '', 'stripWidth': '', 'padLength': '', 'padWidth': '', 'padCount': '1',
      'matLength': '', 'matWidth': '', 'margin': '10', 'leanThickness': '10', 'rubbleThickness': '25', 'voidsPercent': '35',
    },
    builder: _lean);
