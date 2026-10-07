import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../tools/dedicated/dedicated_tools.dart';
import '../tools/tools_data.dart';

class ToolsTab extends StatefulWidget {
  const ToolsTab({super.key});

  @override
  State<ToolsTab> createState() => _ToolsTabState();
}

class _CatStyle {
  final IconData icon;
  final Color color;
  const _CatStyle(this.icon, this.color);
}

const Map<String, _CatStyle> _catStyles = {
  'technical-office': _CatStyle(Icons.assignment, Color(0xFFFF6B8B)),
  'structural-design': _CatStyle(Icons.domain, Color(0xFF8E7CFF)),
  'civil': _CatStyle(Icons.foundation, Color(0xFFFFA14A)),
  'architecture': _CatStyle(Icons.architecture, Color(0xFF4FC3F7)),
  'electrical': _CatStyle(Icons.electric_bolt, Color(0xFFFFD166)),
  'installations': _CatStyle(Icons.plumbing, Color(0xFF2ED5C4)),
  'mechanical': _CatStyle(Icons.settings, Color(0xFF9AA5B8)),
  'surveying': _CatStyle(Icons.straighten, Color(0xFF7BDC6A)),
  'general': _CatStyle(Icons.apps, Color(0xFFB08CFF)),
};

const _fallbackStyle = _CatStyle(Icons.calculate_outlined, C.redLight);

/// آیکن اختصاصی هر ابزار بر اساس نام؛ اگر نبود آیکن دسته
IconData _toolIcon(_Entry t) {
  final n = t.name;
  const rules = <List<dynamic>>[
    ['متره', Icons.receipt_long],
    ['صورت وضعیت', Icons.request_quote],
    ['بالاسری', Icons.percent],
    ['آرماتور', Icons.grid_4x4],
    ['میلگرد', Icons.grid_4x4],
    ['خاموت', Icons.grid_4x4],
    ['بتن مگر', Icons.layers],
    ['بتن', Icons.view_in_ar],
    ['زلزله', Icons.vibration],
    ['لرزه', Icons.vibration],
    ['خاک', Icons.terrain],
    ['ژئوتک', Icons.terrain],
    ['دیوار حائل', Icons.terrain],
    ['فونداسیون', Icons.foundation],
    ['پی ', Icons.foundation],
    ['سقف', Icons.roofing],
    ['بار', Icons.line_weight],
    ['تبدیل', Icons.swap_horiz],
    ['واحد', Icons.swap_horiz],
    ['فولاد', Icons.view_column],
    ['تیرآهن', Icons.view_column],
    ['پروفیل', Icons.view_column],
    ['آسفالت', Icons.add_road],
    ['قیمت', Icons.attach_money],
    ['هزینه', Icons.attach_money],
    ['مالی', Icons.attach_money],
    ['لوله', Icons.plumbing],
    ['آب', Icons.water_drop],
    ['برق', Icons.electric_bolt],
    ['کابل', Icons.cable],
    ['حرارت', Icons.thermostat],
    ['نقشه', Icons.map_outlined],
    ['زاویه', Icons.straighten],
    ['مساحت', Icons.square_foot],
    ['پله', Icons.stairs],
    ['تیر', Icons.horizontal_rule],
    ['ستون', Icons.view_week],
    ['دال', Icons.crop_square],
  ];
  for (final r in rules) {
    if (n.contains(r[0] as String)) return r[1] as IconData;
  }
  return (_catStyles[t.category] ?? _fallbackStyle).icon;
}

void _openEntry(BuildContext context, _Entry e) {
  final ded = e.ded;
  if (ded != null) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ded.build()));
    return;
  }
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => ToolScreen(tool: e.tool!)),
  );
}

/// کارت یک ابزار (داخل صفحه‌ی گروه یا نتایج جستجو)
Widget _toolCard(BuildContext context, _Entry t) {
  final st = _catStyles[t.category] ?? _fallbackStyle;
  return InkWell(
    borderRadius: BorderRadius.circular(18),
    onTap: () => _openEntry(context, t),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: st.color.withAlpha(90)),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [st.color.withAlpha(50), C.bg2, C.bg1],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: st.color.withAlpha(45),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_toolIcon(t), color: st.color, size: 24),
          ),
          const SizedBox(height: 10),
          Text(
            t.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontWeight: FontWeight.w800, fontSize: 13, height: 1.45),
          ),
          const Spacer(),
          Text(
            t.description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: C.soft, fontSize: 10.5),
          ),
        ],
      ),
    ),
  );
}

SliverGridDelegate _toolsGridDelegate(double extent) =>
    SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      mainAxisExtent: extent,
    );

class _ToolsTabState extends State<ToolsTab> {
  String _query = '';

  late final List<_Entry> _all = [
    for (final d in dedicatedTools) _Entry(d.id, d.name, d.description, d.category, ded: d),
    for (final t in allTools)
      if (!dedicatedTools.any((d) => d.id == t.id)) _Entry(t.id, t.name, t.description, t.category, tool: t),
  ];

  late final List<List<String>> _cats = () {
    final out = <List<String>>[];
    out.add(dedicatedExtraCategories[0]); // دفتر فنی
    for (final c in toolCategories) {
      out.add(c);
      if (c[0] == 'civil') out.add(dedicatedExtraCategories[1]); // طراحی سازه بعد از عمران
    }
    return out.where((c) => _all.any((t) => t.category == c[0])).toList();
  }();

