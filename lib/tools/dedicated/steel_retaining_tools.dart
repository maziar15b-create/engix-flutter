import 'dart:math';

import 'tool_kit.dart';

// ───────────────────────── طراحی فولاد ─────────────────────────

FormBuilder _steel = (Vals v) {
  final mode = v.s('mode');
  final e = v.n('E'), fy = v.n('fy');
  final zx = v.n('Zx'), ry = v.n('ry'), d = v.n('d'), tw = v.n('tw'), ix = v.n('Ix'), lb = v.n('Lb');
  final muBeam = v.n('MuBeam'), vuBeam = v.n('VuBeam');
  final phiF = v.n('phiFlexure'), phiS = v.n('phiShearSteel'), cv = v.n('cvFactor');
  final spanBeam = v.n('spanBeam'), service = v.n('serviceLoad'), defLimit = v.n('deflectionLimit');
  final ag = v.n('Ag'), rx = v.n('rxCol'), ryC = v.n('ryCol'), kCol = v.n('KCol'), lCol = v.n('LCol');
  final puCol = v.n('PuCol'), phiComp = v.n('phiCompSteel');

  final mp = fy * zx;
  final lp = ry > 0 ? 1.76 * ry * sqrt(e / fy) : 0.0;
  final fullyBraced = lb <= lp;
  final mnBeam = fullyBraced ? mp : mp * 0.85;
  final phiMn = phiF * mnBeam;
  final muKgCm = muBeam * 100000;
  final flexOk = muKgCm <= phiMn;
  final vn = 0.6 * fy * d * tw * cv;
  final phiVn = phiS * vn;
  final vuKg = vuBeam * 1000;
  final shearOk = vuKg <= phiVn;
  final deflection = (ix > 0 && e > 0) ? (5 * (service / 100) * pow(spanBeam, 4)) / (384 * e * ix) : 0.0;
  final allowDef = defLimit > 0 ? spanBeam / defLimit : 0.0;
  final defOk = deflection <= allowDef;

  final governingR = min(rx, ryC);
  final slender = governingR > 0 ? (kCol * lCol) / governingR : 0.0;
  final fe = slender > 0 ? (pi * pi * e) / (slender * slender) : 0.0;
  final fyOverFe = fe > 0 ? fy / fe : double.infinity;
  final fcr = fyOverFe <= 2.25 ? pow(0.658, fyOverFe) * fy : 0.877 * fe;
  final pn = fcr * ag;
  final phiPn = phiComp * pn;
  final puKg = puCol * 1000;
  final colOk = puKg <= phiPn;

  return [
    const Note(
        '⚠️ کمک‌محاسبه بر پایه‌ی روش LRFD (مبحث ۱۰ / معادل AISC 360). مشخصات مقطع (Zx، ry، rx، Ag و...) را از کاتالوگ رسمی پروفیل (مثلاً جدول پروفیل‌های ایرانی یا اروپایی) بردارید — این ابزار پروفیل را نمی‌شناسد. برای Lb بزرگ‌تر از Lp، کنترل دقیق کمانش جانبی-پیچشی (LTB) نیازمند مشخصات بیشتری (rts، J، Cw) است که اینجا لحاظ نشده — نتیجه‌ی این حالت محافظه‌کارانه و تقریبی است.'),
    Sec('مصالح', [
      const S('grade', 'کیفیت فولاد (انتخاب سریع Fy)', [
        ['st37', 'St37 (معادل A36) — 2400'],
        ['st52', 'St52 — 3600'],
        ['custom', 'دستی'],
      ]),
      const F('fy', 'تنش تسلیم (Fy)', unit: 'kg/cm²'),
      const F('E', 'مدول الاستیسیته (E)', unit: 'kg/cm²'),
    ]),
    Sec('نوع عضو', [
      const S('mode', 'نوع عضو', [['beam', 'تیر فولادی'], ['column', 'ستون فولادی']]),
    ]),
    if (mode == 'beam') ...[
      Sec('مشخصات مقطع (از کاتالوگ پروفیل)', [
        const F('Zx', 'مدول مقطع پلاستیک (Zx)', unit: 'cm³'),
        const F('ry', 'شعاع ژیراسیون ضعیف (ry)', unit: 'cm'),
        const F('d', 'ارتفاع مقطع (d)', unit: 'cm'),
        const F('tw', 'ضخامت جان (tw)', unit: 'cm'),
        const F('Ix', 'ممان اینرسی قوی (Ix)', unit: 'cm⁴'),
        const F('Lb', 'طول مهارنشده جانبی (Lb)', unit: 'cm'),
      ]),
      Sec('بارهای طراحی', [
        const F('MuBeam', 'لنگر نهایی (Mu)', unit: 'ton.m'),
        const F('VuBeam', 'برش نهایی (Vu)', unit: 'ton'),
      ]),
      Sec('طراحی خمشی', [
        const F('phiFlexure', 'φ خمشی'),
        R('ظرفیت خمشی پلاستیک (Mp)', fixed(mp / 100000, 2), unit: 'ton.m'),
        R('طول مهار برای ظرفیت کامل (Lp)', fixed(lp, 0), unit: 'cm'),
        R('وضعیت مهاربندی', fullyBraced ? 'مهار کافی (Lb ≤ Lp)' : 'مهار ناکافی — کاهش ظرفیت', warn: !fullyBraced),
        R('φMn', fixed(phiMn / 100000, 2), unit: 'ton.m'),
        R('Mu', plain(muBeam), unit: 'ton.m', warn: !flexOk, hl: flexOk),
      ]),
      Sec('طراحی برشی', [
        const F('phiShearSteel', 'φ برشی'),
        const F('cvFactor', 'ضریب Cv'),
        R('φVn', fixed(phiVn / 1000, 1), unit: 'ton'),
        R('Vu', plain(vuBeam), unit: 'ton', warn: !shearOk, hl: shearOk),
      ]),
      Sec('کنترل خیز سرویس', [
        const F('spanBeam', 'دهانه', unit: 'cm'),
        const F('serviceLoad', 'بار سرویس خطی', unit: 'kg/m'),
        const F('deflectionLimit', 'حد مجاز L/x'),
        R('خیز محاسبه‌شده', fixed(deflection, 2), unit: 'cm', warn: !defOk),
        R('خیز مجاز', fixed(allowDef, 2), unit: 'cm', hl: defOk),
      ]),
    ],
    if (mode == 'column') ...[
      Sec('مشخصات مقطع', [
        const F('Ag', 'سطح مقطع (Ag)', unit: 'cm²'),
        const F('rxCol', 'شعاع ژیراسیون قوی (rx)', unit: 'cm'),
        const F('ryCol', 'شعاع ژیراسیون ضعیف (ry)', unit: 'cm'),
      ]),
      Sec('طول و بار', [
        const F('KCol', 'ضریب طول موثر (K)'),
        const F('LCol', 'طول آزاد ستون (L)', unit: 'cm'),
        const F('PuCol', 'بار محوری نهایی (Pu)', unit: 'ton'),
        const F('phiCompSteel', 'φ فشاری'),
      ]),
      Sec('کنترل کمانش و ظرفیت', [
        R('شعاع ژیراسیون حاکم', fixed(governingR, 2), unit: 'cm'),
        R('نسبت لاغری (KL/r)', fixed(slender, 1), warn: slender > 200),
        if (slender > 200) const Note('⚠ لاغری بیشتر از حد رایج توصیه‌شده (۲۰۰) است.'),
        R('تنش کمانش الاستیک (Fe)', fixed(fe, 0), unit: 'kg/cm²'),
        R('تنش بحرانی (Fcr)', fixed(fcr.toDouble(), 0), unit: 'kg/cm²'),
        R('ظرفیت اسمی (Pn)', fixed(pn / 1000, 1), unit: 'ton'),
        R('φPn', fixed(phiPn / 1000, 1), unit: 'ton'),
        R('Pu', plain(puCol), unit: 'ton', warn: !colOk, hl: colOk),
      ]),
    ],
  ];
};

