import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'tab_common.dart';

class WorkOrderTab extends StatefulWidget {
  final String projectId;
  final Map<String, dynamic> profile;
  const WorkOrderTab({super.key, required this.projectId, required this.profile});
  @override
  State<WorkOrderTab> createState() => _WorkOrderTabState();
}

class _WorkOrderTabState extends State<WorkOrderTab> {
  List<Map<String, dynamic>>? _orders;
  bool _form = false;
  dynamic _activeId;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final d = await sb
        .from('project_work_orders')
        .select()
        .eq('project_id', widget.projectId)
        .order('meeting_date', ascending: false);
    if (mounted) setState(() => _orders = List<Map<String, dynamic>>.from(d));
  }

  @override
  Widget build(BuildContext context) {
    if (_orders == null) return const TabLoading();
    if (_form) {
      return _WorkOrderForm(
        projectId: widget.projectId,
        profile: widget.profile,
        orderId: _activeId,
        onBack: () {
          setState(() {
            _form = false;
            _activeId = null;
          });
          _refresh();
        },
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const TabHeader('دستورکار / صورتجلسه',
            subtitle: 'صورتجلسات رسمی کارگاهی با حاضرین، مصوبات و اقدامات پیگیریشدنی.'),
        FilledButton(
            onPressed: () => setState(() {
                  _activeId = null;
                  _form = true;
                }),
            child: const Text('+ صورتجلسه جدید')),
        const SizedBox(height: 12),
        if (_orders!.isEmpty) const EmptyNote('هنوز صورتجلسه‌ای ثبت نشده.'),
        for (final o in _orders!)
          GestureDetector(
            onTap: () => setState(() {
              _activeId = o['id'];
              _form = true;
            }),
            child: TabCard(
              child: Row(children: [
                Expanded(
                    child: Text('${o['title']}',
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600))),
                Text(faDate(o['meeting_date']), style: const TextStyle(fontSize: 11, color: C.muted)),
              ]),
            ),
          ),
      ],
    );
  }
}

class _Act {
  dynamic id;
  final TextEditingController text;
  final TextEditingController assignee;
  String due;
  String status;
  _Act({this.id, String t = '', String a = '', this.due = '', this.status = 'pending'})
      : text = TextEditingController(text: t),
        assignee = TextEditingController(text: a);
  void dispose() {
    text.dispose();
    assignee.dispose();
  }
}

class _WorkOrderForm extends StatefulWidget {
  final String projectId;
  final Map<String, dynamic> profile;
  final dynamic orderId;
  final VoidCallback onBack;
  const _WorkOrderForm(
      {required this.projectId, required this.profile, required this.orderId, required this.onBack});
  @override
  State<_WorkOrderForm> createState() => _WorkOrderFormState();
}

class _WorkOrderFormState extends State<_WorkOrderForm> {
  final _title = TextEditingController();
  final _attendees = TextEditingController();
  final _content = TextEditingController();
  String _date = todayStr();
  final List<_Act> _actions = [];
  bool _loading = false;
  bool _saving = false;
  String _error = '';

  bool get _viewing => widget.orderId != null;

