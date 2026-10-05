import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import 'tab_common.dart';

const _exportBucket = 'project-exports';

const _sectionDefs = <List<String>>[
  ['correspondence', 'نامه‌ها / مکاتبات'],
  ['dailyreport', 'گزارش روزانه'],
  ['reports', 'گزارش کار'],
  ['supervision', 'نظارت'],
  ['gantt', 'برنامه زمان‌بندی'],
  ['workorder', 'دستور کار'],
  ['qc', 'کنترل کیفیت'],
  ['documents', 'دفتر فنی / اسناد'],
  ['inventory', 'انبار'],
  ['attendance', 'حضور و غیاب'],
  ['photos', 'گالری تصاویر'],
  ['announcements', 'اطلاعیه‌ها'],
];

const _dirLabels = {'incoming': 'وارده', 'outgoing': 'صادره'};
const _qcLabels = {'pass': 'قبول', 'fail': 'رد', 'pending': 'در انتظار'};
const _attLabels = {'present': 'حاضر', 'absent': 'غایب', 'half': 'نیمه‌روز'};
const _woLabels = {'done': 'انجام‌شده', 'pending': 'در انتظار'};
const _invLabels = {'in': 'ورود', 'out': 'خروج'};

String _d(dynamic v) => (v == null || '$v'.isEmpty) ? '—' : '$v'.substring(0, '$v'.length < 10 ? '$v'.length : 10);
String _v(dynamic v) => (v == null || '$v'.isEmpty) ? '—' : '$v';

class _Section {
  final String key;
  final String label;
  final List<String> headers;
  final List<List<String>> rows;
  _Section(this.key, this.label, this.headers, this.rows);
}

class ExportTab extends StatefulWidget {
  final String projectId;
  final Map<String, dynamic> profile;
  final Map<String, dynamic> project;
  final List<Map<String, dynamic>> members;
  const ExportTab(
      {super.key,
      required this.projectId,
      required this.profile,
      required this.project,
      required this.members});
  @override
  State<ExportTab> createState() => _ExportTabState();
}

class _ExportTabState extends State<ExportTab> {
  final Set<String> _selected = {for (final s in _sectionDefs) s[0]};
  String _busy = '';
  String _error = '';
  String _notice = '';
  bool _showShare = false;
  final Set<String> _picked = {};
  String? _xlsxUrl;
  String? _htmlUrl;

  Future<List<Map<String, dynamic>>> _q(String table, String order, {bool asc = false}) async {
    final d = await sb.from(table).select().eq('project_id', widget.projectId).order(order, ascending: asc);
    return List<Map<String, dynamic>>.from(d);
  }

