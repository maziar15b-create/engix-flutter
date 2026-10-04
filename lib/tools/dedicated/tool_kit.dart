import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api.dart' show toLatinDigits;
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// تاریخ امروز به شمسی (معادل toLocaleDateString("fa-IR"))
String jalaliToday() {
  final now = DateTime.now();
  final j = _toJalali(now.year, now.month, now.day);
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  String f(int n) => n.toString().split('').map((c) => fa[int.parse(c)]).join();
  return '${f(j[0])}/${f(j[1])}/${f(j[2])}';
}

List<int> _toJalali(int gy, int gm, int gd) {
  const gdm = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
  final gy2 = gm > 2 ? gy + 1 : gy;
  var days = 355666 + (365 * gy) + ((gy2 + 3) ~/ 4) - ((gy2 + 99) ~/ 100) + ((gy2 + 399) ~/ 400) + gd + gdm[gm - 1];
  var jy = -1595 + (33 * (days ~/ 12053));
  days %= 12053;
  jy += 4 * (days ~/ 1461);
  days %= 1461;
  if (days > 365) {
    jy += (days - 1) ~/ 365;
    days = (days - 1) % 365;
  }
  final jm = days < 186 ? 1 + (days ~/ 31) : 7 + ((days - 186) ~/ 30);
  final jd = 1 + (days < 186 ? (days % 31) : ((days - 186) % 30));
  return [jy, jm, jd];
}

/// ذخیره‌ی متن در فایل موقت و باز کردن برگه‌ی اشتراک‌گذاری
Future<void> shareBytesOut(String fileName, List<int> bytes, {String? mime}) async {
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/$fileName');
  await f.writeAsBytes(bytes);
  await Share.shareXFiles([XFile(f.path, mimeType: mime)], text: fileName);
}

Future<void> shareTextOut(String fileName, String content, {String mime = 'text/plain'}) async {
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/$fileName');
  await f.writeAsBytes(utf8.encode(content));
  await Share.shareXFiles([XFile(f.path, mimeType: mime)], text: fileName);
}

/// parseFloat(...) || 0 در وب (با پشتیبانی ارقام فارسی)
double nv(String? s) {
  if (s == null) return 0;
  final t = toLatinDigits(s).replaceAll('٫', '.').replaceAll(',', '').trim();
  final v = double.tryParse(t);
  if (v == null || v.isNaN) return 0;
  return v;
}

/// معادل toLocaleString("fa-IR")
String faNum(num n, {int maxFrac = 3}) {
  if (n.isNaN) return 'NaN';
  if (n.isInfinite) return n.isNegative ? '-∞' : '∞';
  final s = n.abs().toStringAsFixed(maxFrac);
  final parts = s.split('.');
  final ip = parts[0];
  var fp = parts.length > 1 ? parts[1].replaceFirst(RegExp(r'0+$'), '') : '';
  final b = StringBuffer();
  for (var i = 0; i < ip.length; i++) {
    if (i > 0 && (ip.length - i) % 3 == 0) b.write('٬');
    b.write(ip[i]);
  }
  var out = b.toString() + (fp.isEmpty ? '' : '٫$fp');
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  out = out.split('').map((c) {
    final d = int.tryParse(c);
    return d == null ? c : fa[d];
  }).join();
  final isZero = !RegExp(r'[1-9۱-۹]').hasMatch(out);
  return (n < 0 && !isZero) ? '-$out' : out;
}

String fixed(num n, int d) => n.isNaN ? 'NaN' : n.toStringAsFixed(d);

/// چاپ عدد مثل جاوااسکریپت (بدون .0 اضافه)
String plain(num n) {
  if (n.isNaN) return 'NaN';
  if (n == n.roundToDouble() && n.abs() < 1e15) return n.toInt().toString();
  return n.toString();
}

/// ورودی عددی با کنترلر
class NumInput extends StatelessWidget {
  final String label;
  final String? unit;
  final TextEditingController controller;
  final VoidCallback onChanged;
  const NumInput(
      {super.key, required this.label, required this.controller, required this.onChanged, this.unit});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(unit == null ? label : '$label ($unit)',
          style: const TextStyle(fontSize: 11.5, color: C.soft)),
      const SizedBox(height: 4),
      TextField(
        controller: controller,
        onChanged: (_) => onChanged(),
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        textDirection: TextDirection.ltr,
      ),
    ]);
  }
}

