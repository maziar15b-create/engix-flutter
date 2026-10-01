import 'package:flutter/material.dart';
import '../../core/notify.dart';
import '../../core/theme.dart';
import 'tab_common.dart';

class AnnouncementsTab extends StatefulWidget {
  final String projectId;
  final Map<String, dynamic> profile;
  final List<Map<String, dynamic>> members;
  const AnnouncementsTab(
      {super.key, required this.projectId, required this.profile, required this.members});
  @override
  State<AnnouncementsTab> createState() => _AnnouncementsTabState();
}

class _AnnouncementsTabState extends State<AnnouncementsTab> {
  final _text = TextEditingController();
  List<Map<String, dynamic>>? _list;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final data = await sb
        .from('announcements')
        .select()
        .eq('project_id', widget.projectId)
        .order('created_at', ascending: false);
    final pMap = await fetchProfilesMap(data.map((a) => a['by']).toList());
    if (!mounted) return;
    setState(() => _list = [
          for (final a in data) {...a, 'byName': pMap[a['by']]?['name'] ?? '—'}
        ]);
  }

  Future<void> _post() async {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    await sb.from('announcements').insert(
        {'project_id': widget.projectId, 'text': t, 'by': widget.profile['id']});
    final others = widget.members
        .where((m) => m['user_id'] != widget.profile['id'])
        .map((m) => m['user_id'])
        .toList();
    notifyUsers(others, 'announcements', 'اطلاعیه جدید پروژه', t);
    _text.clear();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (_list == null) return const TabLoading();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const TabHeader('اطلاعیه‌های پروژه',
            subtitle: 'اطلاعیه برای همه‌ی اعضای پروژه ارسال کنید.'),
        Row(children: [
          Expanded(
              child: TextField(
                  controller: _text,
                  onSubmitted: (_) => _post(),
                  decoration: hint('متن اطلاعیه...'))),
          const SizedBox(width: 8),
          FilledButton(onPressed: _post, child: const Text('ارسال')),
        ]),
        const SizedBox(height: 16),
        if (_list!.isEmpty) const EmptyNote('اطلاعیه‌ای ثبت نشده.'),
        for (final a in _list!)
          TabCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${a['text']}', style: const TextStyle(fontSize: 13.5)),
              const SizedBox(height: 4),
              Text('${a['byName']}', style: const TextStyle(fontSize: 11, color: C.muted)),
            ]),
          ),
      ],
    );
  }
}
