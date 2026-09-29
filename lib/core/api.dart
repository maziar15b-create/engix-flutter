import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class Api {
  static Future<Map<String, dynamic>> post(
      String path, Map<String, dynamic> body) async {
    final client = http.Client();
    try {
      var uri = Uri.parse('${Config.apiBase}$path');
      for (var i = 0; i < 5; i++) {
        final req = http.Request('POST', uri)
          ..followRedirects = false
          ..headers['Content-Type'] = 'application/json'
          ..headers['Accept'] = 'application/json'
          ..body = jsonEncode(body);
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
      final snippet = text.replaceAll(RegExp(r'\s+'), ' ');
      final short = snippet.length > 120 ? snippet.substring(0, 120) : snippet;
      throw ApiException('پاسخ نامعتبر (کد ${res.statusCode}): $short');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException((data['error'] ?? 'خطای ناشناخته').toString());
    }
    return data;
  }
}

String toLatinDigits(String s) {
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  const ar = '٠١٢٣٤٥٦٧٨٩';
  var out = s;
  for (var i = 0; i < 10; i++) {
    out = out.replaceAll(fa[i], '$i').replaceAll(ar[i], '$i');
  }
  return out;
}

String normalizePhone(String p) {
  final d = toLatinDigits(p).replaceAll(RegExp(r'\D'), '');
  return d.length > 10 ? d.substring(d.length - 10) : d;
}