/// دو ورودی کنار هم (مثل grid دو ستونه‌ی وب)
class FieldGrid extends StatelessWidget {
  final List<Widget> children;
  const FieldGrid(this.children, {super.key});
  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: children[i]),
          const SizedBox(width: 10),
          Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox()),
        ]),
      ));
    }
    return Column(children: rows);
  }
}

class ToolSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const ToolSection(this.title, this.children, {super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: C.bg2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x2EC50337)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.redLight)),
        const SizedBox(height: 10),
        ...children,
      ]),
    );
  }
}

class ResultRow extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final bool highlight;
  final bool warn;
  const ResultRow(this.label, this.value,
      {super.key, this.unit = '', this.highlight = false, this.warn = false});
  @override
  Widget build(BuildContext context) {
    final color = warn ? const Color(0xFFE5484D) : (highlight ? C.redLight : C.text);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5, color: C.soft))),
        const SizedBox(width: 8),
        Flexible(
          child: Text(unit.isEmpty ? value : '$value $unit',
              textAlign: TextAlign.end,
              style: TextStyle(
                  fontSize: highlight ? 14 : 13,
                  fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
                  color: color)),
        ),
      ]),
    );
  }
}

class NoticeBox extends StatelessWidget {
  final String text;
  final Color color;
  const NoticeBox(this.text, {super.key, this.color = const Color(0xFFFBBF24)});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(text, style: TextStyle(fontSize: 12, height: 1.8, color: color)),
      );
}

