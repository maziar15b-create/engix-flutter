import 'package:flutter/material.dart';
import '../../core/theme.dart';
import 'tab_common.dart';

class SupervisionTab extends StatefulWidget {
  final String projectId;
  final Map<String, dynamic> profile;
  const SupervisionTab({super.key, required this.projectId, required this.profile});
  @override
  State<SupervisionTab> createState() => _SupervisionTabState();
}

class _SupervisionTabState extends State<SupervisionTab> {
  final _note = TextEditingController();
  List<Map<String, dynamic>>? _reports;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final data = await sb
        .from('reports')
        .select()
        .eq('project_id', widget.projectId)
        .order('created_at', ascending: false);
    final pMap = await fetchProfilesMap(data.map((r) => r['by']).toList());
    if (!mounted) return;
    setState(() => _reports = [
          for (final r in data) {...r, 'byName': pMap[r['by']]?['name'] ?? '—'}
        ]);
  }

  Future<void> _add() async {
    final t = _note.text.trim();
    if (t.isEmpty) return;
    await sb
        .from('reports')
        .insert({'project_id': widget.projectId, 'text': t, 'by': widget.profile['id']});
    _note.clear();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (_reports == null) return const TabLoading();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const TabHeader('گزارش‌های نظارت کارگاهی',
            subtitle: 'یادداشت‌های بازدید از سایت، قابل مشاهده برای همه‌ی اعضای پروژه.'),
        Row(children: [
          Expanded(child: TextField(controller: _note, decoration: hint('یادداشت بازدید امروز...'))),
          const SizedBox(width: 8),
          FilledButton(onPressed: _add, child: const Text('ثبت')),
        ]),
        const SizedBox(height: 16),
        if (_reports!.isEmpty) const EmptyNote('هنوز گزارشی ثبت نشده.'),
        for (final r in _reports!)
          TabCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${r['text']}', style: const TextStyle(fontSize: 13.5)),
              const SizedBox(height: 4),
              Text('${r['byName']}', style: const TextStyle(fontSize: 11, color: C.muted)),
            ]),
          ),
      ],
    );
  }
}