  Future<List<_Section>> _buildSections() async {
    if (_selected.isEmpty) throw Exception('حداقل یک بخش را برای خروجی انتخاب کنید.');
    final corr = await _q('project_correspondence', 'correspondence_date');
    final daily = await _q('project_daily_reports', 'report_date');
    final updates = await _q('project_updates', 'created_at');
    final superv = await _q('reports', 'created_at');
    final gantt = await _q('project_gantt_tasks', 'order_index', asc: true);
    final wos = await _q('project_work_orders', 'meeting_date');
    final qc = await _q('project_qc_items', 'order_index', asc: true);
    final docs = await _q('project_documents', 'created_at');
    final inv = await _q('project_inventory_transactions', 'transaction_date');
    final att = await _q('project_attendance', 'attendance_date');
    final photos = await _q('project_photos', 'taken_date');
    final ann = await _q('announcements', 'created_at');

    var actions = <Map<String, dynamic>>[];
    final woIds = wos.map((w) => w['id']).toList();
    if (woIds.isNotEmpty) {
      final a = await sb
          .from('project_work_order_actions')
          .select()
          .inFilter('work_order_id', woIds)
          .order('order_index');
      actions = List<Map<String, dynamic>>.from(a);
    }

    final ids = <dynamic>[
      ...corr.map((r) => r['created_by']),
      ...daily.map((r) => r['created_by']),
      ...updates.map((r) => r['author_id']),
      ...superv.map((r) => r['by']),
      ...docs.map((r) => r['uploaded_by']),
      ...ann.map((r) => r['by']),
    ];
    final pm = await fetchProfilesMap(ids);
    String nm(dynamic id) => id == null ? '—' : (pm['$id']?['name'] ?? '—').toString();

    final out = <_Section>[];
    void push(String key, String label, List<String> h, List<List<String>> rows) {
      if (_selected.contains(key)) out.add(_Section(key, label, h, rows));
    }

    push('correspondence', 'نامه‌ها / مکاتبات',
        ['تاریخ', 'جهت', 'شماره نامه', 'موضوع', 'طرف مقابل', 'متن/خلاصه'],
        [for (final r in corr) [_d(r['correspondence_date']), _dirLabels[r['direction']] ?? _v(r['direction']), _v(r['letter_number']), _v(r['subject']), _v(r['counterparty']), _v(r['content'])]]);
    push('dailyreport', 'گزارش روزانه',
        ['تاریخ', 'آب‌وهوا', 'نیروی انسانی', 'یادداشت تجهیزات', 'فعالیت‌ها', 'مشکلات'],
        [for (final r in daily) [_d(r['report_date']), _v(r['weather']), _v(r['workforce_count']), _v(r['equipment_notes']), _v(r['activities']), _v(r['issues'])]]);
    push('reports', 'گزارش کار', ['تاریخ', 'نوع گزارش', 'نویسنده', 'متن'],
        [for (final r in updates) [_d(r['created_at']), _v(r['report_type']), nm(r['author_id']), _v(r['body'])]]);
    push('supervision', 'نظارت', ['تاریخ', 'ثبت‌کننده', 'متن یادداشت'],
        [for (final r in superv) [_d(r['created_at']), nm(r['by']), _v(r['text'])]]);
    push('gantt', 'برنامه زمان‌بندی', ['فعالیت', 'تاریخ شروع', 'مدت (روز)', 'درصد پیشرفت'],
        [for (final r in gantt) [_v(r['name']), _d(r['start_date']), _v(r['duration_days']), '${r['progress_percent'] ?? 0}%']]);

    final woRows = <List<String>>[];
    for (final w in wos) {
      woRows.add([_d(w['meeting_date']), _v(w['title']), _v(w['attendees']), _v(w['content']), '—']);
      for (final a in actions.where((a) => a['work_order_id'] == w['id'])) {
        woRows.add([
          '',
          '  ↳ ${_v(a['text'])}',
          _v(a['assignee']),
          a['due_date'] != null ? 'مهلت: ${_d(a['due_date'])}' : '',
          _woLabels[a['status']] ?? _v(a['status']),
        ]);
      }
    }
    push('workorder', 'دستور کار', ['تاریخ جلسه', 'عنوان / اقدام', 'حاضرین / مسئول', 'متن / مهلت', 'وضعیت'], woRows);
    push('qc', 'کنترل کیفیت', ['فاز', 'آیتم', 'وضعیت', 'یادداشت'],
        [for (final r in qc) [_v(r['phase']), _v(r['item_text']), _qcLabels[r['status']] ?? 'در انتظار', _v(r['notes'])]]);
    push('documents', 'دفتر فنی / اسناد', ['تاریخ', 'عنوان', 'دسته‌بندی', 'آپلودکننده', 'لینک فایل'],
        [for (final r in docs) [_d(r['created_at']), _v(r['title']), _v(r['category']), nm(r['uploaded_by']), _v(r['file_url'])]]);
    push('inventory', 'انبار', ['تاریخ', 'کد کالا', 'نام کالا', 'واحد', 'نوع تراکنش', 'مقدار', 'یادداشت'],
        [for (final r in inv) [_d(r['transaction_date']), _v(r['material_code']), _v(r['material_name']), _v(r['unit']), _invLabels[r['transaction_type']] ?? _v(r['transaction_type']), _v(r['quantity']), _v(r['notes'])]]);
    push('attendance', 'حضور و غیاب', ['تاریخ', 'نام نیرو', 'تخصص', 'وضعیت'],
        [for (final r in att) [_d(r['attendance_date']), _v(r['worker_name']), _v(r['trade']), _attLabels[r['status']] ?? _v(r['status'])]]);
    push('photos', 'گالری تصاویر', ['تاریخ', 'توضیح', 'لینک تصویر'],
        [for (final r in photos) [_d(r['taken_date']), _v(r['caption']), _v(r['photo_url'])]]);
    push('announcements', 'اطلاعیه‌ها', ['تاریخ', 'ثبت‌کننده', 'متن'],
        [for (final r in ann) [_d(r['created_at']), nm(r['by']), _v(r['text'])]]);
    return out;
  }

  // ───────── ساخت فایل‌ها ─────────

  Uint8List _xlsxBytes(List<_Section> sections) {
    final ex = Excel.createExcel();
    final def = ex.getDefaultSheet();
    for (final s in sections) {
      var name = s.label.replaceAll(RegExp(r'[\\/*?:\[\]]'), '-');
      if (name.length > 31) name = name.substring(0, 31);
      final sh = ex[name];
      sh.appendRow([for (final h in s.headers) TextCellValue(h)]);
      for (final r in s.rows) {
        sh.appendRow([for (final c in r) TextCellValue(c)]);
      }
    }
    if (def != null && sections.isNotEmpty) ex.delete(def);
    final bytes = ex.encode();
    if (bytes == null) throw Exception('ساخت فایل اکسل ناموفق بود.');
    return Uint8List.fromList(bytes);
  }

