import 'package:flutter/material.dart';
import '../../core/theme.dart';
import 'tab_common.dart';

const _statusLabels = {'present': 'حاضر', 'absent': 'غایب', 'half': 'نیمهروز'};
const _statusColors = {
  'present': Color(0xFF4ADE80),
  'absent': Color(0xFFF87171),
  'half': Color(0xFFFBBF24),
};

class AttendanceTab extends StatefulWidget {
  final String projectId;
  final Map<String, dynamic> profile;
  const AttendanceTab({super.key, required this.projectId, required this.profile});
  @override
  State<AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<AttendanceTab> {
  List<Map<String, dynamic>>? _records;
  String _date = todayStr();
  String _status = 'present';
  final _worker = TextEditingController();
  final _trade = TextEditingController();
  String _error = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _worker.dispose();
    _trade.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final d = await sb
        .from('project_attendance')
        .select()
        .eq('project_id', widget.projectId)
        .order('attendance_date', ascending: false);
    if (mounted) setState(() => _records = List<Map<String, dynamic>>.from(d));
  }

  Future<void> _add() async {
    if (_worker.text.trim().isEmpty) {
      setState(() => _error = 'نام کارگر را وارد کنید.');
      return;
    }
    setState(() => _error = '');
    try {
      await sb.from('project_attendance').insert({
        'project_id': widget.projectId,
        'worker_name': _worker.text.trim(),
        'trade': _trade.text.trim().isEmpty ? null : _trade.text.trim(),
        'attendance_date': _date,
        'status': _status,
        'recorded_by': widget.profile['id'],
      });
    } catch (e) {
      setState(() => _error = '$e');
      return;
    }
    _worker.clear();
    _trade.clear();
    _refresh();
  }

  Future<void> _delete(dynamic id) async {
    await sb.from('project_attendance').delete().eq('id', id);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (_records == null) return const TabLoading();
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final r in _records!) {
      grouped.putIfAbsent('${r['attendance_date']}', () => []).add(r);
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const TabHeader('حضور و غیاب کارگران', subtitle: 'ثبت روزانه‌ی حضور نیروی کار کارگاه.'),
        TabCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ErrorLine(_error),
            DateField(label: 'تاریخ', value: _date, onChanged: (v) => setState(() => _date = v)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(flex: 2, child: TextField(controller: _worker, decoration: hint('نام کارگر'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _trade, decoration: hint('تخصص (بنا، آرماتوربند...)'))),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              for (final e in _statusLabels.entries) ...[
                Expanded(
                    child: ChoiceChipBtn(
                        label: e.value,
                        active: _status == e.key,
                        color: _statusColors[e.key],
                        onTap: () => setState(() => _status = e.key))),
                const SizedBox(width: 6),
              ],
            ]),
            const SizedBox(height: 10),
            FilledButton(onPressed: _add, child: const Text('ثبت')),
          ]),
        ),
        const SizedBox(height: 10),
        if (grouped.isEmpty) const EmptyNote('هنوز رکوردی ثبت نشده.'),
        for (final e in grouped.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 6),
            child: Text('${faDate(e.key)}  (${e.value.length} نفر)',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.soft)),
          ),
          for (final r in e.value)
            TabCard(
              child: Row(children: [
                Expanded(
                  child: Text(
                      '${r['worker_name']}${(r['trade'] ?? '').toString().isNotEmpty ? ' (${r['trade']})' : ''}',
                      style: const TextStyle(fontSize: 13.5)),
                ),
                Text(_statusLabels['${r['status']}'] ?? '${r['status']}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _statusColors['${r['status']}'] ?? C.soft)),
                IconButton(
                    onPressed: () => _delete(r['id']),
                    icon: const Icon(Icons.delete_outline, size: 18, color: C.danger)),
              ]),
            ),
        ],
      ],
    );
  }
}
