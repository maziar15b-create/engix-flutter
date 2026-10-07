import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_settings.dart';
import 'core/config.dart';
import 'core/push.dart';
import 'core/theme.dart';
import 'core/widgets.dart';
import 'screens/auth_screen.dart';
import 'screens/complete_profile_screen.dart';
import 'screens/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: Config.supabaseUrl,
    anonKey: Config.supabaseAnonKey,
  );
  runApp(const EngixApp());
}

final supabase = Supabase.instance.client;

class EngixApp extends StatelessWidget {
  const EngixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EngiX',
      debugShowCheckedModeBanner: false,
      navigatorKey: Push.navigatorKey,
      scaffoldMessengerKey: Push.messengerKey,
      theme: buildTheme(),
      locale: const Locale('fa'),
      supportedLocales: const [Locale('fa'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => ValueListenableBuilder<double>(
        valueListenable: AppSettings.fontScale,
        builder: (context, scale, _) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      home: const Root(),
    );
  }
}

/// بر اساس وضعیت لاگین، صفحه‌ی مناسب را نشان می‌دهد
class Root extends StatefulWidget {
  const Root({super.key});
  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> {
  Session? _session = supabase.auth.currentSession;
  StreamSubscription<AuthState>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = supabase.auth.onAuthStateChange.listen((data) {
      if (mounted) setState(() => _session = data.session);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _session;
    if (s == null) return const AuthScreen();
    return ProfileGate(key: ValueKey(s.user.id), userId: s.user.id);
  }
}

/// پروفایل را می‌گیرد؛ اگر نبود صفحه‌ی تکمیل پروفایل، وگرنه اپ اصلی
class ProfileGate extends StatefulWidget {
  final String userId;
  const ProfileGate({super.key, required this.userId});
  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await supabase
          .from('profiles')
          .select('*, active_role:roles!active_role_id(label)')
          .eq('id', widget.userId)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _profile = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'خطا در دریافت پروفایل. اینترنت را بررسی کنید.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Backdrop(
          child: Center(child: CircularProgressIndicator(color: C.red)),
        ),
      );
    }
    if (_error != null) {
      return Scaffold(
        body: Backdrop(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _load, child: const Text('تلاش دوباره')),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => supabase.auth.signOut(),
                    child: const Text('خروج'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (_profile == null) {
      return CompleteProfileScreen(userId: widget.userId, onDone: _load);
    }
    return Shell(profile: _profile!, onProfileChanged: _load);
  }
}
