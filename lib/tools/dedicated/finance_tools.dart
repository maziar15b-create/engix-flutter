import 'package:flutter/material.dart';

import 'tool_kit.dart';

// ───────────────────────── تعدیل ─────────────────────────

class PriceAdjustmentTool extends StatefulWidget {
  final String title, description;
  const PriceAdjustmentTool({super.key, required this.title, required this.description});
  @override
  State<PriceAdjustmentTool> createState() => _PriceAdjustmentToolState();
}

class _PriceAdjustmentToolState extends State<PriceAdjustmentTool> {
  final _gross = TextEditingController(text: '300000000');
  final _base = TextEditingController(text: '100');
  final _cur = TextEditingController(text: '118');
  final _coef = TextEditingController(text: '0.85');

  @override
  void dispose() {
    for (final c in [_gross, _base, _cur, _coef]) {
      c.dispose();
    }
    super.dispose();
  }

  void _s() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final periodGrossWork = nv(_gross.text);
    final baseIndex = nv(_base.text);
    final currentIndex = nv(_cur.text);
    final coefA = nv(_coef.text);
    final indexRatio = baseIndex > 0 ? currentIndex / baseIndex : 0.0;
    final factor = (indexRatio - 1) * coefA;
    final amount = periodGrossWork * factor;
    return ToolPage(
      toolId: 'price-adjustment',
      title: widget.title,
      description: '',
      getData: () => {
        'periodGrossWork': _gross.text,
        'baseIndex': _base.text,
        'currentIndex': _cur.text,
        'adjustmentCoefA': _coef.text,
      },
      onLoad: (m) => setState(() {
        if (m['periodGrossWork'] != null) _gross.text = '${m['periodGrossWork']}';
        if (m['baseIndex'] != null) _base.text = '${m['baseIndex']}';
        if (m['currentIndex'] != null) _cur.text = '${m['currentIndex']}';
        if (m['adjustmentCoefA'] != null) _coef.text = '${m['adjustmentCoefA']}';
      }),
      children: [
        const NoticeBox(
            '⚠️ این نسخه‌ی ساده‌شده‌ی تعدیل است (یک شاخص واحد). فرمول رسمی «دستورالعمل نحوه تعدیل آحاد بها» معمولاً وزنی و رشته‌محور است (ترکیبی از چند شاخص مصالح/دستمزد/ماشین‌آلات با ضرایب مختلف). برای محاسبه‌ی دقیق و قابل‌ارائه به کارفرما، حتماً از شاخص‌های رسمی بانک مرکزی/سازمان برنامه‌وبودجه برای همان رشته استفاده کنید.'),
        ToolSection('ورودی‌ها', [
          FieldGrid([
            NumInput(label: 'کارکرد ناخالص این دوره', unit: 'ریال', controller: _gross, onChanged: _s),
            NumInput(label: 'ضریب الف (سهم قابل‌تعدیل)', controller: _coef, onChanged: _s),
            NumInput(label: 'شاخص دوره پایه', controller: _base, onChanged: _s),
            NumInput(label: 'شاخص دوره تعدیل', controller: _cur, onChanged: _s),
          ]),
        ]),
        ToolSection('نتایج', [
          ResultRow('نسبت شاخص (دوره تعدیل/پایه)', fixed(indexRatio, 4)),
          ResultRow('ضریب تعدیل', fixed(factor, 4)),
          ResultRow('مبلغ تعدیل این دوره', faNum(amount), unit: 'ریال', highlight: true),
        ]),
      ],
    );
  }
}

// ───────────────────────── ضرایب بالاسری ─────────────────────────

class OverheadCoefficientsTool extends StatefulWidget {
  final String title, description;
  const OverheadCoefficientsTool({super.key, required this.title, required this.description});
  @override
  State<OverheadCoefficientsTool> createState() => _OverheadCoefficientsToolState();
}

