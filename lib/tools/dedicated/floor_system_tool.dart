import 'dart:math';

import 'tool_kit.dart';

const _concreteUnit = 2400.0;
const _precastWeights = <int, double>{12: 220, 15: 260, 20: 300, 25: 350, 30: 380, 40: 440};

FormBuilder _floor = (Vals v) {
  final type = v.s('floorType');
  final fc = v.n('fc'), fy = v.n('fy'), dead = v.n('deadLoad'), live = v.n('liveLoad');

  // تیرچه بلوک
  final spanJoist = v.n('spanJoist'), joistSpacing = v.n('joistSpacing');
  const joistWidth = 10;
  final joistDepth = spanJoist / 20;
  final loadPerJoist = ((dead + live) * joistSpacing) / 100;
  final muJoist = (1.2 * ((dead * joistSpacing) / 100) + 1.6 * ((live * joistSpacing) / 100)) * pow(spanJoist / 100, 2) / 8;

  // دال یک‌طرفه
  final spanOne = v.n('spanOneWay'), thkOne = v.n('onewayThickness');
  final thkOneMin = spanOne / 24;
  final dOne = thkOne - 2.5;
  final muOne = (1.2 * dead + 1.6 * live) * pow(spanOne / 100, 2) / 10;
  final muOneKgCm = muOne * 100;
  final rnOne = dOne > 0 ? muOneKgCm / (0.9 * 100 * dOne * dOne) : 0.0;
  final rhoOne = (rnOne > 0 && (1 - (2 * rnOne) / (0.85 * fc)) >= 0)
      ? (0.85 * fc / fy) * (1 - sqrt(1 - (2 * rnOne) / (0.85 * fc)))
      : 0.0;
  const rhoMinTemp = 0.0018;
  final asOne = max(rhoOne, rhoMinTemp) * 100 * dOne;

  // دال دوطرفه
  final lx = v.n('lx'), ly = v.n('ly');
  final aspect = lx > 0 ? ly / lx : 0.0;
  final isTwoWay = aspect > 0 && aspect <= 2;
  final twoMin = (2 * (lx + ly)) / 180;

  // وافل
  final wX = v.n('waffleSpanX'), wY = v.n('waffleSpanY'), wDepth = v.n('waffleTotalDepth');
  final wTop = v.n('waffleToppingThickness'), wRibW = v.n('waffleRibWidth'), wRibS = v.n('waffleRibSpacing');
  final wMinGuide = max(wX, wY) / 20;
  final wRatio = wRibS > 0 ? (wTop / 100) + ((wRibW / 100) * ((wDepth - wTop) / 100) * (2 / (wRibS / 100))) : 0.0;
  final wWeight = wRatio * _concreteUnit;
  final wSolidEq = 100 * wRatio;
  final wSaving = wDepth > 0 ? (1 - wRatio / (wDepth / 100)) * 100 : 0.0;

  // کوبیاکس
  final cX = v.n('cobiaxSpanX'), cY = v.n('cobiaxSpanY'), cDepth = v.n('cobiaxTotalDepth'), cRed = v.n('voidReductionPercent');
  final cMinGuide = max(cX, cY) / 30;
  final cSolidW = (cDepth / 100) * _concreteUnit;
  final cActualW = cSolidW * (1 - cRed / 100);
  final cZone = cDepth * 2;

  // عرشه
  final deckSpan = v.n('deckSpan'), deckH = v.n('deckHeight'), topAbove = v.n('toppingAboveDeck');
  final deckTotal = deckH + topAbove;
  final deckW = ((topAbove / 100) + 0.5 * (deckH / 100)) * _concreteUnit + 12;
  final deckRatio = deckSpan / deckTotal;

  // پیش‌تنیده
  final pDepth = int.tryParse(v.s('precastDepth')) ?? 20;
  final pSpan = v.n('precastSpan');
  final pWeight = _precastWeights[pDepth];
  final pRatio = pDepth > 0 ? pSpan / pDepth : 0.0;

  return [
    const Note(
        '⚠️ کمک‌محاسبه است، نه جایگزین محاسبات مهندس محاسب. برای سیستم‌های وافل، کوبیاکس/یوبوت و عرشه فولادی، توزیع دقیق لنگر و ظرفیت برشی معمولاً نیازمند نرم‌افزار تحلیل (SAFE و مشابه) یا کاتالوگ فنی سازنده است — این ابزار عمدتاً وزن تقریبی، صرفه‌جویی وزنی، و نکات کلیدی طراحی را ارائه می‌دهد.'),
    Sec('نوع سقف', [
      const S('floorType', 'نوع سقف', [
        ['joist', 'تیرچه و بلوک'],
        ['oneway', 'دال یک‌طرفه'],
        ['twoway', 'دال دوطرفه'],
        ['waffle', 'وافل'],
        ['cobiax', 'کوبیاکس / یوبوت'],
        ['deck', 'عرشه فولادی'],
        ['precast', 'پیش‌تنیده / هالوکور'],
      ]),
    ]),
    if (type != 'deck' && type != 'precast')
      Sec('بارها و مصالح (مشترک)', [
        const F('deadLoad', 'بار مرده (بدون وزن سقف)', unit: 'kg/m²'),
        const F('liveLoad', 'بار زنده', unit: 'kg/m²'),
        const F('fc', "fc'", unit: 'kg/cm²'),
        const F('fy', 'fy', unit: 'kg/cm²'),
      ]),
    if (type == 'joist')
      Sec('سقف تیرچه و بلوک', [
        const F('spanJoist', 'دهانه آزاد', unit: 'cm'),
        const F('joistSpacing', 'فاصله محور تیرچه‌ها', unit: 'cm'),
        R('ارتفاع تقریبی سقف (راهنما)', fixed(joistDepth, 0), unit: 'cm'),
        R('بار خطی هر تیرچه', fixed(loadPerJoist, 0), unit: 'kg/m'),
        R('لنگر تقریبی هر تیرچه (Mu)', fixed(muJoist, 0), unit: 'kg.m', hl: true),
        const Note('برای طراحی نهایی میلگرد کف تیرچه، از ابزار «طراحی تیر بتنی» با b=${joistWidth}cm و همین Mu استفاده کنید.',
            warn: false),
      ]),
    if (type == 'oneway')
      Sec('دال یک‌طرفه (بر عرض ۱ متر)', [
        const F('spanOneWay', 'دهانه', unit: 'cm'),
        const F('onewayThickness', 'ضخامت دال', unit: 'cm'),
        R('حداقل ضخامت پیشنهادی (L/24)', fixed(thkOneMin, 1), unit: 'cm'),
        R('عمق موثر (d)', fixed(dOne, 1), unit: 'cm'),
        R('لنگر طراحی (Mu بر متر عرض)', fixed(muOne, 0), unit: 'kg.m/m'),
        R('ρ مورد نیاز', fixed(rhoOne, 5)),
        R('ρ حداقل حرارتی', fixed(rhoMinTemp, 5)),
        R('سطح میلگرد لازم (As) بر متر عرض', fixed(asOne, 2), unit: 'cm²/m', hl: true),
      ]),
    if (type == 'twoway')
      Sec('دال دوطرفه', [
        const F('lx', 'دهانه کوتاه (lx)', unit: 'cm'),
        const F('ly', 'دهانه بلند (ly)', unit: 'cm'),
        const F('twowayThickness', 'ضخامت دال', unit: 'cm'),
        R('نسبت ly/lx', fixed(aspect, 2)),
        R('طبقه‌بندی', isTwoWay ? 'دوطرفه (ly/lx ≤ 2)' : 'یک‌طرفه (ly/lx > 2)', warn: !isTwoWay),
        R('حداقل ضخامت پیشنهادی (پیرامون/۱۸۰)', fixed(twoMin, 1), unit: 'cm'),
        if (!isTwoWay)
          const Note('⚠ چون ly/lx بیشتر از ۲ است، این دال عملاً یک‌طرفه رفتار می‌کند — از بخش «دال یک‌طرفه» با دهانه lx استفاده کنید.'),
      ]),
    if (type == 'waffle')
      Sec('سقف وافل (Waffle Slab)', [
        const Note('مناسب دهانه‌های بزرگ (معمولاً بیش از ۶ متر) با شبکه تیرچه در هر دو جهت.', warn: false),
        const F('waffleSpanX', 'دهانه جهت X', unit: 'cm'),
        const F('waffleSpanY', 'دهانه جهت Y', unit: 'cm'),
        const F('waffleTotalDepth', 'ارتفاع کل سقف', unit: 'cm'),
        const F('waffleToppingThickness', 'ضخامت دال فوقانی', unit: 'cm'),
        const F('waffleRibWidth', 'عرض تیرچه (Rib)', unit: 'cm'),
        const F('waffleRibSpacing', 'فاصله محور تیرچه‌ها', unit: 'cm'),
        R('حداقل ارتفاع پیشنهادی (دهانه/۲۰)', fixed(wMinGuide, 1), unit: 'cm'),
        R('وزن تقریبی سقف', fixed(wWeight, 0), unit: 'kg/m²', hl: true),
        R('معادل ضخامت دال توپر هم‌وزن', fixed(wSolidEq, 1), unit: 'cm'),
        R('صرفه‌جویی وزنی نسبت به دال توپر هم‌ضخامت', fixed(wSaving, 0), unit: '%'),
        const Note('نکته: نزدیک ستون‌ها باید ناحیه‌ی توپر (Solid Head) برای کنترل برش پانچ در نظر گرفته شود — این ابزار آن را محاسبه نمی‌کند.',
            warn: false),
      ]),
    if (type == 'cobiax')
      Sec('سقف کوبیاکس / یوبوت (دال توخالی دوطرفه)', [
        const Note(
            'درصد کاهش وزن به قطر و آرایش گوی/باکس‌های پلاستیکی بستگی دارد و باید از دیتاشیت سازنده گرفته شود؛ مقدار پیش‌فرض صرفاً یک تخمین رایج است.',
            warn: false),
        const F('cobiaxSpanX', 'دهانه جهت X', unit: 'cm'),
        const F('cobiaxSpanY', 'دهانه جهت Y', unit: 'cm'),
        const F('cobiaxTotalDepth', 'ارتفاع کل دال', unit: 'cm'),
        const F('voidReductionPercent', 'درصد کاهش وزن (طبق سازنده)', unit: '%'),
        R('حداقل ارتفاع راهنما (دهانه/۳۰ تا ۳۵)', fixed(cMinGuide, 1), unit: 'cm'),
        R('وزن دال توپر هم‌ضخامت', fixed(cSolidW, 0), unit: 'kg/m²'),
        R('وزن واقعی دال با احتساب گوی/باکس', fixed(cActualW, 0), unit: 'kg/m²', hl: true),
        R('عرض راهنمای ناحیه‌ی توپر دور ستون (هر طرف)', fixed(cZone, 0), unit: 'cm'),
        const Note(
            '⚠ دور تمام ستون‌ها باید یک ناحیه‌ی کاملاً توپر (بدون گوی/باکس) برای تحمل برش پانچ باقی بماند — طبق دستورالعمل فنی سازنده.'),
      ]),
    if (type == 'deck')
      Sec('سقف عرشه فولادی (کامپوزیت)', [
        const F('deckSpan', 'دهانه عرشه (فاصله تیر فرعی)', unit: 'cm'),
        const F('deckHeight', 'ارتفاع موج عرشه', unit: 'cm'),
        const F('toppingAboveDeck', 'ضخامت بتن روی موج', unit: 'cm'),
        R('ضخامت کل سقف', fixed(deckTotal, 1), unit: 'cm'),
        R('وزن تقریبی سقف (با ورق)', fixed(deckW, 0), unit: 'kg/m²', hl: true),
        R('نسبت دهانه به ضخامت کل', fixed(deckRatio, 1)),
        const Note(
            'ظرفیت باربری واقعی عرشه (بدون/با شمع‌بندی حین اجرا) باید از جدول فنی سازنده‌ی ورق عرشه استخراج شود — این ابزار فقط وزن تقریبی و راهنمای هندسی می‌دهد.',
            warn: false),
      ]),
    if (type == 'precast')
      Sec('دال پیش‌تنیده / هالوکور', [
        S('precastDepth', 'ارتفاع دال (رایج کارخانه‌ای)', [for (final d in [12, 15, 20, 25, 30, 40]) ['$d', '$d cm']]),
        const F('precastSpan', 'دهانه', unit: 'cm'),
        R('وزن تقریبی (راهنما، نه دقیق)', pWeight != null ? plain(pWeight) : '—', unit: 'kg/m²'),
        R('نسبت دهانه به ارتفاع', fixed(pRatio, 1)),
        const Note(
            '⚠ ظرفیت باربری دقیق دال‌های پیش‌تنیده کاملاً به طرح اختصاصی هر کارخانه بستگی دارد — حتماً جدول بار-دهانه (Load-Span Table) رسمی همان تولیدکننده را برای تایید نهایی دریافت کنید.'),
      ]),
  ];
};

FormTool floorSystemTool(String title) => FormTool(
    toolId: 'floor-system-design',
    title: title,
    description: '',
    defaults: const {
      'floorType': 'joist', 'fc': '250', 'fy': '4000', 'deadLoad': '350', 'liveLoad': '200',
      'spanJoist': '400', 'joistSpacing': '60', 'spanOneWay': '300', 'onewayThickness': '13',
      'lx': '400', 'ly': '500', 'twowayThickness': '10',
      'waffleSpanX': '700', 'waffleSpanY': '700', 'waffleTotalDepth': '35', 'waffleToppingThickness': '6',
      'waffleRibWidth': '12', 'waffleRibSpacing': '90',
      'cobiaxSpanX': '800', 'cobiaxSpanY': '800', 'cobiaxTotalDepth': '35', 'voidReductionPercent': '30',
      'deckSpan': '250', 'deckHeight': '7.5', 'toppingAboveDeck': '6', 'precastDepth': '20', 'precastSpan': '600',
    },
    builder: _floor);
