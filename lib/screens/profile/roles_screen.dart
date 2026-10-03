import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme.dart';
import 'profile_common.dart';

class RolesScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  const RolesScreen({super.key, required this.profile});

  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  SupabaseClient get _db => Supabase.instance.client;
  String get _uid => widget.profile['id'].toString();

  List<Map<String, dynamic>>? _all;
  List<Map<String, dynamic>>? _mine;
  String? _activeId;
  String? _busy;
  String _msg = '';

  @override
  void initState() {
    super.initState();
    _activeId = widget.profile['active_role_id']?.toString();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final all = await _db
          .from('roles')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true);
      final mine = await _db.from('user_roles').select('role_id, roles(*)').eq('user_id', _uid);
      final myRoles = <Map<String, dynamic>>[];
      for (final r in mine) {
        var role = r['roles'];
        if (role is List && role.isNotEmpty) role = role.first;
        if (role is Map) myRoles.add(Map<String, dynamic>.from(role));
      }
      myRoles.sort((a, b) =>
          ((a['sort_order'] ?? 0) as num).compareTo((b['sort_order'] ?? 0) as num));
      final prof = await _db.from('profiles').select('active_role_id').eq('id', _uid).maybeSingle();
      if (!mounted) return;
      setState(() {
        _all = List<Map<String, dynamic>>.from(all);
        _mine = myRoles;
        _activeId = prof?['active_role_id']?.toString() ?? _activeId;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _all ??= [];
        _mine ??= [];
        _msg = 'خطا در دریافت نقش‌ها: $e';
      });
    }
  }

  Future<void> _toggle(Map<String, dynamic> role) async {
    final id = role['id'].toString();
    final mine = _mine ?? [];
    final has = mine.any((r) => r['id'].toString() == id);
    setState(() {
      _msg = '';
      _busy = id;
    });
    try {
      if (has) {
        if (mine.length == 1) {
          setState(() {
            _msg = 'حداقل یک نقش باید فعال بماند.';
            _busy = null;
          });
          return;
        }
        await _db.from('user_roles').delete().eq('user_id', _uid).eq('role_id', role['id']);
        if (_activeId == id) {
          final next = mine.firstWhere((r) => r['id'].toString() != id);
          await _db.from('profiles').update({'active_role_id': next['id']}).eq('id', _uid);
        }
      } else {
        await _db.from('user_roles').insert({'user_id': _uid, 'role_id': role['id']});
      }
      await _refresh();
    } catch (e) {
      if (mounted) setState(() => _msg = 'خطا: $e');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _setActive(Map<String, dynamic> role) async {
    final id = role['id'].toString();
    setState(() {
      _busy = 'active-$id';
      _msg = '';
    });
    try {
      await _db.from('profiles').update({'active_role_id': role['id']}).eq('id', _uid);
      if (mounted) setState(() => _activeId = id);
    } catch (e) {
      if (mounted) setState(() => _msg = 'خطا: $e');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = _all;
    final mine = _mine;
    final myIds = {for (final r in mine ?? []) r['id'].toString()};
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final r in all ?? []) {
      grouped.putIfAbsent((r['category'] ?? 'سایر').toString(), () => []).add(r);
    }
    return PfPage(
      title: 'نقش‌های من',
      child: (all == null || mine == null)
          ? const PfLoading()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'نقش فعال شما روی عنوان پروفایل، جستجو و پیشنهادها اثر می‌گذارد. برای تغییر نیازی به خروج از حساب نیست.',
                  style: TextStyle(color: C.muted, fontSize: 12.5, height: 1.8),
                ),
                const SizedBox(height: 16),
                if (mine.isNotEmpty) ...[
                  const PfTitle('نقش فعال'),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final r in mine)
                      ChoiceChip(
                        label: Text((r['label'] ?? '').toString()),
                        selected: _activeId == r['id'].toString(),
                        selectedColor: const Color(0x55C50337),
                        backgroundColor: C.bg1,
                        onSelected: _busy == null ? (_) => _setActive(r) : null,
                      ),
                  ]),
                  const SizedBox(height: 18),
                ],
                if (_msg.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_msg, style: const TextStyle(color: C.redLight, fontSize: 12.5)),
                  ),
                const PfTitle('افزودن / حذف نقش'),
                for (final e in grouped.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 8),
                    child: Text(e.key, style: const TextStyle(color: C.muted, fontSize: 12)),
                  ),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final r in e.value)
                      FilterChip(
                        label: Text((r['label'] ?? '').toString()),
                        selected: myIds.contains(r['id'].toString()),
                        selectedColor: const Color(0x55C50337),
                        backgroundColor: C.bg1,
                        checkmarkColor: Colors.white,
                        onSelected: _busy == null ? (_) => _toggle(r) : null,
                      ),
                  ]),
                ],
                const SizedBox(height: 30),
              ],
            ),
    );
  }
}
