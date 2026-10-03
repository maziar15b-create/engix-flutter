import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'profile_common.dart';

const _fieldOptions = ['عمران', 'معماری', 'برق', 'مکانیک', 'نقشه‌برداری', 'شهرسازی'];
const _roleKeys = ['ناظر', 'مجری', 'طراح', 'مالک', 'پیمانکار'];

List<String> _list(dynamic v) =>
    v is List ? v.map((e) => e.toString()).toList() : <String>[];

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  SupabaseClient get _db => Supabase.instance.client;

  late final TextEditingController _name;
  late final TextEditingController _username;
  late final TextEditingController _bio;
  late final TextEditingController _resume;
  late final TextEditingController _experience;
  late final TextEditingController _skills;
  late final TextEditingController _certs;
  late final TextEditingController _portfolio;
  late String _field;
  late final Set<String> _roles;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _name = TextEditingController(text: (p['name'] ?? '').toString());
    _username = TextEditingController(text: (p['username'] ?? '').toString());
    _bio = TextEditingController(text: (p['bio'] ?? '').toString());
    _resume = TextEditingController(text: (p['resume'] ?? '').toString());
    _experience = TextEditingController(text: (p['experience'] ?? '').toString());
    _skills = TextEditingController(text: _list(p['skills']).join('، '));
    _certs = TextEditingController(text: _list(p['certificates']).join('\n'));
    _portfolio = TextEditingController(text: _list(p['portfolio']).join('\n'));
    final f = (p['field'] ?? '').toString();
    _field = _fieldOptions.contains(f) ? f : _fieldOptions.first;
    _roles = {..._list(p['roles'])};
  }

  @override
  void dispose() {
    for (final c in [_name, _username, _bio, _resume, _experience, _skills, _certs, _portfolio]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> _splitLines(String s) =>
      s.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  List<String> _splitSkills(String s) => s
      .split(RegExp(r'[,،]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Future<void> _save() async {
    setState(() => _error = null);
    if (_name.text.trim().isEmpty || _roles.isEmpty) {
      setState(() => _error = 'نام و حداقل یک حوزه فعالیت لازم است.');
      return;
    }
    final cleanUsername =
        _username.text.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '').toLowerCase();
    if (cleanUsername.isNotEmpty && cleanUsername.length < 4) {
      setState(() =>
          _error = 'آیدی باید حداقل ۴ کاراکتر (فقط حروف انگلیسی/عدد/آندرلاین) باشد.');
      return;
    }
    setState(() => _saving = true);
    try {
      await _db.from('profiles').update({
        'name': _name.text.trim(),
        'field': _field,
        'roles': _roles.toList(),
        'resume': _resume.text.trim(),
        'experience': _experience.text.trim(),
        'skills': _splitSkills(_skills.text),
        'certificates': _splitLines(_certs.text),
        'portfolio': _splitLines(_portfolio.text),
        'username': cleanUsername.isEmpty ? null : cleanUsername,
        'bio': _bio.text.trim().isEmpty ? null : _bio.text.trim(),
      }).eq('id', widget.profile['id']);
      if (!mounted) return;
      toast(context, 'ذخیره شد.');
      Navigator.pop(context, true);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = (e.code == '23505' || e.message.contains('duplicate'))
            ? 'این آیدی قبلاً توسط کاربر دیگری انتخاب شده است.'
            : e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'خطا: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PfPage(
      title: 'ویرایش پروفایل',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'نام')),
          const SizedBox(height: 12),
          TextField(
            controller: _username,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
                labelText: 'آیدی (username)', hintText: 'مثلاً: ali_civil'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bio,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'بیوگرافی'),
          ),
          const SizedBox(height: 12),
          const Text('رشته', style: TextStyle(color: C.soft, fontSize: 12.5)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final f in _fieldOptions)
              ChoiceChip(
                label: Text(f),
                selected: _field == f,
                selectedColor: const Color(0x55C50337),
                backgroundColor: C.bg1,
                onSelected: (_) => setState(() => _field = f),
              ),
          ]),
          const SizedBox(height: 14),
          const Text('حوزه فعالیت', style: TextStyle(color: C.soft, fontSize: 12.5)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final r in _roleKeys)
              FilterChip(
                label: Text(r),
                selected: _roles.contains(r),
                selectedColor: const Color(0x55C50337),
                backgroundColor: C.bg1,
                checkmarkColor: Colors.white,
                onSelected: (v) => setState(() => v ? _roles.add(r) : _roles.remove(r)),
              ),
          ]),
          const SizedBox(height: 14),
          TextField(
            controller: _resume,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(labelText: 'رزومه'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _experience,
            minLines: 2,
            maxLines: 6,
            decoration: const InputDecoration(labelText: 'سوابق کاری'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _skills,
            decoration: const InputDecoration(
                labelText: 'مهارت‌ها (با کاما جدا کنید)', hintText: 'Etabs, Safe, نظارت'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _certs,
            minLines: 2,
            maxLines: 6,
            decoration: const InputDecoration(labelText: 'گواهینامه‌ها (هرکدام یک خط)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _portfolio,
            minLines: 2,
            maxLines: 6,
            decoration: const InputDecoration(labelText: 'نمونه‌کار (هرکدام یک خط)'),
          ),
          const SizedBox(height: 10),
          ErrorText(_error),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'در حال ذخیره...' : 'ذخیره تغییرات'),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
