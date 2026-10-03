import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'tab_common.dart';

const _statusLabel = {'pending': 'در صف', 'in_progress': 'در حال اجرا', 'done': 'اجرا شده'};
const _statusColor = {
  'pending': Color(0xFF6B7F99),
  'in_progress': Color(0xFFFF6B35),
  'done': Color(0xFF22C55E),
};

/// معادل ProjectPhases.js — در «نمای کلی» پروژه نمایش داده می‌شود
class PhasesPanel extends StatefulWidget {
  final String projectId;
  final bool isOwner;
  const PhasesPanel({super.key, required this.projectId, required this.isOwner});
  @override
  State<PhasesPanel> createState() => _PhasesPanelState();
}

class _PhasesPanelState extends State<PhasesPanel> {
  List<Map<String, dynamic>>? _phases;
  final _title = TextEditingController();
  bool _adding = false;

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
    try {
      final d = await sb
          .from('project_phases')
          .select()
          .eq('project_id', widget.projectId)
          .order('sort_order');
      if (mounted) setState(() => _phases = List<Map<String, dynamic>>.from(d));
    } catch (_) {
      if (mounted) setState(() => _phases = _phases ?? []);
    }
  }

  Future<void> _add() async {
    if (_title.text.trim().isEmpty) return;
    setState(() => _adding = true);
    await sb.from('project_phases').insert({
      'project_id': widget.projectId,
      'title': _title.text.trim(),
      'sort_order': _phases?.length ?? 0,
    });
    _title.clear();
    setState(() => _adding = false);
    _refresh();
  }

  Future<void> _cycle(Map<String, dynamic> p) async {
    if (!widget.isOwner) return;
    final cur = '${p['status']}';
    final next = cur == 'pending' ? 'in_progress' : (cur == 'in_progress' ? 'done' : 'pending');
    await sb.from('project_phases').update({'status': next}).eq('id', p['id']);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final phases = _phases;
    if (phases == null) return const SizedBox.shrink();
    return TabCard(
      margin: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('مراحل پروژه',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.redLight)),
        const SizedBox(height: 8),
        if (phases.isEmpty) const EmptyNote('هنوز مرحله‌ای تعریف نشده.'),
        for (final p in phases)
          InkWell(
            onTap: () => _cycle(p),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(children: [
                Expanded(child: Text('${p['title']}', style: const TextStyle(fontSize: 13.5))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: (_statusColor['${p['status']}'] ?? C.muted).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_statusLabel['${p['status']}'] ?? '${p['status']}',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _statusColor['${p['status']}'] ?? C.muted)),
                ),
              ]),
            ),
          ),
        if (widget.isOwner) ...[
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: _title,
                    onSubmitted: (_) => _add(),
                    decoration: hint('نام مرحله جدید (مثلاً: نازک‌کاری)'))),
            const SizedBox(width: 8),
            FilledButton(onPressed: _adding ? null : _add, child: const Text('افزودن')),
          ]),
        ],
      ]),
    );
  }
}