  String _esc(String s) =>
      s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

  String _html(List<_Section> sections) {
    final b = StringBuffer();
    b.write('<!DOCTYPE html><html lang="fa" dir="rtl"><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width, initial-scale=1">'
        '<title>گزارش پروژه</title><style>'
        'body{font-family:Tahoma,Vazirmatn,Arial,sans-serif;margin:18px;color:#111;background:#fff}'
        'h1{font-size:18px;color:#7A0224}h2{font-size:14px;color:#7A0224;border-bottom:2px solid #C50337;padding-bottom:4px;margin-top:22px}'
        'table{border-collapse:collapse;width:100%;font-size:11px}'
        'th{background:#f3f1ec;border:1px solid #ccc;padding:5px}td{border:1px solid #ddd;padding:5px;vertical-align:top}'
        '.n{color:#999;font-size:12px}@media print{body{margin:6mm}}'
        '</style></head><body>');
    b.write('<h1>گزارش یکپارچه پروژه «${_esc('${widget.project['name'] ?? ''}')}»</h1>');
    b.write('<div class="n">تاریخ تهیه: ${todayStr()}</div>');
    for (final s in sections) {
      b.write('<h2>${_esc(s.label)} <span class="n">(${s.rows.length})</span></h2>');
      if (s.rows.isEmpty) {
        b.write('<div class="n">داده‌ای ثبت نشده است.</div>');
        continue;
      }
      b.write('<table><tr>');
      for (final h in s.headers) {
        b.write('<th>${_esc(h)}</th>');
      }
      b.write('</tr>');
      for (final r in s.rows) {
        b.write('<tr>');
        for (final c in r) {
          b.write('<td>${_esc(c)}</td>');
        }
        b.write('</tr>');
      }
      b.write('</table>');
    }
    b.write('</body></html>');
    return b.toString();
  }

  String get _base => 'report-${DateTime.now().millisecondsSinceEpoch}';

