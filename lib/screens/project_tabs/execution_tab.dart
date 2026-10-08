import 'package:flutter/material.dart';

import '../../core/notify.dart';
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

const _priorities = <String, List<dynamic>>{
  'high': ['فوری', Color(0xFFE5484D)],
  'normal': ['عادی', Color(0xFF4FC3F7)],
  'low': ['کم‌اهمیت', Color(0xFF9AA5B8)],
};

class ExecutionTab extends StatefulWidget {
  final String projectId;
  final Map<String, dynamic> profile;
  final List<Map<String, dynamic>> members;
  const ExecutionTab({
    super.key,
    required this.projectId,
    required this.profile,
    this.members = const [],
  });
  @override
  State<ExecutionTab> createState() => _ExecutionTabState();
}

class _ExecutionTabState extends State<ExecutionTab> {
  List<Map<String, dynamic>>? _items;
  String _filter = 'all'; // all | open | done

  String get _uid => widget.profile['id'].toString();

  String _memberName(dynamic id) {
    if (id == null) return '';
    for (final m in widget.members) {
      if (m['user_id'].toString() == id.toString()) {
        return ((m['profile'] as Map?)?['name'] ?? '').toString();
      }
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    _refresh();
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
    try {
      var data = await _fetch();
      if (data.isEmpty) {
        await sb.from('checklist_items').insert([
          for (final t in _defaultChecklist) {'project_id': widget.projectId, 'text': t}
        ]);
        data = await _fetch();
      }
      if (mounted) setState(() => _items = data);
    } catch (e) {
      if (mounted) {
        setState(() => _items = _items ?? []);
        snack(context, 'خطا در دریافت کارها: $e');
      }
    }
  }

  Future<void> _toggle(Map<String, dynamic> it) async {
    final done = !(it['done'] == true);
    try {
      await sb.from('checklist_items').update({
        'done': done,
        'done_at': done ? DateTime.now().toUtc().toIso8601String() : null,
      }).eq('id', it['id']);
    } catch (_) {
      await sb.from('checklist_items').update({'done': done}).eq('id', it['id']);
    }
    _refresh();
  }

  Future<void> _delete(Map<String, dynamic> it) async {
    if (!await confirmDialog(context, 'این کار حذف شود؟')) return;
    try {
      final res = await sb.from('checklist_items').delete().eq('id', it['id']).select();
      if (res.isEmpty && mounted) snack(context, 'اجازه‌ی حذف ندارید.');
    } catch (e) {
      if (mounted) snack(context, 'خطا: $e');
    }
    _refresh();
  }

  Future<void> _openForm() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg2,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _TaskForm(
          projectId: widget.projectId,
          profile: widget.profile,
          members: widget.members,
        ),
      ),
    );
    if (ok == true) _refresh();
  }

  bool _overdue(Map<String, dynamic> it) {
    final d = it['due_date']?.toString();
    if (d == null || d.isEmpty || it['done'] == true) return false;
    return daysBetween(todayStr(), d) < 0;
  }

  @override
  Widget build(BuildContext context) {
    final all = _items;
    if (all == null) return const TabLoading();
    final done = all.where((x) => x['done'] == true).length;
    final list = all.where((x) {
      if (_filter == 'open') return x['done'] != true;
      if (_filter == 'done') return x['done'] == true;
      return true;
    }).toList();
    final overdue = all.where(_overdue).length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: C.red,
        foregroundColor: Colors.white,
        onPressed: _openForm,
        icon: const Icon(Icons.add_task),
        label: const Text('کار اجرایی'),
      ),
      body: RefreshIndicator(
        color: C.red,
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          children: [
            const TabHeader('کارهای اجرایی کارگاه',
                subtitle: 'فهرست کارهای پروژه با مسئول و مهلت؛ مشترک بین همه‌ی اعضا.'),
            Row(children: [
              MiniStat('کل', faDigits(all.length)),
              MiniStat('انجام‌شده', faDigits(done), color: const Color(0xFF2ED573)),
              MiniStat('معوق', faDigits(overdue), color: C.danger),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              ChoiceChipBtn(
                  label: 'همه', active: _filter == 'all', onTap: () => setState(() => _filter = 'all')),
              const SizedBox(width: 8),
              ChoiceChipBtn(
                  label: 'انجام نشده',
                  active: _filter == 'open',
                  onTap: () => setState(() => _filter = 'open')),
              const SizedBox(width: 8),
              ChoiceChipBtn(
                  label: 'انجام شده',
                  active: _filter == 'done',
                  onTap: () => setState(() => _filter = 'done')),
            ]),
            const SizedBox(height: 12),
            if (list.isEmpty) const EmptyNote('کاری در این فهرست نیست.'),
            for (final it in list) _row(it),
          ],
        ),
      ),
    );
  }

  Widget _row(Map<String, dynamic> it) {
    final isDone = it['done'] == true;
    final pr = _priorities[it['priority'] ?? 'normal'] ?? _priorities['normal']!;
    final over = _overdue(it);
    final assignee = _memberName(it['assignee_id']);
    final due = it['due_date']?.toString() ?? '';
    final desc = (it['description'] ?? '').toString();
    return TabCard(
      borderColor: over ? C.danger.withAlpha(120) : null,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: () => _toggle(it),
          child: Padding(
            padding: const EdgeInsets.only(top: 2, left: 10),
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isDone ? C.red : Colors.transparent,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: C.red, width: 1.5),
              ),
              child: isDone ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
            ),
          ),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${it['text']}',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDone ? C.muted : C.text,
                    decoration: isDone ? TextDecoration.lineThrough : null)),
            if (desc.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(desc, style: const TextStyle(fontSize: 12, color: C.soft, height: 1.6)),
              ),
            const SizedBox(height: 6),
            Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              if ((it['priority'] ?? 'normal') != 'normal')
                Text(pr[0] as String,
                    style: TextStyle(fontSize: 11, color: pr[1] as Color, fontWeight: FontWeight.w700)),
              if (assignee.isNotEmpty)
                Text('👤 $assignee', style: const TextStyle(fontSize: 11, color: C.soft)),
              if (due.isNotEmpty)
                Text(
                  '📅 ${faDate(due)}${over ? ' (معوق)' : ''}',
                  style: TextStyle(fontSize: 11, color: over ? C.danger : C.soft),
                ),
            ]),
          ]),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.delete_outline, size: 18, color: C.muted),
          onPressed: () => _delete(it),
        ),
      ]),
    );
  }
}

