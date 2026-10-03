import 'package:flutter/material.dart';

import '../../core/notify.dart';
import '../../core/project_media.dart';
import '../../core/theme.dart';
import 'tab_common.dart';

const _reportTypes = <List<String>>[
  ['daily', 'روزانه'],
  ['weekly', 'هفتگی'],
  ['monthly', 'ماهانه'],
  ['general', 'عمومی'],
];

String _typeLabel(String? k) {
  for (final t in _reportTypes) {
    if (t[0] == k) return t[1];
  }
  return '';
}

class ReportsTab extends StatefulWidget {
  final String projectId;
  final Map<String, dynamic> profile;
  final List<Map<String, dynamic>> members;
  final String projectName;
  const ReportsTab(
      {super.key,
      required this.projectId,
      required this.profile,
      required this.members,
      required this.projectName});
  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  List<Map<String, dynamic>>? _updates;
  String _type = 'daily';
  final _body = TextEditingController();
  final List<UploadedMedia> _pending = [];
  bool _uploading = false;
  bool _posting = false;
  String _err = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final rows = await sb
        .from('project_updates')
        .select('id, report_type, body, media, created_at, author_id')
        .eq('project_id', widget.projectId)
        .order('created_at', ascending: false);
    final pMap = await fetchProfilesMap(rows.map((r) => r['author_id']).toList());
    if (!mounted) return;
    setState(() => _updates = [
          for (final r in rows) {...r, 'authorName': pMap[r['author_id']]?['name'] ?? 'کاربر'}
        ]);
  }

  Future<void> _pick(Future<PickedMedia?> Function() picker) async {
    setState(() => _err = '');
    try {
      final f = await picker();
      if (f == null) return;
      setState(() => _uploading = true);
      final m = await uploadProjectMedia(f, widget.projectId);
      if (mounted) setState(() => _pending.add(m));
    } catch (e) {
      if (mounted) setState(() => _err = '$e'.replaceFirst('Exception: ', ''));
    }
    if (mounted) setState(() => _uploading = false);
  }

  Future<void> _post() async {
    setState(() => _err = '');
    if (_body.text.trim().isEmpty && _pending.isEmpty) {
      setState(() => _err = 'متن یا حداقل یک فایل اضافه کنید.');
      return;
    }
    setState(() => _posting = true);
    try {
      await sb.from('project_updates').insert({
        'project_id': widget.projectId,
        'author_id': widget.profile['id'],
        'report_type': _type,
        'body': _body.text.trim(),
        'media': [for (final m in _pending) m.toJson()],
      });
    } catch (e) {
      setState(() {
        _posting = false;
        _err = '$e';
      });
      return;
    }
    final label = _typeLabel(_type);
    final others = widget.members
        .where((m) => m['user_id'] != widget.profile['id'])
        .map((m) => m['user_id'])
        .toList();
    notifyUsers(others, 'project_update', 'گزارش کار جدید',
        '${widget.profile['name']} یک گزارش $label برای «${widget.projectName}» ثبت کرد.');
    _body.clear();
    setState(() {
      _pending.clear();
      _posting = false;
    });
    _refresh();
  }

  String _mediaLabel(String t) =>
      t == 'image' ? '🖼 عکس' : (t == 'video' ? '🎬 ویدیو' : '🎙 صوت');

  Widget _mediaView(Map m) {
    final t = '${m['type']}';
    final url = '${m['url']}';
    if (t == 'image') {
      return GestureDetector(
        onTap: () => openUrl(url),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(url,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox(height: 40)),
        ),
      );
    }
    return OutlinedButton(
        onPressed: () => openUrl(url),
        child: Text(t == 'video' ? '▶ پخش ویدیو' : '▶ پخش صوت'));
  }

  @override
  Widget build(BuildContext context) {
    if (_updates == null) return const TabLoading();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const TabHeader('گزارش کار',
            subtitle: 'گزارش‌های روزانه، هفتگی و ماهانه پروژه — با عکس، متن، صوت و ویدیو.'),
        TabCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in _reportTypes)
                ChoiceChipBtn(
                    label: t[1], active: _type == t[0], onTap: () => setState(() => _type = t[0])),
            ]),
            const SizedBox(height: 10),
            TextField(controller: _body, minLines: 3, maxLines: 6, decoration: hint('متن گزارش...')),
            if (_pending.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 6, children: [
                for (var i = 0; i < _pending.length; i++)
                  Chip(
                    label: Text(_mediaLabel(_pending[i].type)),
                    onDeleted: () => setState(() => _pending.removeAt(i)),
                  ),
              ]),
            ],
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              OutlinedButton(
                  onPressed: _uploading ? null : () => _pick(pickImageMedia),
                  child: const Text('🖼 عکس')),
              OutlinedButton(
                  onPressed: _uploading ? null : () => _pick(pickVideoMedia),
                  child: const Text('🎬 ویدیو')),
              OutlinedButton(
                  onPressed: _uploading ? null : () => _pick(pickAudioMedia),
                  child: const Text('🎙 صوت')),
              if (_uploading)
                const Text('در حال آپلود...', style: TextStyle(fontSize: 12, color: C.muted)),
            ]),
            const SizedBox(height: 10),
            ErrorLine(_err),
            FilledButton(
                onPressed: (_posting || _uploading) ? null : _post,
                child: Text(_posting ? '...' : 'ثبت گزارش')),
          ]),
        ),
        const SizedBox(height: 10),
        if (_updates!.isEmpty) const EmptyNote('هنوز گزارشی ثبت نشده است.'),
        for (final u in _updates!)
          TabCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text('${u['authorName']}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5))),
                Text(_typeLabel(u['report_type'] as String?),
                    style: const TextStyle(fontSize: 11.5, color: C.redLight)),
              ]),
              Text('${u['created_at']}'.substring(0, 10),
                  style: const TextStyle(fontSize: 10.5, color: C.muted)),
              if ('${u['body'] ?? ''}'.isNotEmpty)
                Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('${u['body']}', style: const TextStyle(fontSize: 13, height: 1.7))),
              for (final m in (u['media'] as List? ?? const []))
                Padding(padding: const EdgeInsets.only(top: 8), child: _mediaView(m as Map)),
              _Comments(updateId: u['id'], profile: widget.profile),
            ]),
          ),
      ],
    );
  }
}