  @override
  void initState() {
    super.initState();
    if (_viewing) {
      _loading = true;
      _load();
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _attendees.dispose();
    _content.dispose();
    for (final a in _actions) {
      a.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final order = await sb
        .from('project_work_orders')
        .select()
        .eq('id', widget.orderId)
        .maybeSingle();
    final acts = await sb
        .from('project_work_order_actions')
        .select()
        .eq('work_order_id', widget.orderId)
        .order('order_index');
    if (!mounted) return;
    setState(() {
      if (order != null) {
        _title.text = '${order['title'] ?? ''}';
        _date = '${order['meeting_date'] ?? todayStr()}';
        _attendees.text = '${order['attendees'] ?? ''}';
        _content.text = '${order['content'] ?? ''}';
      }
      for (final a in acts) {
        _actions.add(_Act(
          id: a['id'],
          t: '${a['text'] ?? ''}',
          a: '${a['assignee'] ?? ''}',
          due: '${a['due_date'] ?? ''}',
          status: '${a['status'] ?? 'pending'}',
        ));
      }
      _loading = false;
    });
  }

  Future<void> _toggleStatus(_Act a) async {
    final ns = a.status == 'done' ? 'pending' : 'done';
    if (_viewing && a.id != null) {
      await sb.from('project_work_order_actions').update({'status': ns}).eq('id', a.id);
    }
    setState(() => a.status = ns);
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'عنوان صورتجلسه را وارد کنید.');
      return;
    }
    setState(() {
      _saving = true;
      _error = '';
    });
    try {
      dynamic woId = widget.orderId;
      final payload = {
        'project_id': widget.projectId,
        'title': _title.text.trim(),
        'meeting_date': _date,
        'attendees': _attendees.text.trim(),
        'content': _content.text.trim(),
        'created_by': widget.profile['id'],
      };
      if (woId != null) {
        await sb.from('project_work_orders').update(payload).eq('id', woId);
        await sb.from('project_work_order_actions').delete().eq('work_order_id', woId);
      } else {
        final d = await sb.from('project_work_orders').insert(payload).select().single();
        woId = d['id'];
      }
      final valid = _actions.where((a) => a.text.text.trim().isNotEmpty).toList();
      if (valid.isNotEmpty) {
        await sb.from('project_work_order_actions').insert([
          for (var i = 0; i < valid.length; i++)
            {
              'work_order_id': woId,
              'text': valid[i].text.text.trim(),
              'assignee': valid[i].assignee.text.trim().isEmpty ? null : valid[i].assignee.text.trim(),
              'due_date': valid[i].due.isEmpty ? null : valid[i].due,
              'status': valid[i].status,
              'order_index': i,
            }
        ]);
      }
      widget.onBack();
    } catch (e) {
      setState(() {
        _saving = false;
        _error = '$e';
      });
    }
  }

  Future<void> _delete() async {
    if (!await confirmDialog(context, 'این صورتجلسه حذف شود؟')) return;
    await sb.from('project_work_order_actions').delete().eq('work_order_id', widget.orderId);
    await sb.from('project_work_orders').delete().eq('id', widget.orderId);
    widget.onBack();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const TabLoading();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [TextButton(onPressed: widget.onBack, child: const Text('← بازگشت'))]),
        TabHeader(_viewing ? 'ویرایش صورتجلسه' : 'صورتجلسه جدید'),
        TextField(controller: _title, decoration: hint('عنوان صورتجلسه')),
        const SizedBox(height: 10),
        DateField(label: 'تاریخ جلسه', value: _date, onChanged: (v) => setState(() => _date = v)),
        const SizedBox(height: 10),
        TextField(controller: _attendees, maxLines: 2, decoration: hint('حاضرین جلسه')),
        const SizedBox(height: 10),
        TextField(controller: _content, maxLines: 5, decoration: hint('مصوبات و متن صورتجلسه')),
        const SizedBox(height: 14),
        const Text('اقدامات پیگیری‌شدنی',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.soft)),
        const SizedBox(height: 8),
        for (var i = 0; i < _actions.length; i++)
          TabCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(controller: _actions[i].text, decoration: hint('شرح اقدام')),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: _actions[i].assignee, decoration: hint('مسئول'))),
                const SizedBox(width: 8),
                Expanded(
                    child: DateField(
                        label: 'مهلت',
                        value: _actions[i].due.isEmpty ? '—' : _actions[i].due,
                        onChanged: (v) => setState(() => _actions[i].due = v))),
              ]),
              Row(children: [
                TextButton(
                    onPressed: () => _toggleStatus(_actions[i]),
                    child: Text(_actions[i].status == 'done' ? '✓ انجام‌شده' : '○ در انتظار',
                        style: TextStyle(
                            color: _actions[i].status == 'done'
                                ? const Color(0xFF4ADE80)
                                : C.soft))),
                const Spacer(),
                TextButton(
                    onPressed: () => setState(() {
                          _actions[i].dispose();
                          _actions.removeAt(i);
                        }),
                    child: const Text('حذف', style: TextStyle(color: C.danger))),
              ]),
            ]),
          ),
        OutlinedButton(
            onPressed: () => setState(() => _actions.add(_Act())),
            child: const Text('+ افزودن اقدام')),
        const SizedBox(height: 14),
        ErrorLine(_error),
        Row(children: [
          Expanded(
              child: FilledButton(
                  onPressed: _saving ? null : _save, child: Text(_saving ? '...' : 'ذخیره'))),
          if (_viewing) ...[
            const SizedBox(width: 8),
            Expanded(
                child: OutlinedButton(
                    onPressed: _delete,
                    child: const Text('حذف', style: TextStyle(color: C.danger)))),
          ],
        ]),
      ],
    );
  }
}
