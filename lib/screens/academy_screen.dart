import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme.dart';
import '../core/widgets.dart';

const _books = <Map<String, String>>[
  {'title': 'مکانیک خاک و پی', 'field': 'عمران', 'note': 'کتاب مرجع دانشگاهی؛ از کتابفروشی‌های تخصصی عمران تهیه کنید.'},
  {'title': 'طراحی سازه‌های بتنی (بر اساس آیین‌نامه آبا)', 'field': 'عمران', 'note': 'آیین‌نامه بتن ایران (آبا) از سازمان برنامه و بودجه قابل تهیه است.'},
  {'title': 'متره و برآورد پروژه‌های عمرانی', 'field': 'عمران', 'note': 'کتاب مرجع دانشگاهی و حرفه‌ای.'},
  {'title': 'مقررات ملی ساختمان — مبحث اول: تعاریف', 'field': 'همه رشته‌ها', 'note': 'نسخه رسمی از سایت وزارت راه و شهرسازی قابل دریافت است.'},
  {'title': 'مقررات ملی ساختمان — مبحث دوم: نظامات اداری', 'field': 'همه رشته‌ها', 'note': 'نسخه رسمی از سایت وزارت راه و شهرسازی.'},
  {'title': 'مقررات ملی ساختمان — مبحث سوم: حفاظت ساختمان‌ها در برابر حریق', 'field': 'همه رشته‌ها', 'note': 'نسخه رسمی از سایت وزارت راه و شهرسازی.'},
  {'title': 'مقررات ملی ساختمان — مبحث چهارم: الزامات عمومی ساختمان‌ها', 'field': 'همه رشته‌ها', 'note': 'نسخه رسمی از سایت وزارت راه و شهرسازی.'},
  {'title': 'مقررات ملی ساختمان — مبحث ششم: بارهای وارد بر ساختمان', 'field': 'عمران', 'note': 'مرجع اصلی بارگذاری مرده، زنده، باد و برف.'},
  {'title': 'مقررات ملی ساختمان — مبحث هفتم: پی و پی‌سازی', 'field': 'عمران', 'note': 'ژئوتکنیک و طراحی پی.'},
  {'title': 'مقررات ملی ساختمان — مبحث نهم: طرح و اجرای ساختمان‌های بتن‌آرمه', 'field': 'عمران', 'note': 'همراه با آیین‌نامه آبا (ABA) کاربرد دارد.'},
  {'title': 'مقررات ملی ساختمان — مبحث دهم: طرح و اجرای ساختمان‌های فولادی', 'field': 'عمران', 'note': 'شامل ضوابط اتصالات، جوش و پیچ.'},
  {'title': 'مقررات ملی ساختمان — مبحث دوازدهم: ایمنی و حفاظت کار در حین اجرا', 'field': 'همه رشته‌ها', 'note': 'مرجع اصلی HSE کارگاه.'},
  {'title': 'مقررات ملی ساختمان — مبحث سیزدهم: طرح و اجرای تاسیسات برقی', 'field': 'برق', 'note': 'مرجع اصلی طراحی برق ساختمان.'},
  {'title': 'مقررات ملی ساختمان — مبحث چهاردهم: تاسیسات مکانیکی', 'field': 'مکانیک', 'note': 'مرجع اصلی طراحی تاسیسات مکانیکی.'},
  {'title': 'مقررات ملی ساختمان — مبحث هفدهم: لوله‌کشی گاز طبیعی', 'field': 'مکانیک', 'note': 'ضوابط ایمنی و اجرای لوله‌کشی گاز.'},
  {'title': 'مقررات ملی ساختمان — مبحث نوزدهم: صرفه‌جویی در مصرف انرژی', 'field': 'همه رشته‌ها', 'note': 'الزامات عایق‌کاری حرارتی ساختمان.'},
  {'title': 'مقررات ملی ساختمان — مبحث بیست‌ودوم: مراقبت و نگهداری از ساختمان‌ها', 'field': 'همه رشته‌ها', 'note': 'ضوابط نگهداری بعد از بهره‌برداری.'},
  {'title': 'آیین‌نامه طراحی ساختمان‌ها در برابر زلزله (استاندارد ۲۸۰۰)', 'field': 'عمران', 'note': 'نسخه رسمی از پژوهشگاه بین‌المللی زلزله‌شناسی و مهندسی زلزله (IIEES).'},
  {'title': 'ضوابط جوش سازه‌های فولادی (استاندارد ملی / AWS D1.1)', 'field': 'عمران', 'note': 'مرجع کنترل کیفیت و اجرای جوش در سازه‌های فلزی.'},
  {'title': 'اصول معماری داخلی', 'field': 'معماری', 'note': 'کتاب مرجع دانشگاهی.'},
  {'title': 'نقشه‌برداری عمومی و ژئودزی', 'field': 'عمران', 'note': 'کتاب مرجع دانشگاهی رشته نقشه‌برداری.'},
];

