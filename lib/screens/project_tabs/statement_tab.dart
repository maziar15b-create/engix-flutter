import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'tab_common.dart';

String fmtFa(double n) {
  final r = n.round();
  final neg = r < 0;
  final s = r.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('٬');
    b.write(s[i]);
  }
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  final out = b.toString().split('').map((c) {
    final d = int.tryParse(c);
    return d == null ? c : fa[d];
  }).join();
  return neg ? '-$out' : out;
}

class StatementTab extends StatefulWidget {
  final String projectId;
  final Map<String, dynamic> profile;
  const StatementTab({super.key, required this.projectId, required this.profile});
  @override
  State<StatementTab> createState() => _StatementTabState();
}

class _StatementTabState extends State<StatementTab> {
  List<Map<String, dynamic>>? _boq;
  List<Map<String, dynamic>>? _statements;
  String _view = 'list'; // list | boq | form
  dynamic _activeId;

  @override
  void initState() {
    super.initState();
    _refreshBoq();
    _refreshStatements();
  }

  Future<void> _refreshBoq() async {
    final d = await sb
        .from('project_boq_items')
        .select()
        .eq('project_id', widget.projectId)
        .order('order_index', ascending: true);
    if (mounted) setState(() => _boq = List<Map<String, dynamic>>.from(d));
  }

  Future<void> _refreshStatements() async {
    final d = await sb
        .from('project_statements')
        .select()
        .eq('project_id', widget.projectId)
        .order('statement_number', ascending: true);
    if (mounted) setState(() => _statements = List<Map<String, dynamic>>.from(d));
  }

  @override
  Widget build(BuildContext context) {
    if (_boq == null || _statements == null) return const TabLoading();
    if (_view == 'boq') {
      return _BoqEditor(
        projectId: widget.projectId,
        items: _boq!,
        onRefresh: _refreshBoq,
        onBack: () => setState(() => _view = 'list'),
      );
    }
    if (_view == 'form') {
      return _StatementForm(
        key: ValueKey('stmt-$_activeId'),
        projectId: widget.projectId,
        profile: widget.profile,
        boqItems: _boq!,
        statements: _statements!,
        statementId: _activeId,
        onBack: () {
          setState(() {
            _view = 'list';
            _activeId = null;
          });
          _refreshStatements();
        },
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const TabHeader('صورت‌وضعیت',
            subtitle:
                'صورتحساب پیشرفت کار بر اساس فهرست بهای قرارداد — هر دوره به‌طور خودکار با دوره‌ی قبل مقایسه می‌شود.'),
        Row(children: [
          Expanded(
              child: OutlinedButton(
                  onPressed: () => setState(() => _view = 'boq'),
                  child: Text('📋 فهرست بها (${_boq!.length} قلم)'))),
          const SizedBox(width: 8),
          Expanded(
              child: FilledButton(
                  onPressed: _boq!.isEmpty
                      ? null
                      : () => setState(() {
                            _activeId = null;
                            _view = 'form';
                          }),
                  child: const Text('+ صورت‌وضعیت جدید'))),
        ]),
        const SizedBox(height: 10),
        if (_boq!.isEmpty) const EmptyNote('اول باید فهرست بهای قرارداد را وارد کنید.'),
        const SizedBox(height: 6),
        const Text('تاریخچه‌ی صورت‌وضعیت‌ها',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.soft)),
        const SizedBox(height: 8),
        if (_statements!.isEmpty) const EmptyNote('هنوز صورت‌وضعیتی ثبت نشده.'),
        for (final s in _statements!)
          GestureDetector(
            onTap: () => setState(() {
              _activeId = s['id'];
              _view = 'form';
            }),
            child: TabCard(
              child: Row(children: [
                Expanded(
                    child: Text('صورت‌وضعیت شماره ${s['statement_number']}',
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600))),
                Text('${s['statement_date']}', style: const TextStyle(fontSize: 11, color: C.muted)),
              ]),
            ),
          ),
      ],
    );
  }
}

// ───────── ویرایش فهرست بها ─────────

class _BoqRow {
  final TextEditingController code;
  final TextEditingController desc;
  final TextEditingController unit;
  final TextEditingController qty;
  final TextEditingController price;
  _BoqRow({String c = '', String d = '', String u = '', String q = '', String p = ''})
      : code = TextEditingController(text: c),
        desc = TextEditingController(text: d),
        unit = TextEditingController(text: u),
        qty = TextEditingController(text: q),
        price = TextEditingController(text: p);
  void dispose() {
    code.dispose();
    desc.dispose();
    unit.dispose();
    qty.dispose();
    price.dispose();
  }
}

