import 'package:flutter/material.dart';

import 'theme.dart';

/// تبدیل و نمایش تاریخ شمسی. ذخیره‌ی تاریخ‌ها در دیتابیس همچنان میلادی (yyyy-MM-dd) می‌ماند؛
/// فقط نمایش و انتخاب تاریخ شمسی است.

const jalaliMonthNames = [
  'فروردین',
  'اردیبهشت',
  'خرداد',
  'تیر',
  'مرداد',
  'شهریور',
  'مهر',
  'آبان',
  'آذر',
  'دی',
  'بهمن',
  'اسفند',
];

const _faD = '۰۱۲۳۴۵۶۷۸۹';

String faDigits(Object? v) => (v ?? '')
    .toString()
    .replaceAllMapped(RegExp(r'\d'), (m) => _faD[int.parse(m[0]!)]);

String _p2(int n) => n.toString().padLeft(2, '0');

List<int> gregorianToJalali(int gy, int gm, int gd) {
  const gdm = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
  final gy2 = gm > 2 ? gy + 1 : gy;
  var days = 355666 +
      (365 * gy) +
      ((gy2 + 3) ~/ 4) -
      ((gy2 + 99) ~/ 100) +
      ((gy2 + 399) ~/ 400) +
      gd +
      gdm[gm - 1];
  var jy = -1595 + (33 * (days ~/ 12053));
  days %= 12053;
  jy += 4 * (days ~/ 1461);
  days %= 1461;
  if (days > 365) {
    jy += (days - 1) ~/ 365;
    days = (days - 1) % 365;
  }
  final jm = days < 186 ? 1 + (days ~/ 31) : 7 + ((days - 186) ~/ 30);
  final jd = 1 + (days < 186 ? (days % 31) : ((days - 186) % 30));
  return [jy, jm, jd];
}

List<int> jalaliToGregorian(int jy, int jm, int jd) {
  jy += 1595;
  var days = -355668 +
      (365 * jy) +
      ((jy ~/ 33) * 8) +
      (((jy % 33) + 3) ~/ 4) +
      jd +
      (jm < 7 ? (jm - 1) * 31 : ((jm - 7) * 30) + 186);
  var gy = 400 * (days ~/ 146097);
  days %= 146097;
  if (days > 36524) {
    days--;
    gy += 100 * (days ~/ 36524);
    days %= 36524;
    if (days >= 365) days++;
  }
  gy += 4 * (days ~/ 1461);
  days %= 1461;
  if (days > 365) {
    gy += (days - 1) ~/ 365;
    days = (days - 1) % 365;
  }
  var gd = days + 1;
  final sal = [
    0,
    31,
    ((gy % 4 == 0 && gy % 100 != 0) || gy % 400 == 0) ? 29 : 28,
    31,
    30,
    31,
    30,
    31,
    31,
    30,
    31,
    30,
    31
  ];
  var gm = 0;
  while (gm < 13 && gd > sal[gm]) {
    gd -= sal[gm];
    gm++;
  }
  return [gy, gm, gd];
}

bool isJalaliLeap(int jy) {
  final g = jalaliToGregorian(jy, 12, 30);
  final j = gregorianToJalali(g[0], g[1], g[2]);
  return j[0] == jy && j[1] == 12 && j[2] == 30;
}

int jalaliMonthLength(int jy, int jm) {
  if (jm <= 6) return 31;
  if (jm <= 11) return 30;
  return isJalaliLeap(jy) ? 30 : 29;
}

DateTime? _parseAny(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v.toLocal();
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) {
    final p = s.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }
  return DateTime.tryParse(s)?.toLocal();
}

/// «۱۴۰۵/۰۷/۱۶» از رشته‌ی yyyy-MM-dd یا تایم‌استمپ ISO یا DateTime
String faDate(dynamic v) {
  final d = _parseAny(v);
  if (d == null) return v == null ? '' : v.toString();
  final j = gregorianToJalali(d.year, d.month, d.day);
  return faDigits('${j[0]}/${_p2(j[1])}/${_p2(j[2])}');
}

/// «۱۴۰۵/۰۷/۱۶ ۱۴:۳۰»
String faDateTime(dynamic v) {
  final d = _parseAny(v);
  if (d == null) return v == null ? '' : v.toString();
  return '${faDate(d)} ${faDigits('${_p2(d.hour)}:${_p2(d.minute)}')}';
}

/// «۱۶ مهر ۱۴۰۵»
String faDateLong(dynamic v) {
  final d = _parseAny(v);
  if (d == null) return v == null ? '' : v.toString();
  final j = gregorianToJalali(d.year, d.month, d.day);
  return faDigits('${j[2]} ${jalaliMonthNames[j[1] - 1]} ${j[0]}');
}

