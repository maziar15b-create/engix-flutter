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

class _ToolsTabState extends State<ToolsTab> {
  String _query = '';

  // ابزارهای اختصاصی وب (فرم‌های چندبخشی) + ابزارهای فرمولی
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
    return out;
  }();

  void _open(_Entry e) {
    final ded = e.ded;
    if (ded != null) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ded.build()));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ToolScreen(tool: e.tool!)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim();
    final searching = q.isNotEmpty;
    final found = _all
        .where((t) => t.name.contains(q) || t.description.contains(q))
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(
              hintText: 'جستجوی ابزار...',
              prefixIcon: Icon(Icons.search, color: C.muted),
            ),
          ),
        ),
        Expanded(
          child: searching
              ? (found.isEmpty
                  ? const Center(
                      child: Text('ابزاری پیدا نشد.',
                          style: TextStyle(color: C.muted)))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      children: [for (final t in found) _toolTile(t)],
                    ))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    for (final c in _cats) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 8),
                        child: Text(
                          c[1],
                          style: const TextStyle(
                            color: C.redLight,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      for (final t in _all.where((t) => t.category == c[0]))
                        _toolTile(t),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _toolTile(_Entry t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _open(t),
        child: EngixPanel(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.calculate_outlined, color: C.redLight),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.name,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(
                      t.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: C.soft, fontSize: 12, height: 1.6),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left, color: C.muted),
            ],
          ),
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