const _fields = ['همه', 'عمران', 'معماری', 'برق', 'مکانیک'];

const _softwareCourses = [
  'AutoCAD', 'Revit', 'ETABS', 'SAFE', 'SAP2000', 'Civil3D',
  'Tekla', 'Lumion', '3ds Max', 'MATLAB', 'Primavera', 'MSP',
];

String _fa(Object? v) {
  const d = '۰۱۲۳۴۵۶۷۸۹';
  return (v ?? '').toString().replaceAllMapped(RegExp(r'\d'), (m) => d[int.parse(m[0]!)]);
}

class AcademyScreen extends StatelessWidget {
  final Map<String, dynamic> profile;
  const AcademyScreen({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: C.bg1,
          title: const Text('EngiX Academy', style: TextStyle(fontSize: 16)),
          bottom: const TabBar(
            indicatorColor: C.red,
            labelColor: C.redLight,
            unselectedLabelColor: C.muted,
            tabs: [
              Tab(text: 'کتابخانه'),
              Tab(text: 'آزمون آزمایشی'),
              Tab(text: 'دوره نرم‌افزار'),
            ],
          ),
        ),
        body: Backdrop(
          child: TabBarView(
            children: [
              const _LibraryTab(),
              _ExamTab(profile: profile),
              const _SoftwareTab(),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ کتابخانه

class _LibraryTab extends StatefulWidget {
  const _LibraryTab();
  @override
  State<_LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<_LibraryTab> {
  String _field = 'همه';

  @override
  Widget build(BuildContext context) {
    final shown = _field == 'همه'
        ? _books
        : _books.where((b) => b['field'] == _field || b['field'] == 'همه رشته‌ها').toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'به دلیل رعایت حق نشر، متن کتاب‌ها و آیین‌نامه‌ها در دسترس نیست؛ فقط مشخصات و منبع تهیه رسمی نمایش داده می‌شود.',
          style: TextStyle(color: C.muted, fontSize: 12.5, height: 1.8),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final f in _fields)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6),
                  child: ChoiceChip(
                    label: Text(f, style: const TextStyle(fontSize: 12)),
                    selected: _field == f,
                    selectedColor: const Color(0x55C50337),
                    backgroundColor: C.bg1,
                    onSelected: (_) => setState(() => _field = f),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final b in shown)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x29C50337)),
              gradient: const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0xFF1D1B22), Color(0xFF141318)],
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Text(b['title']!,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, height: 1.7)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0x26C50337),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0x59C50337)),
                  ),
                  child: Text(b['field']!, style: const TextStyle(fontSize: 10.5, color: C.redLight)),
                ),
              ]),
              const SizedBox(height: 6),
              Text(b['note']!, style: const TextStyle(color: C.soft, fontSize: 12, height: 1.7)),
            ]),
          ),
      ],
    );
  }
}

// -------------------------------------------------------------------- آزمون

class _ExamTab extends StatefulWidget {
  final Map<String, dynamic> profile;
  const _ExamTab({required this.profile});
  @override
  State<_ExamTab> createState() => _ExamTabState();
}

class _ExamTabState extends State<_ExamTab> {
  SupabaseClient get _db => Supabase.instance.client;
  String get _uid => widget.profile['id'].toString();