class _BoqEditor extends StatefulWidget {
  final String projectId;
  final List<Map<String, dynamic>> items;
  final Future<void> Function() onRefresh;
  final VoidCallback onBack;
  const _BoqEditor(
      {required this.projectId, required this.items, required this.onRefresh, required this.onBack});
  @override
  State<_BoqEditor> createState() => _BoqEditorState();
}

class _BoqEditorState extends State<_BoqEditor> {
  final List<_BoqRow> _rows = [];
  bool _saving = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    if (widget.items.isEmpty) {
      _rows.add(_BoqRow());
    } else {
      for (final i in widget.items) {
        _rows.add(_BoqRow(
          c: '${i['code'] ?? ''}',
          d: '${i['description'] ?? ''}',
          u: '${i['unit'] ?? ''}',
          q: i['contract_quantity'] == null ? '' : '${i['contract_quantity']}',
          p: i['unit_price'] == null ? '' : '${i['unit_price']}',
        ));
      }
    }
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = '';
    });
    try {
      await sb.from('project_boq_items').delete().eq('project_id', widget.projectId);
      final valid = _rows.where((r) => r.desc.text.trim().isNotEmpty).toList();
      if (valid.isNotEmpty) {
        await sb.from('project_boq_items').insert([
          for (var i = 0; i < valid.length; i++)
            {
              'project_id': widget.projectId,
              'code': valid[i].code.text.trim().isEmpty ? null : valid[i].code.text.trim(),
              'description': valid[i].desc.text.trim(),
              'unit': valid[i].unit.text.trim().isEmpty ? '-' : valid[i].unit.text.trim(),
              'contract_quantity':
                  valid[i].qty.text.trim().isEmpty ? null : numOf(valid[i].qty.text),
              'unit_price': numOf(valid[i].price.text),
              'order_index': i,
            }
        ]);
      }
      await widget.onRefresh();
      widget.onBack();
    } catch (e) {
      setState(() {
        _saving = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [TextButton(onPressed: widget.onBack, child: const Text('← بازگشت'))]),
        const TabHeader('فهرست بهای قرارداد',
            subtitle:
                'هر ردیف یک قلم از قرارداد است. اگر صورت‌وضعیتی قبلاً ثبت شده، تغییر قیمت واحد روی محاسبات آن اثر می‌گذارد.'),
        ErrorLine(_error),
        for (var i = 0; i < _rows.length; i++)
          TabCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: TextField(controller: _rows[i].code, decoration: hint('کد ردیف'))),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: TextField(controller: _rows[i].desc, decoration: hint('شرح'))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: _rows[i].unit, decoration: hint('واحد'))),
                const SizedBox(width: 8),
                Expanded(
                    child: TextField(
                        controller: _rows[i].qty,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: hint('مقدار قرارداد'))),
                const SizedBox(width: 8),
                Expanded(
                    child: TextField(
                        controller: _rows[i].price,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: hint('قیمت واحد (تومان)'))),
              ]),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                    onPressed: () => setState(() {
                          _rows[i].dispose();
                          _rows.removeAt(i);
                        }),
                    child: const Text('حذف ردیف', style: TextStyle(color: C.danger))),
              ),
            ]),
          ),
        OutlinedButton(
            onPressed: () => setState(() => _rows.add(_BoqRow())), child: const Text('+ افزودن قلم')),
        const SizedBox(height: 10),
        FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'در حال ذخیره...' : 'ذخیره فهرست بها')),
      ],
    );
  }
}

// ───────── فرم صورت‌وضعیت ─────────

class _StatementForm extends StatefulWidget {
  final String projectId;
  final Map<String, dynamic> profile;
  final List<Map<String, dynamic>> boqItems;
  final List<Map<String, dynamic>> statements;
  final dynamic statementId;
  final VoidCallback onBack;
  const _StatementForm(
      {super.key,
      required this.projectId,
      required this.profile,
      required this.boqItems,
      required this.statements,
      required this.statementId,
      required this.onBack});
  @override
  State<_StatementForm> createState() => _StatementFormState();
}

