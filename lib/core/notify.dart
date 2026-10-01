import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';

/// معادل lib/notify.js در نسخه‌ی وب
Future<void> notifyUsers(
    List<dynamic> userIds, String type, String title, String body) async {
  final ids = userIds.where((e) => e != null).map((e) => e.toString()).toList();
  if (ids.isEmpty) return;
  final sb = Supabase.instance.client;
  try {
    final profs = await sb
        .from('profiles')
        .select('id, notification_prefs')
        .inFilter('id', ids);
    final allowed = <String>[];
    for (final p in profs) {
      final prefs = (p['notification_prefs'] as Map?) ?? {};
      if (prefs[type] != false) allowed.add(p['id'].toString());
    }
    if (allowed.isEmpty) return;
    await sb.from('notifications').insert([
      for (final uid in allowed)
        {'user_id': uid, 'type': type, 'title': title, 'body': body}
    ]);
    _triggerPush(allowed, title, body, {'type': type});
  } catch (_) {}
}

Future<void> notifyUser(
        String userId, String type, String title, String body) =>
    notifyUsers([userId], type, title, body);

Future<void> _triggerPush(List<String> userIds, String title, String body,
    Map<String, dynamic> data) async {
  try {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null) return;
    await http.post(
      Uri.parse('${Config.apiBase}/api/notifications/send-push'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(
          {'userIds': userIds, 'title': title, 'body': body, 'data': data}),
    );
  } catch (_) {}
}