  List<Map<String, dynamic>>? _subjects;
  List<Map<String, dynamic>> _history = [];
  Map<String, dynamic>? _subject;
  List<Map<String, dynamic>>? _questions;
  int _idx = 0;
  int? _picked;
  final Map<String, int> _answers = {};
  Map<String, int>? _result;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
    _loadHistory();
  }

  Future<void> _loadSubjects() async {
    try {
      final rows = await _db.from('exam_subjects').select().order('sort_order');
      if (mounted) setState(() => _subjects = List<Map<String, dynamic>>.from(rows));
    } catch (e) {
      if (mounted) {
        setState(() {
          _subjects = [];
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _loadHistory() async {
    try {
      final rows = await _db
          .from('exam_attempts')
          .select('id, score, total, created_at, exam_subjects(label)')
          .eq('user_id', _uid)
          .order('created_at', ascending: false)
          .limit(5);
      if (mounted) setState(() => _history = List<Map<String, dynamic>>.from(rows));
    } catch (_) {}
  }

  Future<void> _pickSubject(Map<String, dynamic> s) async {
    setState(() {
      _error = null;
      _questions = null;
      _subject = s;
      _idx = 0;
      _picked = null;
      _answers.clear();
      _result = null;
    });
    try {
      final rows = await _db.from('exam_questions').select().eq('subject_id', s['id']);
      final list = List<Map<String, dynamic>>.from(rows)..shuffle();
      if (mounted) setState(() => _questions = list);
    } catch (e) {
      if (mounted) {
        setState(() {
          _questions = [];
          _error = e.toString();
        });
      }
    }
  }

  void _back() {
    setState(() {
      _subject = null;
      _questions = null;
      _result = null;
      _picked = null;
      _idx = 0;
      _answers.clear();
    });
  }

  List<String> _options(Map<String, dynamic> q) =>
      (q['options'] as List? ?? []).map((e) => e.toString()).toList();

  void _choose(int i) {
    if (_picked != null) return;
    final q = _questions![_idx];
    setState(() {
      _picked = i;
      _answers[q['id'].toString()] = i;
    });
  }

  Future<void> _next() async {
    final qs = _questions!;
    if (_idx < qs.length - 1) {
      setState(() {
        _idx++;
        _picked = null;
      });
      return;
    }
    var score = 0;
    for (final q in qs) {
      if (_answers[q['id'].toString()] == (q['correct_index'] as num?)?.toInt()) score++;
    }
    setState(() => _saving = true);
    try {
      await _db.from('exam_attempts').insert({
        'user_id': _uid,
        'subject_id': _subject!['id'],
        'score': score,
        'total': qs.length,
        'answers': _answers,
      });
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _saving = false;
      _result = {'score': score, 'total': qs.length};
    });
    _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    if (_subjects == null) {
      return const Center(child: CircularProgressIndicator(color: C.red));
    }
    if (_subject == null) return _subjectList();
    if (_questions == null) {
      return const Center(child: CircularProgressIndicator(color: C.red));
    }
    if (_result != null) return _resultView();
    if (_questions!.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('هنوز سوالی برای این موضوع ثبت نشده است.',
              style: TextStyle(color: C.muted)),
          const SizedBox(height: 10),
          TextButton(onPressed: _back, child: const Text('بازگشت به موضوعات')),
        ]),
      );
    }
    return _quizView();
  }

  Widget _subjectList() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('یک موضوع را برای شروع آزمون آزمایشی انتخاب کنید.',
            style: TextStyle(color: C.muted, fontSize: 12.5)),
        const SizedBox(height: 12),
        ErrorText(_error),
        if (_subjects!.isEmpty && _error == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('موضوعی ثبت نشده است.', style: TextStyle(color: C.muted))),
          ),
        for (final s in _subjects!)
          GestureDetector(
            onTap: () => _pickSubject(s),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x29C50337)),
                gradient: const LinearGradient(
                    colors: [Color(0xFF1D1B22), Color(0xFF141318)]),
              ),
              child: Row(children: [
                Expanded(
                  child: Text((s['label'] ?? '').toString(),
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                ),
                const Text('شروع ›', style: TextStyle(color: C.redLight, fontSize: 12)),
              ]),
            ),
          ),
        if (_history.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('آخرین نتایج شما',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: C.soft)),
          const SizedBox(height: 8),
          for (final h in _history)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(((h['exam_subjects'] as Map?)?['label'] ?? '').toString(),
                    style: const TextStyle(color: C.soft, fontSize: 12)),
                Text('${_fa(h['score'])}/${_fa(h['total'])}',
                    style: const TextStyle(color: C.soft, fontSize: 12)),
              ]),
            ),
        ],
      ],
    );
  }

  Widget _quizView() {
    final qs = _questions!;
    final q = qs[_idx];
    final opts = _options(q);
    final correct = (q['correct_index'] as num?)?.toInt();
    final isLast = _idx == qs.length - 1;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text((_subject!['label'] ?? '').toString(),
              style: const TextStyle(color: C.redLight, fontWeight: FontWeight.w700, fontSize: 12.5)),
          Text('سوال ${_fa(_idx + 1)} از ${_fa(qs.length)}',
              style: const TextStyle(color: C.soft, fontSize: 12)),
        ]),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: (_idx + 1) / qs.length,
          color: C.redLight,
          backgroundColor: const Color(0xFF0B0A0D),
          minHeight: 5,
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x29C50337)),
            gradient: const LinearGradient(colors: [Color(0xFF1D1B22), Color(0xFF141318)]),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text((q['question'] ?? '').toString(),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.8)),
            const SizedBox(height: 14),
            for (var i = 0; i < opts.length; i++)
              GestureDetector(
                onTap: () => _choose(i),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: _picked == null
                        ? C.bg1
                        : i == correct
                            ? const Color(0x4022C55E)
                            : i == _picked
                                ? const Color(0x40EF4444)
                                : C.bg1,
                    border: Border.all(color: const Color(0x22FFFFFF)),
                  ),
                  child: Text(opts[i], style: const TextStyle(fontSize: 13, height: 1.6)),
                ),
              ),
            if (_picked != null && (q['explanation'] ?? '').toString().isNotEmpty) ...[
              const Divider(color: Color(0x22FFFFFF)),
              Text(q['explanation'].toString(),
                  style: const TextStyle(color: C.soft, fontSize: 12, height: 1.8)),
            ],
          ]),
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: (_picked == null || _saving) ? null : _next,
          child: Text(_saving ? '...' : (isLast ? 'پایان و مشاهده نتیجه' : 'سوال بعدی ›')),
        ),
        TextButton(onPressed: _back, child: const Text('انصراف و بازگشت')),
      ],
    );
  }

  Widget _resultView() {
    final score = _result!['score']!;
    final total = _result!['total']!;
    final pct = total == 0 ? 0 : (score / total * 100).round();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 20),
        const Center(child: Text('نتیجه آزمون', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
        const SizedBox(height: 12),
        Center(
          child: Text('${_fa(pct)}٪',
              style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  color: pct >= 60 ? const Color(0xFF22C55E) : const Color(0xFFEF4444))),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text('${_fa(score)} پاسخ صحیح از ${_fa(total)} سوال',
              style: const TextStyle(color: C.soft, fontSize: 13)),
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: () => _pickSubject(_subject!), child: const Text('تلاش دوباره')),
        const SizedBox(height: 8),
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: _back,
          child: const Text('بازگشت به موضوعات'),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ دوره نرم‌افزار

class _SoftwareTab extends StatefulWidget {
  const _SoftwareTab();
  @override
  State<_SoftwareTab> createState() => _SoftwareTabState();
}

class _SoftwareTabState extends State<_SoftwareTab> {
  final Set<String> _enrolled = {};

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('در دوره‌ای که نیاز دارید ثبت‌نام کنید.',
            style: TextStyle(color: C.muted, fontSize: 12.5)),
        const SizedBox(height: 12),
        for (final c in _softwareCourses)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x29C50337)),
              gradient: const LinearGradient(colors: [Color(0xFF1D1B22), Color(0xFF141318)]),
            ),
            child: Row(children: [
              Expanded(child: Text(c, style: const TextStyle(fontSize: 13.5))),
              _enrolled.contains(c)
                  ? OutlinedButton(
                      onPressed: () => setState(() => _enrolled.remove(c)),
                      child: const Text('ثبت‌نام شده ✓'),
                    )
                  : FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size(90, 38)),
                      onPressed: () => setState(() => _enrolled.add(c)),
                      child: const Text('ثبت‌نام'),
                    ),
            ]),
          ),
        const SizedBox(height: 8),
        const Text(
          'ثبت‌نام دوره‌ها فعلاً فقط در همین صفحه ذخیره می‌شود؛ اتصال دائمی به دیتابیس در نسخه بعدی اضافه می‌شود.',
          style: TextStyle(color: C.muted, fontSize: 10.5, height: 1.8),
        ),
      ],
    );
  }
}
