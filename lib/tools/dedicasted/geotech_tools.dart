import 'dart:math';

import 'tool_kit.dart';

double _toRad(double deg) => (deg * pi) / 180;

({double nc, double nq, double ng}) _bearingFactors(double phiDeg) {
  final phi = _toRad(phiDeg);
  if (phiDeg <= 0.001) return (nc: 5.7, nq: 1.0, ng: 0.0);
  final double nq = (exp(pi * tan(phi)) * pow(tan(_toRad(45) + phi / 2), 2)).toDouble();
  final double nc = (nq - 1) / tan(phi);
  final double ng = (nq - 1) * tan(1.4 * phi);
  return (nc: nc, nq: nq, ng: ng);
}

FormBuilder _soil = (Vals v) {
  final shape = v.s('shape');
  final b = v.n('B'), l = v.n('L'), df = v.n('Df');
  final unitWeight = v.n('unitWeight'), cohesion = v.n('cohesion'), phiDeg = v.n('phiDeg'), fs = v.n('FS');
  final f = _bearingFactors(phiDeg);
  final gamma = unitWeight / 1000000;
  final q = gamma * df;
  final ratio = b / (l == 0 ? b : l);
  late double sfC, sfG;
  switch (shape) {
    case 'square':
      sfC = 1.3;
      sfG = 0.4;
      break;
    case 'circular':
      sfC = 1.3;
      sfG = 0.3;
      break;
    case 'rectangular':
      sfC = 1 + 0.3 * ratio;
      sfG = 0.5 - 0.1 * ratio;
      break;
    default:
      sfC = 1.0;
      sfG = 0.5;
  }
  final qu = cohesion * f.nc * sfC + q * f.nq + sfG * gamma * b * f.ng;
  final qaGross = fs > 0 ? qu / fs : 0.0;
  final qaNet = qaGross - q;
  return [
    const Note(
        '⚠️ این ابزار از فرمول کلاسیک ترزاقی (۱۹۴۳) برای برآورد اولیه استفاده می‌کند و اثر سطح آب زیرزمینی، لایه‌بندی خاک، و بارگذاری خارج از مرکز را در نظر نمی‌گیرد. برای هر پروژه‌ی واقعی، ظرفیت باربری مجاز نهایی باید از گزارش رسمی مکانیک خاک (ژئوتکنیک) همان زمین گرفته شود — نه از این محاسبه‌ی تقریبی.'),
    Sec('هندسه پی و عمق', [
      const S('shape', 'شکل پی', [
        ['strip', 'نواری'],
        ['square', 'مربعی'],
        ['rectangular', 'مستطیلی'],
        ['circular', 'دایره‌ای'],
      ]),
      const F('B', 'عرض/قطر پی (B)', unit: 'cm'),
      if (shape == 'rectangular') const F('L', 'طول پی (L)', unit: 'cm'),
      const F('Df', 'عمق پی از تراز زمین (Df)', unit: 'cm'),
    ]),
    Sec('مشخصات ژئوتکنیکی خاک', [
      const F('unitWeight', 'وزن مخصوص خاک (γ)', unit: 'kg/m³'),
      const F('cohesion', 'چسبندگی (c)', unit: 'kg/cm²'),
      const F('phiDeg', 'زاویه اصطکاک داخلی (φ)', unit: 'درجه'),
      const F('FS', 'ضریب اطمینان (FS)'),
      R('Nc', fixed(f.nc, 2)),
      R('Nq', fixed(f.nq, 2)),
      R('Nγ', fixed(f.ng, 2)),
    ]),
    Sec('نتایج', [
      R('سربار موثر در تراز پی (q)', fixed(q, 3), unit: 'kg/cm²'),
      R('ظرفیت باربری نهایی (qu)', fixed(qu, 2), unit: 'kg/cm²'),
      R('ظرفیت باربری مجاز ناخالص (qa)', fixed(qaGross, 2), unit: 'kg/cm²', hl: true),
      R('ظرفیت باربری مجاز خالص (qa,net)', fixed(qaNet, 2), unit: 'kg/cm²', hl: true),
      const Note('مقدار «ظرفیت مجاز خالص» را می‌توانید در ابزار «طراحی فونداسیون» به‌عنوان qa وارد کنید.', warn: false),
    ]),
  ];
};

FormTool soilBearingTool(String title) => FormTool(
    toolId: 'soil-bearing-capacity',
    title: title,
    description: '',
    defaults: const {
      'shape': 'strip', 'B': '200', 'L': '300', 'Df': '150',
      'unitWeight': '1800', 'cohesion': '0', 'phiDeg': '30', 'FS': '3',
    },
    builder: _soil);

double _log10(double x) => log(x) / ln10;

