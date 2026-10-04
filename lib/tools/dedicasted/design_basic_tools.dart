import 'dart:math';

import 'tool_kit.dart';

// ───────────────────────── دیوار برشی ─────────────────────────

FormBuilder _shearWall = (Vals v) {
  final lw = v.n('lw'), tw = v.n('tw'), hw = v.n('hw'), fc = v.n('fc'), fy = v.n('fy');
  final Vu = v.n('Vu'), Mu = v.n('Mu'), Pu = v.n('Pu');
  final phiShear = v.n('phiShear'), vcCoef = v.n('vcCoef');
  final rhoH = v.n('rhoH'), rhoV = v.n('rhoV');

  final d = 0.8 * lw;
  final vuKg = Vu * 1000;
  final vc = vcCoef * sqrt(fc) * tw * d;
  final phiVc = phiShear * vc;
  final vsReq = phiShear > 0 ? (vuKg / phiShear) - vc : 0.0;
  final ashReq = (vsReq > 0 && d > 0) ? (vsReq * 100) / (fy * d) : 0.0;
  final ashMin = rhoH * tw * 100;
  final ashFinal = max(ashReq, ashMin);
  final asvMin = rhoV * tw * 100;
  final ag = lw * tw;
  final inertia = (tw * pow(lw, 3)) / 12;
  final c = lw / 2;
  final puKg = Pu * 1000;
  final muKgCm = Mu * 100000;
  final stressAxial = ag > 0 ? puKg / ag : 0.0;
  final stressBending = inertia > 0 ? (muKgCm * c) / inertia : 0.0;
  final maxEdge = stressAxial + stressBending;
  final allowable = 0.2 * fc;
  final needsBE = maxEdge > allowable;
  final hwlw = lw > 0 ? hw / lw : 0.0;
  final slender = hwlw > 5;

  return [
    const Note(
        '⚠️ کمک‌محاسبه ساده‌شده. الزامات «المان مرزی» (Boundary Element) طبق ACI 318 فصل ۱۸ بسیار دقیق‌تر از این کنترل تقریبی است — اگر این ابزار نیاز به المان مرزی را نشان داد، حتماً با محاسبات کامل و آیین‌نامه‌ای تایید شود. طراحی دیوار برشی نهایی باید توسط مهندس محاسب دارای پروانه بررسی و تایید شود.'),
    Sec('هندسه و مصالح', [
      const F('lw', 'طول دیوار (lw)', unit: 'cm'),
      const F('tw', 'ضخامت دیوار (tw)', unit: 'cm'),
      const F('hw', 'ارتفاع طبقه (hw)', unit: 'cm'),
      const F('fc', "fc'", unit: 'kg/cm²'),
      const F('fy', 'fy', unit: 'kg/cm²'),
      R('نسبت hw/lw', fixed(hwlw, 2)),
      R('رفتار دیوار', slender ? 'باریک/بلند (رفتار تیر طره‌ای غالب)' : 'کوتاه/عریض (رفتار برشی غالب)'),
    ]),
    Sec('بارهای طراحی', [
      const F('Vu', 'Vu', unit: 'ton'),
      const F('Mu', 'Mu', unit: 'ton.m'),
      const F('Pu', 'Pu', unit: 'ton'),
    ]),
    Sec('طراحی برشی', [
      const F('vcCoef', 'ضریب Vc'),
      const F('phiShear', 'φ برشی'),
      R('عمق موثر (d ≈ 0.8lw)', fixed(d, 0), unit: 'cm'),
      R('مقاومت برشی بتن (Vc)', fixed(vc / 1000, 1), unit: 'ton'),
      R('φVc', fixed(phiVc / 1000, 1), unit: 'ton'),
      R('Vu', faNum(Vu), unit: 'ton', warn: vuKg > phiVc + 100000),
    ]),
    Sec('آرماتور دیوار', [
      const F('rhoH', 'حداقل ρ افقی'),
      const F('rhoV', 'حداقل ρ قائم'),
      R('آرماتور افقی لازم (بر متر ارتفاع)', fixed(ashFinal, 2), unit: 'cm²/m', hl: true),
      R('آرماتور قائم حداقل (بر متر طول)', fixed(asvMin, 2), unit: 'cm²/m', hl: true),
    ]),
    Sec('کنترل تنش لبه و نیاز به المان مرزی', [
      R('تنش محوری (Pu/Ag)', fixed(stressAxial, 1), unit: 'kg/cm²'),
      R('تنش خمشی لبه (Mu·c/I)', fixed(stressBending, 1), unit: 'kg/cm²'),
      R('حداکثر تنش لبه', fixed(maxEdge, 1), unit: 'kg/cm²'),
      R("حد مجاز ساده‌شده (0.2fc')", fixed(allowable, 1), unit: 'kg/cm²'),
      R('نیاز به المان مرزی؟', needsBE ? 'بله — بررسی دقیق لازم است' : 'خیر (طبق این کنترل ساده)', warn: needsBE),
    ]),
  ];
};

