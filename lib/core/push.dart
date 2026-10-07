import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/chat_thread_screen.dart';
import 'theme.dart';

class Push {
  static final navigatorKey = GlobalKey<NavigatorState>();
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();

  static String? activeConversation;

  static bool _inited = false;
  static Map<String, dynamic>? _profile;
  static StreamSubscription? _tokenSub;

  static SupabaseClient get _db => Supabase.instance.client;

  static Future<void> init(Map<String, dynamic> profile) async {
    _profile = profile;
    if (_inited) {
      await _saveToken();
      return;
    }
    _inited = true;
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      final fm = FirebaseMessaging.instance;
      await fm.requestPermission(alert: true, badge: true, sound: true);
      await _saveToken();
      _tokenSub = fm.onTokenRefresh.listen((t) => _saveToken(token: t));

      FirebaseMessaging.onMessage.listen(_onForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(_open);
      final initial = await fm.getInitialMessage();
      if (initial != null) {
        Future.delayed(const Duration(milliseconds: 700), () => _open(initial));
      }
    } catch (_) {
      _inited = false;
    }
  }

  static Future<void> _saveToken({String? token}) async {
    try {
      final t = token ?? await FirebaseMessaging.instance.getToken();
      final id = _profile?['id'] ?? _db.auth.currentUser?.id;
      if (t == null || id == null) return;
      await _db.from('profiles').update({'fcm_token': t}).eq('id', id);
    } catch (_) {}
  }

  static Future<void> clearToken() async {
    try {
      final id = _profile?['id'] ?? _db.auth.currentUser?.id;
      if (id != null) {
        await _db.from('profiles').update({'fcm_token': null}).eq('id', id);
      }
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
    _tokenSub?.cancel();
    _inited = false;
  }

  static void _onForeground(RemoteMessage m) {
    final convId = m.data['conversationId']?.toString();
    if (convId != null && convId == activeConversation) return;
    final n = m.notification;
    if (n == null) return;
    final sm = messengerKey.currentState;
    if (sm == null) return;
    sm
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: C.bg3,
        duration: const Duration(seconds: 4),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(n.title ?? 'EngiX',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, color: C.redLight)),
            const SizedBox(height: 2),
            Text(n.body ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
        action: convId == null
            ? null
            : SnackBarAction(
                label: 'باز کردن',
                textColor: C.redLight,
                onPressed: () => _open(m),
              ),
      ));
  }

  static void _open(RemoteMessage m) {
    final convId = m.data['conversationId']?.toString();
    final nav = navigatorKey.currentState;
    final profile = _profile;
    if (convId == null || nav == null || profile == null) return;
    nav.push(MaterialPageRoute(
      builder: (_) => ChatThreadScreen(
        profile: profile,
        conversationId: convId,
        title: '',
      ),
    ));
  }
}