class _Comments extends StatefulWidget {
  final dynamic updateId;
  final Map<String, dynamic> profile;
  const _Comments({required this.updateId, required this.profile});
  @override
  State<_Comments> createState() => _CommentsState();
}

class _CommentsState extends State<_Comments> {
  bool _open = false;
  List<Map<String, dynamic>>? _list;
  final _text = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final rows = await sb
        .from('project_update_comments')
        .select('id, body, created_at, author_id')
        .eq('update_id', widget.updateId)
        .order('created_at');
    final pMap = await fetchProfilesMap(rows.map((r) => r['author_id']).toList());
    if (!mounted) return;
    setState(() => _list = [
          for (final r in rows) {...r, 'name': pMap[r['author_id']]?['name'] ?? 'کاربر'}
        ]);
  }

  Future<void> _send() async {
    if (_text.text.trim().isEmpty) return;
    setState(() => _busy = true);
    await sb.from('project_update_comments').insert({
      'update_id': widget.updateId,
      'author_id': widget.profile['id'],
      'body': _text.text.trim(),
    });
    _text.clear();
    setState(() => _busy = false);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextButton(
        onPressed: () {
          setState(() => _open = !_open);
          if (_open && _list == null) _load();
        },
        child: Text(_open ? 'بستن پاسخ‌ها' : 'پاسخ‌ها'),
      ),
      if (_open) ...[
        if (_list == null) const EmptyNote('در حال بارگذاری...'),
        if (_list != null && _list!.isEmpty) const EmptyNote('هنوز پاسخی ثبت نشده.'),
        for (final c in _list ?? const <Map<String, dynamic>>[])
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${c['name']}',
                  style: const TextStyle(fontSize: 11.5, color: C.redLight, fontWeight: FontWeight.w700)),
              Text('${c['body']}', style: const TextStyle(fontSize: 12.5)),
            ]),
          ),
        Row(children: [
          Expanded(child: TextField(controller: _text, decoration: hint('پاسخ بنویسید...'))),
          const SizedBox(width: 8),
          FilledButton(onPressed: _busy ? null : _send, child: const Text('ارسال')),
        ]),
      ],
    ]);
  }
}
