import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'tab_common.dart';

const _weatherOptions = ['آفتابی', 'ابری', 'بارانی', 'برفی', 'طوفانی'];

class DailyReportTab extends StatefulWidget {
  final String projectId;
  final Map<String, dynamic> profile;
  const DailyReportTab({super.key, required this.projectId, required this.profile});
  @override
  State<DailyReportTab> createState() => _DailyReportTabState();
}

class _DailyReportTabState extends State<DailyReportTab> {
  List<Map<String, dynamic>>? _reports;
  bool _form = false;
  Map<String, dynamic>? _editing;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final d = await sb
        .from('project_daily_reports')
        .select()
        .eq('project_id', widget.projectId)
        .order('report_date', ascending: false);
    if (mounted) setState(() => _reports = List<Map<String, dynamic>>.from(d));
  }

  @override
  Widget build(BuildContext context) {
    if (_reports == null) return const TabLoading();
    if (_form) {
      return _DailyForm(
        projectId: widget.projectId,
        profile: widget.profile,
        existing: _editing,
        onBack: () {
          setState(() {
            _form = false;
            _editing = null;
          });
          _refresh();
        },
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const TabHeader('گزارش روزانه‌ی کارگاه',
            subtitle: 'آب‌وهوا، نیروی انسانی، تجهیزات و فعالیت‌های هر روز.'),
        FilledButton(
            onPressed: () => setState(() {
                  _editing = null;
                  _form = true;
                }),
            child: const Text('+ گزارش امروز')),
        const SizedBox(height: 12),
        if (_reports!.isEmpty) const EmptyNote('هنوز گزارشی ثبت نشده.'),
        for (final r in _reports!)
          GestureDetector(
            onTap: () => setState(() {
              _editing = r;
              _form = true;
            }),
            child: TabCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('${r['report_date']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 10),
                  if ('${r['weather'] ?? ''}'.isNotEmpty)
                    Text('${r['weather']}', style: const TextStyle(fontSize: 12, color: C.redLight)),
                ]),
                if (r['workforce_count'] != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('نیروی کار: ${r['workforce_count']} نفر',
                          style: const TextStyle(fontSize: 12, color: C.soft))),
                if ('${r['activities'] ?? ''}'.isNotEmpty)
                  Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('${r['activities']}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5))),
              ]),
            ),
          ),
      ],
    );
  }
}

class _DailyForm extends StatefulWidget {
  final String projectId;
  final Map<String, dynamic> profile;
  final Map<String, dynamic>? existing;
  final VoidCallback onBack;
  const _DailyForm(
      {required this.projectId, required this.profile, required this.existing, required this.onBack});
  @override
  State<_DailyForm> createState() => _DailyFormState();
}

class _DailyFormState extends State<_DailyForm> {
  late String _date = widget.existing?['report_date']?.toString() ?? todayStr();
  late String _weather = widget.existing?['weather']?.toString() ?? 'آفتابی';
  late final _workforce = TextEditingController(
      text: widget.existing?['workforce_count'] != null ? '${widget.existing!['workforce_count']}' : '');
  late final _equipment = TextEditingController(text: '${widget.existing?['equipment_notes'] ?? ''}');
  late final _activities = TextEditingController(text: '${widget.existing?['activities'] ?? ''}');
  late final _issues = TextEditingController(text: '${widget.existing?['issues'] ?? ''}');
  bool _saving = false;
  String _error = '';

  @override
  void dispose() {
    for (final c in [_workforce, _equipment, _activities, _issues]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _n(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = '';
    });
    try {
      await sb.from('project_daily_reports').upsert({
        'project_id': widget.projectId,
        'report_date': _date,
        'weather': _weather,
        'workforce_count': _workforce.text.trim().isEmpty ? null : intOf(_workforce.text),
        'equipment_notes': _n(_equipment),
        'activities': _n(_activities),
        'issues': _n(_issues),
        'created_by': widget.profile['id'],
      }, onConflict: 'project_id,report_date');
    } catch (e) {
      setState(() {
        _saving = false;
        _error = '$e';
      });
      return;
    }
    widget.onBack();
  }

  Future<void> _delete() async {
    if (widget.existing == null) return;
    if (!await confirmDialog(context, 'این گزارش حذف شود؟')) return;
    await sb.from('project_daily_reports').delete().eq('id', widget.existing!['id']);
    widget.onBack();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          TextButton(onPressed: widget.onBack, child: const Text('← بازگشت')),
        ]),
        TabHeader(widget.existing == null ? 'گزارش روزانه جدید' : 'ویرایش گزارش روزانه'),
        DateField(label: 'تاریخ', value: _date, onChanged: (v) => setState(() => _date = v)),
        const SizedBox(height: 10),
        const Text('آب‌وهوا', style: TextStyle(fontSize: 11, color: C.soft)),
        const SizedBox(height: 4),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final w in _weatherOptions)
            ChoiceChipBtn(label: w, active: _weather == w, onTap: () => setState(() => _weather = w)),
        ]),
        const SizedBox(height: 10),
        TextField(
            controller: _workforce,
            keyboardType: TextInputType.number,
            decoration: hint('تعداد نیروی انسانی')),
        const SizedBox(height: 10),
        TextField(controller: _equipment, maxLines: 2, decoration: hint('یادداشت تجهیزات و ماشین‌آلات')),
        const SizedBox(height: 10),
        TextField(controller: _activities, maxLines: 4, decoration: hint('فعالیت‌های انجام‌شده')),
        const SizedBox(height: 10),
        TextField(controller: _issues, maxLines: 3, decoration: hint('مشکلات و موانع')),
        const SizedBox(height: 12),
        ErrorLine(_error),
        Row(children: [
          Expanded(
              child: FilledButton(
                  onPressed: _saving ? null : _save, child: Text(_saving ? '...' : 'ذخیره'))),
          if (widget.existing != null) ...[
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
