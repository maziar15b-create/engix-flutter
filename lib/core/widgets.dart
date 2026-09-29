import 'package:flutter/material.dart';
import 'theme.dart';

/// پس‌زمینه‌ی تیره با درخشش قرمز بالای صفحه
class Backdrop extends StatelessWidget {
  final Widget child;
  const Backdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: C.bg0,
        gradient: RadialGradient(
          center: Alignment(0, -1.15),
          radius: 1.1,
          colors: [Color(0x24C50337), Color(0x00C50337)],
        ),
      ),
      child: child,
    );
  }
}

class EngixPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const EngixPanel(
      {super.key, required this.child, this.padding = const EdgeInsets.all(18)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: C.line),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [C.bg3, C.bg2, C.bg1],
        ),
      ),
      child: child,
    );
  }
}

class EngixLogo extends StatelessWidget {
  final double size;
  const EngixLogo({super.key, this.size = 34});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [C.redLight, C.red, C.redDeep],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x8CC50337), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Text('E',
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: size * 0.44)),
    );
  }
}

class ErrorText extends StatelessWidget {
  final String? text;
  const ErrorText(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    if (text == null || text!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(text!, style: const TextStyle(color: C.danger, fontSize: 12.5)),
    );
  }
}
