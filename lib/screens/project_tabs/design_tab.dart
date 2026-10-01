import 'package:flutter/material.dart';
import '../../core/theme.dart';
import 'tab_common.dart';

class DesignTab extends StatefulWidget {
  final String projectId;
  final Map<String, dynamic> profile;
  const DesignTab({super.key, required this.projectId, required this.profile});
  @override
  State<DesignTab> createState() => _DesignTabState();
}

class _DesignTabState extends State<DesignTab> {
  final _l = TextEditingController();
  final _w = TextEditingController();
  final _h = TextEditingController();
  List<Map<String, dynamic>>? _notes;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _l.dispose();
    _w.dispose();
    _h.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final data = await sb
        .from('design_notes')
        .select()
        .eq('project_id', widget.projectId)
        .order('created_at', ascending: false);
    final pMap = await fetchProfilesMap(data.map((n) => n['by']).toList());
    if (!mounted) return;
    setState(() => _notes = [
          for (final n in data)
            {...n, 'byName': pMap[n['by']]?['name'] ?? '—'}
        ]);
  }

  double get _volume => numOf(_l.text) * numOf(_w.text) * numOf(_h.text);

  Future<void> _save() async {
    final v = _volume;
    if (v == 0) return;
    final bags = (v * 6.3).ceil();
    final text =
        'محاسبه حجم بتن: ${fmtNum(numOf(_l.text))}×${fmtNum(numOf(_w.text))}×${fmtNum(numOf(_h.text))} متر = ${v.toStringAsFixed(2)} m3 (تقریباً $bags کیسه سیمان)';
    await sb.from('design_notes').insert(
        {'project_id': widget.projectId, 'text': text, 'by': widget.profile['id']});
    _l.clear();
    _w.clear();
    _h.clear();
    setState(() {});
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (_notes == null) return const TabLoading();
    final v = _volume;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const TabHeader('محاسبه حجم بتن',
            subtitle: 'ابعاد را وارد کنید تا حجم و برآورد کیسه سیمان در پرونده پروژه ثبت شود.'),
        Row(children: [
          for (final e in [
            [_l, 'طول (m)'],
            [_w, 'عرض (m)'],
            [_h, 'ارتفاع (m)'],
          ])
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: TextField(
                  controller: e[0] as TextEditingController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: hint(e[1] as String),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 20, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('حجم: ', style: TextStyle(fontSize: 12, color: C.soft)),
            Text('${v.toStringAsFixed(2)} m3',
                style: const TextStyle(color: C.redLight, fontWeight: FontWeight.w700)),
          ]),
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('کیسه سیمان: ', style: TextStyle(fontSize: 12, color: C.soft)),
            Text('${(v * 6.3).ceil()}', style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
          FilledButton(onPressed: _save, child: const Text('ثبت در پرونده پروژه')),
        ]),
        const SizedBox(height: 16),
        const Text('یادداشت‌های محاسباتی پروژه',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.soft)),
        const SizedBox(height: 8),
        if (_notes!.isEmpty) const EmptyNote('یادداشتی ثبت نشده.'),
        for (final n in _notes!)
          TabCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${n['text']}', style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 4),
              Text('${n['byName']}', style: const TextStyle(fontSize: 10.5, color: C.muted)),
            ]),
          ),
      ],
    );
  }
}