/// صفحه‌ی مشترک همه‌ی ابزارهای اختصاصی: هدر + سابقه + توضیح + محتوا
class ToolPage extends StatelessWidget {
  final String toolId;
  final String title;
  final String description;
  final Map<String, dynamic> Function() getData;
  final void Function(Map<String, dynamic>) onLoad;
  final void Function(String title)? onTitle;
  final String? historyDefaultTitle;
  final List<Widget> children;
  const ToolPage(
      {super.key,
      this.onTitle,
      this.historyDefaultTitle,
      required this.toolId,
      required this.title,
      required this.description,
      required this.getData,
      required this.onLoad,
      required this.children});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Backdrop(
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
              child: Row(children: [
                IconButton(
                    icon: const Icon(Icons.arrow_forward), onPressed: () => Navigator.pop(context)),
                Expanded(
                    child: Text(title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
              ]),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
                children: [
                  ToolHistoryPanel(
                      toolId: toolId,
                      defaultTitle: historyDefaultTitle ?? title,
                      getData: getData,
                      onLoad: onLoad,
                      onTitle: onTitle),
                  if (description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(description,
                          style: const TextStyle(fontSize: 12.5, color: C.soft, height: 1.8)),
                    ),
                  ...children,
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// معادل ToolHistoryPanel.js + useToolHistory.js (جدول tool_saves)
class ToolHistoryPanel extends StatefulWidget {
  final String toolId;
  final String defaultTitle;
  final Map<String, dynamic> Function() getData;
  final void Function(Map<String, dynamic>) onLoad;
  final void Function(String title)? onTitle;
  const ToolHistoryPanel(
      {super.key,
      this.onTitle,
      required this.toolId,
      required this.defaultTitle,
      required this.getData,
      required this.onLoad});
  @override
  State<ToolHistoryPanel> createState() => _ToolHistoryPanelState();
}

class _ToolHistoryPanelState extends State<ToolHistoryPanel> {
  SupabaseClient get _db => Supabase.instance.client;
  String? get _uid => _db.auth.currentUser?.id;

  Future<void> _save() async {
    final ctl = TextEditingController(text: widget.defaultTitle);
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.bg2,
        title: const Text('ذخیره در سابقه'),
        content: TextField(
            controller: ctl,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'عنوان (مثلاً: پروژه احمدی)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctl.text), child: const Text('ذخیره')),
        ],
      ),
    );
    ctl.dispose();
    if (title == null || _uid == null) return;
    try {
      await _db.from('tool_saves').insert({
        'user_id': _uid,
        'tool_id': widget.toolId,
        'title': title.trim().isEmpty ? 'بدون عنوان' : title.trim(),
        'data': widget.getData(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('در سابقه ذخیره شد.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _openHistory() async {
    if (_uid == null) return;
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg2,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _HistorySheet(toolId: widget.toolId, userId: _uid!),
    );
    if (picked != null && picked['data'] is Map) {
      widget.onLoad(Map<String, dynamic>.from(picked['data'] as Map));
      if (picked['title'] != null) widget.onTitle?.call('${picked['title']}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Expanded(child: OutlinedButton(onPressed: _save, child: const Text('💾 ذخیره در سابقه'))),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton(onPressed: _openHistory, child: const Text('📂 سابقه‌ی ذخیره‌شده'))),
      ]),
    );
  }
}

class _HistorySheet extends StatefulWidget {
  final String toolId;
  final String userId;
  const _HistorySheet({required this.toolId, required this.userId});
  @override
  State<_HistorySheet> createState() => _HistorySheetState();
}

class _HistorySheetState extends State<_HistorySheet> {
  SupabaseClient get _db => Supabase.instance.client;
  List<Map<String, dynamic>>? _items;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await _db
          .from('tool_saves')
          .select('id, title, updated_at')
          .eq('user_id', widget.userId)
          .eq('tool_id', widget.toolId)
          .order('updated_at', ascending: false);
      if (mounted) setState(() => _items = List<Map<String, dynamic>>.from(d));
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _items = [];
        });
      }
    }
  }

  Future<void> _open(dynamic id) async {
    try {
      final row = await _db.from('tool_saves').select().eq('id', id).maybeSingle();
      if (row != null && mounted) Navigator.pop(context, Map<String, dynamic>.from(row));
    } catch (_) {}
  }

  Future<void> _remove(dynamic id) async {
    try {
      await _db.from('tool_saves').delete().eq('id', id);
      if (mounted) setState(() => _items?.removeWhere((i) => i['id'] == id));
    } catch (_) {}
  }

  String _when(dynamic iso) {
    final d = DateTime.tryParse('$iso')?.toLocal();
    if (d == null) return '';
    String p(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${p(d.month)}-${p(d.day)}  ${p(d.hour)}:${p(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
            child: Row(children: [
              const Expanded(
                  child: Text('سابقه‌ی ذخیره‌شده',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('بستن')),
            ]),
          ),
          Flexible(
            child: _items == null
                ? const Padding(padding: EdgeInsets.all(30), child: Text('در حال بارگذاری...'))
                : ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      if (_error.isNotEmpty)
                        Text(_error, style: const TextStyle(color: C.danger, fontSize: 12)),
                      if (_items!.isEmpty)
                        const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('چیزی ذخیره نشده.', style: TextStyle(color: C.muted))),
                      for (final it in _items!)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: C.bg1,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0x1FC50337)),
                          ),
                          child: Row(children: [
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('${it['title']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text(_when(it['updated_at']),
                                    style: const TextStyle(fontSize: 10.5, color: C.muted)),
                              ]),
                            ),
                            TextButton(onPressed: () => _open(it['id']), child: const Text('بازکردن')),
                            TextButton(
                                onPressed: () => _remove(it['id']),
                                child: const Text('حذف', style: TextStyle(color: C.danger))),
                          ]),
                        ),
                    ],
                  ),
          ),
        ]),
      ),
    );
  }
}

// ═════════════ چارچوب اعلامی برای ابزارهای «فرم + نتایج» ═════════════

class F {
  final String key, label;
  final String? unit;
  const F(this.key, this.label, {this.unit});
}

class S {
  final String key, label;
  final List<List<String>> options; // [value, label]
  const S(this.key, this.label, this.options);
}

class R {
  final String label, value, unit;
  final bool hl, warn;
  const R(this.label, this.value, {this.unit = '', this.hl = false, this.warn = false});
}

class Note {
  final String text;
  final bool warn;
  const Note(this.text, {this.warn = true});
}

class Sec {
  final String title;
  final List<Object> items;
  const Sec(this.title, this.items);
}

