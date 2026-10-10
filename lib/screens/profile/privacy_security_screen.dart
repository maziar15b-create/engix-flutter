import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/jalali.dart';
import '../../core/secure_api.dart';
import '../../core/theme.dart';
import 'profile_common.dart';

bool _sessionRegistered = false;

class PrivacySecurityScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  const PrivacySecurityScreen({super.key, required this.profile});

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  SupabaseClient get _db => Supabase.instance.client;
  String get _uid => widget.profile['id'].toString();

  late String _showPhone;
  late String _showLastSeen;
  late String _allowGroup;
  String _status = '';

  List<Map<String, dynamic>>? _blocked;
  final _blockCtl = TextEditingController();
  String _blockMsg = '';

  bool _pinEnabled = false;
  final _pinCtl = TextEditingController();
  String _pinMsg = '';
  bool _pinBusy = false;

  List<Map<String, dynamic>>? _sessions;
  String? _currentSessionId;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _showPhone = (p['show_phone'] ?? 'everyone').toString();
    _showLastSeen = (p['show_last_seen'] ?? 'everyone').toString();
    _allowGroup = (p['allow_group_invites'] ?? 'everyone').toString();
    _pinEnabled = (p['two_factor_pin_hash'] ?? '').toString().isNotEmpty;
    _loadBlocked();
    _initSessions();
  }

  @override
  void dispose() {
    _blockCtl.dispose();
    _pinCtl.dispose();
    super.dispose();
  }

  Future<void> _savePrivacy(Map<String, dynamic> updates) async {
    setState(() => _status = '');
    try {
      await _db.from('profiles').update(updates).eq('id', _uid);
      if (mounted) setState(() => _status = 'ذخیره شد.');
    } catch (e) {
      if (mounted) setState(() => _status = 'خطا: $e');
    }
  }

  // --------------------------------------------------------------- مسدودیها

  Future<void> _loadBlocked() async {
    try {
      final data = await SecureApi.get('/api/security/block');
      final list = (data['blocked'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (mounted) setState(() => _blocked = list);
    } catch (e) {
      if (mounted) {
        setState(() {
          _blocked = [];
          _blockMsg = e.toString();
        });
      }
    }
  }

  Future<void> _block() async {
    final v = _blockCtl.text.trim().replaceAll('@', '');
    if (v.isEmpty) return;
    setState(() => _blockMsg = '');
    try {
      await SecureApi.post('/api/security/block', {'username': v});
      _blockCtl.clear();
      _loadBlocked();
    } catch (e) {
      if (mounted) setState(() => _blockMsg = e.toString());
    }
  }

  Future<void> _unblock(String blockedId) async {
    try {
      await SecureApi.delete('/api/security/block', body: {'blockedId': blockedId});
    } catch (e) {
      if (mounted) setState(() => _blockMsg = e.toString());
    }
    _loadBlocked();
  }

  // ---------------------------------------------------------------- رمز PIN

  Future<void> _savePin() async {
    final pin = _pinCtl.text.trim();
    setState(() {
      _pinMsg = '';
      _pinBusy = true;
    });
    try {
      final data = await SecureApi.post('/api/security/set-pin', {'pin': pin.isEmpty ? null : pin});
      if (!mounted) return;
      setState(() {
        _pinEnabled = data['enabled'] == true;
        _pinCtl.clear();
        _pinMsg = _pinEnabled ? 'رمز دو مرحله‌ای فعال شد.' : 'رمز دو مرحلهای غیرفعال شد.';
      });
    } catch (e) {
      if (mounted) setState(() => _pinMsg = e.toString());
    } finally {
      if (mounted) setState(() => _pinBusy = false);
    }
  }

  // ------------------------------------------------------------------ نشستها

  String get _deviceLabel {
    String os;
    if (Platform.isAndroid) {
      os = 'Android';
    } else if (Platform.isIOS) {
      os = 'iPhone (iOS)';
    } else {
      os = Platform.operatingSystem;
    }
    return '$os · اپ EngiX';
  }

  Future<void> _initSessions() async {
    var registeredNow = false;
    if (!_sessionRegistered) {
      try {
        await SecureApi.post('/api/security/sessions', {'deviceInfo': _deviceLabel});
        _sessionRegistered = true;
        registeredNow = true;
      } catch (_) {}
    }
    await _loadSessions(markFirstAsCurrent: registeredNow);
  }

  Future<void> _loadSessions({bool markFirstAsCurrent = false}) async {
    try {
      final data = await SecureApi.get('/api/security/sessions');
      final list = (data['sessions'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _sessions = list;
        if (markFirstAsCurrent && list.isNotEmpty) {
          _currentSessionId = list.first['id'].toString();
        } else if (_currentSessionId == null && list.isNotEmpty) {
          _currentSessionId = list.first['id'].toString();
        }
      });
    } catch (_) {
      if (mounted) setState(() => _sessions = []);
    }
  }

  Future<void> _revokeOne(String id) async {
    try {
      await SecureApi.delete('/api/security/sessions', body: {'sessionId': id});
    } catch (e) {
      if (mounted) toast(context, e.toString());
    }
    _loadSessions();
  }

  Future<void> _revokeOthers() async {
    final ok = await pfConfirm(context, 'از همه‌ی نشست‌های دیگر خارج می‌شوید؟', yes: 'خروج');
    if (!ok) return;
    try {
      await SecureApi.delete('/api/security/sessions');
    } catch (e) {
      if (mounted) toast(context, e.toString());
    }
    _loadSessions();
  }

  String _fmt(dynamic iso) => faDateTime(iso);

  Widget _vis(String label, String value, ValueChanged<String> on) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          DropdownButton<String>(
            value: value,
            dropdownColor: C.bg2,
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(value: 'everyone', child: Text('همه')),
              DropdownMenuItem(value: 'nobody', child: Text('هیچ‌کس')),
            ],
            onChanged: (v) {
              if (v != null) on(v);
            },
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final sessions = _sessions;
    final blocked = _blocked;
    return PfPage(
      title: 'حریم خصوصی و امنیت',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const PfTitle('حریم خصوصی'),
          PfCard(
            child: Column(children: [
              _vis('نمایش شماره موبایل', _showPhone, (v) {
                setState(() => _showPhone = v);
                _savePrivacy({'show_phone': v});
              }),
              _vis('نمایش آخرین بازدید / آنلاین بودن', _showLastSeen, (v) {
                setState(() => _showLastSeen = v);
                _savePrivacy({'show_last_seen': v});
              }),
              _vis('افزودن/دعوت به گروه توسط دیگران', _allowGroup, (v) {
                setState(() => _allowGroup = v);
                _savePrivacy({'allow_group_invites': v});
              }),
              if (_status.isNotEmpty)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(_status, style: const TextStyle(color: C.soft, fontSize: 12)),
                ),
            ]),
          ),
          const PfTitle('تایید دو مرحله‌ای'),
          PfCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('وضعیت: ${_pinEnabled ? 'فعال ✅' : 'غیرفعال'}',
                  style: const TextStyle(color: C.soft, fontSize: 12.5)),
              const SizedBox(height: 10),
              TextField(
                controller: _pinCtl,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 8,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  counterText: '',
                  hintText: 'رمز جدید (۴ تا ۸ رقم) — خالی = غیرفعال‌سازی',
                ),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: _pinBusy ? null : _savePin,
                child: Text(_pinBusy
                    ? '...'
                    : (_pinCtl.text.trim().isEmpty ? 'غیرفعال کردن' : 'فعالسازی')),
              ),
              if (_pinMsg.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_pinMsg, style: const TextStyle(color: C.soft, fontSize: 12)),
                ),
            ]),
          ),
          const PfTitle('نشست‌های فعال'),
          PfCard(
            child: sessions == null
                ? const PfLoading()
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (sessions.isEmpty)
                      const Text('نشستی ثبت نشده است.',
                          style: TextStyle(color: C.muted, fontSize: 12.5)),
                    for (var i = 0; i < sessions.length; i++)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          border: i < sessions.length - 1
                              ? const Border(bottom: BorderSide(color: Color(0x14FFFFFF)))
                              : null,
                        ),
                        child: Row(children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text.rich(TextSpan(children: [
                                TextSpan(
                                    text: (sessions[i]['device_info'] ?? 'دستگاه نامشخص').toString(),
                                    style: const TextStyle(fontSize: 12.5)),
                                if (sessions[i]['id'].toString() == _currentSessionId)
                                  const TextSpan(
                                      text: '  (همین دستگاه)',
                                      style: TextStyle(color: Color(0xFF22C55E), fontSize: 11)),
                              ])),
                              const SizedBox(height: 2),
                              Text('آخرین فعالیت: ${_fmt(sessions[i]['last_active'])}',
                                  style: const TextStyle(color: C.muted, fontSize: 11)),
                            ]),
                          ),
                          if (sessions[i]['id'].toString() != _currentSessionId)
                            TextButton(
                              onPressed: () => _revokeOne(sessions[i]['id'].toString()),
                              child: const Text('حذف', style: TextStyle(fontSize: 12)),
                            ),
                        ]),
                      ),
                    if (sessions.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: OutlinedButton(
                          onPressed: _revokeOthers,
                          child: const Text('خروج از همهی نشست‌های دیگر'),
                        ),
                      ),
                  ]),
          ),
          const PfTitle('کاربران مسدود شده',
              sub: 'کاربرانی که از پروفایل، چت یا شبکه اجتماعی مسدود میکنید هم اینجا نمایش داده می‌شوند.'),
          PfCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _blockCtl,
                    textDirection: TextDirection.ltr,
                    onSubmitted: (_) => _block(),
                    decoration: const InputDecoration(hintText: 'آیدی کاربر (بدون @)'),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(90, 50)),
                  onPressed: _block,
                  child: const Text('مسدود'),
                ),
              ]),
              if (_blockMsg.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_blockMsg, style: const TextStyle(color: C.redLight, fontSize: 12)),
                ),
              const SizedBox(height: 10),
              if (blocked == null) const PfLoading(),
              if (blocked != null && blocked.isEmpty)
                const Text('کاربر مسدودی وجود ندارد.',
                    style: TextStyle(color: C.muted, fontSize: 12.5)),
              if (blocked != null)
                for (final b in blocked)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      PfAvatar(
                          url: (b['blocked'] as Map?)?['avatar_url']?.toString(),
                          name: ((b['blocked'] as Map?)?['name'] ?? '').toString(),
                          size: 34),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${(b['blocked'] as Map?)?['name'] ?? ''}${((b['blocked'] as Map?)?['username'] ?? '').toString().isNotEmpty ? ' (@${(b['blocked'] as Map)['username']})' : ''}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _unblock(b['blocked_id'].toString()),
                        child: const Text('رفع مسدودیت', style: TextStyle(fontSize: 12)),
                      ),
                    ]),
                  ),
            ]),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