class _TaskForm extends StatefulWidget {
  final String projectId;
  final Map<String, dynamic> profile;
  final List<Map<String, dynamic>> members;
  const _TaskForm(
      {required this.projectId, required this.profile, required this.members});

  @override
  State<_TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<_TaskForm> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  String _priority = 'normal';
  String? _due;
  String? _assignee;
  bool _busy = false;
  String _error = '';

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final d = await pickDateStr(context, _due ?? todayStr());
    if (d != null) setState(() => _due = d);
  }

  Future<void> _save() async {
    final t = _title.text.trim();
    if (t.isEmpty) {
      setState(() => _error = 'عنوان کار را وارد کنید.');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await sb.from('checklist_items').insert({
        'project_id': widget.projectId,
        'text': t,
        if (_desc.text.trim().isNotEmpty) 'description': _desc.text.trim(),
        'priority': _priority,
        if (_due != null) 'due_date': _due,
        if (_assignee != null) 'assignee_id': _assignee,
        'created_by': widget.profile['id'],
      });
      if (_assignee != null && _assignee != widget.profile['id'].toString()) {
        notifyUsers([_assignee], 'project_update', 'کار اجرایی جدید برای شما', t);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'ثبت کار ناموفق بود: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Center(
              child: Text('کار اجرایی جدید',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
          const SizedBox(height: 14),
          TextField(controller: _title, decoration: hint('عنوان کار *')),
          const SizedBox(height: 10),
          TextField(
              controller: _desc,
              minLines: 2,
              maxLines: 5,
              decoration: hint('توضیحات (اختیاری)')),
          const SizedBox(height: 12),
          const Text('اولویت', style: TextStyle(fontSize: 11, color: C.soft)),
          const SizedBox(height: 6),
          Row(children: [
            for (final e in _priorities.entries) ...[
              ChoiceChipBtn(
                label: e.value[0] as String,
                color: e.value[1] as Color,
                active: _priority == e.key,
                onTap: () => setState(() => _priority = e.key),
              ),
              const SizedBox(width: 8),
            ],
          ]),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickDue,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              decoration: BoxDecoration(
                color: C.bg1,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x33FFFFFF)),
              ),
              child: Row(children: [
                const Icon(Icons.event, size: 16, color: C.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_due == null ? 'مهلت انجام (اختیاری)' : 'مهلت: ${faDate(_due)}',
                      style: const TextStyle(fontSize: 13.5)),
                ),
                if (_due != null)
                  GestureDetector(
                      onTap: () => setState(() => _due = null),
                      child: const Icon(Icons.close, size: 16, color: C.muted)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            value: _assignee,
            dropdownColor: C.bg2,
            decoration: const InputDecoration(labelText: 'مسئول انجام (اختیاری)'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('بدون مسئول')),
              for (final m in widget.members)
                DropdownMenuItem<String?>(
                  value: m['user_id'].toString(),
                  child: Text(((m['profile'] as Map?)?['name'] ?? 'کاربر').toString()),
                ),
            ],
            onChanged: (v) => setState(() => _assignee = v),
          ),
          const SizedBox(height: 12),
          ErrorLine(_error),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? '...' : 'افزودن کار'),
          ),
        ]),
      ),
    );
  }
}
