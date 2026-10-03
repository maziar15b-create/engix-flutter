import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme.dart';
import '../core/widgets.dart';
import 'project_tabs/announcements_tab.dart';
import 'project_tabs/attendance_tab.dart';
import 'project_tabs/correspondence_tab.dart';
import 'project_tabs/daily_report_tab.dart';
import 'project_tabs/design_tab.dart';
import 'project_tabs/documents_tab.dart';
import 'project_tabs/execution_tab.dart';
import 'project_tabs/export_tab.dart';
import 'project_tabs/gantt_tab.dart';
import 'project_tabs/inventory_tab.dart';
import 'project_tabs/phases_panel.dart';
import 'project_tabs/photos_tab.dart';
import 'project_tabs/qc_tab.dart';
import 'project_tabs/reports_tab.dart';
import 'project_tabs/statement_tab.dart';
import 'project_tabs/supervision_tab.dart';
import 'project_tabs/workorder_tab.dart';

class ProjectDetailScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  final String projectId;
  const ProjectDetailScreen(
      {super.key, required this.profile, required this.projectId});
  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  final _sb = Supabase.instance.client;

  static const _tabs = <List<String>>[
    ['overview', 'نمای کلی'],
    ['reports', 'گزارش کار'],
    ['design', 'محاسبات'],
    ['execution', 'اجرا'],
    ['supervision', 'نظارت'],
    ['gantt', 'برنامه‌زمانبندی'],
    ['statement', 'صورت‌وضعیت'],
    ['workorder', 'دستورکار'],
    ['qc', 'کنترل کیفیت'],
    ['inventory', 'انبار'],
    ['documents', 'اسناد و نقشه‌ها'],
    ['attendance', 'حضور و غیاب'],
    ['photos', 'گالری تصاویر'],
    ['correspondence', 'مکاتبات'],
    ['dailyreport', 'گزارش روزانه'],
    ['announcements', 'اطلاعیه‌ها'],
    ['export', 'خروجی و اشتراک‌گذاری'],
    ['members', 'اعضا'],
  ];

  Map<String, dynamic>? _project;
  List<Map<String, dynamic>>? _members;
  String _tab = 'overview';
  String? _error;

  bool get _isOwner => _project?['created_by'] == widget.profile['id'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final proj = await _sb
          .from('projects')
          .select()
          .eq('id', widget.projectId)
          .maybeSingle();
      final rows = await _sb
          .from('project_members')
          .select('user_id, roles')
          .eq('project_id', widget.projectId);
      final ids = rows.map((r) => r['user_id']).toSet().toList();
      final profs = ids.isEmpty
          ? <dynamic>[]
          : await _sb.from('profiles').select('id, code, name, phone').inFilter('id', ids);
      final pMap = {for (final p in profs) p['id']: p};
      if (!mounted) return;
      setState(() {
        _project = proj;
        _members = [
          for (final r in rows)
            {
              'user_id': r['user_id'],
              'roles': r['roles'] ?? [],
              'profile': pMap[r['user_id']],
            }
        ];
        _error = proj == null ? 'پروژه پیدا نشد.' : null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'خطا در دریافت پروژه: $e');
    }
  }

  Future<void> _edit() async {
    final p = _project!;
    final name = TextEditingController(text: (p['name'] ?? '').toString());
    final company = TextEditingController(text: (p['company_name'] ?? '').toString());
    final location = TextEditingController(text: (p['location'] ?? '').toString());
    double progress = ((p['progress_percent'] ?? 0) as num).toDouble();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg2,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: Text('ویرایش پروژه',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                      controller: name,
                      decoration: const InputDecoration(hintText: 'نام پروژه')),
                  const SizedBox(height: 10),
                  TextField(
                      controller: company,
                      decoration: const InputDecoration(hintText: 'نام شرکت')),
                  const SizedBox(height: 10),
                  TextField(
                      controller: location,
                      decoration: const InputDecoration(hintText: 'محل اجرا')),
                  const SizedBox(height: 14),
                  Text('درصد پیشرفت: ${progress.round()}٪',
                      style: const TextStyle(color: C.soft, fontSize: 12.5)),
                  Slider(
                    value: progress,
                    min: 0,
                    max: 100,
                    divisions: 100,
                    activeColor: C.red,
                    onChanged: (v) => setS(() => progress = v),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('ذخیره')),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (saved == true) {
      try {
        await _sb.from('projects').update({
          'name': name.text.trim(),
          'company_name': company.text.trim(),
          'location': location.text.trim(),
          'progress_percent': progress.round(),
        }).eq('id', widget.projectId);
        await _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('خطا در ذخیره: $e')));
        }
      }
    }
    name.dispose();
    company.dispose();
    location.dispose();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.bg2,
        title: const Text('حذف پروژه'),
        content: const Text('این پروژه برای همه اعضا حذف می‌شود. مطمئنید؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('انصراف')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف', style: TextStyle(color: C.danger))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _sb.from('project_members').delete().eq('project_id', widget.projectId);
      await _sb.from('projects').delete().eq('id', widget.projectId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطا در حذف: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _project;
    return Scaffold(
      body: Backdrop(
        child: SafeArea(
          child: p == null || _members == null
              ? Column(children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                        icon: const Icon(Icons.arrow_forward),
                        onPressed: () => Navigator.pop(context)),
                  ),
                  Expanded(
                    child: Center(
                      child: _error != null
                          ? Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(_error!, textAlign: TextAlign.center))
                          : const CircularProgressIndicator(color: C.red),
                    ),
                  ),
                ])
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
                      child: Row(
                        children: [
                          IconButton(
                              icon: const Icon(Icons.arrow_forward),
                              onPressed: () => Navigator.pop(context)),
                          Expanded(
                            child: Text((p['name'] ?? '').toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700)),
                          ),
                          if (_isOwner)
                            IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                onPressed: _edit),
                          if (_isOwner)
                            IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 20, color: C.danger),
                                onPressed: _delete),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: [
                          for (final t in _tabs)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: _chip(t[1], _tab == t[0],
                                  () => setState(() => _tab = t[0])),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(child: _body(p)),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _chip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          color: active ? const Color(0x33C50337) : C.bg1,
          border: Border.all(
              color: active ? C.red : const Color(0x1AFFFFFF)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? C.redLight : C.muted)),
      ),
    );
  }

  Widget _body(Map<String, dynamic> p) {
    switch (_tab) {
      case 'overview':
        return _overview(p);
      case 'members':
        return _membersList();
      case 'reports':
        return ReportsTab(
            projectId: widget.projectId,
            profile: widget.profile,
            members: _members ?? const [],
            projectName: (p['name'] ?? '').toString());
      case 'workorder':
        return WorkOrderTab(projectId: widget.projectId, profile: widget.profile);
      case 'documents':
        return DocumentsTab(projectId: widget.projectId, profile: widget.profile);
      case 'photos':
        return PhotosTab(projectId: widget.projectId, profile: widget.profile);
      case 'dailyreport':
        return DailyReportTab(projectId: widget.projectId, profile: widget.profile);
      case 'export':
        return ExportTab(
            projectId: widget.projectId,
            profile: widget.profile,
            project: p,
            members: _members ?? const []);
      case 'statement':
        return StatementTab(projectId: widget.projectId, profile: widget.profile);
      case 'design':
        return DesignTab(projectId: widget.projectId, profile: widget.profile);
      case 'execution':
        return ExecutionTab(projectId: widget.projectId);
      case 'supervision':
        return SupervisionTab(projectId: widget.projectId, profile: widget.profile);
      case 'announcements':
        return AnnouncementsTab(
            projectId: widget.projectId,
            profile: widget.profile,
            members: _members ?? const []);
      case 'gantt':
        return GanttTab(projectId: widget.projectId, profile: widget.profile);
      case 'qc':
        return QcTab(projectId: widget.projectId, profile: widget.profile);
      case 'inventory':
        return InventoryTab(projectId: widget.projectId, profile: widget.profile);
      case 'attendance':
        return AttendanceTab(projectId: widget.projectId, profile: widget.profile);
      case 'correspondence':
        return CorrespondenceTab(projectId: widget.projectId, profile: widget.profile);
      default:
        final label = _tabs.firstWhere((t) => t[0] == _tab)[1];
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.construction, size: 38, color: C.muted),
              const SizedBox(height: 10),
              Text(label,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text('به‌زودی', style: TextStyle(color: C.muted)),
            ],
          ),
        );
    }
  }

  Widget _overview(Map<String, dynamic> p) {
    final progress = ((p['progress_percent'] ?? 0) as num).toDouble();
    final cover = p['cover_image_url'] as String?;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (cover != null && cover.isNotEmpty)
          Container(
            height: 150,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              image: DecorationImage(image: NetworkImage(cover), fit: BoxFit.cover),
            ),
          ),
        EngixPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _row('نام پروژه', p['name']),
              _row('شرکت', p['company_name']),
              _row('محل اجرا', p['location']),
              _row('آدرس', p['address']),
            ],
          ),
        ),
        const SizedBox(height: 12),
        EngixPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('پیشرفت پروژه',
                      style: TextStyle(color: C.soft, fontSize: 13)),
                  Text('${progress.round()}٪',
                      style: const TextStyle(
                          color: C.redLight,
                          fontWeight: FontWeight.w800,
                          fontSize: 16)),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress / 100,
                  minHeight: 8,
                  color: C.red,
                  backgroundColor: C.bg1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        PhasesPanel(projectId: widget.projectId, isOwner: _isOwner),
        const SizedBox(height: 12),
        EngixPanel(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('کد پروژه (برای دعوت اعضا)',
                        style: TextStyle(color: C.soft, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(widget.projectId,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 3)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 20),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: widget.projectId));
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('کد کپی شد.')));
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(String k, dynamic v) {
    final s = (v ?? '').toString();
    if (s.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 80,
              child: Text(k, style: const TextStyle(color: C.muted, fontSize: 12.5))),
          Expanded(child: Text(s, style: const TextStyle(fontSize: 13.5))),
        ],
      ),
    );
  }

  Widget _membersList() {
    final members = _members!;
    if (members.isEmpty) {
      return const Center(child: Text('عضوی وجود ندارد.'));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final m in members)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: C.bg2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x2EC50337)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                          ((m['profile'] as Map?)?['name'] ?? 'کاربر').toString(),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                    if (m['user_id'] == _project?['created_by'])
                      const Text('سازنده',
                          style: TextStyle(color: C.redLight, fontSize: 11)),
                  ],
                ),
                if (((m['profile'] as Map?)?['phone'] ?? '').toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text((m['profile'] as Map)['phone'].toString(),
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(color: C.muted, fontSize: 12)),
                  ),
                if ((m['roles'] as List).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final r in (m['roles'] as List))
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0x22C50337),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0x44C50337)),
                          ),
                          child: Text('$r', style: const TextStyle(fontSize: 11)),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