const shearWallDefaults = {
  'lw': '300', 'tw': '20', 'hw': '320', 'fc': '250', 'fy': '4000',
  'Vu': '25', 'Mu': '80', 'Pu': '40', 'phiShear': '0.75', 'vcCoef': '0.53',
  'rhoH': '0.0025', 'rhoV': '0.0025',
};

FormTool shearWallTool(String title, String desc) => FormTool(
    toolId: 'shear-wall-design', title: title, description: '', defaults: shearWallDefaults, builder: _shearWall);

// ───────────────────────── پله ─────────────────────────

FormBuilder _stairs = (Vals v) {
  final riser = v.n('riser'), going = v.n('going'), numSteps = v.n('numSteps');
  final waist = v.n('waist'), fc = v.n('fc'), fy = v.n('fy');
  final finish = v.n('finish'), live = v.n('live'), span = v.n('span');

  final blondel = 2 * riser + going;
  final blondelOk = blondel >= 60 && blondel <= 65;
  final run = going * numSteps;
  final totalRise = riser * numSteps;
  final ang = atan(totalRise / run);
  final slopeF = cos(ang) > 0 ? 1 / cos(ang) : 1.0;
  final stepW = (riser / 2) * 2400 / 100;
  final waistW = (waist / 100) * 2400 * slopeF;
  final dead = stepW + waistW + finish;
  final combo = 1.2 * dead + 1.6 * live;
  final mu = (combo * pow(span / 100, 2)) / 10;
  final d = waist - 2.5;
  final rn = d > 0 ? (mu * 100) / (0.9 * 100 * d * d) : 0.0;
  final under = 1 - (2 * rn) / (0.85 * fc);
  final rho = under >= 0 ? (0.85 * fc / fy) * (1 - sqrt(under)) : 0.0;
  final rhoUsed = max(rho, 0.0018);
  final asStair = rhoUsed * 100 * d;

  return [
    const Note(
        '⚠️ کمک‌محاسبه است، نه جایگزین محاسبات مهندس محاسب. ضریب L²/10 برای لنگر پله یک تقریب رایج برای تکیه‌گاه نیمه‌گیردار است — شرایط تکیه‌گاهی واقعی (ساده، گیردار، طره) را بررسی و در صورت نیاز اصلاح کنید.'),
    Sec('هندسه پله', [
      const F('riser', 'ارتفاع هر پله (Riser)', unit: 'cm'),
      const F('going', 'کف هر پله (Going)', unit: 'cm'),
      const F('numSteps', 'تعداد پله', unit: 'عدد'),
      const F('waist', 'ضخامت جان پله (Waist)', unit: 'cm'),
      R('فرمول بلوندل (2R+G)', fixed(blondel, 1), unit: 'cm', warn: !blondelOk),
      if (!blondelOk) const Note('⚠ خارج از بازه‌ی راحت رایج (۶۰ تا ۶۵ سانتی‌متر) است — ابعاد پله را بازبینی کنید.'),
      R('طول افقی کل پله', fixed(run / 100, 2), unit: 'متر'),
      R('ارتفاع کل', fixed(totalRise / 100, 2), unit: 'متر'),
    ]),
    Sec('بارگذاری', [
      const F('finish', 'بار کف‌سازی', unit: 'kg/m²'),
      const F('live', 'بار زنده', unit: 'kg/m²'),
      const F('fc', "fc'", unit: 'kg/cm²'),
      const F('fy', 'fy', unit: 'kg/cm²'),
      R('وزن پله‌های مثلثی', fixed(stepW, 0), unit: 'kg/m²'),
      R('وزن جان پله', fixed(waistW, 0), unit: 'kg/m²'),
      R('بار مرده کل', fixed(dead, 0), unit: 'kg/m²'),
      R('بار طرح (1.2D+1.6L)', fixed(combo, 0), unit: 'kg/m²', hl: true),
    ]),
    Sec('طراحی خمشی (بر عرض ۱ متر)', [
      const F('span', 'دهانه افقی پله', unit: 'cm'),
      R('عمق موثر (d)', fixed(d, 1), unit: 'cm'),
      R('لنگر طراحی (Mu بر متر عرض)', fixed(mu, 0), unit: 'kg.m/m'),
      R('ρ مورد نیاز', fixed(rho, 5)),
      R('سطح میلگرد لازم (As)', fixed(asStair, 2), unit: 'cm²/m', hl: true),
    ]),
  ];
};

const stairsDefaults = {
  'riser': '17.5', 'going': '28', 'numSteps': '18', 'waist': '15',
  'fc': '250', 'fy': '4000', 'finish': '100', 'live': '350', 'span': '300',
};

FormTool stairsTool(String title, String desc) => FormTool(
    toolId: 'stairs-design', title: title, description: '', defaults: stairsDefaults, builder: _stairs);