class _StatementFormState extends State<_StatementForm> {
  late final bool _viewing = widget.statementId != null;
  late final int _number;
  String _date = todayStr();
  final _ins = TextEditingController(text: '6.5');
  final _ret = TextEditingController(text: '10');
  final _vat = TextEditingController(text: '9');
  final _adv = TextEditingController(text: '0');
  final _advPct = TextEditingController(text: '0');
  final _other = TextEditingController(text: '0');
  final Map<String, TextEditingController> _qty = {};
  Map<String, double> _prevCum = {};
  bool _loading = true;
  bool _saving = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    for (final b in widget.boqItems) {
      _qty['${b['id']}'] = TextEditingController();
    }
    if (_viewing) {
      final s = widget.statements.firstWhere((x) => x['id'] == widget.statementId);
      _number = (s['statement_number'] as num).toInt();
    } else {
      _number = widget.statements.isEmpty
          ? 1
          : widget.statements
                  .map((s) => (s['statement_number'] as num).toInt())
                  .reduce((a, b) => a > b ? a : b) +
              1;
    }
    _load();
  }

  @override
  void dispose() {
    for (final c in [_ins, _ret, _vat, _adv, _advPct, _other, ..._qty.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      if (_viewing) {
        final stmt = await sb
            .from('project_statements')
            .select()
            .eq('id', widget.statementId)
            .maybeSingle();
        if (stmt != null) {
          _date = '${stmt['statement_date']}';
          _ins.text = '${stmt['insurance_percent']}';
          _ret.text = '${stmt['retention_percent']}';
          _vat.text = '${stmt['vat_percent']}';
          _adv.text = '${stmt['advance_balance']}';
          _advPct.text = '${stmt['advance_recovery_percent']}';
          _other.text = '${stmt['other_deductions']}';
        }
        final items = await sb
            .from('project_statement_items')
            .select()
            .eq('statement_id', widget.statementId);
        for (final it in items) {
          _qty['${it['boq_item_id']}']?.text = '${it['cumulative_quantity']}';
        }
      }
      final previous = widget.statements
          .where((s) => !_viewing || (s['statement_number'] as num) < _number)
          .toList()
        ..sort((a, b) => (b['statement_number'] as num).compareTo(a['statement_number'] as num));
      if (previous.isNotEmpty) {
        final prior = await sb
            .from('project_statement_items')
            .select()
            .eq('statement_id', previous.first['id']);
        final m = <String, double>{};
        for (final it in prior) {
          final boq = widget.boqItems.where((b) => b['id'] == it['boq_item_id']).toList();
          final price = boq.isEmpty ? 0.0 : ((boq.first['unit_price'] ?? 0) as num).toDouble();
          m['${it['boq_item_id']}'] = ((it['cumulative_quantity'] ?? 0) as num).toDouble() * price;
        }
        _prevCum = m;
      }
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  ({
    List<({Map<String, dynamic> item, double periodAmount})> rows,
    double gross,
    double ins,
    double ret,
    double vat,
    double adv,
    double other,
    double net,
  }) _calc() {
    var gross = 0.0;
    final rows = <({Map<String, dynamic> item, double periodAmount})>[];
    for (final item in widget.boqItems) {
      final cumQty = numOf(_qty['${item['id']}']!.text);
      final price = ((item['unit_price'] ?? 0) as num).toDouble();
      final period = cumQty * price - (_prevCum['${item['id']}'] ?? 0);
      gross += period;
      rows.add((item: item, periodAmount: period));
    }
    final ins = gross * (numOf(_ins.text) / 100);
    final ret = gross * (numOf(_ret.text) / 100);
    final vat = gross * (numOf(_vat.text) / 100);
    final maxAdv = numOf(_adv.text);
    final advRec = [maxAdv, gross * (numOf(_advPct.text) / 100)].reduce((a, b) => a < b ? a : b);
    final other = numOf(_other.text);
    final net = gross + vat - ins - ret - advRec - other;
    return (rows: rows, gross: gross, ins: ins, ret: ret, vat: vat, adv: advRec, other: other, net: net);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = '';
    });
    try {
      dynamic id = widget.statementId;
      final payload = {
        'project_id': widget.projectId,
        'statement_number': _number,
        'statement_date': _date,
        'insurance_percent': numOf(_ins.text),
        'retention_percent': numOf(_ret.text),
        'vat_percent': numOf(_vat.text),
        'advance_balance': numOf(_adv.text),
        'advance_recovery_percent': numOf(_advPct.text),
        'other_deductions': numOf(_other.text),
        'created_by': widget.profile['id'],
      };
      if (id != null) {
        await sb.from('project_statements').update(payload).eq('id', id);
        await sb.from('project_statement_items').delete().eq('statement_id', id);
      } else {
        final d = await sb.from('project_statements').insert(payload).select().single();
        id = d['id'];
      }
      final items = [
        for (final b in widget.boqItems)
          if (_qty['${b['id']}']!.text.trim().isNotEmpty)
            {
              'statement_id': id,
              'boq_item_id': b['id'],
              'cumulative_quantity': numOf(_qty['${b['id']}']!.text),
            }
      ];
      if (items.isNotEmpty) await sb.from('project_statement_items').insert(items);
      widget.onBack();
    } catch (e) {
      setState(() {
        _saving = false;
        _error = '$e';
      });
    }
  }

  Future<void> _delete() async {
    if (!await confirmDialog(context, 'این صورت‌وضعیت حذف شود؟')) return;
    await sb.from('project_statements').delete().eq('id', widget.statementId);
    widget.onBack();
  }

  Widget _pct(String label, TextEditingController c) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 11, color: C.soft)),
            const SizedBox(height: 4),
            TextField(
                controller: c,
                onChanged: (_) => setState(() {}),
                keyboardType: const TextInputType.numberWithOptions(decimal: true)),
          ]),
        ),
      );

  Widget _sum(String label, double v, {bool positive = false}) {
    final color = positive ? const Color(0xFF4ADE80) : (v < 0 ? const Color(0xFFE5484D) : C.text);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5, color: C.soft))),
        Text(fmtFa(v), style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const TabLoading();
    final calc = _calc();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [TextButton(onPressed: widget.onBack, child: const Text('← بازگشت'))]),
        TabHeader('صورت‌وضعیت شماره $_number'),
        ErrorLine(_error),
        DateField(label: 'تاریخ صورت‌وضعیت', value: _date, onChanged: (v) => setState(() => _date = v)),
        const SizedBox(height: 14),
        const Text('مقدار تجمعی هر قلم (تا این تاریخ)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.soft)),
        const SizedBox(height: 8),
        for (final r in calc.rows)
          TabCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  '${'${r.item['code'] ?? ''}'.isNotEmpty ? '[${r.item['code']}] ' : ''}${r.item['description']}',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              Text('(${r.item['unit']} — قیمت واحد: ${fmtFa(((r.item['unit_price'] ?? 0) as num).toDouble())})',
                  style: const TextStyle(fontSize: 11, color: C.muted)),
              const SizedBox(height: 8),
              TextField(
                  controller: _qty['${r.item['id']}'],
                  onChanged: (_) => setState(() {}),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: hint('مقدار تجمعی انجام‌شده')),
              const SizedBox(height: 6),
              Text('مبلغ این دوره: ${fmtFa(r.periodAmount)} تومان',
                  style: const TextStyle(fontSize: 12, color: C.redLight)),
            ]),
          ),
        const SizedBox(height: 8),
        const Text('کسورات و اضافات',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.soft)),
        const SizedBox(height: 8),
        Row(children: [_pct('بیمه (٪ کسر)', _ins), _pct('حسن انجام کار (٪ کسر)', _ret)]),
        const SizedBox(height: 8),
        Row(children: [_pct('ارزش‌افزوده (٪ اضافه)', _vat), _pct('سایر کسورات (مبلغ ثابت)', _other)]),
        const SizedBox(height: 8),
        Row(children: [_pct('مانده پیش‌پرداخت', _adv), _pct('بازپرداخت پیش‌پرداخت (٪)', _advPct)]),
        const SizedBox(height: 14),
        TabCard(
          borderColor: C.red,
          child: Column(children: [
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text('خلاصه‌ی صورت‌وضعیت',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.redLight)),
            ),
            const SizedBox(height: 6),
            _sum('مبلغ ناخالص این دوره', calc.gross),
            _sum('+ مالیات ارزش‌افزوده', calc.vat, positive: true),
            _sum('- کسر بیمه', -calc.ins),
            _sum('- کسر حسن انجام کار', -calc.ret),
            _sum('- بازپرداخت پیش‌پرداخت', -calc.adv),
            _sum('- سایر کسورات', -calc.other),
            const Divider(color: Color(0x33C50337)),
            Row(children: [
              const Expanded(
                  child: Text('مبلغ قابل پرداخت',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800))),
              Text('${fmtFa(calc.net)} تومان',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800, color: C.redLight)),
            ]),
          ]),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'در حال ذخیره...' : 'ذخیره صورت‌وضعیت'))),
          if (_viewing) ...[
            const SizedBox(width: 8),
            OutlinedButton(
                onPressed: _delete, child: const Text('حذف', style: TextStyle(color: C.danger))),
          ],
        ]),
      ],
    );
  }
}
