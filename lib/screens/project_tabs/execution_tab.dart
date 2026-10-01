import 'package:flutter/material.dart';
import '../../core/theme.dart';
import 'tab_common.dart';

const _defaultChecklist = [
  'پیاده‌سازی و پی‌کنی',
  'آرماتوربندی فونداسیون',
  'قالب‌بندی',
  'بتن‌ریزی',
  'عمل‌آوری بتن',
  'اجرای اسکلت',
];

class ExecutionTab extends StatefulWidget {
  final String projectId;
  const ExecutionTab({super.key, required this.projectId});
  @override
  State<ExecutionTab> createState() => _ExecutionTabState();
}

class _ExecutionTabState extends State<ExecutionTab> {
  final _new = TextEditingController();
  List<Map<String, dynamic>>? _items;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _new.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetch() async {
    final d = await sb
        .from('checklist_items')
        .select()
        .eq('project_id', widget.projectId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(d);
  }

  Future<void> _refresh() async {
    var data = await _fetch();
    if (data.isEmpty) {
      await sb.from('checklist_items').insert([
        for (final t in _defaultChecklist) {'project_id': widget.projectId, 'text': t}
      ]);
      data = await _fetch();
    }
    if (mounted) setState(() => _items = data);
  }

  Future<void> _toggle(Map<String, dynamic> it) async {
    await sb.from('checklist_items').update({'done': !(it['done'] == true)}).eq('id', it['id']);
    _refresh();
  }

  Future<void> _add() async {
    final t = _new.text.trim();
    if (t.isEmpty) return;
    await sb.from('checklist_items').insert({'project_id': widget.projectId, 'text': t});
    _new.clear();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (_items == null) return const TabLoading();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const TabHeader('چک‌لیست اجرایی کارگاه',
            subtitle: 'این چک‌لیست بین همه‌ی اعضای پروژه مشترک است.'),
        for (final it in _items!)
          InkWell(
            onTap: () => _toggle(it),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0x1AC50337)))),
              child: Row(children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: it['done'] == true ? C.red : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: C.red, width: 1.5),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('${it['text']}',
                      style: TextStyle(
                          fontSize: 14,
                          color: it['done'] == true ? C.muted : C.text,
                          decoration:
                              it['done'] == true ? TextDecoration.lineThrough : null)),
                ),
              ]),
            ),
          ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
              child: TextField(
                  controller: _new,
                  onSubmitted: (_) => _add(),
                  decoration: hint('افزودن مرحله جدید...'))),
          const SizedBox(width: 8),
          FilledButton(onPressed: _add, child: const Text('افزودن')),
        ]),
      ],
    );
  }
}
