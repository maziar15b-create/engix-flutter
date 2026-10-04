import 'package:flutter/material.dart';

import '../../core/api.dart' show toLatinDigits;
import '../../core/notify.dart';
import '../../core/theme.dart';
import 'tab_common.dart';

class MembersTab extends StatefulWidget {
  final String projectId;
  final Map<String, dynamic> profile;
  final Map<String, dynamic> project;
  final List<Map<String, dynamic>> members;
  final bool isOwner;
  final Future<void> Function() onUpdated;
  const MembersTab({
    super.key,
    required this.projectId,
    required this.profile,
    required this.project,
    required this.members,
    required this.isOwner,
    required this.onUpdated,
  });

  @override
  State<MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends State<MembersTab> {
  final _phone = TextEditingController();
  String _msg = '';
  bool _busy = false;

  String get _uid => widget.profile['id'].toString();

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  List<String> _phoneVariants(String raw) {
    final d = toLatinDigits(raw).replaceAll(RegExp(r'\D'), '');
    final ten = d.length > 10 ? d.substring(d.length - 10) : d;
    return {raw.trim(), d, '0$ten', ten, '+98$ten', '98$ten'}.where((e) => e.isNotEmpty).toList();
  }

  Future<void> _invite() async {
    final raw = _phone.text.trim();
    if (raw.isEmpty) {
      setState(() => _msg = 'شماره تلفن همکار را وارد کنید.');
      return;
    }
    setState(() {
      _busy = true;
      _msg = '';
    });
    try {
      final eng = await sb
          .from('profiles')
          .select('id')
          .inFilter('phone', _phoneVariants(raw))
          .limit(1)
          .maybeSingle();
      if (eng == null) {
        setState(() => _msg = 'کاربری با این شماره تلفن در EngiX پیدا نشد.');
        return;
      }
      try {
        await sb.from('project_members').insert(
            {'project_id': widget.projectId, 'user_id': eng['id'], 'roles': []});
      } catch (e) {
        setState(() => _msg = '$e'.contains('23505') ? 'قبلاً عضو است.' : '$e');
        return;
      }
      final proj = await sb
          .from('projects')
          .select('chat_conversation_id')
          .eq('id', widget.projectId)
          .maybeSingle();
      final conv = proj?['chat_conversation_id'];
      if (conv != null) {
        try {
          await sb.from('conversation_members').insert(
              {'conversation_id': conv, 'user_id': eng['id'], 'role': 'member'});
        } catch (_) {}
      }
      notifyUsers([eng['id']], 'project_invite', 'دعوت به پروژه',
          '${widget.profile['name'] ?? ''} شما را به پروژه «${widget.project['name'] ?? ''}» اضافه کرد.');
      _phone.clear();
      setState(() => _msg = 'افزوده شد و به گروه پروژه هم پیوست.');
      await widget.onUpdated();
    } catch (e) {
      if (mounted) setState(() => _msg = 'خطا: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Map<String, dynamic> get _me => widget.members.firstWhere(
        (m) => m['user_id'].toString() == _uid,
        orElse: () => {'roles': []},
      );

  Future<void> _toggleMyRole(String r) async {
    final cur = List<String>.from((_me['roles'] as List? ?? []).map((e) => '$e'));
    cur.contains(r) ? cur.remove(r) : cur.add(r);
    await sb
        .from('project_members')
        .update({'roles': cur})
        .eq('project_id', widget.projectId)
        .eq('user_id', _uid);
    await widget.onUpdated();
  }

  Future<void> _remove(Map<String, dynamic> m) async {
    final name = ((m['profile'] as Map?)?['name'] ?? 'این عضو').toString();
    if (!await confirmDialog(context, '$name از پروژه حذف شود؟')) return;
    try {
      await sb
          .from('project_members')
          .delete()
          .eq('project_id', widget.projectId)
          .eq('user_id', m['user_id']);
      final conv = widget.project['chat_conversation_id'];
      if (conv != null) {
        try {
          await sb
              .from('conversation_members')
              .delete()
              .eq('conversation_id', conv)
              .eq('user_id', m['user_id']);
        } catch (_) {}
      }
      await widget.onUpdated();
    } catch (e) {
      if (mounted) snack(context, 'خطا: $e');
    }
  }

  Future<void> _leave() async {
    if (!await confirmDialog(context, 'از این پروژه خارج می‌شوید؟')) return;
    try {
      await sb
          .from('project_members')
          .delete()
          .eq('project_id', widget.projectId)
          .eq('user_id', _uid);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) snack(context, 'خطا: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final myRoles = (_me['roles'] as List? ?? []).map((e) => '$e').toSet();
    final creator = widget.project['created_by']?.toString();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const TabHeader('اعضای پروژه',
            subtitle: 'با شماره تلفن، همکار جدید را اضافه کنید — نیازی به کد نظام مهندسی نیست.'),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              onSubmitted: (_) => _invite(),
              decoration: hint('شماره تلفن همکار (مثلاً 09121234567)'),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(80, 50)),
            onPressed: _busy ? null : _invite,
            child: Text(_busy ? '...' : 'افزودن'),
          ),
        ]),
        if (_msg.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_msg, style: const TextStyle(color: C.soft, fontSize: 12.5)),
          ),
        const SizedBox(height: 20),
        const Text('نقش من در این پروژه',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.muted)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final r in kRoleKeys)
            ChoiceChipBtn(label: r, active: myRoles.contains(r), onTap: () => _toggleMyRole(r)),
        ]),
        const SizedBox(height: 22),
        const Text('لیست اعضا',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.muted)),
        const SizedBox(height: 8),
        for (final m in widget.members)
          TabCard(
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(
                      child: Text(((m['profile'] as Map?)?['name'] ?? '—').toString(),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    ),
                    if (m['user_id'].toString() == creator)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Text('سازنده', style: TextStyle(color: C.redLight, fontSize: 11)),
                      ),
                  ]),
                  Text(
                    (((m['profile'] as Map?)?['code'] ?? (m['profile'] as Map?)?['phone'] ?? '')).toString(),
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(color: C.muted, fontSize: 11),
                  ),
                  if ((m['roles'] as List? ?? []).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(spacing: 6, runSpacing: 6, children: [
                        for (final r in (m['roles'] as List))
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
              if (widget.isOwner && m['user_id'].toString() != _uid)
                IconButton(
                  icon: const Icon(Icons.person_remove_outlined, color: C.danger, size: 20),
                  onPressed: () => _remove(m),
                ),
            ]),
          ),
        if (!widget.isOwner) ...[
          const SizedBox(height: 14),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48), foregroundColor: C.danger),
            onPressed: _leave,
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('خروج از پروژه'),
          ),
        ],
        const SizedBox(height: 30),
      ],
    );
  }
}
