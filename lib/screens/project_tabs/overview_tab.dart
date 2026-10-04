import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'tab_common.dart';

const _phaseLabel = {'pending': 'در صف', 'in_progress': 'در حال اجرا', 'done': 'اجرا شده'};
const _phaseColor = {
  'pending': Color(0xFF6B7F99),
  'in_progress': Color(0xFFFF6B35),
  'done': Color(0xFF22C55E),
};

String _fa(Object? v) {
  const d = '۰۱۲۳۴۵۶۷۸۹';
  return (v ?? '').toString().replaceAllMapped(RegExp(r'\d'), (m) => d[int.parse(m[0]!)]);
}

class OverviewTab extends StatefulWidget {
  final String projectId;
  final Map<String, dynamic> project;
  final List<Map<String, dynamic>> members;
  final bool isOwner;
  final Future<void> Function() onChanged;
  const OverviewTab({
    super.key,
    required this.projectId,
    required this.project,
    required this.members,
    required this.isOwner,
    required this.onChanged,
  });

  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab> {
  List<Map<String, dynamic>>? _phases;
  List<Map<String, dynamic>>? _checklist;
  List<Map<String, dynamic>>? _ann;
  int _notes = 0;
  int _reports = 0;
  final _phaseCtl = TextEditingController();
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _phaseCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final phases = await sb
          .from('project_phases')
          .select()
          .eq('project_id', widget.projectId)
          .order('sort_order');
      final cl = await sb.from('checklist_items').select('done').eq('project_id', widget.projectId);
      final notes = await sb.from('design_notes').select('id').eq('project_id', widget.projectId);
      final reps = await sb.from('reports').select('id').eq('project_id', widget.projectId);
      final ann = await sb
          .from('announcements')
          .select('text, created_at')
          .eq('project_id', widget.projectId)
          .order('created_at', ascending: false)
          .limit(3);
      if (!mounted) return;
      setState(() {
        _phases = List<Map<String, dynamic>>.from(phases);
        _checklist = List<Map<String, dynamic>>.from(cl);
        _ann = List<Map<String, dynamic>>.from(ann);
        _notes = notes.length;
        _reports = reps.length;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _phases ??= [];
          _checklist ??= [];
          _ann ??= [];
        });
      }
    }
  }

  Future<void> _cycle(Map<String, dynamic> p) async {
    if (!widget.isOwner) return;
    final next = p['status'] == 'pending'
        ? 'in_progress'
        : (p['status'] == 'in_progress' ? 'done' : 'pending');
    setState(() => p['status'] = next);
    await sb.from('project_phases').update({'status': next}).eq('id', p['id']);
  }

  Future<void> _deletePhase(Map<String, dynamic> p) async {
    if (!widget.isOwner) return;
    if (!await confirmDialog(context, 'این مرحله حذف شود؟')) return;
    await sb.from('project_phases').delete().eq('id', p['id']);
    _load();
  }

  Future<void> _addPhase() async {
    final t = _phaseCtl.text.trim();
    if (t.isEmpty) return;
    setState(() => _adding = true);
    try {
      await sb.from('project_phases').insert({
        'project_id': widget.projectId,
        'title': t,
        'sort_order': _phases?.length ?? 0,
      });
      _phaseCtl.clear();
      await _load();
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Widget _bar(double pct) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: (pct / 100).clamp(0.0, 1.0),
          minHeight: 8,
          color: C.redLight,
          backgroundColor: const Color(0xFF0B0A0D),
        ),
      );

  Widget _stat(String label, int v) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0x29C50337)),
            gradient: const LinearGradient(colors: [Color(0xFF1D1B22), Color(0xFF141318)]),
          ),
          child: Column(children: [
            Text(_fa(v),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: C.redLight)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: C.muted, fontSize: 11)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (_phases == null || _checklist == null || _ann == null) return const TabLoading();
    final p = widget.project;
    final progress = ((p['progress_percent'] ?? 0) as num).toDouble();
    final done = _checklist!.where((x) => x['done'] == true).length;
    final clPct = _checklist!.isEmpty ? 0.0 : done / _checklist!.length * 100;

    return RefreshIndicator(
      color: C.red,
      onRefresh: () async {
        await widget.onChanged();
        await _load();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const TabHeader('نمای کلی پروژه',
              subtitle: 'خلاصه‌ای برای سرپرست کارگاه از روند اجرا، محاسبات و نظارت.'),
          EngixPanel(
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('کد پروژه (برای دعوت اعضا)',
                      style: TextStyle(color: C.soft, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(widget.projectId,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 3)),
                ]),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 20),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: widget.projectId));
                  snack(context, 'کد کپی شد.');
                },
              ),
            ]),
          ),
          const SizedBox(height: 18),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('پیشرفت کلی پروژه', style: TextStyle(color: C.muted, fontSize: 12.5)),
            Text('${_fa(progress.round())}٪',
                style: const TextStyle(color: C.redLight, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 6),
          _bar(progress),
          const SizedBox(height: 20),
          const Text('مراحل پروژه',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.soft)),
          const SizedBox(height: 8),
          if (_phases!.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('هنوز مرحله‌ای تعریف نشده.', style: TextStyle(color: C.muted, fontSize: 12)),
            ),
          for (final ph in _phases!)
            GestureDetector(
              onTap: () => _cycle(ph),
              onLongPress: () => _deletePhase(ph),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A5F),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Expanded(child: Text((ph['title'] ?? '').toString(), style: const TextStyle(fontSize: 12.5))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(_phaseLabel[ph['status']] ?? '',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _phaseColor[ph['status']] ?? C.soft)),
                  ),
                ]),
              ),
            ),
          if (widget.isOwner) ...[
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _phaseCtl,
                  onSubmitted: (_) => _addPhase(),
                  decoration: hint('نام مرحله جدید (مثلاً: نازک‌کاری)'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(80, 50)),
                onPressed: _adding ? null : _addPhase,
                child: const Text('افزودن'),
              ),
            ]),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('روی هر مرحله بزنید تا وضعیتش عوض شود؛ نگه‌داشتن = حذف',
                  style: TextStyle(color: C.muted, fontSize: 10.5)),
            ),
          ],
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('چک‌لیست اجرا', style: TextStyle(color: C.muted, fontSize: 12.5)),
            Text('${_fa(clPct.round())}٪ (${_fa(done)}/${_fa(_checklist!.length)})',
                style: const TextStyle(color: C.redLight, fontSize: 12.5)),
          ]),
          const SizedBox(height: 6),
          _bar(clPct),
          const SizedBox(height: 20),
          Row(children: [
            _stat('یادداشت محاسباتی', _notes),
            _stat('گزارش نظارتی', _reports),
            _stat('عضو تیم', widget.members.length),
          ]),
          const SizedBox(height: 20),
          const Text('آخرین اطلاعیه‌ها',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.muted)),
          const SizedBox(height: 8),
          if (_ann!.isEmpty)
            const Text('اطلاعیه‌ای ثبت نشده.', style: TextStyle(color: C.muted, fontSize: 12.5)),
          for (final a in _ann!) TabCard(child: Text((a['text'] ?? '').toString(), style: const TextStyle(fontSize: 13))),
          const SizedBox(height: 10),
          const Text('اعضای تیم',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.muted)),
          const SizedBox(height: 6),
          for (final m in widget.members)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0x1AC50337)))),
              child: Row(children: [
                Expanded(child: Text(((m['profile'] as Map?)?['name'] ?? '—').toString())),
                Wrap(spacing: 6, children: [
                  for (final r in (m['roles'] as List? ?? []))
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
              ]),
            ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