FormTool steelTool(String title) => FormTool(
    toolId: 'steel-design',
    title: title,
    description: '',
    defaults: const {
      'grade': 'st37', 'mode': 'beam', 'E': '2100000', 'fy': '2400', 'Zx': '650', 'ry': '3.5', 'd': '30', 'tw': '0.75',
      'Ix': '15000', 'Lb': '400', 'MuBeam': '15', 'VuBeam': '12', 'phiFlexure': '0.9', 'phiShearSteel': '0.9',
      'cvFactor': '1', 'spanBeam': '500', 'serviceLoad': '2000', 'deflectionLimit': '360', 'Ag': '60', 'rxCol': '12',
      'ryCol': '4', 'KCol': '1', 'LCol': '320', 'PuCol': '60', 'phiCompSteel': '0.9',
    },
    onSelect: (key, value, setField) {
      if (key == 'grade') {
        if (value == 'st37') setField('fy', '2400');
        if (value == 'st52') setField('fy', '3600');
      }
    },
    builder: _steel);

// ───────────────────────── دیوار حائل ─────────────────────────

double _rad(double deg) => (deg * pi) / 180;

FormBuilder _retaining = (Vals v) {
  final stemH = v.n('stemHeight'), baseT = v.n('baseThickness'), baseW = v.n('baseWidth');
  final toeW = v.n('toeWidth'), stemWBase = v.n('stemWidthAtBase');
  final gammaB = v.n('backfillUnitWeight'), phiDeg = v.n('phiDeg'), surcharge = v.n('surcharge');
  final baseFric = v.n('baseFrictionAngleDeg'), qa = v.n('qa');
  final considerPassive = v.s('considerPassive') == 'true';
  final embed = v.n('embedmentDepth');
  final fsOvMin = v.n('fsOverturningMin'), fsSlMin = v.n('fsSlidingMin');

  final heelW = max(0.0, baseW - toeW - stemWBase);
  final totalH = stemH + baseT;
  const concreteUnit = 2400.0;
  final phi = _rad(phiDeg);
  final ka = pow(tan(_rad(45) - phi / 2), 2).toDouble();
  final kp = pow(tan(_rad(45) + phi / 2), 2).toDouble();
  final hM = totalH / 100;
  final gammaTon = gammaB / 1000;
  final paSoil = 0.5 * ka * gammaTon * hM * hM;
  final paSur = ka * (surcharge / 1000) * hM;
  final paTotal = paSoil + paSur;
  final yStrip = hM > 0 ? (paSoil * (hM / 3) + paSur * (hM / 2)) / paTotal : 0.0;

  final stemHM = stemH / 100, baseTM = baseT / 100, baseWM = baseW / 100;
  final toeWM = toeW / 100, stemWM = stemWBase / 100, heelWM = heelW / 100;
  final wBase = baseWM * baseTM * concreteUnit / 1000;
  final wStem = stemWM * stemHM * concreteUnit / 1000;
  final wSoilHeel = heelWM * stemHM * gammaTon;
  final totalV = wBase + wStem + wSoilHeel;
  final xBase = baseWM / 2;
  final xStem = toeWM + stemWM / 2;
  final xHeelSoil = toeWM + stemWM + heelWM / 2;
  final resisting = wBase * xBase + wStem * xStem + wSoilHeel * xHeelSoil;
  final overturning = paTotal * yStrip;
  final fsOv = overturning > 0 ? resisting / overturning : double.infinity;
  final ovOk = fsOv >= fsOvMin;

  final friction = totalV * tan(_rad(baseFric));
  final passive = considerPassive ? 0.5 * kp * gammaTon * pow(embed / 100, 2) : 0.0;
  final totalSliding = friction + passive;
  final fsSl = paTotal > 0 ? totalSliding / paTotal : double.infinity;
  final slOk = fsSl >= fsSlMin;

  final xRes = totalV > 0 ? (resisting - overturning) / totalV : 0.0;
  final ecc = baseWM / 2 - xRes;
  final midThird = ecc.abs() <= baseWM / 6;
  final qMaxT = baseWM > 0 ? (totalV / baseWM) * (1 + (6 * ecc) / baseWM) : 0.0;
  final qMinT = baseWM > 0 ? (totalV / baseWM) * (1 - (6 * ecc) / baseWM) : 0.0;
  final qMax = (qMaxT * 1000) / 10000;
  final qMin = (qMinT * 1000) / 10000;
  final bearingOk = qMax <= qa && qMin >= 0;

  return [
    const Note(
        '⚠️ کمک‌محاسبه است، نه جایگزین محاسبات مهندس محاسب و گزارش مکانیک خاک. فشار جانبی با نظریه‌ی رانکین (پشت‌بند قائم و صاف) محاسبه شده — اگر پشت‌بند شیب‌دار یا اصطکاک دیوار-خاک مهم است، نتیجه تقریبی خواهد بود. طراحی سازه‌ای خود دیوار (خمش و برش ساقه/پی) در این ابزار انجام نشده — از ابزارهای «طراحی تیر بتنی» یا «طراحی دال» برای آن استفاده کنید.'),
    Sec('هندسه دیوار (بر متر طول)', [
      const F('stemHeight', 'ارتفاع ساقه (روی پی)', unit: 'cm'),
      const F('baseThickness', 'ضخامت پی', unit: 'cm'),
      const F('baseWidth', 'عرض کل پی (B)', unit: 'cm'),
      const F('toeWidth', 'عرض پنجه (Toe)', unit: 'cm'),
      const F('stemWidthAtBase', 'عرض ساقه در پایین', unit: 'cm'),
      R('عرض پاشنه (Heel) — محاسبه‌شده', fixed(heelW, 1), unit: 'cm', warn: heelW < 0),
      R('ارتفاع کل (برای فشار خاک)', fixed(totalH, 0), unit: 'cm'),
    ]),
    Sec('مشخصات خاک', [
      const F('backfillUnitWeight', 'وزن مخصوص خاک پشت دیوار (γ)', unit: 'kg/m³'),
      const F('phiDeg', 'زاویه اصطکاک داخلی (φ)', unit: 'درجه'),
      const F('surcharge', 'سرچارژ روی خاک', unit: 'kg/m²'),
      const F('baseFrictionAngleDeg', 'زاویه اصطکاک پی-خاک (δ)', unit: 'درجه'),
      const F('qa', 'ظرفیت باربری مجاز خاک زیر پی (qa)', unit: 'kg/cm²'),
      R('ضریب فشار فعال (Ka)', fixed(ka, 3)),
      R('ضریب فشار غیرفعال (Kp)', fixed(kp, 3)),
    ]),
    Sec('فشار جانبی خاک', [
      R('نیروی فشار فعال از خاک', fixed(paSoil, 2), unit: 'ton/m'),
      R('نیروی فشار فعال از سرچارژ', fixed(paSur, 2), unit: 'ton/m'),
      R('نیروی فشار فعال کل (Pa)', fixed(paTotal, 2), unit: 'ton/m', hl: true),
      R('ارتفاع نقطه اثر از پایه پی', fixed(yStrip, 2), unit: 'متر'),
    ]),
    Sec('وزن‌های مقاوم', [
      R('وزن پی', fixed(wBase, 2), unit: 'ton/m'),
      R('وزن ساقه', fixed(wStem, 2), unit: 'ton/m'),
      R('وزن خاک روی پاشنه', fixed(wSoilHeel, 2), unit: 'ton/m'),
      R('جمع کل وزن مقاوم (ΣV)', fixed(totalV, 2), unit: 'ton/m', hl: true),
    ]),
    Sec('کنترل واژگونی (Overturning)', [
      const F('fsOverturningMin', 'حداقل ضریب اطمینان مجاز'),
      R('لنگر مقاوم', fixed(resisting, 2), unit: 'ton.m/m'),
      R('لنگر واژگون‌کننده', fixed(overturning, 2), unit: 'ton.m/m'),
      R('ضریب اطمینان واژگونی (FS)', fixed(fsOv, 2), warn: !ovOk, hl: ovOk),
    ]),
    Sec('کنترل لغزش (Sliding)', [
      const S('considerPassive', 'مقاومت پسیو جلوی دیوار', [
        ['false', 'نادیده گرفته شود (محافظه‌کارانه)'],
        ['true', 'لحاظ شود'],
      ]),
      if (considerPassive) const F('embedmentDepth', 'عمق دفن جلوی دیوار', unit: 'cm'),
      const F('fsSlidingMin', 'حداقل ضریب اطمینان مجاز'),
      R('مقاومت اصطکاکی', fixed(friction, 2), unit: 'ton/m'),
      if (considerPassive) R('مقاومت پسیو', fixed(passive, 2), unit: 'ton/m'),
      R('جمع کل مقاومت لغزش', fixed(totalSliding, 2), unit: 'ton/m'),
      R('ضریب اطمینان لغزش (FS)', fixed(fsSl, 2), warn: !slOk, hl: slOk),
    ]),
    Sec('کنترل خارج از مرکزیت و فشار تکیه‌گاه', [
      R('محل برآیند از پنجه', fixed(xRes, 2), unit: 'متر'),
      R('خارج از مرکزیت (e)', fixed(ecc, 3), unit: 'متر'),
      R('حد مجاز (B/6)', fixed(baseWM / 6, 3), unit: 'متر', warn: !midThird),
      R('حداکثر فشار تکیه‌گاه (qmax)', fixed(qMax, 2), unit: 'kg/cm²', warn: qMax > qa),
      R('حداقل فشار تکیه‌گاه (qmin)', fixed(qMin, 2), unit: 'kg/cm²', warn: qMin < 0),
      R('ظرفیت مجاز خاک (qa)', plain(qa), unit: 'kg/cm²'),
      if (qMin < 0)
        const Note('⚠ فشار منفی به معنای کشش زیر پی است (غیرقابل‌قبول در تماس خاک-پی) — عرض پی را افزایش دهید.'),
    ]),
    Note(
        (ovOk && slOk && bearingOk)
            ? '✅ هر سه کنترل پایداری برآورده می‌شود'
            : '⚠️ حداقل یکی از کنترل‌های پایداری برآورده نمی‌شود',
        warn: !(ovOk && slOk && bearingOk)),
  ];
};

FormTool retainingWallTool(String title) => FormTool(
    toolId: 'retaining-wall-design',
    title: title,
    description: '',
    defaults: const {
      'stemHeight': '300', 'baseThickness': '40', 'baseWidth': '220', 'toeWidth': '50', 'stemWidthAtBase': '35',
      'backfillUnitWeight': '1800', 'phiDeg': '30', 'surcharge': '0', 'baseFrictionAngleDeg': '20', 'qa': '2',
      'considerPassive': 'false', 'embedmentDepth': '0', 'fsOverturningMin': '2', 'fsSlidingMin': '1.5',
    },
    builder: _retaining);