class _OverheadCoefficientsToolState extends State<OverheadCoefficientsTool> {
  final _base = TextEditingController(text: '1000000000');
  final _over = TextEditingController(text: '1.32');
  final _mob = TextEditingController(text: '3');
  final _demob = TextEditingController(text: '1');
  final _reg = TextEditingController(text: '1');

  @override
  void dispose() {
    for (final c in [_base, _over, _mob, _demob, _reg]) {
      c.dispose();
    }
    super.dispose();
  }

  void _s() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final baseEstimate = nv(_base.text);
    final afterOverhead = baseEstimate * nv(_over.text) * nv(_reg.text);
    final mobAmount = baseEstimate * (nv(_mob.text) / 100);
    final demobAmount = baseEstimate * (nv(_demob.text) / 100);
    final total = afterOverhead + mobAmount + demobAmount;
    return ToolPage(
      toolId: 'overhead-coefficients',
      title: widget.title,
      description: '',
      getData: () => {
        'baseEstimate': _base.text,
        'overheadFactor': _over.text,
        'siteMobilizationPercentA': _mob.text,
        'siteDemobilizationPercentB': _demob.text,
        'regionalFactor': _reg.text,
      },
      onLoad: (m) => setState(() {
        if (m['baseEstimate'] != null) _base.text = '${m['baseEstimate']}';
        if (m['overheadFactor'] != null) _over.text = '${m['overheadFactor']}';
        if (m['siteMobilizationPercentA'] != null) _mob.text = '${m['siteMobilizationPercentA']}';
        if (m['siteDemobilizationPercentB'] != null) _demob.text = '${m['siteDemobilizationPercentB']}';
        if (m['regionalFactor'] != null) _reg.text = '${m['regionalFactor']}';
      }),
      children: [
        const NoticeBox(
            '⚠️ ضریب بالاسری و درصدهای تجهیز/برچیدن کارگاه هر سال طی «دستورالعمل تعیین ضرایب» سازمان برنامه و بودجه و بخشنامه‌های مرتبط به‌روزرسانی می‌شوند و به نوع رشته و حجم کار هم بستگی دارند. مقادیر پیش‌فرض این ابزار صرفاً نمونه‌اند — حتماً با آخرین دستورالعمل رسمی و فهرست بهای سال اجرای پروژه تطبیق دهید.'),
        ToolSection('ورودی‌ها', [
          FieldGrid([
            NumInput(label: 'برآورد اولیه (مبنای فهرست بها)', unit: 'ریال', controller: _base, onChanged: _s),
            NumInput(label: 'ضریب بالاسری', controller: _over, onChanged: _s),
            NumInput(label: 'ضریب منطقه‌ای', controller: _reg, onChanged: _s),
            NumInput(label: 'درصد تجهیز کارگاه (بند الف)', unit: '%', controller: _mob, onChanged: _s),
            NumInput(label: 'درصد برچیدن کارگاه (بند ب)', unit: '%', controller: _demob, onChanged: _s),
          ]),
        ]),
        ToolSection('نتایج', [
          ResultRow('مبلغ پس از اعمال ضریب بالاسری و منطقه‌ای', faNum(afterOverhead), unit: 'ریال'),
          ResultRow('مبلغ تجهیز کارگاه', faNum(mobAmount), unit: 'ریال'),
          ResultRow('مبلغ برچیدن کارگاه', faNum(demobAmount), unit: 'ریال'),
          ResultRow('مبلغ کل برآوردی پیمان', faNum(total), unit: 'ریال', highlight: true),
        ]),
      ],
    );
  }
}

// ───────────────────────── جریمه تاخیر ─────────────────────────

class DelayPenaltyTool extends StatefulWidget {
  final String title, description;
  const DelayPenaltyTool({super.key, required this.title, required this.description});
  @override
  State<DelayPenaltyTool> createState() => _DelayPenaltyToolState();
}