FormBuilder _settlement = (Vals v) {
  final mode = v.s('mode');
  final q = v.n('q'), b = v.n('B'), es = v.n('Es'), poisson = v.n('poisson'), inf = v.n('influenceFactor');
  final thick = v.n('layerThickness'), e0 = v.n('voidRatio'), cc = v.n('Cc');
  final p0 = v.n('initialStress'), dp = v.n('stressIncrease');
  final oc = v.s('isOC') == 'true';
  final cr = v.n('Cr'), pc = v.n('preconsolidationStress');
  final allowable = v.n('allowableSettlement');

  final immediate = es > 0 ? q * b * (1 - poisson * poisson) * inf / es : 0.0;
  final finalStress = p0 + dp;
  var consolidation = 0.0;
  if (e0 > -1 && p0 > 0 && finalStress > 0) {
    if (!oc) {
      consolidation = (cc * thick) / (1 + e0) * _log10(finalStress / p0);
    } else if (finalStress <= pc) {
      consolidation = (cr * thick) / (1 + e0) * _log10(finalStress / p0);
    } else {
      final sRe = (cr * thick) / (1 + e0) * _log10(pc / p0);
      final sVir = (cc * thick) / (1 + e0) * _log10(finalStress / pc);
      consolidation = sRe + sVir;
    }
  }
  final total = mode == 'immediate' ? immediate : consolidation;
  final ok = total <= allowable;

  return [
    const Note(
        '⚠️ کمک‌محاسبه است، نه جایگزین گزارش رسمی مکانیک خاک. پارامترهای خاک (Es، Cc، Cr، e0، pc) باید از آزمایش‌های ژئوتکنیکی واقعی همان زمین (تحکیم، سه‌محوری و...) گرفته شود، نه از حدس یا مقدار پیش‌فرض. نشست ثانویه (Secondary/Creep) و نشست ناشی از لایه‌های متعدد در این محاسبه لحاظ نشده است.'),
    Sec('نوع نشست', [
      const S('mode', 'نوع نشست', [
        ['immediate', 'نشست آنی (الاستیک)'],
        ['consolidation', 'نشست تحکیمی (رس)'],
      ]),
    ]),
    if (mode == 'immediate') ...[
      Sec('پارامترهای نشست آنی', [
        const F('q', 'فشار خالص اعمالی (q)', unit: 'kg/cm²'),
        const F('B', 'عرض/قطر پی (B)', unit: 'cm'),
        const F('Es', 'مدول الاستیسیته خاک (Es)', unit: 'kg/cm²'),
        const F('poisson', 'ضریب پواسون (μ)'),
        const F('influenceFactor', 'ضریب تاثیر (If)'),
      ]),
      Sec('نتیجه', [R('نشست آنی تخمینی', fixed(immediate, 2), unit: 'cm', hl: true)]),
    ],
    if (mode == 'consolidation') ...[
      Sec('مشخصات لایه رسی', [
        const F('layerThickness', 'ضخامت لایه', unit: 'cm'),
        const F('voidRatio', 'نسبت تخلخل اولیه (e0)'),
        const F('initialStress', 'تنش موثر اولیه (p0)', unit: 'kg/cm²'),
        const F('stressIncrease', 'افزایش تنش (Δp)', unit: 'kg/cm²'),
        const S('isOC', 'وضعیت تحکیم', [
          ['false', 'عادی تحکیم‌یافته (NC)'],
          ['true', 'پیش‌تحکیم‌یافته (OC)'],
        ]),
        const F('Cc', 'ضریب تراکم (Cc)'),
        if (oc) const F('Cr', 'ضریب بازگشت (Cr)'),
        if (oc) const F('preconsolidationStress', 'فشار پیش‌تحکیم (pc)', unit: 'kg/cm²'),
      ]),
      Sec('نتیجه', [
        R('تنش نهایی (p0+Δp)', fixed(finalStress, 2), unit: 'kg/cm²'),
        R('نشست تحکیمی تخمینی', fixed(consolidation, 2), unit: 'cm', hl: true),
      ]),
    ],
    Sec('کنترل نشست مجاز', [
      const F('allowableSettlement', 'حد مجاز نشست کل', unit: 'cm'),
      R('نشست تخمینی', fixed(total, 2), unit: 'cm', warn: !ok, hl: ok),
      if (!ok) const Note('⚠ از حد مجاز بیشتر است — ابعاد پی را بزرگ‌تر کنید یا در بهسازی خاک تجدیدنظر کنید.'),
      const Note(
          'نکته: علاوه‌بر نشست کل، «نشست نسبی بین پی‌های مجاور» هم باید کنترل شود (معمولاً حد مجاز تقریباً نصف نشست کل).',
          warn: false),
    ]),
  ];
};

FormTool settlementTool(String title) => FormTool(
    toolId: 'foundation-settlement',
    title: title,
    description: '',
    defaults: const {
      'mode': 'immediate', 'q': '1.5', 'B': '200', 'Es': '200', 'poisson': '0.3', 'influenceFactor': '0.85',
      'layerThickness': '300', 'voidRatio': '0.8', 'Cc': '0.3', 'initialStress': '1.2', 'stressIncrease': '0.5',
      'isOC': 'false', 'Cr': '0.05', 'preconsolidationStress': '1.5', 'allowableSettlement': '2.5',
    },
    builder: _settlement);

