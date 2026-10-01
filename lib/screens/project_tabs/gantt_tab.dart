import 'package:flutter/material.dart';
import '../../core/theme.dart';
import 'tab_common.dart';

class GanttTab extends StatefulWidget {
  final String projectId;
  final Map<String, dynamic> profile;
  const GanttTab({super.key, required this.projectId, required this.profile});
  @override
  State<GanttTab> createState() => _GanttTabState();
}

class _GanttTabState extends State<GanttTab> {
  List<Map<String, dynamic>>? _tasks;
  bool _adding = false;
  final _name = TextEditingController();
  final _duration = TextEditingController(text: '7');
  String _start = todayStr();
  dynamic _editingId;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _name.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final d = await sb
          .from('project_gantt_tasks')
          .select()
          .eq('project_id', widget.projectId)
          .order('order_index', ascending: true)
          .order('start_date', ascending: true);
      if (mounted) setState(() => _tasks = List<Map<String, dynamic>>.from(d));
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _tasks = [];
        });
      }
    }
  }

  Future<void> _add() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _error = '');
    var maxOrder = 0;
    for (final t in _tasks ?? const <Map<String, dynamic>>[]) {
      final o = (t['order_index'] ?? 0) as num;
      if (o > maxOrder) maxOrder = o.toInt();
    }
    try {
      await sb.from('project_gantt_tasks').insert({
        'project_id': widget.projectId,
        'name': _name.text.trim(),
        'start_date': _start,
        'duration_days': intOf(_duration.text, 1).clamp(1, 100000),
        'progress_percent': 0,
        'order_index': maxOrder + 1,
        'created_by': widget.profile['id'],
      });
    } catch (e) {
      setState(() => _error = '$e');
      return;
    }
    _name.clear();
    _duration.text = '7';
    setState(() => _adding = false);
    _refresh();
  }

  Future<void> _update(dynamic id, Map<String, dynamic> patch) async {
    await sb.from('project_gantt_tasks').update(patch).eq('id', id);
    _refresh();
  }

  Future<void> _delete(dynamic id) async {
    if (!await confirmDialog(context, 'این وظیفه حذف شود؟')) return;
    await sb.from('project_gantt_tasks').delete().eq('id', id);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (_tasks == null) return const TabLoading();
    final tasks = _tasks!;

    DateTime? rs, re;
    for (final t in tasks) {
      final s = parseDay('${t['start_date']}');
      final e = s.add(Duration(days: ((t['duration_days'] ?? 1) as num).toInt()));
      if (rs == null || s.isBefore(rs)) rs = s;
      if (re == null || e.isAfter(re)) re = e;
    }
    final n = DateTime.now();
    final today = DateTime.utc(n.year, n.month, n.day);
    if (tasks.isNotEmpty && rs != null && re != null) {
      if (today.isBefore(rs)) rs = today;
      if (today.isAfter(re)) re = today;
    }
    final totalDays = (rs != null && re != null)
        ? re.difference(rs).inDays.clamp(1, 1000000)
        : 1;
    final todayPct = rs != null ? today.difference(rs).inDays / totalDays * 100 : 0.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const TabHeader('برنامه‌زمانبندی پروژه',
            subtitle:
                'وظایف پروژه را با تاریخ شروع و مدت زمان ثبت کنید — برای همه‌ی اعضای پروژه قابل مشاهده است.'),
        ErrorLine(_error),
        if (tasks.isEmpty && !_adding) const EmptyNote('هنوز هیچ وظیفه‌ای ثبت نشده.'),
        for (final t in tasks) _taskCard(t, rs!, totalDays, todayPct),
        const SizedBox(height: 8),
        if (!_adding)
          FilledButton(
              onPressed: () => setState(() => _adding = true),
              child: const Text('+ افزودن وظیفه'))
        else
          TabCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(controller: _name, decoration: hint('نام وظیفه (مثلاً: اجرای فونداسیون)')),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: DateField(
                        label: 'تاریخ شروع',
                        value: _start,
                        onChanged: (v) => setState(() => _start = v))),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('مدت (روز)', style: TextStyle(fontSize: 11, color: C.soft)),
                    const SizedBox(height: 4),
                    TextField(
                        controller: _duration, keyboardType: TextInputType.number),
                  ]),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: FilledButton(onPressed: _add, child: const Text('ثبت'))),
                const SizedBox(width: 8),
                Expanded(
                    child: OutlinedButton(
                        onPressed: () => setState(() => _adding = false),
                        child: const Text('لغو'))),
              ]),
            ]),
          ),
      ],
    );
  }

  Widget _taskCard(Map<String, dynamic> t, DateTime rangeStart, int totalDays, double todayPct) {
    final dur = ((t['duration_days'] ?? 1) as num).toInt();
    final prog = ((t['progress_percent'] ?? 0) as num).toDouble();
    final offset = parseDay('${t['start_date']}').difference(rangeStart).inDays;
    final leftPct = offset / totalDays * 100;
    final widthPct = (dur / totalDays * 100).clamp(2.0, 100.0);
    return TabCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(
              child: Text('${t['name']}',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600))),
        ]),
        const SizedBox(height: 2),
        Text('${t['start_date']} — $dur روز — ${prog.round()}٪',
            style: const TextStyle(fontSize: 11, color: C.muted)),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (ctx, c) {
          final w = c.maxWidth;
          return Container(
            height: 18,
            decoration: BoxDecoration(
              color: C.bg0,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0x26C50337)),
            ),
            child: Stack(children: [
              Positioned(
                right: w * leftPct / 100,
                width: w * widthPct / 100,
                top: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [C.redDeep, C.redLight]),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FractionallySizedBox(
                      widthFactor: (prog / 100).clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.28),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (todayPct >= 0 && todayPct <= 100)
                Positioned(
                    right: w * todayPct / 100,
                    top: 0,
                    bottom: 0,
                    width: 2,
                    child: Container(color: const Color(0xFFFBBF24))),
            ]),
          );
        }),
        const SizedBox(height: 6),
        Row(children: [
          TextButton(
              onPressed: () =>
                  setState(() => _editingId = _editingId == t['id'] ? null : t['id']),
              child: const Text('✏️ ویرایش')),
          TextButton(
              onPressed: () => _delete(t['id']),
              child: const Text('🗑 حذف', style: TextStyle(color: C.danger))),
        ]),
        if (_editingId == t['id'])
          _EditRow(
            task: t,
            onSave: (patch) {
              _update(t['id'], patch);
              setState(() => _editingId = null);
            },
            onCancel: () => setState(() => _editingId = null),
          ),
      ]),
    );
  }
}

