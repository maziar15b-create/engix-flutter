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
    final res = await http
        .post(
          Uri.parse('${Config.apiBase}$path'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 25));

    Map<String, dynamic> data;
    try {
      data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('پاسخ نامعتبر از سرور دریافت شد.');
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
