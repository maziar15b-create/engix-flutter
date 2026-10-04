import 'package:flutter/material.dart';

import 'finance_tools.dart';
import 'unit_converter_full.dart';

class DedicatedTool {
  final String id, name, description, category;
  final Widget Function() build;
  const DedicatedTool(this.id, this.name, this.description, this.category, this.build);
}

/// دسته‌هایی که وب دارد ولی فلاتر نداشت: [کلید، عنوان]
const List<List<String>> dedicatedExtraCategories = [
  ['technical-office', 'دفتر فنی'],
  ['structural-design', 'طراحی سازه'],
];

final List<DedicatedTool> dedicatedTools = [
  DedicatedTool(
      'progress-payment',
      'صورت وضعیت',
      'محاسبه‌ی کارکرد هر دوره، کسر حسن‌انجام‌کار، بیمه، بازپرداخت پیش‌پرداخت، مالیات بر ارزش افزوده و مبلغ خالص قابل‌پرداخت',
      'technical-office',
      () => const ProgressPaymentTool(title: 'صورت وضعیت', description: '')),
  DedicatedTool(
      'overhead-coefficients',
      'ضرایب بالاسری و تجهیز کارگاه',
      'اعمال ضریب بالاسری، ضریب منطقه‌ای و درصد تجهیز/برچیدن کارگاه روی برآورد اولیه پیمان',
      'technical-office',
      () => const OverheadCoefficientsTool(title: 'ضرایب بالاسری و تجهیز کارگاه', description: '')),
  DedicatedTool(
      'price-adjustment',
      'تعدیل (بر اساس شاخص قیمت)',
      'محاسبه‌ی ساده‌شده‌ی مبلغ تعدیل هر دوره بر اساس نسبت شاخص دوره تعدیل به دوره پایه',
      'technical-office',
      () => const PriceAdjustmentTool(title: 'تعدیل (بر اساس شاخص قیمت)', description: '')),
  DedicatedTool(
      'delay-penalty',
      'جریمه تاخیر پیمان',
      'محاسبه‌ی جریمه‌ی روزانه‌ی تاخیر غیرمجاز نسبت به مبلغ پیمان، با اعمال سقف مجاز',
      'technical-office',
      () => const DelayPenaltyTool(title: 'جریمه تاخیر پیمان', description: '')),
  DedicatedTool(
      'unit-converter-full',
      'مبدل واحد',
      'تبدیل بین واحدهای طول، سطح، حجم، وزن، فشار، دما و بیشتر',
      'general',
      () => const UnitConverterFullTool(
          title: 'مبدل واحد', description: 'تبدیل بین واحدهای طول، سطح، حجم، وزن، فشار، دما و بیشتر')),
];