  void _openCategory(List<String> c) {
    final items = _all.where((t) => t.category == c[0]).toList();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _CategoryScreen(
        catKey: c[0],
        title: c[1],
        items: items,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim();
    final searching = q.isNotEmpty;
    final found = _all
        .where((t) => t.name.contains(q) || t.description.contains(q))
        .toList();

    Widget content;
    if (searching) {
      content = found.isEmpty
          ? const Center(
              child: Text('ابزاری پیدا نشد.', style: TextStyle(color: C.muted)))
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              gridDelegate: _toolsGridDelegate(142),
              itemCount: found.length,
              itemBuilder: (ctx, i) => _toolCard(ctx, found[i]),
            );
    } else {
      content = GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        gridDelegate: _toolsGridDelegate(150),
        itemCount: _cats.length,
        itemBuilder: (_, i) => _categoryWidget(_cats[i]),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(
              hintText: 'جستجوی ابزار...',
              prefixIcon: Icon(Icons.search, color: C.muted),
            ),
          ),
        ),
        Expanded(child: content),
      ],
    );
  }

  /// هر گروه ابزار یک ویجت در صفحه‌ی اول
  Widget _categoryWidget(List<String> c) {
    final st = _catStyles[c[0]] ?? _fallbackStyle;
    final count = _all.where((t) => t.category == c[0]).length;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _openCategory(c),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: st.color.withAlpha(110)),
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [st.color.withAlpha(70), C.bg2, C.bg1],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: st.color.withAlpha(55),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(st.icon, color: st.color, size: 28),
            ),
            const Spacer(),
            Text(
              c[1],
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 4),
            Text(
              '${_faNum(count)} ابزار',
              style: TextStyle(color: st.color, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }
}

String _faNum(int n) {
  const d = '۰۱۲۳۴۵۶۷۸۹';
  return n.toString().replaceAllMapped(RegExp(r'\d'), (m) => d[int.parse(m[0]!)]);
}

/// صفحه‌ی داخل هر گروه: ابزارهای همان گروه
class _CategoryScreen extends StatefulWidget {
  final String catKey;
  final String title;
  final List<_Entry> items;
  const _CategoryScreen(
      {required this.catKey, required this.title, required this.items});

  @override
  State<_CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<_CategoryScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final st = _catStyles[widget.catKey] ?? _fallbackStyle;
    final q = _query.trim();
    final shown = widget.items
        .where((t) => q.isEmpty || t.name.contains(q) || t.description.contains(q))
        .toList();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: C.bg1,
        title: Row(children: [
          Icon(st.icon, color: st.color, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(widget.title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
      body: Backdrop(
        child: Column(
          children: [
            if (widget.items.length > 6)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'جستجو در این گروه...',
                    prefixIcon: Icon(Icons.search, color: C.muted),
                  ),
                ),
              ),
            Expanded(
              child: shown.isEmpty
                  ? const Center(
                      child: Text('ابزاری پیدا نشد.',
                          style: TextStyle(color: C.muted)))
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      gridDelegate: _toolsGridDelegate(142),
                      itemCount: shown.length,
                      itemBuilder: (ctx, i) => _toolCard(ctx, shown[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Entry {
  final String id, name, description, category;
  final ToolDef? tool;
  final DedicatedTool? ded;
  const _Entry(this.id, this.name, this.description, this.category, {this.tool, this.ded});
}

class ToolScreen extends StatefulWidget {
  final ToolDef tool;
  const ToolScreen({super.key, required this.tool});

  @override
  State<ToolScreen> createState() => _ToolScreenState();
}

class _ToolScreenState extends State<ToolScreen> {
  late final Map<String, TextEditingController> _ctl;
  List<ToolResult>? _results;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _ctl = {
      for (final i in widget.tool.inputs) i.key: TextEditingController(),
    };
  }

  @override
  void dispose() {
    for (final c in _ctl.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _run() {
    final values = <String, double>{};
    for (final i in widget.tool.inputs) {
      final raw = toLatinDigits(_ctl[i.key]!.text)
          .replaceAll('٫', '.')
          .replaceAll(',', '.')
          .trim();
      final d = double.tryParse(raw);
      if (d == null) {
        setState(() {
          _error = 'مقدار «${i.label}» را درست وارد کنید.';
          _results = null;
        });
        return;
      }
      values[i.key] = d;
    }
    try {
      final r = widget.tool.calc(values);
      setState(() {
        _error = '';
        _results = r;
      });
    } catch (_) {
      setState(() {
        _error = 'محاسبه انجام نشد؛ ورودی‌ها را بررسی کنید.';
        _results = null;
      });
    }
  }

  void _copy() {
    final r = _results;
    if (r == null) return;
    final text = r
        .map((e) => '${e.label}: ${e.value}${e.unit.isEmpty ? '' : ' ${e.unit}'}')
        .join('\n');
    Clipboard.setData(ClipboardData(text: '${widget.tool.name}\n$text'));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('نتیجه کپی شد.')));
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tool;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: C.bg1,
        title: Text(t.name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
      body: Backdrop(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(t.description,
                style: const TextStyle(color: C.soft, height: 1.8, fontSize: 13)),
            const SizedBox(height: 16),
            for (final i in t.inputs)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: _ctl[i.key],
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: true),
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(labelText: i.label),
                ),
              ),
            ErrorText(_error),
            const SizedBox(height: 8),
            FilledButton(onPressed: _run, child: const Text('محاسبه')),
            if (_results != null) ...[
              const SizedBox(height: 18),
              EngixPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text('نتیجه',
                              style: TextStyle(
                                  color: C.redLight,
                                  fontWeight: FontWeight.w700)),
                        ),
                        IconButton(
                          onPressed: _copy,
                          icon: const Icon(Icons.copy, size: 18, color: C.soft),
                        ),
                      ],
                    ),
                    for (final r in _results!)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(r.label,
                                  style: const TextStyle(
                                      color: C.soft, height: 1.6)),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              r.unit.isEmpty ? r.value : '${r.value} ${r.unit}',
                              textDirection: TextDirection.rtl,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
