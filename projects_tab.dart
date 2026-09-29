import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme.dart';
import '../core/widgets.dart';
import 'complete_profile_screen.dart' show roleKeys;
import 'project_detail_screen.dart';

class ProjectsTab extends StatefulWidget {
  final Map<String, dynamic> profile;
  const ProjectsTab({super.key, required this.profile});
  @override
  State<ProjectsTab> createState() => _ProjectsTabState();
}

class _ProjectsTabState extends State<ProjectsTab> {
  final _sb = Supabase.instance.client;
  List<Map<String, dynamic>>? _projects;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final rows = await _sb
          .from('project_members')
          .select(
              'roles, projects(id, name, location, company_name, cover_image_url, progress_percent, created_at)')
          .eq('user_id', widget.profile['id']);
      final list = <Map<String, dynamic>>[];
      for (final r in rows) {
        var p = r['projects'];
        if (p is List && p.isNotEmpty) p = p.first;
        if (p is Map) {
          list.add({...Map<String, dynamic>.from(p), 'myRoles': r['roles'] ?? []});
        }
      }
      if (!mounted) return;
      setState(() {
        _projects = list;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _projects = [];
        _error = 'خطا در دریافت پروژه‌ها: $e';
      });
    }
  }

  Future<void> _openDetail(String id) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProjectDetailScreen(profile: widget.profile, projectId: id),
    ));
    _refresh();
  }

  Future<void> _newProject() async {
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg2,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _NewProjectSheet(profile: widget.profile),
      ),
    );
    if (id != null) {
      await _refresh();
      if (mounted) _openDetail(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final projects = _projects;
    return RefreshIndicator(
      color: C.red,
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('پروژه‌های من',
              style: TextStyle(
                  color: C.redLight, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('پروژه‌هایی که در آن‌ها عضو هستید.',
              style: TextStyle(color: C.muted, fontSize: 12.5)),
          const SizedBox(height: 14),
          if (projects == null)
            const Padding(
              padding: EdgeInsets.all(30),
              child: Center(child: CircularProgressIndicator(color: C.red)),
            ),
          if (_error != null) ErrorText(_error),
          if (projects != null && projects.isEmpty && _error == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('هنوز عضو هیچ پروژه‌ای نیستید.',
                  style: TextStyle(color: C.muted)),
            ),
          if (projects != null)
            for (final p in projects) _card(p),
          const SizedBox(height: 8),
          FilledButton(onPressed: _newProject, child: const Text('+ پروژه جدید')),
        ],
      ),
    );
  }

  Widget _card(Map<String, dynamic> p) {
    final cover = p['cover_image_url'] as String?;
    final progress = (p['progress_percent'] ?? 0);
    final roles = List<dynamic>.from(p['myRoles'] ?? []);
    return GestureDetector(
      onTap: () => _openDetail(p['id'].toString()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x2EC50337)),
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF1D1B22), Color(0xFF141318)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: cover != null && cover.isNotEmpty ? 100 : 56,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF26232C), Color(0xFF0B0A0D)]),
                image: (cover != null && cover.isNotEmpty)
                    ? DecorationImage(image: NetworkImage(cover), fit: BoxFit.cover)
                    : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text((p['name'] ?? '').toString(),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 14.5)),
                            if ((p['company_name'] ?? '').toString().isNotEmpty)
                              Text(p['company_name'].toString(),
                                  style: const TextStyle(color: C.muted, fontSize: 11.5)),
                            if ((p['location'] ?? '').toString().isNotEmpty)
                              Text(p['location'].toString(),
                                  style: const TextStyle(color: C.soft, fontSize: 12)),
                          ],
                        ),
                      ),
                      Text('$progress٪',
                          style: const TextStyle(
                              color: C.redLight,
                              fontSize: 17,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                  if (roles.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [for (final r in roles) _badge(r.toString())],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _badge(String t) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0x22C50337),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x44C50337)),
      ),
      child: Text(t, style: const TextStyle(fontSize: 11, color: C.text)),
    );

class _NewProjectSheet extends StatefulWidget {
  final Map<String, dynamic> profile;
  const _NewProjectSheet({required this.profile});
  @override
  State<_NewProjectSheet> createState() => _NewProjectSheetState();
}

class _NewProjectSheetState extends State<_NewProjectSheet> {
  final _sb = Supabase.instance.client;
  final _name = TextEditingController();
  final _company = TextEditingController();
  final _location = TextEditingController();
  late final Set<String> _roles;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _roles = {...List<dynamic>.from(widget.profile['roles'] ?? []).map((e) => '$e')};
  }

  @override
  void dispose() {
    _name.dispose();
    _company.dispose();
    _location.dispose();
    super.dispose();
  }

  String _genCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }

  Future<void> _create() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'نام پروژه را وارد کنید.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final id = _genCode();
    try {
      await _sb.from('projects').insert({
        'id': id,
        'name': _name.text.trim(),
        'location': _location.text.trim(),
        'company_name': _company.text.trim(),
        'created_by': widget.profile['id'],
      });
      await _sb.from('project_members').insert({
        'project_id': id,
        'user_id': widget.profile['id'],
        'roles': _roles.isEmpty
            ? List<dynamic>.from(widget.profile['roles'] ?? [])
            : _roles.toList(),
      });
      if (mounted) Navigator.pop(context, id);
    } on PostgrestException catch (e) {
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'خطا: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: Text('پروژه جدید',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 16),
            TextField(
                controller: _name,
                decoration: const InputDecoration(hintText: 'نام پروژه')),
            const SizedBox(height: 10),
            TextField(
                controller: _company,
                decoration: const InputDecoration(hintText: 'نام شرکت (اختیاری)')),
            const SizedBox(height: 10),
            TextField(
                controller: _location,
                decoration: const InputDecoration(hintText: 'آدرس / محل اجرا')),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: roleKeys
                  .map((k) => FilterChip(
                        label: Text(k),
                        selected: _roles.contains(k),
                        selectedColor: const Color(0x55C50337),
                        backgroundColor: C.bg1,
                        checkmarkColor: Colors.white,
                        onSelected: (v) =>
                            setState(() => v ? _roles.add(k) : _roles.remove(k)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            ErrorText(_error),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: _busy ? null : _create,
              child: Text(_busy ? '...' : 'ساخت پروژه'),
            ),
          ],
        ),
      ),
    );
  }
}
