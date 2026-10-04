import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'tool_kit.dart';

const _categories = <String, Map<String, dynamic>>{
  'length': {'label': 'طول', 'units': {'mm': 0.001, 'cm': 0.01, 'm': 1.0, 'km': 1000.0, 'inch': 0.0254, 'ft': 0.3048}},
  'area': {'label': 'سطح', 'units': {'mm2': 1e-6, 'cm2': 1e-4, 'm2': 1.0, 'km2': 1e6, 'hectare': 10000.0, 'ft2': 0.09290304}},
  'volume': {'label': 'حجم', 'units': {'mm3': 1e-9, 'cm3': 1e-6, 'm3': 1.0, 'liter': 0.001, 'ft3': 0.0283168, 'gallon': 0.00378541}},
  'weight': {'label': 'وزن و جرم', 'units': {'mg': 1e-6, 'g': 0.001, 'kg': 1.0, 'ton': 1000.0, 'lb': 0.45359237}},
  'force': {'label': 'نیرو', 'units': {'N': 1.0, 'kN': 1000.0, 'kgf': 9.80665, 'lbf': 4.4482216153}},
  'pressure': {'label': 'فشار', 'units': {'Pa': 1.0, 'kPa': 1000.0, 'MPa': 1e6, 'bar': 1e5, 'atm': 101325.0, 'psi': 6894.75729}},
  'torque': {'label': 'گشتاور', 'units': {'N.m': 1.0, 'kN.m': 1000.0, 'kgf.m': 9.80665, 'lbf.ft': 1.35581795}},
  'stress': {'label': 'تنش', 'units': {'Pa': 1.0, 'MPa': 1e6, 'kgf/cm2': 98066.5, 'psi': 6894.75729}},
  'speed': {'label': 'سرعت', 'units': {'m/s': 1.0, 'km/h': 0.277778, 'mph': 0.44704, 'ft/s': 0.3048}},
  'flow': {'label': 'دبی', 'units': {'m3/s': 1.0, 'l/s': 0.001, 'l/min': 0.0000166667, 'm3/h': 0.000277778}},
  'density': {'label': 'چگالی', 'units': {'kg/m3': 1.0, 'g/cm3': 1000.0, 'kg/l': 1000.0}},
  'angle': {'label': 'زاویه', 'units': {'degree': 0.0174533, 'rad': 1.0, 'gradian': 0.0157080}},
  'time': {'label': 'زمان', 'units': {'s': 1.0, 'min': 60.0, 'hour': 3600.0, 'day': 86400.0}},
};

const _tempNames = {'C': 'سلسیوس', 'F': 'فارنهایت', 'K': 'کلوین'};

class UnitConverterFullTool extends StatefulWidget {
  final String title, description;
  const UnitConverterFullTool({super.key, required this.title, required this.description});
  @override
  State<UnitConverterFullTool> createState() => _UnitConverterFullToolState();
}

class _UnitConverterFullToolState extends State<UnitConverterFullTool> {
  String _cat = 'length';
  String _from = 'mm';
  String _to = 'cm';
  final _value = TextEditingController(text: '1');

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  bool get _isTemp => _cat == 'temperature';

  List<String> get _unitKeys =>
      _isTemp ? ['C', 'F', 'K'] : (_categories[_cat]!['units'] as Map<String, double>).keys.toList();

  void _changeCat(String k) {
    setState(() {
      _cat = k;
      if (k == 'temperature') {
        _from = 'C';
        _to = 'F';
        return;
      }
      final units = (_categories[k]!['units'] as Map<String, double>).keys.toList();
      _from = units[0];
      _to = units.length > 1 ? units[1] : units[0];
    });
  }

  double _convertTemp(double v, String f, String t) {
    double c;
    if (f == 'C') {
      c = v;
    } else if (f == 'F') {
      c = (v - 32) * 5 / 9;
    } else {
      c = v - 273.15;
    }
    if (t == 'C') return c;
    if (t == 'F') return c * 9 / 5 + 32;
    return c + 273.15;
  }

  String _fmt(double r) {
    if (!r.isFinite) return '-';
    var s = r.toStringAsFixed(6).replaceFirst(RegExp(r'\.?0+$'), '');
    final neg = s.startsWith('-');
    if (neg) s = s.substring(1);
    final parts = s.split('.');
    final b = StringBuffer();
    for (var i = 0; i < parts[0].length; i++) {
      if (i > 0 && (parts[0].length - i) % 3 == 0) b.write(',');
      b.write(parts[0][i]);
    }
    return '${neg ? '-' : ''}$b${parts.length > 1 ? '.${parts[1]}' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    final num = nv(_value.text);
    double result;
    if (_isTemp) {
      result = _convertTemp(num, _from, _to);
    } else {
      final units = _categories[_cat]!['units'] as Map<String, double>;
      result = (num * units[_from]!) / units[_to]!;
    }
    String label(String u) => _isTemp ? (_tempNames[u] ?? u) : u;
    return ToolPage(
      toolId: 'unit-converter-full',
      title: widget.title,
      description: widget.description,
      getData: () => {'cat': _cat, 'from': _from, 'to': _to, 'value': _value.text},
      onLoad: (m) => setState(() {
        final c = m['cat']?.toString();
        if (c != null && (c == 'temperature' || _categories.containsKey(c))) _cat = c;
        final keys = _unitKeys;
        final f = m['from']?.toString();
        final t = m['to']?.toString();
        if (f != null && keys.contains(f)) _from = f;
        if (t != null && keys.contains(t)) _to = t;
        if (m['value'] != null) _value.text = '${m['value']}';
      }),
      children: [
        ToolSection('تبدیل', [
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final k in _categories.keys)
              _chip(_categories[k]!['label'] as String, _cat == k, () => _changeCat(k)),
            _chip('دما', _isTemp, () => _changeCat('temperature')),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _value,
            onChanged: (_) => setState(() {}),
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(hintText: 'عدد'),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _unitKeys.contains(_from) ? _from : _unitKeys.first,
                dropdownColor: C.bg2,
                items: [for (final u in _unitKeys) DropdownMenuItem(value: u, child: Text(label(u)))],
                onChanged: (v) => setState(() => _from = v ?? _from),
              ),
            ),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.arrow_back, size: 18, color: C.muted)),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _unitKeys.contains(_to) ? _to : _unitKeys.first,
                dropdownColor: C.bg2,
                items: [for (final u in _unitKeys) DropdownMenuItem(value: u, child: Text(label(u)))],
                onChanged: (v) => setState(() => _to = v ?? _to),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          ResultRow('نتیجه', _fmt(result), unit: _to, highlight: true),
        ]),
      ],
    );
  }

  Widget _chip(String label, bool active, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: active ? const Color(0x33C50337) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? C.red : const Color(0x33FFFFFF)),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? C.redLight : C.soft)),
        ),
      );
}

