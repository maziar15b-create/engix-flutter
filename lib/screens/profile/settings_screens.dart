import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_settings.dart';
import '../../core/theme.dart';
import 'profile_common.dart';

SupabaseClient get _db => Supabase.instance.client;

Map<String, dynamic> _asMap(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

Widget _onOff(bool on, VoidCallback tap) => GestureDetector(
      onTap: tap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: on ? const Color(0x55C50337) : C.bg1,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: on ? C.red : const Color(0x33FFFFFF)),
        ),
        child: Text(on ? 'روشن' : 'خاموش',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: on ? C.text : C.muted)),
      ),
    );

// -------------------------------------------------------------------- اعلان‌ها

class NotificationSettingsScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  const NotificationSettingsScreen({super.key, required this.profile});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  late Map<String, dynamic> _prefs;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _prefs = _asMap(widget.profile['notification_prefs']);
  }

  bool _val(String k) => _prefs[k] != false;

  Future<void> _toggle(String key) async {
    final next = {..._prefs, key: !_val(key)};
    setState(() {
      _prefs = next;
      _status = '';
    });
    try {
      await _db
          .from('profiles')
          .update({'notification_prefs': next}).eq('id', widget.profile['id']);
    } catch (e) {
      if (mounted) setState(() => _status = 'خطا: $e');
    }
  }

  Widget _row(String label, String key) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13.5))),
          _onOff(_val(key), () => _toggle(key)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return PfPage(
      title: 'اعلان‌ها',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const PfTitle('تنظیمات نوتیفیکیشن'),
          PfCard(
            child: Column(children: [
              _row('اعلان پیام‌های جدید', 'messages'),
              _row('اعلان اطلاعیه‌های پروژه', 'announcements'),
              _row('اعلان گزارش کار جدید', 'project_update'),
              _row('اعلان دعوت به پروژه', 'project_invite'),
            ]),
          ),
          if (_status.isNotEmpty)
            Text(_status, style: const TextStyle(color: C.redLight, fontSize: 12.5)),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------ ظاهر

class AppearanceScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  const AppearanceScreen({super.key, required this.profile});

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  late String _theme;
  late String _fontScale;
  String _wallpaper = '';
  bool _uploading = false;
  String _status = '';

  String get _uid => widget.profile['id'].toString();

  @override
  void initState() {
    super.initState();
    _theme = (widget.profile['theme'] ?? 'dark').toString();
    _fontScale = (widget.profile['font_scale'] ?? 'medium').toString();
    _wallpaper = (widget.profile['chat_wallpaper_url'] ?? '').toString();
  }

  Future<void> _update(Map<String, dynamic> u) async {
    try {
      await _db.from('profiles').update(u).eq('id', _uid);
    } catch (e) {
      if (mounted) setState(() => _status = 'خطا: $e');
    }
  }

  Future<void> _pickWallpaper() async {
    if (_uploading) return;
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1800);
    if (x == null) return;
    setState(() {
      _uploading = true;
      _status = '';
    });
    try {
      final lower = x.name.toLowerCase();
      final ext = lower.contains('.') ? lower.substring(lower.lastIndexOf('.') + 1) : 'jpg';
      final mime = ext == 'png'
          ? 'image/png'
          : ext == 'webp'
              ? 'image/webp'
              : 'image/jpeg';
      final path = '$_uid/wallpaper-${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _db.storage.from('wallpapers').upload(
            path,
            File(x.path),
            fileOptions: FileOptions(contentType: mime, upsert: true),
          );
      final url = _db.storage.from('wallpapers').getPublicUrl(path);
      await _db.from('profiles').update({'chat_wallpaper_url': url}).eq('id', _uid);
      if (mounted) {
        setState(() {
          _wallpaper = url;
          _status = 'پس‌زمینه چت به‌روزرسانی شد.';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _status = 'آپلود ناموفق بود: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _removeWallpaper() async {
    await _update({'chat_wallpaper_url': null});
    if (mounted) {
      setState(() {
        _wallpaper = '';
        _status = 'پس‌زمینه چت حذف شد (به حالت پیش‌فرض برگشت).';
      });
    }
  }

  Widget _choice(String label, bool sel, VoidCallback on) => ChoiceChip(
        label: Text(label),
        selected: sel,
        selectedColor: const Color(0x55C50337),
        backgroundColor: C.bg1,
        onSelected: (_) => on(),
      );

  @override
  Widget build(BuildContext context) {
    return PfPage(
      title: 'ظاهر',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const PfTitle('تم / پوسته رنگی',
              sub: 'انتخاب شما ذخیره می‌شود و در نسخه وب هم اعمال می‌شود.'),
          Wrap(spacing: 8, children: [
            _choice('تیره', _theme == 'dark', () {
              setState(() => _theme = 'dark');
              _update({'theme': 'dark'});
            }),
            _choice('روشن', _theme == 'light', () {
              setState(() => _theme = 'light');
              _update({'theme': 'light'});
            }),
          ]),
          const SizedBox(height: 22),
          const PfTitle('اندازه متن'),
          Wrap(spacing: 8, children: [
            for (final f in const [
              ['small', 'کوچک'],
              ['medium', 'متوسط'],
              ['large', 'بزرگ'],
            ])
              _choice(f[1], _fontScale == f[0], () {
                setState(() => _fontScale = f[0]);
                AppSettings.fontScale.value = AppSettings.scaleFor(f[0]);
                _update({'font_scale': f[0]});
              }),
          ]),
          const SizedBox(height: 22),
          const PfTitle('پس‌زمینه چت'),
          PfCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (_wallpaper.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(_wallpaper,
                        height: 140,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(height: 60)),
                  ),
                ),
              Row(children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _uploading ? null : _pickWallpaper,
                    child: Text(_uploading ? 'در حال آپلود...' : 'انتخاب تصویر'),
                  ),
                ),
                if (_wallpaper.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                      onPressed: _removeWallpaper,
                      child: const Text('حذف پس‌زمینه'),
                    ),
                  ),
                ],
              ]),
              if (_status.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_status, style: const TextStyle(color: C.soft, fontSize: 12)),
                ),
            ]),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------- داده و ذخیره‌سازی

