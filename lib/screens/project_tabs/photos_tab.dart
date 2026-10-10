import 'package:flutter/material.dart';

import '../../core/project_media.dart';
import '../../core/theme.dart';
import 'tab_common.dart';

class PhotosTab extends StatefulWidget {
  final String projectId;
  final Map<String, dynamic> profile;
  const PhotosTab({super.key, required this.projectId, required this.profile});
  @override
  State<PhotosTab> createState() => _PhotosTabState();
}

class _PhotosTabState extends State<PhotosTab> {
  List<Map<String, dynamic>>? _photos;
  final _caption = TextEditingController();
  String _date = todayStr();
  bool _uploading = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final d = await sb
        .from('project_photos')
        .select()
        .eq('project_id', widget.projectId)
        .order('taken_date', ascending: false);
    if (mounted) setState(() => _photos = List<Map<String, dynamic>>.from(d));
  }

  Future<void> _upload() async {
    setState(() => _error = '');
    try {
      final f = await pickImageMedia();
      if (f == null) return;
      setState(() => _uploading = true);
      final media = await uploadProjectMedia(f, widget.projectId);
      await sb.from('project_photos').insert({
        'project_id': widget.projectId,
        'photo_url': media.url,
        'caption': _caption.text.trim().isEmpty ? null : _caption.text.trim(),
        'taken_date': _date,
        'uploaded_by': widget.profile['id'],
      });
      _caption.clear();
      _refresh();
    } catch (e) {
      if (mounted) setState(() => _error = '$e'.replaceFirst('Exception: ', ''));
    }
    if (mounted) setState(() => _uploading = false);
  }

  Future<void> _delete(dynamic id) async {
    if (!await confirmDialog(context, 'این تصویر حذف شود؟')) return;
    await sb.from('project_photos').delete().eq('id', id);
    _refresh();
  }

  void _lightbox(Map<String, dynamic> p) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: C.bg1,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Flexible(
            child: InteractiveViewer(child: Image.network('${p['photo_url']}', fit: BoxFit.contain)),
          ),
          if ('${p['caption'] ?? ''}'.isNotEmpty)
            Padding(padding: const EdgeInsets.all(10), child: Text('${p['caption']}')),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('بستن')),
            TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _delete(p['id']);
                },
                child: const Text('حذف', style: TextStyle(color: C.danger))),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_photos == null) return const TabLoading();
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final p in _photos!) {
      grouped.putIfAbsent('${p['taken_date']}', () => []).add(p);
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const TabHeader('تصاویر پیشرفت پروژه', subtitle: 'گالری زمانی از روند اجرای کارگاه.'),
        TabCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ErrorLine(_error),
            DateField(label: 'تاریخ عکس', value: _date, onChanged: (v) => setState(() => _date = v)),
            const SizedBox(height: 8),
            TextField(controller: _caption, decoration: hint('توضیح کوتاه (اختیاری)')),
            const SizedBox(height: 10),
            FilledButton(
                onPressed: _uploading ? null : _upload,
                child: Text(_uploading ? 'در حال آپلود...' : '📷 افزودن عکس')),
          ]),
        ),
        const SizedBox(height: 10),
        if (grouped.isEmpty) const EmptyNote('هنوز تصویری ثبت نشده.'),
        for (final e in grouped.entries) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(faDate(e.key),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.soft)),
          ),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            children: [
              for (final p in e.value)
                GestureDetector(
                  onTap: () => _lightbox(p),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network('${p['photo_url']}',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: C.bg3, child: const Icon(Icons.broken_image))),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
