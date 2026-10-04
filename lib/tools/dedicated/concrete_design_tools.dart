import 'dart:math';

import 'tool_kit.dart';

const _beamBars = <int, double>{
  8: 0.503, 10: 0.785, 12: 1.131, 14: 1.539, 16: 2.011, 18: 2.545, 20: 3.142, 22: 3.801, 25: 4.909,
};
const _beamMainKeys = [10, 12, 14, 16, 18, 20, 22, 25];

FormBuilder _beam = (Vals v) {
  final b = v.n('b'), h = v.n('h'), cover = v.n('cover'), fc = v.n('fc'), fy = v.n('fy');
  final phiF = v.n('phiFlexure'), phiS = v.n('phiShear');
  final mu = v.n('Mu'), vu = v.n('Vu');
  final c1 = v.n('rhoMinCoef1'), c2 = v.n('rhoMinCoef2'), rhoMaxFactor = v.n('rhoMaxFactor'), vcCoef = v.n('vcCoef');
  final barD = int.tryParse(v.s('barDiameter')) ?? 20;
  final stD = int.tryParse(v.s('stirrupDiameter')) ?? 8;
  final legs = int.tryParse(v.s('stirrupLegs')) ?? 2;
  final span = v.n('span');
  final supportType = v.s('supportType');

  final d = h - cover;
  final muKgCm = mu * 100000;
  final vuKg = vu * 1000;
  final rn = (phiF > 0 && b > 0 && d > 0) ? muKgCm / (phiF * b * d * d) : 0.0;
  final underSqrt = 1 - (2 * rn) / (0.85 * fc);
  var rhoReq = 0.0;
  var flexErr = '';
  if (underSqrt < 0) {
    flexErr = 'مقطع کفایت نمی‌کند — ابعاد تیر (b یا h) را افزایش دهید یا مقاومت بتن را بالا ببرید.';
  } else {
    rhoReq = (0.85 * fc / fy) * (1 - sqrt(underSqrt));
  }
  final rhoMin = max(c1 / fy, (c2 * sqrt(fc)) / fy);
  final beta1 = fc <= 280 ? 0.85 : max(0.65, 0.85 - 0.05 * ((fc - 280) / 70));
  final rhoBal = (0.85 * beta1 * fc / fy) * (6300 / (6300 + fy));
  final rhoMax = rhoMaxFactor * rhoBal;
  final rhoUsed = max(rhoReq, rhoMin);
  final overMax = rhoUsed > rhoMax;
  final asReq = rhoUsed * b * d;
  final barArea = _beamBars[barD] ?? 0.0;
  final barsNeeded = barArea > 0 ? (asReq / barArea).ceil() : 0;
  final asProv = barsNeeded * barArea;

  final vc = vcCoef * sqrt(fc) * b * d;
  final phiVc = phiS * vc;
  final vsReq = phiS > 0 ? (vuKg / phiS) - vc : 0.0;
  var shearNote = '';
  if (vuKg <= 0.5 * phiVc) {
    shearNote = 'برش کم است — از حداقل خاموط سازه‌ای (طبق آیین‌نامه) استفاده کنید.';
  } else if (vsReq < 0) {
    shearNote = 'بتن به‌تنهایی کفایت می‌کند؛ خاموط را طبق حداکثر فاصله‌ی مجاز (d/2) قرار دهید.';
  }
  final stArea = (_beamBars[stD] ?? 0.0) * legs;
  final double? spReq = vsReq > 0 ? (fy * stArea * d) / vsReq : null;
  final spMax = d / 2;
  final spFinal = (spReq != null && spReq != 0) ? min(spReq, spMax) : spMax;

  const ratios = {'simple': 16.0, 'oneEndCont': 18.5, 'bothEndCont': 21.0, 'cantilever': 8.0};
  final minH = span / (ratios[supportType] ?? 16.0);

  return [
    const Note(
        '⚠️ این ابزار صرفاً کمک‌محاسبه است، نه جایگزین محاسبات و مهر مهندس محاسب دارای پروانه. روش خمشی (بلوک تنش معادل) اصول مکانیک سازه است، ولی ضرایب آیین‌نامه‌ای (ρmin، Vc، φ) پیش‌فرض و قابل‌ویرایش‌اند — پیش از استفاده‌ی نهایی حتماً با آخرین ویرایش رسمی مبحث ۹ تطبیق دهید.'),
    Sec('۱) هندسه و مصالح', [
      const F('b', 'عرض تیر b', unit: 'cm'),
      const F('h', 'ارتفاع کل h', unit: 'cm'),
      const F('cover', 'پوشش تا مرکز میلگرد', unit: 'cm'),
      const F('fc', "مقاومت بتن fc'", unit: 'kg/cm²'),
      const F('fy', 'تنش تسلیم فولاد fy', unit: 'kg/cm²'),
      const F('phiFlexure', 'ضریب φ خمشی'),
      R('عمق موثر d', fixed(d, 1), unit: 'cm'),
    ]),
    Sec('۲) بارهای طراحی', [
      const F('Mu', 'لنگر خمشی نهایی Mu', unit: 'ton.m'),
      const F('Vu', 'نیروی برشی نهایی Vu', unit: 'ton'),
      const Note('این مقادیر را از ترکیب بار (ابزار بارگذاری) یا تحلیل سازه به‌دست‌آمده وارد کنید.', warn: false),
    ]),
    Sec('۳) طراحی خمشی', [
      const F('rhoMinCoef1', 'ضریب ρmin (اول)'),
      const F('rhoMinCoef2', 'ضریب ρmin (دوم)'),
      const F('rhoMaxFactor', 'ضریب ρmax'),
      S('barDiameter', 'قطر میلگرد', [for (final k in _beamMainKeys) ['$k', 'Ø$k']]),
      if (flexErr.isNotEmpty)
        Note(flexErr)
      else ...[
        R('ρ مورد نیاز', fixed(rhoReq, 5)),
        R('ρmin', fixed(rhoMin, 5)),
        R('ρmax', fixed(rhoMax, 5), warn: overMax),
        if (overMax)
          const Note('⚠ ρ مورد نیاز از ρmax بیشتر است — مقطع باید بزرگ‌تر شود یا از میلگرد فشاری (تیر دوبل) استفاده شود.'),
        R('سطح میلگرد کششی لازم (As)', fixed(asReq, 2), unit: 'cm²', hl: true),
        R('تعداد میلگرد Ø$barD لازم', '$barsNeeded', unit: 'عدد', hl: true),
        R('سطح میلگرد تامین‌شده', fixed(asProv, 2), unit: 'cm²'),
      ],
    ]),
    Sec('۴) طراحی برشی (خاموت)', [
      const F('vcCoef', 'ضریب Vc'),
      const F('phiShear', 'ضریب φ برشی'),
      const S('stirrupDiameter', 'قطر خاموط', [['8', 'Ø8'], ['10', 'Ø10'], ['12', 'Ø12']]),
      const S('stirrupLegs', 'تعداد شاخه (برش)', [['2', '۲ شاخه'], ['4', '۴ شاخه']]),
      R('مقاومت برشی بتن (Vc)', fixed(vc, 0), unit: 'kg'),
      R('φVc', fixed(phiVc, 0), unit: 'kg'),
      if (shearNote.isNotEmpty) Note(shearNote, warn: false),
      if (spReq != null && spReq > 0) R('فاصله خاموط مورد نیاز', fixed(spReq, 1), unit: 'cm'),
      R('حداکثر فاصله مجاز (d/2)', fixed(spMax, 1), unit: 'cm'),
      R('فاصله خاموط پیشنهادی', fixed(spFinal, 0), unit: 'cm', hl: true),
    ]),
    Sec('۵) کنترل خیز (راهنما)', [
      const F('span', 'دهانه تیر (L)', unit: 'cm'),
      const S('supportType', 'نوع تکیه‌گاه', [
        ['simple', 'ساده (دو سر مفصل) — L/16'],
        ['oneEndCont', 'یک سر پیوسته — L/18.5'],
        ['bothEndCont', 'دو سر پیوسته — L/21'],
        ['cantilever', 'طره — L/8'],
      ]),
      R('حداقل ارتفاع توصیه‌شده (بدون محاسبه خیز دقیق)', fixed(minH, 1), unit: 'cm'),
      R('ارتفاع انتخابی شما (h)', plain(h), unit: 'cm', warn: h < minH),
      if (h < minH)
        const Note('⚠ ارتفاع تیر از حداقل توصیه‌شده کمتر است — احتمالاً نیاز به محاسبه‌ی دقیق خیز (تحت بار سرویس) دارید.'),
    ]),
  ];
};

