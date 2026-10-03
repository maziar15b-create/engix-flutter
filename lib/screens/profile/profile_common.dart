import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';

const _faDigits = '۰۱۲۳۴۵۶۷۸۹';

String faNum(Object? v) => (v ?? '')
    .toString()
    .replaceAllMapped(RegExp(r'\d'), (m) => _faDigits[int.parse(m[0]!)]);

void toast(BuildContext context, String m) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));
}

Future<bool> pfConfirm(BuildContext context, String text, {String yes = 'تأیید'}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: C.bg2,
      content: Text(text),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(yes, style: const TextStyle(color: C.danger)),
        ),
      ],
    ),
  );
  return ok == true;
}

class PfPage extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  const PfPage({super.key, required this.title, required this.child, this.actions});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: C.bg1,
        title: Text(title, style: const TextStyle(fontSize: 16)),
        actions: actions,
      ),
      body: Backdrop(child: child),
    );
  }
}

class PfCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  const PfCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x29C50337)),
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF1D1B22), Color(0xFF141318)],
          ),
        ),
        child: child,
      ),
    );
  }
}

class PfTitle extends StatelessWidget {
  final String text;
  final String? sub;
  const PfTitle(this.text, {super.key, this.sub});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Column(
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
            Text(text,
                style: const TextStyle(
                    color: C.redLight, fontSize: 13, fontWeight: FontWeight.w800)),
          ]),
          if (sub != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(sub!,
                  style: const TextStyle(color: C.muted, fontSize: 12.5, height: 1.8)),
            ),
        ],
      ),
    );
  }
}

class PfAvatar extends StatelessWidget {
  final String? url;
  final String name;
  final double size;
  const PfAvatar({super.key, this.url, required this.name, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isEmpty ? '?' : name.trim().substring(0, 1);
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: C.bg3,
        border: Border.all(color: C.line),
      ),
      child: Text(letter,
          style: TextStyle(
              color: C.redLight, fontWeight: FontWeight.w800, fontSize: size * 0.4)),
    );
    if (url == null || url!.isEmpty) return fallback;
    return ClipOval(
      child: Image.network(
        url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}

class PfBadge extends StatelessWidget {
  final String text;
  final Color? color;
  const PfBadge(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? C.redLight;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withOpacity(0.4)),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w700)),
    );
  }
}

class PfLoading extends StatelessWidget {
  const PfLoading({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(30),
        child: Center(child: CircularProgressIndicator(color: C.red)),
      );
}
