import 'package:flutter/material.dart';

import 'concrete_design_tools.dart';
import 'finance_tools.dart';
import 'floor_system_tool.dart';
import 'foundation_lean_tools.dart';
import 'geotech_tools.dart';
import 'loading_tool.dart';
import 'quantity_takeoff_tool.dart';
import 'rebar_cutting_tool.dart';
import 'rebar_shop_drawing_tool.dart';
import 'seismic_tools.dart';
import 'steel_retaining_tools.dart';
import 'design_basic_tools.dart';
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
  // ───── دفتر فنی ─────
  DedicatedTool(
      'quantity-takeoff',
      'متره و برآورد',
      'ثبت چندردیفیِ اقلام (مساحت، دیوار با کسر بازشو، حجم، شمارشی)، محاسبه‌ی خودکار مقدار و هزینه‌ی هر ردیف و جمع کل',
      'technical-office',
      () => const QuantityTakeoffTool(title: 'متره و برآورد')),
  DedicatedTool(
      'rebar-shop-drawing',
      'جدول خم آرماتور (شاپ‌درائینگ)',
      'محاسبه‌ی طول برش میلگرد راست، خم‌دار و خاموت بر اساس ضوابط متداول ACI 318 (کسر خم، طول قلاب)، به‌همراه اورلب و وزن',
      'technical-office',
      () => const RebarShopDrawingTool(title: 'جدول خم آرماتور (شاپ‌درائینگ)')),
  DedicatedTool(
      'lean-concrete-rubble',
      'بتن مگر و سنگ لاشه زیر فونداسیون',
      'محاسبه‌ی حجم بتن مگر و سنگ لاشه بر اساس نوع فونداسیون (نواری، منفرد، گسترده)، با احتساب حاشیه‌ی اضافه و خلل‌وفرج سنگ',
      'technical-office',
      () => leanConcreteTool('بتن مگر و سنگ لاشه زیر فونداسیون')),
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

  // ───── عمران ─────
  DedicatedTool(
      'rebar-cutting-optimizer',
      'لیست‌وفر میلگرد (بهینه‌سازی برش)',
      'محاسبه دقیق تعداد شاخه، چیدمان برش و کمترین پرت برای فونداسیون، ستون، سقف و سایر اعضا',
      'civil',
      () => const RebarCuttingTool(
          title: 'لیست‌وفر میلگرد (بهینه‌سازی برش)',
          description: 'محاسبه دقیق تعداد شاخه، چیدمان برش و کمترین پرت برای فونداسیون، ستون، سقف و سایر اعضا')),

  // ───── طراحی سازه ─────
  DedicatedTool(
      'loading-combination-calculator',
      'بارگذاری و ترکیب بار',
      'محاسبه بار مرده، بار زنده (مبحث ۶)، ترکیب بار (مبحث ۹) و برش پایه لرزه‌ای (استاندارد ۲۸۰۰)',
      'structural-design',
      () => const LoadingCalculatorTool(title: 'بارگذاری و ترکیب بار')),
  DedicatedTool(
      'concrete-beam-design',
      'طراحی تیر بتنی',
      'طراحی خمشی (تعیین میلگرد کششی)، طراحی برشی (خاموت) و کنترل حدود مبحث ۹',
      'structural-design',
      () => beamTool('طراحی تیر بتنی')),
  DedicatedTool(
      'concrete-column-design',
      'طراحی ستون بتنی',
      'ظرفیت محوری، کنترل لاغری و کنترل ترکیبی تقریبی P-M طبق مبحث ۹',
      'structural-design',
      () => columnTool('طراحی ستون بتنی')),
  DedicatedTool(
      'seismic-distribution',
      'توزیع زلزله در ارتفاع + دریفت',
      'توزیع نیروی زلزله بین طبقات و کنترل تغییرمکان نسبی طبقات طبق استاندارد ۲۸۰۰',
      'structural-design',
      () => const SeismicDistributionTool(title: 'توزیع زلزله در ارتفاع + دریفت')),
  DedicatedTool(
      'floor-system-design',
      'طراحی سقف',
      'تیرچه‌بلوک، دال یک/دوطرفه، وافل، کوبیاکس/یوبوت، عرشه فولادی و پیش‌تنیده/هالوکور',
      'structural-design',
      () => floorSystemTool('طراحی سقف')),
  DedicatedTool(
      'shear-wall-design',
      'طراحی دیوار برشی',
      'طراحی برشی، آرماتور افقی/قائم و کنترل ساده‌شده نیاز به المان مرزی',
      'structural-design',
      () => shearWallTool('طراحی دیوار برشی', '')),
  DedicatedTool(
      'stairs-design',
      'طراحی پله',
      'کنترل راحتی (فرمول بلوندل)، بارگذاری و طراحی خمشی جان پله',
      'structural-design',
      () => stairsTool('طراحی پله', '')),
  DedicatedTool(
      'foundation-design',
      'طراحی فونداسیون',
      'پی منفرد، نواری و گسترده — کنترل فشار خاک، برش پانچ/یک‌طرفه و طراحی خمشی',
      'structural-design',
      () => foundationTool('طراحی فونداسیون')),
  DedicatedTool(
      'soil-bearing-capacity',
      'ظرفیت باربری خاک',
      'محاسبه ظرفیت باربری نهایی و مجاز خاک با فرمول ترزاقی، برای پی نواری/مربعی/مستطیلی/دایره‌ای',
      'structural-design',
      () => soilBearingTool('ظرفیت باربری خاک')),
  DedicatedTool(
      'steel-design',
      'طراحی فولاد (تیر و ستون)',
      'طراحی خمشی/برشی تیر و کنترل کمانش ستون فولادی طبق روش LRFD (مبحث ۱۰)',
      'structural-design',
      () => steelTool('طراحی فولاد (تیر و ستون)')),
  DedicatedTool(
      'foundation-settlement',
      'نشست پی',
      'محاسبه نشست آنی (الاستیک) و نشست تحکیمی (رس) و کنترل با حد مجاز',
      'structural-design',
      () => settlementTool('نشست پی')),
  DedicatedTool(
      'retaining-wall-design',
      'طراحی دیوار حائل',
      'فشار جانبی خاک (رانکین)، کنترل واژگونی، لغزش و فشار تکیه‌گاه دیوار طره‌ای',
      'structural-design',
      () => retainingWallTool('طراحی دیوار حائل')),
  DedicatedTool(
      'irregularity-check',
      'کنترل نامنظمی سازه‌ای',
      'نامنظمی پیچشی، نرمی طبقه، جرمی، هندسی و طبقه ضعیف طبق استاندارد ۲۸۰۰',
      'structural-design',
      () => irregularityTool('کنترل نامنظمی سازه‌ای')),

  // ───── عمومی ─────
  DedicatedTool(
      'unit-converter-full',
      'مبدل واحد',
      'تبدیل بین واحدهای طول، سطح، حجم، وزن، فشار، دما و بیشتر',
      'general',
      () => const UnitConverterFullTool(
          title: 'مبدل واحد', description: 'تبدیل بین واحدهای طول، سطح، حجم، وزن، فشار، دما و بیشتر')),
];