class Vals {
  final Map<String, String> _m;
  Vals(this._m);
  double n(String k) => nv(_m[k]);
  String s(String k) => _m[k] ?? '';
}

typedef FormBuilder = List<Object> Function(Vals v);

class FormTool extends StatefulWidget {
  final String toolId, title, description;
  final Map<String, String> defaults;
  final FormBuilder builder;
  final void Function(String key, String value, void Function(String key, String value) setField)? onSelect;
  const FormTool(
      {super.key,
      this.onSelect,
      required this.toolId,
      required this.title,
      required this.description,
      required this.defaults,
      required this.builder});
  @override
  State<FormTool> createState() => _FormToolState();
}

class _FormToolState extends State<FormTool> {
  late final Map<String, TextEditingController> _ctl;
  late final Map<String, String> _sel;
  final Set<String> _selKeys = {};

  @override
  void initState() {
    super.initState();
    _ctl = {};
    _sel = {};
    widget.defaults.forEach((k, v) => _ctl[k] = TextEditingController(text: v));
  }

  @override
  void dispose() {
    for (final c in _ctl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Vals _vals() {
    final m = <String, String>{};
    widget.defaults.forEach((k, d) {
      m[k] = _sel.containsKey(k) ? _sel[k]! : (_ctl[k]?.text ?? d);
    });
    return Vals(m);
  }

  Widget _field(F f) => NumInput(
      label: f.label,
      unit: f.unit,
      controller: _ctl.putIfAbsent(f.key, () => TextEditingController(text: widget.defaults[f.key] ?? '')),
      onChanged: () => setState(() {}));

  Widget _select(S s) {
    _selKeys.add(s.key);
    final cur = _sel[s.key] ?? widget.defaults[s.key] ?? s.options.first[0];
    final value = s.options.any((o) => o[0] == cur) ? cur : s.options.first[0];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(s.label, style: const TextStyle(fontSize: 11.5, color: C.soft)),
      const SizedBox(height: 4),
      DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        dropdownColor: C.bg2,
        items: [for (final o in s.options) DropdownMenuItem(value: o[0], child: Text(o[1], overflow: TextOverflow.ellipsis))],
        onChanged: (v) => setState(() {
          _sel[s.key] = v ?? value;
          widget.onSelect?.call(s.key, v ?? value, (k, val) {
            if (_selKeys.contains(k)) {
              _sel[k] = val;
            } else {
              _ctl[k]?.text = val;
            }
          });
        }),
      ),
    ]);
  }

  List<Widget> _renderItems(List<Object> items) {
    final out = <Widget>[];
    var buf = <Widget>[];
    void flush() {
      if (buf.isNotEmpty) {
        out.add(FieldGrid(List<Widget>.from(buf)));
        buf = [];
      }
    }

    for (final it in items) {
      if (it is F) {
        buf.add(_field(it));
      } else if (it is S) {
        buf.add(_select(it));
      } else {
        flush();
        if (it is R) {
          out.add(ResultRow(it.label, it.value, unit: it.unit, highlight: it.hl, warn: it.warn));
        } else if (it is Note) {
          out.add(NoticeBox(it.text, color: it.warn ? const Color(0xFFFBBF24) : const Color(0xFF4ADE80)));
        }
      }
    }
    flush();
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final top = widget.builder(_vals());
    final children = <Widget>[];
    for (final t in top) {
      if (t is Note) {
        children.add(NoticeBox(t.text, color: t.warn ? const Color(0xFFFBBF24) : const Color(0xFF4ADE80)));
      } else if (t is Sec) {
        children.add(ToolSection(t.title, _renderItems(t.items)));
      }
    }
    return ToolPage(
      toolId: widget.toolId,
      title: widget.title,
      description: widget.description,
      getData: () {
        final m = <String, dynamic>{};
        _ctl.forEach((k, c) => m[k] = c.text);
        _sel.forEach((k, v) => m[k] = v);
        return m;
      },
      onLoad: (m) => setState(() {
        m.forEach((k, v) {
          if (v == null) return;
          if (_selKeys.contains(k)) {
            _sel[k] = '$v';
          } else if (_ctl.containsKey(k)) {
            _ctl[k]!.text = '$v';
          }
        });
      }),
      children: children,
    );
  }
}