  Future<File> _tmp(String name, List<int> bytes) async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/$name');
    await f.writeAsBytes(bytes);
    return f;
  }

  Future<void> _run(String what, Future<void> Function() fn) async {
    setState(() {
      _error = '';
      _notice = '';
      _busy = what;
    });
    try {
      await fn();
    } catch (e) {
      if (mounted) setState(() => _error = '$e'.replaceFirst('Exception: ', ''));
    }
    if (mounted) setState(() => _busy = '');
  }

  Future<void> _exportExcel() => _run('excel', () async {
        final sections = await _buildSections();
        final f = await _tmp('$_base.xlsx', _xlsxBytes(sections));
        await Share.shareXFiles([XFile(f.path)], text: 'گزارش پروژه');
        if (mounted) setState(() => _notice = 'فایل اکسل آماده شد.');
      });

  Future<void> _exportHtml() => _run('html', () async {
        final sections = await _buildSections();
        final f = await _tmp('$_base.html', utf8.encode(_html(sections)));
        await Share.shareXFiles([XFile(f.path, mimeType: 'text/html')], text: 'گزارش پروژه');
        if (mounted) {
          setState(() => _notice = 'گزارش آماده شد. آن را در مرورگر باز کنید و «چاپ ← ذخیره به‌صورت PDF» بزنید.');
        }
      });

  Future<void> _ensureUploaded() async {
    if (_xlsxUrl != null && _htmlUrl != null) return;
    final sections = await _buildSections();
    final st = sb.storage.from(_exportBucket);
    final base = _base;
    final xp = '${widget.projectId}/$base.xlsx';
    final hp = '${widget.projectId}/$base.html';
    try {
      await st.uploadBinary(xp, _xlsxBytes(sections),
          fileOptions: const FileOptions(
              contentType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
              upsert: false));
      await st.uploadBinary(hp, Uint8List.fromList(utf8.encode(_html(sections))),
          fileOptions: const FileOptions(contentType: 'text/html; charset=utf-8', upsert: false));
    } catch (e) {
      throw Exception('آپلود فایل خروجی ناموفق بود: $e');
    }
    _xlsxUrl = st.getPublicUrl(xp);
    _htmlUrl = st.getPublicUrl(hp);
  }

  Future<void> _shareExternal() => _run('upload', () async {
        await _ensureUploaded();
        await Share.share('گزارش یکپارچه پروژه «${widget.project['name'] ?? ''}»\n$_htmlUrl\n$_xlsxUrl');
      });

  Future<void> _shareInternal() async {
    if (_picked.isEmpty) {
      setState(() => _error = 'حداقل یک نفر را از لیست انتخاب کنید.');
      return;
    }
    await _run('upload', () async {
      await _ensureUploaded();
      final text = '📎 گزارش یکپارچه پروژه «${widget.project['name'] ?? ''}»\n'
          '📄 مشاهده/چاپ گزارش: $_htmlUrl\n'
          '📊 دانلود اکسل: $_xlsxUrl';
      final token = sb.auth.currentSession?.accessToken;
      for (final uid in _picked) {
        final convId = await sb.rpc('get_or_create_direct_conversation', params: {'other_user_id': uid});
        await sb.from('messages').insert({
          'conversation_id': convId.toString(),
          'sender_id': widget.profile['id'],
          'type': 'text',
          'content': text,
        });
        if (token != null) {
          http
              .post(
                Uri.parse('${Config.apiBase}/api/notifications/send-message-push'),
                headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
                body: jsonEncode({
                  'conversationId': convId.toString(),
                  'senderId': widget.profile['id'],
                  'text': text,
                }),
              )
              .catchError((_) => http.Response('', 500));
        }
      }
      if (mounted) {
        setState(() {
          _notice = 'گزارش برای ${_picked.length} نفر در پیام‌رسان ارسال شد.';
          _showShare = false;
          _picked.clear();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final options = widget.members.where((m) => m['user_id'] != widget.profile['id']).toList();
    final busy = _busy.isNotEmpty;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const TabHeader('خروجی و اشتراک‌گذاری',
            subtitle: 'بخش‌های مورد نظر را انتخاب کنید و گزارش یکپارچه پروژه را به‌صورت اکسل یا گزارش قابل‌چاپ بگیرید.'),
        Row(children: [
          TextButton(
              onPressed: () => setState(() {
                    if (_selected.length == _sectionDefs.length) {
                      _selected.clear();
                    } else {
                      _selected.addAll(_sectionDefs.map((s) => s[0]));
                    }
                  }),
              child: Text(_selected.length == _sectionDefs.length ? 'برداشتن همه' : 'انتخاب همه')),
        ]),
        for (final s in _sectionDefs)
          InkWell(
            onTap: () => setState(() {
              _xlsxUrl = null;
              _htmlUrl = null;
              _selected.contains(s[0]) ? _selected.remove(s[0]) : _selected.add(s[0]);
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: _selected.contains(s[0]) ? C.red : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: C.red, width: 1.5),
                  ),
                  child: _selected.contains(s[0])
                      ? const Icon(Icons.check, size: 13, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 10),
                Text(s[1], style: const TextStyle(fontSize: 13.5)),
              ]),
            ),
          ),
        const SizedBox(height: 14),
        ErrorLine(_error),
        if (_notice.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(_notice, style: const TextStyle(color: Color(0xFF4ADE80), fontSize: 12.5)),
          ),
        if (busy) const Padding(padding: EdgeInsets.only(bottom: 8), child: LinearProgressIndicator(color: C.red)),
        FilledButton(onPressed: busy ? null : _exportExcel, child: const Text('📊 خروجی اکسل')),
        const SizedBox(height: 8),
        FilledButton(onPressed: busy ? null : _exportHtml, child: const Text('📄 گزارش قابل‌چاپ (PDF)')),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: busy ? null : _shareExternal, child: const Text('🔗 اشتراک‌گذاری بیرونی')),
        const SizedBox(height: 8),
        OutlinedButton(
            onPressed: busy ? null : () => setState(() => _showShare = !_showShare),
            child: const Text('💬 ارسال به اعضا در پیام‌رسان')),
        if (_showShare) ...[
          const SizedBox(height: 10),
          TabCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (options.isEmpty) const EmptyNote('عضو دیگری در پروژه نیست.'),
              for (final m in options)
                CheckboxListTile(
                  dense: true,
                  activeColor: C.red,
                  value: _picked.contains('${m['user_id']}'),
                  onChanged: (v) => setState(() {
                    v == true ? _picked.add('${m['user_id']}') : _picked.remove('${m['user_id']}');
                  }),
                  title: Text('${(m['profile'] as Map?)?['name'] ?? 'کاربر'}'),
                ),
              const SizedBox(height: 8),
              FilledButton(onPressed: busy ? null : _shareInternal, child: const Text('ارسال')),
            ]),
          ),
        ],
      ],
    );
  }
}