class _EditRow extends StatefulWidget {
  final Map<String, dynamic> task;
  final void Function(Map<String, dynamic>) onSave;
  final VoidCallback onCancel;
  const _EditRow({required this.task, required this.onSave, required this.onCancel});
  @override
  State<_EditRow> createState() => _EditRowState();
}

class _EditRowState extends State<_EditRow> {
  late final TextEditingController _name = TextEditingController(text: '${widget.task['name']}');
  late final TextEditingController _dur =
      TextEditingController(text: '${widget.task['duration_days']}');
  late String _start = '${widget.task['start_date']}';
  late double _progress = ((widget.task['progress_percent'] ?? 0) as num).toDouble();

  @override
  void dispose() {
    _name.dispose();
    _dur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(controller: _name),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
            child: DateField(
                label: 'تاریخ شروع',
                value: _start,
                onChanged: (v) => setState(() => _start = v))),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('مدت (روز)', style: TextStyle(fontSize: 11, color: C.soft)),
            const SizedBox(height: 4),
            TextField(controller: _dur, keyboardType: TextInputType.number),
          ]),
        ),
      ]),
      const SizedBox(height: 8),
      Text('پیشرفت: ${_progress.round()}٪',
          style: const TextStyle(fontSize: 12, color: C.soft)),
      Slider(
        value: _progress,
        min: 0,
        max: 100,
        divisions: 100,
        activeColor: C.red,
        onChanged: (v) => setState(() => _progress = v),
      ),
      Row(children: [
        Expanded(
          child: FilledButton(
            onPressed: () => widget.onSave({
              'name': _name.text.trim().isEmpty ? widget.task['name'] : _name.text.trim(),
              'start_date': _start,
              'duration_days': intOf(_dur.text, 1).clamp(1, 100000),
              'progress_percent': _progress.round(),
            }),
            child: const Text('ذخیره'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton(onPressed: widget.onCancel, child: const Text('لغو'))),
      ]),
    ]);
  }
}
