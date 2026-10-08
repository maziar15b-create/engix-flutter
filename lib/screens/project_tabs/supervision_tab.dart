import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/notify.dart';
import '../../core/project_media.dart';
import '../../core/theme.dart';
import '../chat/chat_widgets.dart' show ImageViewerScreen;
import 'tab_common.dart';

const _kinds = <String, List<dynamic>>{
  'visit': ['بازدید کارگاهی', Color(0xFF4FC3F7)],
  'defect': ['نقص و ایراد', Color(0xFFE5484D)],
  'approve': ['تأیید مرحله', Color(0xFF2ED573)],
  'order': ['دستور اصلاح', Color(0xFFFFA14A)],
};

class SupervisionTab extends StatefulWidget {
  final String projectId;
  final Map<String, dynamic> profile;
  final List<Map<String, dynamic>> members;
  const SupervisionTab({
    super.key,
    required this.projectId,
    required this.profile,
    this.members = const [],
  });
  @override
  State<SupervisionTab> createState() => _SupervisionTabState();
}

class _SupervisionTabState extends State<SupervisionTab> {
  List<Map<String, dynamic>>? _reports;
  String? _filter;
  bool _adding = false;

  String get _uid => widget.profile['id'].toString();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
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
    } catch (e) {
      if (mounted) {
        setState(() => _reports = []);
        snack(context, 'خطا در دریافت گزارش‌ها: $e');
      }
    }
  }

  Future<void> _delete(Map<String, dynamic> r) async {
    if (!await confirmDialog(context, 'این گزارش حذف شود؟')) return;
    try {
      final res = await sb.from('reports').delete().eq('id', r['id']).select();
      if (res.isEmpty && mounted) snack(context, 'اجازه‌ی حذف ندارید.');
      _refresh();
    } catch (e) {
      if (mounted) snack(context, 'خطا: $e');
    }
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
        child: _ReportForm(
          projectId: widget.projectId,
          profile: widget.profile,
          members: widget.members,
        ),
      ),
    );
    if (ok == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final all = _reports;
    if (all == null) return const TabLoading();
    final list = _filter == null
        ? all
        : all.where((r) => (r['report_kind'] ?? 'visit') == _filter).toList();
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: C.red,
        foregroundColor: Colors.white,
        onPressed: _adding ? null : _openForm,
        icon: const Icon(Icons.add),
        label: const Text('گزارش ناظر'),
      ),
      body: RefreshIndicator(
        color: C.red,
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          children: [
            const TabHeader('گزارش‌های ناظر',
                subtitle: 'گزارش بازدید، نقص‌ها و دستورهای اصلاح؛ قابل مشاهده برای همه‌ی اعضای پروژه.'),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChipBtn(
                      label: 'همه', active: _filter == null, onTap: () => setState(() => _filter = null)),
                ),
                for (final e in _kinds.entries)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChipBtn(
                      label: e.value[0] as String,
                      color: e.value[1] as Color,
                      active: _filter == e.key,
                      onTap: () => setState(() => _filter = e.key),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 14),
            if (list.isEmpty) const EmptyNote('گزارشی ثبت نشده.'),
            for (final r in list) _card(r),
          ],
        ),
      ),
    );
  }

  Widget _card(Map<String, dynamic> r) {
    final kind = _kinds[r['report_kind'] ?? 'visit'] ?? _kinds['visit']!;
    final color = kind[1] as Color;
    final photos = (r['photo_urls'] is List) ? List<String>.from(r['photo_urls']) : <String>[];
    final title = (r['title'] ?? '').toString();
    return TabCard(
      borderColor: color.withAlpha(90),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: color.withAlpha(40),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(kind[0] as String,
                style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
          ),
          const Spacer(),
          Text(faDate(r['report_date'] ?? r['created_at']),
              style: const TextStyle(fontSize: 11.5, color: C.soft)),
          if ('${r['by']}' == _uid)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.delete_outline, size: 18, color: C.danger),
              onPressed: () => _delete(r),
            ),
        ]),
        if (title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('${r['text'] ?? ''}', style: const TextStyle(fontSize: 13.5, height: 1.7)),
        ),
        if (photos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final u in photos)
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ImageViewerScreen(url: u))),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(u, width: 84, height: 84, fit: BoxFit.cover),
                  ),
                ),
            ]),
          ),
        const SizedBox(height: 6),
        Text('${r['byName']}', style: const TextStyle(fontSize: 11, color: C.muted)),
      ]),
    );
  }
}

