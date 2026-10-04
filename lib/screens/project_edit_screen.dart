import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart' show toLatinDigits;
import '../core/project_media.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'project_tabs/tab_common.dart';

class ProjectEditScreen extends StatefulWidget {
  final String projectId;
  final Map<String, dynamic> project;
  const ProjectEditScreen({super.key, required this.projectId, required this.project});

  @override
  State<ProjectEditScreen> createState() => _ProjectEditScreenState();
}

class _ProjectEditScreenState extends State<ProjectEditScreen> {
  SupabaseClient get _db => Supabase.instance.client;

  late final TextEditingController _name;
  late final TextEditingController _company;
  late final TextEditingController _location;
  late final TextEditingController _address;
  late final TextEditingController _latCtl;
  late final TextEditingController _lngCtl;
  late double _progress;
  String _cover = '';
  bool _coverBusy = false;
  bool _locating = false;
  bool _saving = false;
  bool _deleting = false;
  String _error = '';
  String _locError = '';

  @override
  void initState() {
    super.initState();
    final p = widget.project;
    _name = TextEditingController(text: (p['name'] ?? '').toString());
    _company = TextEditingController(text: (p['company_name'] ?? '').toString());
    _location = TextEditingController(text: (p['location'] ?? '').toString());
    _address = TextEditingController(text: (p['address'] ?? '').toString());
    _latCtl = TextEditingController(text: p['latitude'] == null ? '' : '${p['latitude']}');
    _lngCtl = TextEditingController(text: p['longitude'] == null ? '' : '${p['longitude']}');
    _progress = ((p['progress_percent'] ?? 0) as num).toDouble();
    _cover = (p['cover_image_url'] ?? '').toString();
  }