String _isoDay(int jy, int jm, int jd) {
  final g = jalaliToGregorian(jy, jm, jd);
  return '${g[0].toString().padLeft(4, '0')}-${_p2(g[1])}-${_p2(g[2])}';
}

/// انتخاب تاریخ شمسی؛ خروجی به‌صورت میلادی yyyy-MM-dd (برای ذخیره در دیتابیس)
Future<String?> showJalaliDatePicker(
  BuildContext context, {
  String? initial,
  int minYear = 1380,
  int maxYear = 1460,
}) {
  final init = _parseAny(initial) ?? DateTime.now();
  return showDialog<String>(
    context: context,
    builder: (_) => _JalaliPickerDialog(
      initial: init,
      minYear: minYear,
      maxYear: maxYear,
    ),
  );
}

class _JalaliPickerDialog extends StatefulWidget {
  final DateTime initial;
  final int minYear;
  final int maxYear;
  const _JalaliPickerDialog(
      {required this.initial, required this.minYear, required this.maxYear});

  @override
  State<_JalaliPickerDialog> createState() => _JalaliPickerDialogState();
}

class _JalaliPickerDialogState extends State<_JalaliPickerDialog> {
  late int _vy; // سال نمایش
  late int _vm; // ماه نمایش
  late int _sy;
  late int _sm;
  late int _sd; // انتخاب‌شده

  @override
  void initState() {
    super.initState();
    final j = gregorianToJalali(
        widget.initial.year, widget.initial.month, widget.initial.day);
    _vy = _sy = j[0];
    _vm = _sm = j[1];
    _sd = j[2];
  }

  void _prevMonth() {
    setState(() {
      if (_vm == 1) {
        if (_vy > widget.minYear) {
          _vy--;
          _vm = 12;
        }
      } else {
        _vm--;
      }
    });
  }

  void _nextMonth() {
    setState(() {
      if (_vm == 12) {
        if (_vy < widget.maxYear) {
          _vy++;
          _vm = 1;
        }
      } else {
        _vm++;
      }
    });
  }

  void _changeYear(int delta) {
    setState(() {
      final ny = _vy + delta;
      if (ny >= widget.minYear && ny <= widget.maxYear) _vy = ny;
    });
  }

  void _today() {
    final n = DateTime.now();
    Navigator.pop(context, '${n.year.toString().padLeft(4, '0')}-${_p2(n.month)}-${_p2(n.day)}');
  }

  @override
  Widget build(BuildContext context) {
    final len = jalaliMonthLength(_vy, _vm);
    final g1 = jalaliToGregorian(_vy, _vm, 1);
    final first = DateTime(g1[0], g1[1], g1[2]);
    final offset = (first.weekday + 1) % 7; // شنبه = ۰
    const wd = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];

    final cells = <Widget>[
      for (final w in wd)
        Center(
            child: Text(w,
                style: const TextStyle(color: C.muted, fontSize: 12, fontWeight: FontWeight.w700))),
      for (var i = 0; i < offset; i++) const SizedBox.shrink(),
      for (var d = 1; d <= len; d++)
        GestureDetector(
          onTap: () => setState(() {
            _sy = _vy;
            _sm = _vm;
            _sd = d;
          }),
          child: Container(
            margin: const EdgeInsets.all(2),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (_sy == _vy && _sm == _vm && _sd == d) ? C.red : Colors.transparent,
            ),
            child: Text(faDigits(d),
                style: TextStyle(
                    fontSize: 13,
                    color: (_sy == _vy && _sm == _vm && _sd == d) ? Colors.white : C.text)),
          ),
        ),
    ];

    return AlertDialog(
      backgroundColor: C.bg2,
      contentPadding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      content: SizedBox(
        width: 320,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            IconButton(
                onPressed: () => _changeYear(-1),
                icon: const Icon(Icons.keyboard_double_arrow_right, size: 20)),
            IconButton(onPressed: _prevMonth, icon: const Icon(Icons.chevron_right)),
            Expanded(
              child: Text('${jalaliMonthNames[_vm - 1]} ${faDigits(_vy)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ),
            IconButton(onPressed: _nextMonth, icon: const Icon(Icons.chevron_left)),
            IconButton(
                onPressed: () => _changeYear(1),
                icon: const Icon(Icons.keyboard_double_arrow_left, size: 20)),
          ]),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.05,
            children: cells,
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: _today, child: const Text('امروز')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
        TextButton(
          onPressed: () => Navigator.pop(context, _isoDay(_sy, _sm, _sd)),
          child: const Text('تایید', style: TextStyle(color: C.redLight)),
        ),
      ],
    );
  }
}
