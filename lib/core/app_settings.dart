import 'package:flutter/foundation.dart';

/// تنظیمات ظاهری سراسری اپ (اندازه متن)
class AppSettings {
  static final ValueNotifier<double> fontScale = ValueNotifier<double>(1.0);

  static double scaleFor(String? key) {
    switch (key) {
      case 'small':
        return 0.9;
      case 'large':
        return 1.15;
      default:
        return 1.0;
    }
  }

  static void applyFromProfile(Map<String, dynamic>? p) {
    fontScale.value = scaleFor(p?['font_scale']?.toString());
  }
}