const _mediaTypes = [
  ['image', 'عکس'],
  ['video', 'فیلم'],
  ['voice', 'پیام صوتی / گیف'],
  ['file', 'فایل (PDF / Word)'],
];

const _chatTypes = [
  ['direct', 'چت خصوصی'],
  ['group', 'گروه‌ها'],
  ['channel', 'کانال‌ها'],
];

Map<String, dynamic> _defaultPrefs() => {
      'image': {'direct': true, 'group': true, 'channel': true},
      'video': {'direct': true, 'group': false, 'channel': false},
      'voice': {'direct': true, 'group': true, 'channel': true},
      'file': {'direct': false, 'group': false, 'channel': false},
    };

class DataStorageScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  const DataStorageScreen({super.key, required this.profile});

  @override
  State<DataStorageScreen> createState() => _DataStorageScreenState();
}

class _DataStorageScreenState extends State<DataStorageScreen> {
  late Map<String, dynamic> _prefs;
  String _status = '';

  @override
  void initState() {
    super.initState();
    final base = _defaultPrefs();
    final saved = _asMap(widget.profile['auto_download_prefs']);
    for (final m in _mediaTypes) {
      base[m[0]] = {..._asMap(base[m[0]]), ..._asMap(saved[m[0]])};
    }
    _prefs = base;
  }

  bool _val(String media, String chat) => _asMap(_prefs[media])[chat] == true;

  Future<void> _toggle(String media, String chat) async {
    final next = Map<String, dynamic>.from(_prefs);
    next[media] = {..._asMap(_prefs[media]), chat: !_val(media, chat)};
    setState(() {
      _prefs = next;
      _status = '';
    });
    try {
      await _db
          .from('profiles')
          .update({'auto_download_prefs': next}).eq('id', widget.profile['id']);
    } catch (e) {
      if (mounted) setState(() => _status = 'خطا: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PfPage(
      title: 'داده و ذخیره‌سازی',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const PfTitle('دانلود خودکار رسانه',
              sub: 'مشخص کنید کدام نوع رسانه، در کدام نوع گفتگو، به‌صورت خودکار دانلود/نمایش داده شود.'),
          for (final m in _mediaTypes)
            PfCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m[1], style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                for (final c in _chatTypes)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(children: [
                      Expanded(
                          child: Text(c[1],
                              style: const TextStyle(color: C.soft, fontSize: 12.5))),
                      _onOff(_val(m[0], c[0]), () => _toggle(m[0], c[0])),
                    ]),
                  ),
              ]),
            ),
          if (_status.isNotEmpty)
            Text(_status, style: const TextStyle(color: C.redLight, fontSize: 12.5)),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ دعوت دوستان

class InviteScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  const InviteScreen({super.key, required this.profile});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  String _msg = '';

  String get _link {
    final ref = (widget.profile['username'] ?? widget.profile['code'] ?? '').toString();
    return 'https://www.engixapp.ir/?ref=$ref';
  }

  String get _text => 'سلام! من رو توی اپلیکیشن EngiX (شبکه‌ی مهندسان) پیدا کن:\n$_link';

  void _flash(String m) {
    setState(() => _msg = m);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _msg = '');
    });
  }

  Future<void> _share() async {
    try {
      await Share.share(_text, subject: 'دعوت به EngiX');
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: _text));
      _flash('لینک دعوت کپی شد ✅');
    }
  }

  Future<void> _sms() async {
    final uri = Uri.parse('sms:?body=${Uri.encodeComponent(_text)}');
    final ok = await launchUrl(uri);
    if (!ok) _flash('امکان باز کردن پیامک وجود ندارد.');
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _text));
    _flash('کپی شد ✅');
  }

  @override
  Widget build(BuildContext context) {
    return PfPage(
      title: 'دعوت دوستان',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const PfTitle('دعوت دوستان',
              sub: 'دوستانتان را به EngiX دعوت کنید — از طریق پیامک، بلوتوث یا هر اپلیکیشن دیگر.'),
          PfCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('لینک دعوت شما', style: TextStyle(color: C.muted, fontSize: 12)),
              const SizedBox(height: 8),
              Text(_link,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(fontSize: 12.5, color: C.text)),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _share,
                icon: const Icon(Icons.ios_share),
                label: const Text('اشتراک‌گذاری (بلوتوث، واتساپ، تلگرام و...)'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: _sms,
                icon: const Icon(Icons.sms_outlined),
                label: const Text('ارسال با پیامک'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: _copy,
                icon: const Icon(Icons.copy),
                label: const Text('کپی لینک دعوت'),
              ),
              if (_msg.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_msg, style: const TextStyle(color: C.soft, fontSize: 12)),
                ),
            ]),
          ),
        ],
      ),
    );
  }
}