class _DelayPenaltyToolState extends State<DelayPenaltyTool> {
  final _amount = TextEditingController(text: '1000000000');
  final _rate = TextEditingController(text: '0.1');
  final _days = TextEditingController(text: '15');
  final _cap = TextEditingController(text: '10');

  @override
  void dispose() {
    for (final c in [_amount, _rate, _days, _cap]) {
      c.dispose();
    }
    super.dispose();
  }

  void _s() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final contract = nv(_amount.text);
    final raw = contract * (nv(_rate.text) / 100) * nv(_days.text);
    final capAmount = contract * (nv(_cap.text) / 100);
    final finalPenalty = raw < capAmount ? raw : capAmount;
    final capped = raw > capAmount;
    return ToolPage(
      toolId: 'delay-penalty',
      title: widget.title,
      description: '',
      getData: () => {
        'contractAmount': _amount.text,
        'dailyRatePercent': _rate.text,
        'delayDays': _days.text,
        'capPercent': _cap.text,
      },
      onLoad: (m) => setState(() {
        if (m['contractAmount'] != null) _amount.text = '${m['contractAmount']}';
        if (m['dailyRatePercent'] != null) _rate.text = '${m['dailyRatePercent']}';
        if (m['delayDays'] != null) _days.text = '${m['delayDays']}';
        if (m['capPercent'] != null) _cap.text = '${m['capPercent']}';
      }),
      children: [
        const NoticeBox(
            '⚠️ نرخ و سقف جریمه‌ی تاخیر باید دقیقاً از متن شرایط خصوصی و عمومی همان پیمان (نه یک عدد ثابت عمومی) خوانده شود — مقادیر پیش‌فرض این ابزار (یک‌هزارم روزانه، سقف ۱۰٪) فقط رایج‌ترین حالت مرسوم‌اند و می‌توانند در هر پیمان متفاوت باشند.'),
        ToolSection('ورودی‌ها', [
          FieldGrid([
            NumInput(label: 'مبلغ اولیه پیمان', unit: 'ریال', controller: _amount, onChanged: _s),
            NumInput(label: 'نرخ جریمه روزانه', unit: '%', controller: _rate, onChanged: _s),
            NumInput(label: 'تعداد روز تاخیر غیرمجاز', unit: 'روز', controller: _days, onChanged: _s),
            NumInput(label: 'سقف جریمه', unit: '%', controller: _cap, onChanged: _s),
          ]),
        ]),
        ToolSection('نتایج', [
          ResultRow('جریمه محاسبه‌شده (بدون سقف)', faNum(raw), unit: 'ریال'),
          ResultRow('سقف جریمه', faNum(capAmount), unit: 'ریال'),
          ResultRow('جریمه نهایی (با اعمال سقف)', faNum(finalPenalty), unit: 'ریال', highlight: true),
          if (capped)
            const NoticeBox('⚠ جریمه‌ی محاسبه‌شده از سقف بیشتر بود؛ طبق سقف پیمان محدود شد.'),
        ]),
      ],
    );
  }
}

// ───────────────────────── صورت وضعیت (ساده) ─────────────────────────

class ProgressPaymentTool extends StatefulWidget {
  final String title, description;
  const ProgressPaymentTool({super.key, required this.title, required this.description});
  @override
  State<ProgressPaymentTool> createState() => _ProgressPaymentToolState();
}

class _ProgressPaymentToolState extends State<ProgressPaymentTool> {
  final _cur = TextEditingController(text: '500000000');
  final _prev = TextEditingController(text: '350000000');
  final _ret = TextEditingController(text: '10');
  final _ins = TextEditingController(text: '6.5');
  final _adv = TextEditingController(text: '0');
  final _other = TextEditingController(text: '0');
  final _vat = TextEditingController(text: '9');

  @override
  void dispose() {
    for (final c in [_cur, _prev, _ret, _ins, _adv, _other, _vat]) {
      c.dispose();
    }
    super.dispose();
  }