  @override
  void dispose() {
    for (final c in [_name, _company, _location, _address, _latCtl, _lngCtl]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _parse(String s) {
    final t = toLatinDigits(s).replaceAll('٫', '.').replaceAll(',', '.').trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  Future<void> _pickCover() async {
    if (_coverBusy) return;
    setState(() {
      _coverBusy = true;
      _error = '';
    });
    try {
      final f = await pickImageMedia();
      if (f == null) return;
      final media = await uploadProjectMedia(f, widget.projectId);
      await _db.from('projects').update({'cover_image_url': media.url}).eq('id', widget.projectId);
      if (mounted) setState(() => _cover = media.url);
    } catch (e) {
      if (mounted) setState(() => _error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _coverBusy = false);
    }
  }

  Future<void> _removeCover() async {
    if (!await confirmDialog(context, 'عکس کاور حذف شود؟')) return;
    try {
      await _db.from('projects').update({'cover_image_url': null}).eq('id', widget.projectId);
      if (mounted) setState(() => _cover = '');
    } catch (e) {
      if (mounted) setState(() => _error = 'خطا: $e');
    }
  }

  Future<void> _captureLocation() async {
    setState(() {
      _locError = '';
      _locating = true;
    });
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        setState(() => _locError = 'GPS گوشی خاموش است. آن را روشن کنید.');
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        setState(() => _locError = 'دسترسی به موقعیت مکانی رد شد. از تنظیمات گوشی اجازه بدهید.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted) return;
      setState(() {
        _latCtl.text = pos.latitude.toStringAsFixed(6);
        _lngCtl.text = pos.longitude.toStringAsFixed(6);
      });
    } catch (_) {
      if (mounted) setState(() => _locError = 'دریافت موقعیت مکانی ناموفق بود، دوباره تلاش کنید.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _clearLocation() {
    setState(() {
      _latCtl.clear();
      _lngCtl.clear();
    });
  }

  Future<void> _openMap() async {
    final lat = _parse(_latCtl.text);
    final lng = _parse(_lngCtl.text);
    Uri uri;
    if (lat != null && lng != null) {
      uri = Uri.parse('https://www.google.com/maps?q=$lat,$lng');
    } else {
      final q = [_address.text.trim(), _location.text.trim()].where((e) => e.isNotEmpty).join(' ');
      if (q.isEmpty) {
        setState(() => _locError = 'آدرس یا موقعیت را وارد کنید.');
        return;
      }
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(q)}');
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _save() async {
    setState(() => _error = '');
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'نام پروژه نمی‌تواند خالی باشد.');
      return;
    }
    final lat = _parse(_latCtl.text);
    final lng = _parse(_lngCtl.text);
    if ((lat == null) != (lng == null)) {
      setState(() => _error = 'عرض و طول جغرافیایی باید هر دو پر یا هر دو خالی باشند.');
      return;
    }
    if (lat != null && (lat < -90 || lat > 90 || lng! < -180 || lng > 180)) {
      setState(() => _error = 'مختصات واردشده معتبر نیست.');
      return;
    }
    setState(() => _saving = true);
    try {
      await _db.from('projects').update({
        'name': _name.text.trim(),
        'company_name': _company.text.trim(),
        'location': _location.text.trim(),
        'address': _address.text.trim(),
        'progress_percent': _progress.round(),
        'latitude': lat,
        'longitude': lng,
      }).eq('id', widget.projectId);
      if (!mounted) return;
      Navigator.pop(context, 'saved');
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'خطا: $e';
        });
      }
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.bg2,
        title: const Text('حذف پروژه'),
        content: Text(
            'آیا مطمئنید می‌خواهید پروژه «${_name.text.trim()}» را برای همیشه حذف کنید؟ این کار همه‌ی گزارش‌ها، یادداشت‌ها و چک‌لیست‌های پروژه را نیز حذف می‌کند و غیرقابل بازگشت است.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('بله، حذف شود', style: TextStyle(color: C.danger))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _deleting = true);
    try {
      final chat = widget.project['chat_conversation_id'];
      await _db.from('project_members').delete().eq('project_id', widget.projectId);
      await _db.from('projects').delete().eq('id', widget.projectId);
      if (chat != null) {
        try {
          await _db.from('conversations').delete().eq('id', chat);
        } catch (_) {}
      }
      if (mounted) Navigator.pop(context, 'deleted');
    } catch (e) {
      if (mounted) {
        setState(() {
          _deleting = false;
          _error = 'خطا در حذف: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lat = _parse(_latCtl.text);
    final lng = _parse(_lngCtl.text);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: C.bg1,
        title: const Text('تنظیمات پروژه', style: TextStyle(fontSize: 16)),
      ),
      body: Backdrop(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const TabHeader('عکس کاور'),
            Container(
              height: 150,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: C.bg2,
                border: Border.all(color: const Color(0x29C50337)),
                image: _cover.isEmpty
                    ? null
                    : DecorationImage(image: NetworkImage(_cover), fit: BoxFit.cover),
              ),
              child: _cover.isEmpty
                  ? const Center(child: Icon(Icons.image_outlined, size: 40, color: C.muted))
                  : null,
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                  onPressed: _coverBusy ? null : _pickCover,
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: Text(_coverBusy
                      ? 'در حال آپلود...'
                      : (_cover.isEmpty ? 'افزودن عکس کاور' : 'تغییر عکس کاور')),
                ),
              ),
              if (_cover.isNotEmpty) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size(80, 46), foregroundColor: C.danger),
                  onPressed: _removeCover,
                  child: const Text('حذف'),
                ),
              ],
            ]),
            const SizedBox(height: 22),
            const TabHeader('مشخصات پروژه'),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'نام پروژه')),
            const SizedBox(height: 12),
            TextField(controller: _company, decoration: const InputDecoration(labelText: 'نام شرکت')),
            const SizedBox(height: 12),
            TextField(controller: _location, decoration: const InputDecoration(labelText: 'محل اجرا (شهر)')),
            const SizedBox(height: 12),
            TextField(
              controller: _address,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'آدرس دقیق / لوکیشن'),
            ),
            const SizedBox(height: 22),
            const TabHeader('موقعیت مکانی روی نقشه'),
            FilledButton.icon(
              onPressed: _locating ? null : _captureLocation,
              icon: const Icon(Icons.my_location, size: 18),
              label: Text(_locating ? 'در حال دریافت موقعیت...' : '📍 دریافت موقعیت دقیق از GPS'),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _latCtl,
                  onChanged: (_) => setState(() {}),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(labelText: 'عرض جغرافیایی'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _lngCtl,
                  onChanged: (_) => setState(() {}),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(labelText: 'طول جغرافیایی'),
                ),
              ),
            ]),
            ErrorLine(_locError),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                  onPressed: _openMap,
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: Text(lat != null && lng != null ? 'مشاهده روی نقشه' : 'جستجوی آدرس روی نقشه'),
                ),
              ),
              if (_latCtl.text.isNotEmpty || _lngCtl.text.isNotEmpty) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(80, 46)),
                  onPressed: _clearLocation,
                  child: const Text('پاک کردن'),
                ),
              ],
            ]),
            const SizedBox(height: 22),
            const TabHeader('پیشرفت کلی'),
            Text('درصد پیشرفت کلی: ${_progress.round()}٪',
                style: const TextStyle(color: C.soft, fontSize: 12.5)),
            Slider(
              value: _progress,
              min: 0,
              max: 100,
              divisions: 100,
              activeColor: C.red,
              onChanged: (v) => setState(() => _progress = v),
            ),
            const SizedBox(height: 8),
            ErrorLine(_error),
            FilledButton(
              onPressed: (_saving || _deleting) ? null : _save,
              child: Text(_saving ? 'در حال ذخیره...' : 'ذخیره تغییرات'),
            ),
            const SizedBox(height: 28),
            const Divider(color: Color(0x22FFFFFF)),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: C.danger,
                side: const BorderSide(color: Color(0x59E5484D)),
              ),
              onPressed: (_saving || _deleting) ? null : _delete,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: Text(_deleting ? 'در حال حذف...' : 'حذف پروژه'),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
