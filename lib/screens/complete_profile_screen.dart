import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/api.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

const fieldOptions = [
  'عمران', 'معماری', 'برق', 'مکانیک', 'نقشه‌برداری', 'شهرسازی'
];
const roleKeys = ['ناظر', 'مجری', 'طراح', 'مالک', 'پیمانکار'];

class CompleteProfileScreen extends StatefulWidget {
  final String userId;
  final VoidCallback onDone;
  const CompleteProfileScreen(
      {super.key, required this.userId, required this.onDone});
  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _sb = Supabase.instance.client;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _code = TextEditingController();

  String _field = fieldOptions.first;
  final Set<String> _activities = {};
  final Set<dynamic> _systemRoleIds = {};
  List<Map<String, dynamic>>? _systemRoles;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _loadRoles() async {
    try {
      final rows = await _sb
          .from('roles')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true);
      if (mounted) {
        setState(() => _systemRoles = List<Map<String, dynamic>>.from(rows));
      }
    } catch (_) {
      if (mounted) setState(() => _systemRoles = []);
    }
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (_name.text.trim().isEmpty ||
        _phone.text.trim().isEmpty ||
        _activities.isEmpty) {
      setState(() =>
          _error = 'نام، شماره موبایل و حداقل یک حوزه فعالیت لازم است.');
      return;
    }
    if (_systemRoleIds.isEmpty) {
      setState(() => _error = 'لطفاً حداقل یک نقش خود در پروژه را انتخاب کنید.');
      return;
    }
    setState(() => _busy = true);
    try {
      await _sb.from('profiles').insert({
        'id': widget.userId,
        'code': _code.text.trim().isEmpty ? null : _code.text.trim(),
        'name': _name.text.trim(),
        'phone': toLatinDigits(_phone.text.trim()),
        'field': _field,
        'roles': _activities.toList(),
      });
    } on PostgrestException catch (e) {
      setState(() {
        _busy = false;
        _error = e.message;
      });
      return;
    } catch (_) {
      setState(() {
        _busy = false;
        _error = 'خطا در ذخیره پروفایل.';
      });
      return;
    }

    try {
      for (final id in _systemRoleIds) {
        await _sb.from('user_roles').insert({'user_id': widget.userId, 'role_id': id});
      }
      await _sb
          .from('profiles')
          .update({'active_role_id': _systemRoleIds.first}).eq('id', widget.userId);
    } catch (_) {
      // ثبت نقش اگر خطا بدهد، ثبت‌نام اصلی معتبر می‌ماند
    }

    if (mounted) setState(() => _busy = false);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Backdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: EngixPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: EngixLogo(size: 44)),
                      const SizedBox(height: 10),
                      const Center(
                        child: Text('تکمیل پروفایل مهندسی',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _name,
                        decoration:
                            const InputDecoration(hintText: 'نام و نام خانوادگی'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        textDirection: TextDirection.ltr,
                        decoration:
                            const InputDecoration(hintText: 'شماره موبایل'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _code,
                        textDirection: TextDirection.ltr,
                        decoration: const InputDecoration(
                            hintText: 'کد نظام مهندسی (در صورت داشتن)'),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 4, bottom: 12),
                        child: Text(
                          'اگر کد نظام مهندسی ندارید (مثلاً انباردار یا سایر نیروهای پروژه)، این فیلد را خالی بگذارید.',
                          style: TextStyle(color: C.muted, fontSize: 10.5),
                        ),
                      ),
                      DropdownButtonFormField<String>(
                        value: _field,
                        dropdownColor: C.bg2,
                        decoration: const InputDecoration(),
                        items: fieldOptions
                            .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                            .toList(),
                        onChanged: (v) => setState(() => _field = v ?? _field),
                      ),
                      const SizedBox(height: 16),
                      const Text('حوزه‌های فعالیت',
                          style: TextStyle(color: C.soft, fontSize: 12.5)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: roleKeys
                            .map((k) => FilterChip(
                                  label: Text(k),
                                  selected: _activities.contains(k),
                                  selectedColor: const Color(0x55C50337),
                                  backgroundColor: C.bg1,
                                  checkmarkColor: Colors.white,
                                  onSelected: (v) => setState(() =>
                                      v ? _activities.add(k) : _activities.remove(k)),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                      const Text('نقش شما در پروژه',
                          style: TextStyle(color: C.soft, fontSize: 12.5)),
                      const SizedBox(height: 8),
                      _rolesSection(),
                      const SizedBox(height: 14),
                      ErrorText(_error),
                      const SizedBox(height: 10),
                      FilledButton(
                        onPressed: _busy ? null : _save,
                        child: Text(_busy ? '...' : 'ذخیره و ادامه'),
                      ),
                      TextButton(
                        onPressed: () => _sb.auth.signOut(),
                        child: const Text('خروج'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _rolesSection() {
    final roles = _systemRoles;
    if (roles == null) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator(color: C.red)),
      );
    }
    if (roles.isEmpty) {
      return const Text('نقشی یافت نشد.',
          style: TextStyle(color: C.muted, fontSize: 12));
    }
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final r in roles) {
      grouped.putIfAbsent((r['category'] ?? '').toString(), () => []).add(r);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: grouped.entries.map((e) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (e.key.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(e.key,
                      style: const TextStyle(color: C.muted, fontSize: 11.5)),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: e.value.map((r) {
                  final id = r['id'];
                  return FilterChip(
                    label: Text((r['label'] ?? '').toString()),
                    selected: _systemRoleIds.contains(id),
                    selectedColor: const Color(0x55C50337),
                    backgroundColor: C.bg1,
                    checkmarkColor: Colors.white,
                    onSelected: (v) => setState(
                        () => v ? _systemRoleIds.add(id) : _systemRoleIds.remove(id)),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
