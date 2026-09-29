import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/api.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _emailMode = false;
  bool _codeStep = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() job) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await job();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'خطا: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _applySession(Map<String, dynamic> data) async {
    final session = data['session'] as Map<String, dynamic>?;
    final refresh = session?['refresh_token'] as String?;
    if (refresh == null) throw ApiException('ورود ناموفق بود.');
    await Supabase.instance.client.auth.setSession(refresh);
  }

  Future<void> _sendCode() => _run(() async {
        if (normalizePhone(_phone.text).length != 10) {
          throw ApiException('شماره موبایل را درست وارد کنید (مثلاً 09123456789).');
        }
        await Api.post('/api/auth/send-otp', {'phone': toLatinDigits(_phone.text)});
        if (mounted) setState(() => _codeStep = true);
      });

  Future<void> _verifyCode() => _run(() async {
        final code = toLatinDigits(_code.text).trim();
        if (code.isEmpty) throw ApiException('کد تایید را وارد کنید.');
        final data = await Api.post('/api/auth/verify-otp', {
          'phone': toLatinDigits(_phone.text),
          'code': code,
        });
        await _applySession(data);
      });

  Future<void> _emailLogin() => _run(() async {
        final data = await Api.post('/api/auth/email-login', {
          'email': _email.text.trim(),
          'password': _password.text,
        });
        await _applySession(data);
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Backdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const EngixLogo(size: 56),
                    const SizedBox(height: 14),
                    const Text('ENGINEERS NETWORK',
                        style: TextStyle(
                            color: Color(0xFFFF6B35),
                            fontSize: 12,
                            letterSpacing: 3)),
                    const Text('EngiX',
                        style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    const Text(
                      'شبکه‌ای برای مهندسان عمران — پروژهها، پیام‌رسان و آموزش در یک‌جا.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: C.soft, fontSize: 13.5, height: 1.8),
                    ),
                    const SizedBox(height: 24),
                    EngixPanel(child: _buildForm()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _modeChip('شماره موبایل', !_emailMode, () {
              setState(() {
                _emailMode = false;
                _error = null;
              });
            })),
            const SizedBox(width: 8),
            Expanded(child: _modeChip('ایمیل', _emailMode, () {
              setState(() {
                _emailMode = true;
                _error = null;
              });
            })),
          ],
        ),
        const SizedBox(height: 16),
        if (_emailMode) ..._emailFields() else ..._phoneFields(),
      ],
    );
  }

  Widget _modeChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: _busy ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: active ? const Color(0x33C50337) : C.bg1,
          border: Border.all(color: active ? C.red : const Color(0x33C50337)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? C.text : C.muted)),
      ),
    );
  }

  List<Widget> _phoneFields() {
    if (!_codeStep) {
      return [
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(
              hintText: 'شماره موبایل (مثلاً 09123456789)'),
        ),
        const SizedBox(height: 12),
        ErrorText(_error),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: _busy ? null : _sendCode,
          child: Text(_busy ? '...' : 'ورود'),
        ),
      ];
    }
    return [
      Text('کد تایید به شماره ${_phone.text} پیامک شد.',
          style: const TextStyle(color: C.soft, fontSize: 12.5)),
      const SizedBox(height: 12),
      TextField(
        controller: _code,
        keyboardType: TextInputType.number,
        textDirection: TextDirection.ltr,
        decoration: const InputDecoration(hintText: 'کد ۶ رقمی'),
      ),
      const SizedBox(height: 12),
      ErrorText(_error),
      const SizedBox(height: 10),
      FilledButton(
        onPressed: _busy ? null : _verifyCode,
        child: Text(_busy ? '...' : 'تایید و ورود'),
      ),
      TextButton(
        onPressed: _busy
            ? null
            : () => setState(() {
                  _codeStep = false;
                  _code.clear();
                  _error = null;
                }),
        child: const Text('تغییر شماره موبایل'),
      ),
    ];
  }

  List<Widget> _emailFields() {
    return [
      TextField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        textDirection: TextDirection.ltr,
        decoration: const InputDecoration(hintText: 'ایمیل'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _password,
        obscureText: true,
        textDirection: TextDirection.ltr,
        decoration:
            const InputDecoration(hintText: 'رمز عبور (حداقل ۶ کاراکتر)'),
      ),
      const SizedBox(height: 8),
      const Text(
        'اگه این ایمیل قبلاً ثبتنام نکرده باشه، خودکار یه حساب جدید براش ساخته میشه.',
        style: TextStyle(color: C.muted, fontSize: 11.5, height: 1.7),
      ),
      const SizedBox(height: 10),
      ErrorText(_error),
      const SizedBox(height: 10),
      FilledButton(
        onPressed: _busy ? null : _emailLogin,
        child: Text(_busy ? '...' : 'ورود / ساخت حساب'),
      ),
    ];
  }
}