  void _s() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final gross = nv(_cur.text) - nv(_prev.text);
    final retention = gross * (nv(_ret.text) / 100);
    final insurance = gross * (nv(_ins.text) / 100);
    final advance = gross * (nv(_adv.text) / 100);
    final vat = gross * (nv(_vat.text) / 100);
    final totalDeductions = retention + insurance + advance + nv(_other.text);
    final net = gross - totalDeductions + vat;
    return ToolPage(
      toolId: 'progress-payment',
      title: widget.title,
      description: '',
      getData: () => {
        'cumulativeCurrent': _cur.text,
        'cumulativePrevious': _prev.text,
        'retentionPercent': _ret.text,
        'insurancePercent': _ins.text,
        'advanceRecoupPercent': _adv.text,
        'otherDeductions': _other.text,
        'vatPercent': _vat.text,
      },
      onLoad: (m) => setState(() {
        if (m['cumulativeCurrent'] != null) _cur.text = '${m['cumulativeCurrent']}';
        if (m['cumulativePrevious'] != null) _prev.text = '${m['cumulativePrevious']}';
        if (m['retentionPercent'] != null) _ret.text = '${m['retentionPercent']}';
        if (m['insurancePercent'] != null) _ins.text = '${m['insurancePercent']}';
        if (m['advanceRecoupPercent'] != null) _adv.text = '${m['advanceRecoupPercent']}';
        if (m['otherDeductions'] != null) _other.text = '${m['otherDeductions']}';
        if (m['vatPercent'] != null) _vat.text = '${m['vatPercent']}';
      }),
      children: [
        const NoticeBox(
            '⚠️ کمک‌محاسبه است، نه سند رسمی. درصدهای کسور (حسن‌انجام‌کار، بیمه، مالیات) باید طبق شرایط خصوصی و عمومی همان پیمان و آخرین مصوبات دقیق شوند — همه‌ی مقادیر پیش‌فرض قابل‌ویرایش‌اند.'),
        ToolSection('کارکرد', [
          FieldGrid([
            NumInput(label: 'کارکرد ناخالص تجمعی تا این صورت‌وضعیت', unit: 'ریال', controller: _cur, onChanged: _s),
            NumInput(label: 'کارکرد ناخالص تجمعی تا صورت‌وضعیت قبلی', unit: 'ریال', controller: _prev, onChanged: _s),
          ]),
          ResultRow('کارکرد ناخالص این دوره', faNum(gross), unit: 'ریال', highlight: true),
        ]),
        ToolSection('کسور', [
          FieldGrid([
            NumInput(label: 'کسر حسن انجام کار', unit: '%', controller: _ret, onChanged: _s),
            NumInput(label: 'کسر بیمه تامین اجتماعی', unit: '%', controller: _ins, onChanged: _s),
            NumInput(label: 'بازپرداخت پیش‌پرداخت', unit: '%', controller: _adv, onChanged: _s),
            NumInput(label: 'سایر کسورات (مبلغ مستقیم)', unit: 'ریال', controller: _other, onChanged: _s),
          ]),
          ResultRow('کسر حسن انجام کار', faNum(retention), unit: 'ریال'),
          ResultRow('کسر بیمه', faNum(insurance), unit: 'ریال'),
          ResultRow('بازپرداخت پیش‌پرداخت', faNum(advance), unit: 'ریال'),
          ResultRow('جمع کل کسورات', faNum(totalDeductions), unit: 'ریال', highlight: true),
        ]),
        ToolSection('مالیات بر ارزش افزوده', [
          NumInput(label: 'نرخ مالیات بر ارزش افزوده', unit: '%', controller: _vat, onChanged: _s),
          const SizedBox(height: 8),
          ResultRow('مبلغ مالیات بر ارزش افزوده', faNum(vat), unit: 'ریال'),
        ]),
        ToolSection('نتیجه نهایی', [
          ResultRow('مبلغ خالص قابل‌پرداخت این صورت‌وضعیت', faNum(net), unit: 'ریال', highlight: true),
        ]),
      ],
    );
  }
}
