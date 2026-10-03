import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'api.dart';
import 'config.dart';

/// درخواست‌های احراز هویت‌شده به سرور (GET / POST / DELETE) با توکن کاربر
class SecureApi {
  static Future<Map<String, dynamic>> call(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null) {
      throw ApiException('نشست نامعتبر است. دوباره وارد شوید.');
    }
    final client = http.Client();
    try {
      var uri = Uri.parse('${Config.apiBase}$path');
      for (var i = 0; i < 5; i++) {
        final req = http.Request(method, uri)
          ..followRedirects = false
          ..headers['Authorization'] = 'Bearer $token'
          ..headers['Accept'] = 'application/json';
        if (body != null) {
          req.headers['Content-Type'] = 'application/json';
          req.body = jsonEncode(body);
        }
        final streamed =
            await client.send(req).timeout(const Duration(seconds: 25));
        final res = await http.Response.fromStream(streamed);
        final loc = res.headers['location'];
        if ({301, 302, 303, 307, 308}.contains(res.statusCode) && loc != null) {
          uri = uri.resolve(loc);
          continue;
        }
        return _parse(res);
      }
      throw ApiException('تعداد ریدایرکت‌ها زیاد است.');
    } finally {
      client.close();
    }
  }

  static Map<String, dynamic> _parse(http.Response res) {
    final text = utf8.decode(res.bodyBytes, allowMalformed: true);
    Map<String, dynamic> data;
    try {
      data = jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      if (res.statusCode >= 200 && res.statusCode < 300) return {};
      final snippet = text.replaceAll(RegExp(r'\s+'), ' ');
      final short = snippet.length > 120 ? snippet.substring(0, 120) : snippet;
      throw ApiException('پاسخ نامعتبر (کد ${res.statusCode}): $short');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException((data['error'] ?? 'خطای ناشناخته').toString());
    }
    return data;
  }

  static Future<Map<String, dynamic>> get(String path) => call('GET', path);
  static Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) =>
      call('POST', path, body: body);
  static Future<Map<String, dynamic>> delete(String path, {Map<String, dynamic>? body}) =>
      call('DELETE', path, body: body ?? <String, dynamic>{});
}
