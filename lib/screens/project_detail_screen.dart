import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import '../core/widgets.dart';
import 'chat_thread_screen.dart';
import 'project_edit_screen.dart';
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
import 'project_tabs/members_tab.dart';
import 'project_tabs/overview_tab.dart';
import 'project_tabs/photos_tab.dart';
import 'project_tabs/qc_tab.dart';
import 'project_tabs/reports_tab.dart';
import 'project_tabs/statement_tab.dart';
import 'project_tabs/supervision_tab.dart';
import 'project_tabs/workorder_tab.dart';

String _fa(Object? v) {
  const d = '۰۱۲۳۴۵۶۷۸۹';
  return (v ?? '').toString().replaceAllMapped(RegExp(r'\d'), (m) => d[int.parse(m[0]!)]);
}

class ProjectDetailScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  final String projectId;
  const ProjectDetailScreen({super.key, required this.profile, required this.projectId});
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
  bool _openingChat = false;

  String get _uid => widget.profile['id'].toString();
  bool get _isOwner => _project?['created_by']?.toString() == _uid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final proj = await _sb.from('projects').select().eq('id', widget.projectId).maybeSingle();
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

  Future<void> _openSettings() async {
    final res = await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => ProjectEditScreen(projectId: widget.projectId, project: _project!),
    ));
    if (!mounted) return;
    if (res == 'deleted') {
      Navigator.pop(context);
      return;
    }
    await _load();
  }

  Future<void> _openProjectChat() async {
    final conv = _project?['chat_conversation_id']?.toString();
    if (conv == null || conv.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('این پروژه گروه گفتگو ندارد.')));
      return;
    }
    setState(() => _openingChat = true);
    try {
      try {
        await _sb.from('conversation_members').insert(
            {'conversation_id': conv, 'user_id': _uid, 'role': 'member'});
      } catch (_) {}
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChatThreadScreen(
          profile: widget.profile,
          conversationId: conv,
          title: (_project?['name'] ?? 'گروه پروژه').toString(),
        ),
      ));
    } finally {
      if (mounted) setState(() => _openingChat = false);
    }
  }

  Future<void> _openMap() async {
    final lat = _project?['latitude'];
    final lng = _project?['longitude'];
    if (lat == null || lng == null) return;
    await launchUrl(Uri.parse('https://www.google.com/maps?q=$lat,$lng'),
        mode: LaunchMode.externalApplication);
  }

  Widget _header(Map<String, dynamic> p) {
    final cover = (p['cover_image_url'] ?? '').toString();
    final me = _members!.firstWhere(
      (m) => m['user_id'].toString() == _uid,
      orElse: () => {'roles': []},
    );
    final hasLoc = p['latitude'] != null && p['longitude'] != null;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x29C50337)),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF1D1B22), Color(0xFF141318)],
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (cover.isNotEmpty)
          Container(
            height: 110,
            decoration: BoxDecoration(
              image: DecorationImage(image: NetworkImage(cover), fit: BoxFit.cover),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text((p['name'] ?? '').toString(),
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  if ((p['company_name'] ?? '').toString().isNotEmpty)
                    Text(p['company_name'].toString(),
                        style: const TextStyle(color: C.muted, fontSize: 12)),
                  if ((p['location'] ?? '').toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(p['location'].toString(),
                          style: const TextStyle(color: C.soft, fontSize: 12.5)),
                    ),
                  if ((p['address'] ?? '').toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(p['address'].toString(),
                          style: const TextStyle(color: C.muted, fontSize: 11.5)),
                    ),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(widget.projectId,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(color: C.redLight, fontSize: 12, letterSpacing: 1.5)),
                Text('${_fa(p['progress_percent'] ?? 0)}٪',
                    style: const TextStyle(
                        color: C.redLight, fontSize: 21, fontWeight: FontWeight.w800)),
              ]),
            ]),
            if (hasLoc)
              GestureDetector(
                onTap: _openMap,
                child: const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('📍 مشاهده موقعیت دقیق روی نقشه',
                      style: TextStyle(color: C.redLight, fontSize: 12)),
                ),
              ),
            if ((me['roles'] as List? ?? []).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final r in (me['roles'] as List))
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0x22C50337),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0x44C50337)),
                      ),
                      child: Text('$r', style: const TextStyle(fontSize: 11)),
                    ),
                ]),
              ),
          ]),
        ),
      ]),
    );
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
              : Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
                    child: Row(children: [
                      IconButton(
                          icon: const Icon(Icons.arrow_forward),
                          onPressed: () => Navigator.pop(context)),
                      Expanded(
                        child: Text((p['name'] ?? '').toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                      IconButton(
                        tooltip: 'گروه گفتگوی پروژه',
                        icon: _openingChat
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: C.red))
                            : const Icon(Icons.forum_outlined, size: 21),
                        onPressed: _openingChat ? null : _openProjectChat,
                      ),
                      if (_isOwner)
                        IconButton(
                          tooltip: 'تنظیمات پروژه',
                          icon: const Icon(Icons.settings_outlined, size: 21),
                          onPressed: _openSettings,
                        ),
                    ]),
                  ),
                  _header(p),
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        for (final t in _tabs)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: _chip(t[1], _tab == t[0], () => setState(() => _tab = t[0])),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(child: _body(p)),
                ]),
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
          border: Border.all(color: active ? C.red : const Color(0x1AFFFFFF)),
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
    final id = widget.projectId;
    final prof = widget.profile;
    final members = _members ?? const <Map<String, dynamic>>[];
    switch (_tab) {
      case 'overview':
        return OverviewTab(
          projectId: id,
          project: p,
          members: members,
          isOwner: _isOwner,
          onChanged: _load,
        );
      case 'reports':
        return ReportsTab(
            projectId: id,
            profile: prof,
            members: members,
            projectName: (p['name'] ?? '').toString());
      case 'design':
        return DesignTab(projectId: id, profile: prof);
      case 'execution':
        return ExecutionTab(projectId: id, profile: prof, members: members);
      case 'supervision':
        return SupervisionTab(projectId: id, profile: prof, members: members);
      case 'gantt':
        return GanttTab(projectId: id, profile: prof);
      case 'statement':
        return StatementTab(projectId: id, profile: prof);
      case 'workorder':
        return WorkOrderTab(projectId: id, profile: prof);
      case 'qc':
        return QcTab(projectId: id, profile: prof);
      case 'inventory':
        return InventoryTab(projectId: id, profile: prof);
      case 'documents':
        return DocumentsTab(projectId: id, profile: prof);
      case 'attendance':
        return AttendanceTab(projectId: id, profile: prof);
      case 'photos':
        return PhotosTab(projectId: id, profile: prof);
      case 'correspondence':
        return CorrespondenceTab(projectId: id, profile: prof);
      case 'dailyreport':
        return DailyReportTab(projectId: id, profile: prof);
      case 'announcements':
        return AnnouncementsTab(projectId: id, profile: prof, members: members);
      case 'export':
        return ExportTab(projectId: id, profile: prof, project: p, members: members);
      case 'members':
        return MembersTab(
          projectId: id,
          profile: prof,
          project: p,
          members: members,
          isOwner: _isOwner,
          onUpdated: _load,
        );
    }
    return const SizedBox.shrink();
  }
}
