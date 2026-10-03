import 'package:flutter/material.dart';

import '../../core/project_media.dart';
import '../../core/theme.dart';
import 'tab_common.dart';

const _categories = ['نقشه', 'مجوز', 'قرارداد', 'استعلام', 'سایر'];

class DocumentsTab extends StatefulWidget {
  final String projectId;
  final Map<String, dynamic> profile;
  const DocumentsTab({super.key, required this.projectId, required this.profile});
  @override
  State<DocumentsTab> createState() => _DocumentsTabState();
}

class _DocumentsTabState extends State<DocumentsTab> {
  List<Map<String, dynamic>>? _docs;
  String _category = 'نقشه';
  String? _filter;
  final _title = TextEditingController();
  bool _uploading = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final d = await sb
        .from('project_documents')
        .select()
        .eq('project_id', widget.projectId)
        .order('created_at', ascending: false);
    if (mounted) setState(() => _docs = List<Map<String, dynamic>>.from(d));
  }

  Future<void> _upload() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'اول عنوان سند را وارد کنید.');
      return;
    }
    setState(() => _error = '');
    try {
      final f = await pickAnyMedia();
      if (f == null) return;
      setState(() => _uploading = true);
      final media = await uploadProjectMedia(f, widget.projectId);
      await sb.from('project_documents').insert({
        'project_id': widget.projectId,
        'title': _title.text.trim(),
        'category': _category,
        'file_url': media.url,
        'uploaded_by': widget.profile['id'],
      });
      _title.clear();
      _refresh();
    } catch (e) {
      if (mounted) setState(() => _error = '$e'.replaceFirst('Exception: ', ''));
    }
    if (mounted) setState(() => _uploading = false);
  }

  Future<void> _delete(dynamic id) async {
    if (!await confirmDialog(context, 'این سند حذف شود؟')) return;
    await sb.from('project_documents').delete().eq('id', id);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (_docs == null) return const TabLoading();
    final list = _filter == null ? _docs! : _docs!.where((d) => d['category'] == _filter).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const TabHeader('اسناد و نقشه‌ها',
            subtitle: 'آپلود و دسته‌بندی نقشه، مجوز، قرارداد و سایر اسناد پروژه.'),
        TabCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ErrorLine(_error),
            TextField(
                controller: _title,
                decoration: hint('عنوان سند (مثلاً: نقشه فونداسیون طبقه همکف)')),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in _categories)
                ChoiceChipBtn(label: c, active: _category == c, onTap: () => setState(() => _category = c)),
            ]),
            const SizedBox(height: 10),
            FilledButton(
                onPressed: _uploading ? null : _upload,
                child: Text(_uploading ? 'در حال آپلود...' : '📎 انتخاب و آپلود فایل')),
          ]),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ChoiceChipBtn(label: 'همه', active: _filter == null, onTap: () => setState(() => _filter = null)),
          for (final c in _categories)
            ChoiceChipBtn(label: c, active: _filter == c, onTap: () => setState(() => _filter = c)),
        ]),
        const SizedBox(height: 12),
        if (list.isEmpty) const EmptyNote('سندی ثبت نشده.'),
        for (final d in list)
          TabCard(
            child: Row(children: [
              const Icon(Icons.description_outlined, size: 20, color: C.redLight),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${d['title']}', style: const TextStyle(fontSize: 13.5)),
                  Text('${d['category'] ?? ''} — ${'${d['created_at']}'.substring(0, 10)}',
                      style: const TextStyle(fontSize: 11, color: C.muted)),
                ]),
              ),
              IconButton(
                  onPressed: () => openUrl('${d['file_url']}'),
                  icon: const Icon(Icons.open_in_new, size: 18)),
              IconButton(
                  onPressed: () => _delete(d['id']),
                  icon: const Icon(Icons.delete_outline, size: 18, color: C.danger)),
            ]),
          ),
      ],
    );
  }
}
