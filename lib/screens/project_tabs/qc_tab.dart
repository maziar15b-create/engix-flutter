import 'package:flutter/material.dart';
import '../../core/theme.dart';
import 'tab_common.dart';

const _defaultQc = <Map<String, dynamic>>[
  {'phase': 'خاکبرداری و پی‌کنی', 'items': ['تراز و ابعاد گود مطابق نقشه', 'مقاومت خاک بستر بررسی شده', 'زهکشی/جمع‌آوری آب گود']},
  {'phase': 'فونداسیون', 'items': ['آرماتوربندی مطابق نقشه و کاور مناسب', 'تراز و شاقولی قالب‌بندی', 'کیفیت بتن و عیار مناسب', 'عمل‌آوری بتن']},
  {'phase': 'اسکلت', 'items': ['شاقولی و تراز ستون‌ها', 'آرماتوربندی تیر و ستون مطابق نقشه', 'اتصالات و جوشکاری (در صورت فلزی بودن)']},
  {'phase': 'سفت‌کاری', 'items': ['دیوارچینی شاقول و تراز', 'اجرای صحیح بازشوها (در و پنجره)']},
  {'phase': 'نازک‌کاری', 'items': ['کیفیت گچ‌کاری و سفیدکاری', 'کاشی/سرامیک بدون کجی و درزبندی یکنواخت', 'رنگ‌آمیزی یکدست']},
  {'phase': 'تأسیسات', 'items': ['تست فشار لوله‌کشی آب', 'تست نشتی لوله‌کشی گاز', 'سیم‌کشی برق مطابق استاندارد و ایمنی']},
];

class QcTab extends StatefulWidget {
  final String projectId;
  final Map<String, dynamic> profile;
  const QcTab({super.key, required this.projectId, required this.profile});
  @override
  State<QcTab> createState() => _QcTabState();
}

class _QcTabState extends State<QcTab> {
  List<Map<String, dynamic>>? _items;
  final _phase = TextEditingController();
  final _itemText = TextEditingController();
  final _noteCtl = TextEditingController();
  dynamic _activeNotesId;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _phase.dispose();
    _itemText.dispose();
    _noteCtl.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetch() async {
    final d = await sb
        .from('project_qc_items')
        .select()
        .eq('project_id', widget.projectId)
        .order('order_index');
    return List<Map<String, dynamic>>.from(d);
  }

  Future<void> _refresh() async {
    var data = await _fetch();
    if (data.isEmpty) {
      final rows = <Map<String, dynamic>>[];
      var idx = 0;
      for (final g in _defaultQc) {
        for (final t in (g['items'] as List)) {
          rows.add({
            'project_id': widget.projectId,
            'phase': g['phase'],
            'item_text': t,
            'order_index': idx++,
          });
        }
      }
      await sb.from('project_qc_items').insert(rows);
      data = await _fetch();
    }
    if (mounted) setState(() => _items = data);
  }

  Future<void> _setStatus(Map<String, dynamic> item, String status) async {
    await sb.from('project_qc_items').update({
      'status': status,
      'inspected_by': widget.profile['id'],
      'inspected_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', item['id']);
    _refresh();
  }

  Future<void> _saveNote(Map<String, dynamic> item) async {
    await sb.from('project_qc_items').update({'notes': _noteCtl.text}).eq('id', item['id']);
    setState(() => _activeNotesId = null);
    _refresh();
  }

  Future<void> _addItem() async {
    if (_phase.text.trim().isEmpty || _itemText.text.trim().isEmpty) return;
    var maxOrder = 0;
    for (final i in _items ?? const <Map<String, dynamic>>[]) {
      final o = ((i['order_index'] ?? 0) as num).toInt();
      if (o > maxOrder) maxOrder = o;
    }
    await sb.from('project_qc_items').insert({
      'project_id': widget.projectId,
      'phase': _phase.text.trim(),
      'item_text': _itemText.text.trim(),
      'order_index': maxOrder + 1,
    });
    _itemText.clear();
    _refresh();
  }

  Future<void> _remove(dynamic id) async {
    if (!await confirmDialog(context, 'این آیتم حذف شود؟')) return;
    await sb.from('project_qc_items').delete().eq('id', id);
    _refresh();
  }

  Widget _badge(String? status) {
    late String label;
    late Color color;
    switch (status) {
      case 'pass':
        label = 'قبول';
        color = const Color(0xFF4ADE80);
        break;
      case 'fail':
        label = 'مردود';
        color = const Color(0xFFF87171);
        break;
      default:
        label = 'در انتظار';
        color = C.muted;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_items == null) return const TabLoading();
    final items = _items!;
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final it in items) {
      grouped.putIfAbsent('${it['phase']}', () => []).add(it);
    }
    final passed = items.where((i) => i['status'] == 'pass').length;
    final failed = items.where((i) => i['status'] == 'fail').length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const TabHeader('چک‌لیست کنترل کیفیت',
            subtitle: 'بازرسی هر مرحله را ثبت کنید — قبول، مردود، یا در انتظار بازرسی.'),
        Row(children: [
          MiniStat('کل موارد', '${items.length}'),
          MiniStat('قبول', '$passed', color: const Color(0xFF4ADE80)),
          MiniStat('مردود', '$failed', color: const Color(0xFFF87171)),
        ]),
        const SizedBox(height: 16),
        for (final e in grouped.entries) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 4),
            child: Text(e.key,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.redLight)),
          ),
          for (final item in e.value)
            TabCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                      child: Text('${item['item_text']}', style: const TextStyle(fontSize: 13.5))),
                  _badge(item['status'] as String?),
                ]),
                if ((item['notes'] ?? '').toString().isNotEmpty && _activeNotesId != item['id'])
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('یادداشت: ${item['notes']}',
                        style: const TextStyle(fontSize: 12, color: C.soft)),
                  ),
                Wrap(spacing: 4, children: [
                  TextButton(
                      onPressed: () => _setStatus(item, 'pass'),
                      child: const Text('✓ قبول', style: TextStyle(color: Color(0xFF4ADE80)))),
                  TextButton(
                      onPressed: () => _setStatus(item, 'fail'),
                      child: const Text('✗ مردود', style: TextStyle(color: Color(0xFFF87171)))),
                  TextButton(
                      onPressed: () {
                        setState(() => _activeNotesId = item['id']);
                        _noteCtl.text = (item['notes'] ?? '').toString();
                      },
                      child: const Text('📝 یادداشت')),
                  TextButton(
                      onPressed: () => _remove(item['id']),
                      child: const Text('حذف', style: TextStyle(color: C.danger))),
                ]),
                if (_activeNotesId == item['id'])
                  Row(children: [
                    Expanded(child: TextField(controller: _noteCtl, decoration: hint('یادداشت بازرسی...'))),
                    const SizedBox(width: 8),
                    FilledButton(onPressed: () => _saveNote(item), child: const Text('ذخیره')),
                  ]),
              ]),
            ),
        ],
        const SizedBox(height: 10),
        TabCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('افزودن آیتم جدید',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.soft)),
            const SizedBox(height: 8),
            TextField(controller: _phase, decoration: hint('مرحله (مثلاً: تأسیسات)')),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: _itemText, decoration: hint('متن آیتم بازرسی'))),
              const SizedBox(width: 8),
              FilledButton(onPressed: _addItem, child: const Text('افزودن')),
            ]),
          ]),
        ),
      ],
    );
  }
}
