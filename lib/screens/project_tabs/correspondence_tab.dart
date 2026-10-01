import 'package:flutter/material.dart';
import '../../core/theme.dart';
import 'tab_common.dart';

class CorrespondenceTab extends StatefulWidget {
  final String projectId;
  final Map<String, dynamic> profile;
  const CorrespondenceTab({super.key, required this.projectId, required this.profile});
  @override
  State<CorrespondenceTab> createState() => _CorrespondenceTabState();
}

class _CorrespondenceTabState extends State<CorrespondenceTab> {
  List<Map<String, dynamic>>? _items;
  bool _adding = false;
  String _direction = 'outgoing';
  String _date = todayStr();
  String? _filter;
  String _error = '';
  final _number = TextEditingController();
  final _subject = TextEditingController();
  final _counter = TextEditingController();
  final _content = TextEditingController();

  static const _green = Color(0xFF4ADE80);
  static const _amber = Color(0xFFFBBF24);

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    for (final c in [_number, _subject, _counter, _content]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _refresh() async {
    final d = await sb
        .from('project_correspondence')
        .select()
        .eq('project_id', widget.projectId)
        .order('correspondence_date', ascending: false);
    if (mounted) setState(() => _items = List<Map<String, dynamic>>.from(d));
  }

  String? _n(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    if (_subject.text.trim().isEmpty) {
      setState(() => _error = 'موضوع نامه را وارد کنید.');
      return;
    }
    setState(() => _error = '');
    try {
      await sb.from('project_correspondence').insert({
        'project_id': widget.projectId,
        'direction': _direction,
        'letter_number': _n(_number),
        'subject': _subject.text.trim(),
        'correspondence_date': _date,
        'counterparty': _n(_counter),
        'content': _n(_content),
        'created_by': widget.profile['id'],
      });
    } catch (e) {
      setState(() => _error = '$e');
      return;
    }
    for (final c in [_number, _subject, _counter, _content]) {
      c.clear();
    }
    setState(() => _adding = false);
    _refresh();
  }

  Future<void> _delete(dynamic id) async {
    if (!await confirmDialog(context, 'این نامه حذف شود؟')) return;
    await sb.from('project_correspondence').delete().eq('id', id);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (_items == null) return const TabLoading();
    final list = _filter == null ? _items! : _items!.where((i) => i['direction'] == _filter).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const TabHeader('نامه‌نگاری / مکاتبات رسمی', subtitle: 'ثبت نامه‌های وارده و صادره‌ی پروژه.'),
        Row(children: [
          Expanded(child: ChoiceChipBtn(label: 'همه', active: _filter == null, onTap: () => setState(() => _filter = null))),
          const SizedBox(width: 6),
          Expanded(child: ChoiceChipBtn(label: 'وارده', active: _filter == 'incoming', color: _green, onTap: () => setState(() => _filter = 'incoming'))),
          const SizedBox(width: 6),
          Expanded(child: ChoiceChipBtn(label: 'صادره', active: _filter == 'outgoing', color: _amber, onTap: () => setState(() => _filter = 'outgoing'))),
        ]),
        const SizedBox(height: 14),
        if (!_adding)
          FilledButton(onPressed: () => setState(() => _adding = true), child: const Text('+ ثبت نامه جدید'))
        else
          TabCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ErrorLine(_error),
              Row(children: [
                Expanded(child: ChoiceChipBtn(label: '↓ وارده', active: _direction == 'incoming', color: _green, onTap: () => setState(() => _direction = 'incoming'))),
                const SizedBox(width: 8),
                Expanded(child: ChoiceChipBtn(label: '↑ صادره', active: _direction == 'outgoing', color: _amber, onTap: () => setState(() => _direction = 'outgoing'))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: _number, decoration: hint('شماره نامه'))),
                const SizedBox(width: 8),
                Expanded(child: DateField(label: 'تاریخ', value: _date, onChanged: (v) => setState(() => _date = v))),
              ]),
              const SizedBox(height: 8),
              TextField(controller: _subject, decoration: hint('موضوع نامه')),
              const SizedBox(height: 8),
              TextField(controller: _counter, decoration: hint('طرف مقابل (شرکت/شخص)')),
              const SizedBox(height: 8),
              TextField(controller: _content, maxLines: 4, decoration: hint('متن یا خلاصه‌ی نامه...')),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: FilledButton(onPressed: _save, child: const Text('ثبت'))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton(onPressed: () => setState(() => _adding = false), child: const Text('لغو'))),
              ]),
            ]),
          ),
        const SizedBox(height: 14),
        if (list.isEmpty) const EmptyNote('نامه‌ای ثبت نشده.'),
        for (final i in list)
          TabCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('${i['subject']}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600))),
                Text(i['direction'] == 'incoming' ? 'وارده' : 'صادره',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: i['direction'] == 'incoming' ? _green : _amber)),
              ]),
              if ((i['counterparty'] ?? '').toString().isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 3), child: Text('${i['counterparty']}', style: const TextStyle(fontSize: 12, color: C.soft))),
              if ((i['content'] ?? '').toString().isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 6), child: Text('${i['content']}', style: const TextStyle(fontSize: 12.5))),
              Row(children: [
                Expanded(
                  child: Text(
                      '${(i['letter_number'] ?? '').toString().isNotEmpty ? 'شماره ${i['letter_number']} — ' : ''}${i['correspondence_date']}',
                      style: const TextStyle(fontSize: 11, color: C.muted)),
                ),
                TextButton(onPressed: () => _delete(i['id']), child: const Text('حذف', style: TextStyle(color: C.danger))),
              ]),
            ]),
          ),
      ],
    );
  }
}