FormTool beamTool(String title) => FormTool(
    toolId: 'concrete-beam-design',
    title: title,
    description: '',
    defaults: const {
      'b': '30', 'h': '50', 'cover': '4', 'fc': '250', 'fy': '4000', 'phiFlexure': '0.9', 'phiShear': '0.75',
      'Mu': '15', 'Vu': '10', 'rhoMinCoef1': '14', 'rhoMinCoef2': '0.8', 'rhoMaxFactor': '0.75', 'vcCoef': '0.53',
      'barDiameter': '20', 'stirrupDiameter': '8', 'stirrupLegs': '2', 'span': '500', 'supportType': 'simple',
    },
    builder: _beam);

// ───────────────────────── ستون ─────────────────────────

const _colBars = <int, double>{
  12: 1.131, 14: 1.539, 16: 2.011, 18: 2.545, 20: 3.142, 22: 3.801, 25: 4.909, 28: 6.158,
};

FormBuilder _column = (Vals v) {
  final b = v.n('b'), h = v.n('h'), cover = v.n('cover'), fc = v.n('fc'), fy = v.n('fy');
  final phiC = v.n('phiCompression'), maxFactor = v.n('maxFactor');
  final barD = int.tryParse(v.s('barDiameter')) ?? 20;
  final barCount = v.n('barCount').truncate();
  final pu = v.n('Pu'), mu = v.n('Mu');
  final lu = v.n('Lu'), k = v.n('kFactor');
  final braced = v.s('braced') != 'unbraced';
  final m1m2 = v.n('M1M2');

  final ag = b * h;
  final barArea = _colBars[barD] ?? 0.0;
  final ast = barCount * barArea;
  final rhoG = ag > 0 ? ast / ag : 0.0;
  final po = 0.85 * fc * (ag - ast) + fy * ast;
  final phiPnMax = maxFactor * phiC * po;
  final puKg = pu * 1000;
  final axialOk = puKg <= phiPnMax;
  final r = 0.3 * h;
  final klr = r > 0 ? (k * lu) / r : 0.0;
  final limit = braced ? min(40.0, 34 - 12 * m1m2) : 22.0;
  final slender = klr > limit;
  final d = h - cover;
  final dPrime = cover;
  final asOneFace = ast / 2;
  final mnApprox = asOneFace * fy * (d - dPrime);
  final phiMn0 = phiC * mnApprox;
  final muKgCm = mu * 100000;
  final ratio = (phiPnMax > 0 ? puKg / phiPnMax : 0.0) + (phiMn0 > 0 ? muKgCm / phiMn0 : 0.0);
  final interOk = ratio <= 1.0;
  final rhoOk = rhoG >= 0.01 && rhoG <= 0.08;

  return [
    const Note(
        '⚠️ توجه ویژه: طراحی دقیق ستون تحت بار محوری+خمشی نیازمند «نمودار برهم‌کنش P-M» است که با محاسبات تکراری (iterative) به‌دست می‌آید. بخش «کنترل ترکیبی» این ابزار یک تقریب خطی ساده‌شده است، نه معادل نمودار دقیق — می‌تواند در برخی نواحی محافظه‌کارانه یا در برخی نواحی غیرمحافظه‌کارانه باشد. ظرفیت محوری خالص (بدون خمش) دقیق و مطابق فرمول استاندارد است. برای طراحی نهایی، حتماً با نرم‌افزار تخصصی سازه یا محاسبات دستی کامل توسط مهندس محاسب دارای پروانه تایید کنید.'),
    Sec('۱) هندسه، مصالح و میلگرد', [
      const F('b', 'عرض ستون b', unit: 'cm'),
      const F('h', 'ارتفاع مقطع h', unit: 'cm'),
      const F('cover', 'پوشش تا مرکز میلگرد', unit: 'cm'),
      const F('fc', "مقاومت بتن fc'", unit: 'kg/cm²'),
      const F('fy', 'تنش تسلیم فولاد fy', unit: 'kg/cm²'),
      const S('tieType', 'نوع خاموط', [['tied', 'خاموت بسته (Tied)'], ['spiral', 'مارپیچ (Spiral)']]),
      S('barDiameter', 'قطر میلگرد طولی', [for (final k in _colBars.keys) ['$k', 'Ø$k']]),
      const F('barCount', 'تعداد میلگرد طولی', unit: 'عدد'),
      R('سطح مقطع ستون (Ag)', fixed(ag, 0), unit: 'cm²'),
      R('سطح میلگرد طولی (Ast)', fixed(ast, 2), unit: 'cm²'),
      R('درصد میلگرد (ρg)', fixed(rhoG * 100, 2), unit: '%', warn: !rhoOk),
      if (!rhoOk)
        const Note('⚠ درصد میلگرد باید بین ۱٪ تا ۸٪ باشد (طبق مبحث ۹). عملاً بین ۱٪ تا ۴٪ رایج‌تر و اقتصادی‌تر است.'),
    ]),
    Sec('۲) بارهای طراحی', [
      const F('Pu', 'نیروی محوری نهایی Pu', unit: 'ton'),
      const F('Mu', 'لنگر خمشی نهایی Mu', unit: 'ton.m'),
    ]),
    Sec('۳) ظرفیت محوری خالص', [
      const F('phiCompression', 'φ فشاری'),
      const F('maxFactor', 'ضریب حداکثر ظرفیت'),
      R('ظرفیت محوری خالص (Po)', fixed(po / 1000, 1), unit: 'ton'),
      R('ظرفیت طراحی حداکثر (φPn,max)', fixed(phiPnMax / 1000, 1), unit: 'ton', hl: true),
      R('نیروی محوری اعمالی (Pu)', plain(pu), unit: 'ton', warn: !axialOk),
      if (!axialOk) const Note('⚠ Pu بیشتر از ظرفیت محوری مجاز است — مقطع یا درصد میلگرد را افزایش دهید.'),
    ]),
    Sec('۴) کنترل لاغری', [
      const F('Lu', 'طول آزاد ستون Lu', unit: 'cm'),
      const F('kFactor', 'ضریب طول موثر k'),
      const S('braced', 'نوع ستون', [['braced', 'مهاربندی‌شده (Braced)'], ['unbraced', 'بدون مهاربندی (Unbraced)']]),
      if (braced) const F('M1M2', 'نسبت M1/M2'),
      R('شعاع ژیراسیون تقریبی (r)', fixed(r, 1), unit: 'cm'),
      R('نسبت لاغری (kLu/r)', fixed(klr, 1)),
      R('حد مجاز لاغری', fixed(limit, 1)),
      R('وضعیت', slender ? 'ستون لاغر (نیاز به بزرگ‌نمایی لنگر)' : 'ستون کوتاه (لاغری قابل‌صرف‌نظر)', warn: slender),
      if (slender)
        const Note(
            '⚠ این ستون لاغر محسوب می‌شود — Mu باید با روش بزرگ‌نمایی لنگر (Moment Magnification) اصلاح شود؛ این ابزار آن اصلاح را انجام نمی‌دهد.'),
    ]),
    Sec('۵) کنترل ترکیبی تقریبی (P-M)', [
      R('ظرفیت خمشی تقریبی (φMn0)', fixed(phiMn0 / 100000, 2), unit: 'ton.m'),
      R('نسبت Pu/φPn,max', fixed(phiPnMax > 0 ? puKg / phiPnMax : 0.0, 2)),
      R('نسبت Mu/φMn0', fixed(phiMn0 > 0 ? muKgCm / phiMn0 : 0.0, 2)),
      R('مجموع نسبت‌ها (باید ≤ ۱ باشد)', fixed(ratio, 2), warn: !interOk, hl: interOk),
      if (!interOk)
        const Note(
            '⚠ طبق کنترل تقریبی، مقطع کفایت نمی‌کند — مقطع را بزرگ‌تر کنید یا میلگرد را افزایش دهید و دوباره با نمودار دقیق P-M بررسی کنید.'),
    ]),
  ];
};

FormTool columnTool(String title) => FormTool(
    toolId: 'concrete-column-design',
    title: title,
    description: '',
    defaults: const {
      'b': '40', 'h': '40', 'cover': '4', 'fc': '250', 'fy': '4000', 'tieType': 'tied',
      'phiCompression': '0.65', 'maxFactor': '0.8', 'barDiameter': '20', 'barCount': '8',
      'Pu': '80', 'Mu': '6', 'Lu': '320', 'kFactor': '1', 'braced': 'braced', 'M1M2': '0.6',
    },
    onSelect: (key, value, setField) {
      if (key == 'tieType') {
        if (value == 'spiral') {
          setField('phiCompression', '0.7');
          setField('maxFactor', '0.85');
        } else {
          setField('phiCompression', '0.65');
          setField('maxFactor', '0.8');
        }
      }
    },
    builder: _column);
