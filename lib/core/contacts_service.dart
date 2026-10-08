import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'api.dart' show normalizePhone;

/// مخاطبی که در EngiX هم حساب دارد
class AppContact {
  final String id; // شناسه‌ی کاربر در EngiX
  final String name; // نام در EngiX
  final String contactName; // نام ذخیره‌شده در دفترچه‌ی تلفن
  final String? avatarUrl;
  final String phone;
  const AppContact({
    required this.id,
    required this.name,
    required this.contactName,
    required this.avatarUrl,
    required this.phone,
  });
}

class ContactsPermissionException implements Exception {
  const ContactsPermissionException();
  @override
  String toString() => 'دسترسی به مخاطبین داده نشده است.';
}

/// همگام‌سازی دفترچه‌ی تلفن با کاربران EngiX (شماره‌ها فقط برای تطبیق استفاده می‌شوند)
class ContactsService {
  static List<AppContact>? _cache;
  static DateTime? lastSync;

  static List<AppContact>? get cached => _cache;

  static Future<List<AppContact>> sync(String selfId, {bool force = false}) async {
    if (!force && _cache != null) return _cache!;

    final granted = await FlutterContacts.requestPermission(readonly: true);
    if (!granted) throw const ContactsPermissionException();

    final contacts = await FlutterContacts.getContacts(withProperties: true);
    // ده رقم آخر شماره‌ی موبایل → نام مخاطب
    final byTen = <String, String>{};
    for (final c in contacts) {
      for (final p in c.phones) {
        final t = normalizePhone(p.number);
        if (t.length == 10 && t.startsWith('9')) {
          byTen.putIfAbsent(t, () => c.displayName);
        }
      }
    }

    final db = Supabase.instance.client;
    final tens = byTen.keys.toList();
    final found = <String, AppContact>{};
    const chunk = 40;
    for (var i = 0; i < tens.length; i += chunk) {
      final part = tens.sublist(i, i + chunk > tens.length ? tens.length : i + chunk);
      final variants = <String>[
        for (final t in part) ...['0$t', t, '+98$t', '98$t'],
      ];
      try {
        final rows = await db
            .from('profiles')
            .select('id, name, avatar_url, phone')
            .inFilter('phone', variants);
        for (final r in rows) {
          final id = r['id'].toString();
          if (id == selfId) continue;
          final ten = normalizePhone((r['phone'] ?? '').toString());
          found[id] = AppContact(
            id: id,
            name: (r['name'] ?? 'کاربر').toString(),
            contactName: byTen[ten] ?? (r['name'] ?? '').toString(),
            avatarUrl: r['avatar_url']?.toString(),
            phone: (r['phone'] ?? '').toString(),
          );
        }
      } catch (_) {}
    }

    final list = found.values.toList()
      ..sort((a, b) => a.contactName.compareTo(b.contactName));
    _cache = list;
    lastSync = DateTime.now();
    return list;
  }

  static void clear() {
    _cache = null;
    lastSync = null;
  }
}