class _ReportForm extends StatefulWidget {
  final String projectId;
  final Map<String, dynamic> profile;
  final List<Map<String, dynamic>> members;
  const _ReportForm(
      {required this.projectId, required this.profile, required this.members});

  @override
  State<_ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends State<_ReportForm> {
  final _title = TextEditingController();
  final _text = TextEditingController();
  String _kind = 'visit';
  String _date = todayStr();
  final List<PickedMedia> _photos = [];
  bool _busy = false;
  String _error = '';

  @override
  void dispose() {
    _title.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    try {
      final xs = await ImagePicker().pickMultiImage(imageQuality: 80, maxWidth: 1600);
      for (final x in xs) {
        if (_photos.length >= 6) break;
        _photos.add(PickedMedia(await x.readAsBytes(), x.name, x.mimeType));
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = 'انتخاب عکس ممکن نشد.');
    }
  }

  Future<void> _save() async {
    final t = _text.text.trim();
    if (t.isEmpty) {
      setState(() => _error = 'متن گزارش را بنویسید.');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final urls = <String>[];
      for (final p in _photos) {
        final up = await uploadProjectMedia(p, widget.projectId);
        urls.add(up.url);
      }
      await sb.from('reports').insert({
        'project_id': widget.projectId,
        'text': t,
        'by': widget.profile['id'],
        'report_kind': _kind,
        'report_date': _date,
        if (_title.text.trim().isNotEmpty) 'title': _title.text.trim(),
        if (urls.isNotEmpty) 'photo_urls': urls,
      });
      final others = widget.members
          .where((m) => m['user_id'].toString() != widget.profile['id'].toString())
          .map((m) => m['user_id'])
          .toList();
      notifyUsers(others, 'project_update', 'گزارش جدید ناظر', t);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'ثبت گزارش ناموفق بود: $e';
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
              child: Text('گزارش جدید ناظر',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in _kinds.entries)
              ChoiceChipBtn(
                label: e.value[0] as String,
                color: e.value[1] as Color,
                active: _kind == e.key,
                onTap: () => setState(() => _kind = e.key),
              ),
          ]),
          const SizedBox(height: 12),
          DateField(label: 'تاریخ بازدید', value: _date, onChanged: (v) => setState(() => _date = v)),
          const SizedBox(height: 10),
          TextField(controller: _title, decoration: hint('عنوان (اختیاری)')),
          const SizedBox(height: 10),
          TextField(
              controller: _text,
              minLines: 4,
              maxLines: 8,
              decoration: hint('شرح بازدید، ایرادها و توصیه‌ها...')),
          const SizedBox(height: 10),
          Row(children: [
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickPhotos,
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: Text(_photos.isEmpty ? 'افزودن عکس' : 'عکس‌ها (${_photos.length})'),
            ),
            const SizedBox(width: 10),
            if (_photos.isNotEmpty)
              TextButton(
                  onPressed: () => setState(() => _photos.clear()),
                  child: const Text('پاک کردن')),
          ]),
          if (_photos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                for (final p in _photos)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.memory(p.bytes, width: 54, height: 54, fit: BoxFit.cover),
                  ),
              ]),
            ),
          const SizedBox(height: 10),
          ErrorLine(_error),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'در حال ثبت...' : 'ثبت گزارش'),
          ),
        ]),
      ),
    );
  }
}
