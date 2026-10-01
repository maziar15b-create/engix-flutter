import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api.dart' show toLatinDigits;
import '../../core/theme.dart';

SupabaseClient get sb => Supabase.instance.client;

const kRoleKeys = ['ناظر', 'مجری', 'طراح', 'مالک', 'پیمانکار'];

String pad2(int n) => n.toString().padLeft(2, '0');
String fmtDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${pad2(d.month)}-${pad2(d.day)}';
String todayStr() => fmtDate(DateTime.now());

/// تاریخ yyyy-MM-dd را بدون مشکل ساعت تابستانی به UTC تبدیل می‌کند
DateTime parseDay(String s) {
  final d = DateTime.tryParse(s.length >= 10 ? s.substring(0, 10) : s) ?? DateTime.now();
  return DateTime.utc(d.year, d.month, d.day);
}

int daysBetween(String a, String b) =>
    parseDay(b).difference(parseDay(a)).inDays;

/// parseFloat جاوااسکریپت (با پشتیبانی ارقام فارسی)؛ در صورت خطا صفر
double numOf(String? v) {
  if (v == null) return 0;
  final s = toLatinDigits(v).replaceAll('٫', '.').replaceAll(',', '').trim();
  return double.tryParse(s) ?? 0;
}

int intOf(String? v, [int fallback = 0]) {
  final s = toLatinDigits(v ?? '').trim();
  return int.tryParse(s) ?? fallback;
}

String fmtNum(num n, [int digits = 2]) {
  if (n == n.roundToDouble()) return n.toInt().toString();
  return n.toStringAsFixed(digits);
}

Future<bool> confirmDialog(BuildContext c, String msg) async {
  final r = await showDialog<bool>(
    context: c,
    builder: (ctx) => AlertDialog(
      backgroundColor: C.bg2,
      content: Text(msg),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
        TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأیید', style: TextStyle(color: C.redLight))),
      ],
    ),
  );
  return r == true;
}

Future<String?> pickDateStr(BuildContext c, String current) async {
  final init = DateTime.tryParse(current) ?? DateTime.now();
  final d = await showDatePicker(
    context: c,
    initialDate: init,
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
  );
  return d == null ? null : fmtDate(d);
}

/// معادل fetchProfilesMap در وب: id -> {id, name, ...}
Future<Map<String, Map<String, dynamic>>> fetchProfilesMap(List<dynamic> ids) async {
  final u = ids.where((e) => e != null).map((e) => e.toString()).toSet().toList();
  if (u.isEmpty) return {};
  final rows = await sb.from('profiles').select('id, name, code, phone').inFilter('id', u);
  return {for (final r in rows) r['id'].toString(): Map<String, dynamic>.from(r)};
}

/// ذخیره‌ی متن در فایل موقت و باز کردن برگه‌ی اشتراک‌گذاری (معادل دانلود در وب)
Future<void> shareTextFile(String fileName, String content, {String mime = 'text/csv'}) async {
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/$fileName');
  await f.writeAsString(content);
  await Share.shareXFiles([XFile(f.path, mimeType: mime)], text: fileName);
}

void snack(BuildContext c, String msg) {
  ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(msg)));
}

// ───────────── ویجت‌های مشترک ─────────────

class TabHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  const TabHeader(this.title, {super.key, this.subtitle});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: C.red,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: C.red, blurRadius: 8)],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: C.redLight)),
          ),
        ]),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(subtitle!, style: const TextStyle(fontSize: 12.5, color: C.soft)),
        ],
        const SizedBox(height: 14),
      ],
    );
  }
}

class TabLoading extends StatelessWidget {
  const TabLoading({super.key});
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Text('در حال بارگذاری...', style: TextStyle(color: C.muted, fontSize: 13)),
        ),
      );
}

class TabCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets margin;
  final Color? borderColor;
  const TabCard(
      {super.key,
      required this.child,
      this.margin = const EdgeInsets.only(bottom: 10),
      this.borderColor});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: C.bg2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor ?? const Color(0x1FC50337)),
      ),
      child: child,
    );
  }
}

class EmptyNote extends StatelessWidget {
  final String text;
  const EmptyNote(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text, style: const TextStyle(fontSize: 13, color: C.muted)),
      );
}

class DateField extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  const DateField(
      {super.key, required this.label, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: C.soft)),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            final d = await pickDateStr(context, value);
            if (d != null) onChanged(d);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            decoration: BoxDecoration(
              color: C.bg1,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x33FFFFFF)),
            ),
            child: Row(children: [
              const Icon(Icons.event, size: 16, color: C.muted),
              const SizedBox(width: 8),
              Text(value, style: const TextStyle(fontSize: 13.5)),
            ]),
          ),
        ),
      ],
    );
  }
}

class ChoiceChipBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color? color;
  const ChoiceChipBtn(
      {super.key, required this.label, required this.active, required this.onTap, this.color});
  @override
  Widget build(BuildContext context) {
    final c = color ?? C.red;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? c.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? c : const Color(0x33FFFFFF)),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? c : C.soft)),
      ),
    );
  }
}

class MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const MiniStat(this.label, this.value, {super.key, this.color});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: C.bg2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0x29C50337)),
          ),
          child: Column(children: [
            Text(value,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700, color: color ?? C.redLight)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11.5, color: C.soft)),
          ]),
        ),
      );
}

InputDecoration hint(String t) => InputDecoration(hintText: t);

class ErrorLine extends StatelessWidget {
  final String text;
  const ErrorLine(this.text, {super.key});
  @override
  Widget build(BuildContext context) => text.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(text, style: const TextStyle(color: C.danger, fontSize: 12.5)),
        );
}
