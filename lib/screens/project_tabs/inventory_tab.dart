import 'package:flutter/material.dart';
import '../../core/theme.dart';
import 'tab_common.dart';

class InventoryTab extends StatefulWidget {
  final String projectId;
  final Map<String, dynamic> profile;
  const InventoryTab({super.key, required this.projectId, required this.profile});
  @override
  State<InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<InventoryTab> {
  List<Map<String, dynamic>>? _tx;
  bool _adding = false;
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _unit = TextEditingController();
  final _qty = TextEditingController();
  final _notes = TextEditingController();
  final _search = TextEditingController();
  String _type = 'in';
  String _date = todayStr();
  String _error = '';
  String? _filterKey;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    for (final c in [_code, _name, _unit, _qty, _notes, _search]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _refresh() async {
    final d = await sb
        .from('project_inventory_transactions')
        .select()
        .eq('project_id', widget.projectId)
        .order('transaction_date', ascending: false)
        .order('created_at', ascending: false);
    if (mounted) setState(() => _tx = List<Map<String, dynamic>>.from(d));
  }

  String _key(Map<String, dynamic> t) =>
      '${t['material_code'] ?? ''}|${t['material_name']}|${t['unit']}';

  Map<String, Map<String, dynamic>> get _balances {
    final map = <String, Map<String, dynamic>>{};
    for (final t in _tx ?? const <Map<String, dynamic>>[]) {
      final k = _key(t);
      map.putIfAbsent(
          k,
          () => {
                'material_code': t['material_code'] ?? '',
                'material_name': t['material_name'],
                'unit': t['unit'],
                'balance': 0.0,
              });
      final q = ((t['quantity'] ?? 0) as num).toDouble();
      map[k]!['balance'] = (map[k]!['balance'] as double) + (t['transaction_type'] == 'in' ? q : -q);
    }
    return map;
  }

  Future<void> _add() async {
    if (_name.text.trim().isEmpty || _unit.text.trim().isEmpty || _qty.text.trim().isEmpty) {
      setState(() => _error = 'نام مصالح، واحد و مقدار را وارد کنید.');
      return;
    }
    setState(() => _error = '');
    try {
      await sb.from('project_inventory_transactions').insert({
        'project_id': widget.projectId,
        'material_code': _code.text.trim().isEmpty ? null : _code.text.trim(),
        'material_name': _name.text.trim(),
        'unit': _unit.text.trim(),
        'transaction_type': _type,
        'quantity': numOf(_qty.text),
        'transaction_date': _date,
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        'created_by': widget.profile['id'],
      });
    } catch (e) {
      setState(() => _error = '$e');
      return;
    }
    for (final c in [_code, _name, _unit, _qty, _notes]) {
      c.clear();
    }
    setState(() => _adding = false);
    _refresh();
  }

  Future<void> _delete(dynamic id) async {
    if (!await confirmDialog(context, 'این تراکنش حذف شود؟ این کار غیرقابل بازگشت است.')) return;
    await sb.from('project_inventory_transactions').delete().eq('id', id);
    _refresh();
  }

  String _q(String s) => '"${s.replaceAll('"', '""')}"';

  Future<void> _exportCsv() async {
    final lines = <String>[
      ['تاریخ', 'کد کالا', 'نام مصالح', 'نوع', 'مقدار', 'واحد', 'یادداشت'].join(',')
    ];
    for (final t in _tx!) {
      lines.add([
        faDate(t['transaction_date']),
        _q('${t['material_code'] ?? ''}'),
        _q('${t['material_name']}'),
        t['transaction_type'] == 'in' ? 'ورود' : 'خروج',
        '${t['quantity']}',
        '${t['unit']}',
        _q('${t['notes'] ?? ''}'),
      ].join(','));
    }
    lines.add('');
    lines.add('موجودی فعلی:');
    lines.add(['کد کالا', 'نام مصالح', 'واحد', 'موجودی'].join(','));
    for (final b in _balances.values) {
      lines.add([
        _q('${b['material_code']}'),
        _q('${b['material_name']}'),
        '${b['unit']}',
        fmtNum(b['balance'] as double, 3),
      ].join(','));
    }
    await shareTextFile('کنترل-انبار.csv', '\uFEFF${lines.join('\n')}');
  }

  @override
  Widget build(BuildContext context) {
    if (_tx == null) return const TabLoading();
    final q = _search.text.trim().toLowerCase();
    final balances = _balances.entries.where((e) {
      if (q.isEmpty) return true;
      final b = e.value;
      return '${b['material_name']}'.toLowerCase().contains(q) ||
          '${b['material_code']}'.toLowerCase().contains(q);
    }).toList();
    final filteredTx = _filterKey == null ? _tx! : _tx!.where((t) => _key(t) == _filterKey).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const TabHeader('کنترل موجودی / مصالح انبار',
            subtitle: 'ورود و خروج مصالح کارگاه، با موجودی لحظه‌ای برای هر قلم.'),
        TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: hint('🔍 جستجو با نام یا کد کالا...')),
        const SizedBox(height: 14),
        const Text('موجودی فعلی',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.soft)),
        const SizedBox(height: 8),
        if (balances.isEmpty)
          EmptyNote(q.isNotEmpty ? 'چیزی با این نام/کد پیدا نشد.' : 'هنوز تراکنشی ثبت نشده.'),
        for (final e in balances)
          GestureDetector(
            onTap: () => setState(() => _filterKey = _filterKey == e.key ? null : e.key),
            child: TabCard(
              borderColor: _filterKey == e.key ? C.red : null,
              child: Row(children: [
                Expanded(
                  child: Text(
                      '${e.value['material_name']}${(e.value['material_code'] ?? '').toString().isNotEmpty ? '  [${e.value['material_code']}]' : ''}',
                      style: const TextStyle(fontSize: 13.5)),
                ),
                Text('${fmtNum(e.value['balance'] as double, 3)} ${e.value['unit']}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: C.redLight, fontSize: 13.5)),
              ]),
            ),
          ),
        const SizedBox(height: 8),
        Row(children: [
          if (!_adding)
            Expanded(
                child: FilledButton(
                    onPressed: () => setState(() => _adding = true),
                    child: const Text('+ ثبت ورود/خروج مصالح'))),
          if (!_adding) const SizedBox(width: 8),
          Expanded(
              child: OutlinedButton(
                  onPressed: _tx!.isEmpty ? null : _exportCsv, child: const Text('📊 خروجی اکسل'))),
        ]),
        if (_adding) ...[
          const SizedBox(height: 10),
          TabCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ErrorLine(_error),
              Row(children: [
                Expanded(
                    child: ChoiceChipBtn(
                        label: '↓ ورود',
                        active: _type == 'in',
                        color: const Color(0xFF4ADE80),
                        onTap: () => setState(() => _type = 'in'))),
                const SizedBox(width: 8),
                Expanded(
                    child: ChoiceChipBtn(
                        label: '↑ خروج / مصرف',
                        active: _type == 'out',
                        color: const Color(0xFFFBBF24),
                        onTap: () => setState(() => _type = 'out'))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: _code, decoration: hint('کد کالا (اختیاری)'))),
                const SizedBox(width: 8),
                Expanded(
                    flex: 2,
                    child: TextField(controller: _name, decoration: hint('نام مصالح (مثلاً: سیمان تیپ ۲)'))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: _unit, decoration: hint('واحد (کیسه، متر مکعب، عدد...)'))),
                const SizedBox(width: 8),
                Expanded(
                    child: TextField(
                        controller: _qty,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: hint('مقدار'))),
              ]),
              const SizedBox(height: 8),
              DateField(label: 'تاریخ', value: _date, onChanged: (v) => setState(() => _date = v)),
              const SizedBox(height: 8),
              TextField(controller: _notes, decoration: hint('یادداشت (تأمین‌کننده، محل مصرف و...)')),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: FilledButton(onPressed: _add, child: const Text('ثبت'))),
                const SizedBox(width: 8),
                Expanded(
                    child: OutlinedButton(
                        onPressed: () => setState(() => _adding = false), child: const Text('لغو'))),
              ]),
            ]),
          ),
        ],
        const SizedBox(height: 16),
        Text(_filterKey == null ? 'تاریخچه‌ی تراکنش‌ها' : 'تاریخچه‌ی قلم انتخاب‌شده',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.soft)),
        const SizedBox(height: 8),
        if (filteredTx.isEmpty) const EmptyNote('تراکنشی وجود ندارد.'),
        for (final t in filteredTx)
          TabCard(
            child: Row(children: [
              Icon(t['transaction_type'] == 'in' ? Icons.arrow_downward : Icons.arrow_upward,
                  size: 16,
                  color: t['transaction_type'] == 'in'
                      ? const Color(0xFF4ADE80)
                      : const Color(0xFFFBBF24)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${t['material_name']} — ${fmtNum((t['quantity'] as num).toDouble(), 3)} ${t['unit']}',
                      style: const TextStyle(fontSize: 13)),
                  Text(
                      '${faDate(t['transaction_date'])}${(t['notes'] ?? '').toString().isNotEmpty ? ' — ${t['notes']}' : ''}',
                      style: const TextStyle(fontSize: 11, color: C.muted)),
                ]),
              ),
              IconButton(
                  onPressed: () => _delete(t['id']),
                  icon: const Icon(Icons.delete_outline, size: 18, color: C.danger)),
            ]),
          ),
      ],
    );
  }
}
