import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme.dart';
import 'edit_profile_screen.dart';
import 'people_screens.dart';
import 'privacy_security_screen.dart';
import 'profile_card.dart';
import 'profile_common.dart';
import 'roles_screen.dart';
import 'settings_screens.dart';

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  const ProfileScreen({super.key, required this.profile});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  SupabaseClient get _db => Supabase.instance.client;

  late Map<String, dynamic> _p;
  int? _followers;
  int? _following;
  int? _posts;
  bool _uploading = false;

  String get _uid => _p['id'].toString();

  @override
  void initState() {
    super.initState();
    _p = Map<String, dynamic>.from(widget.profile);
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final data = await _db
          .from('profiles')
          .select('*, active_role:roles!active_role_id(label)')
          .eq('id', _uid)
          .maybeSingle();
      if (data != null && mounted) setState(() => _p = Map<String, dynamic>.from(data));
    } catch (_) {}
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    try {
      final a = await _db.from('follows').select('follower_id').eq('following_id', _uid);
      final b = await _db.from('follows').select('following_id').eq('follower_id', _uid);
      final c = await _db.from('posts').select('id').eq('author_id', _uid);
      if (!mounted) return;
      setState(() {
        _followers = a.length;
        _following = b.length;
        _posts = c.length;
      });
    } catch (_) {}
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) _refresh();
  }

  Future<void> _changeAvatar() async {
    if (_uploading) return;
    final x = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1600);
    if (x == null) return;
    final lower = x.name.toLowerCase();
    final ext = lower.contains('.') ? lower.substring(lower.lastIndexOf('.') + 1) : 'jpg';
    const allowed = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'webp': 'image/webp',
      'gif': 'image/gif',
    };
    final mime = allowed[ext];
    if (mime == null) {
      if (mounted) {
        toast(context, 'فرمت این عکس پشتیبانی نمی‌شود. JPG، PNG، WebP یا GIF انتخاب کنید.');
      }
      return;
    }
    setState(() => _uploading = true);
    try {
      final path = '$_uid/avatar-${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _db.storage.from('avatars').upload(
            path,
            File(x.path),
            fileOptions: FileOptions(contentType: mime, upsert: true),
          );
      final url = _db.storage.from('avatars').getPublicUrl(path);
      await _db.from('profiles').update({'avatar_url': url}).eq('id', _uid);
      await _refresh();
    } catch (e) {
      if (mounted) toast(context, 'آپلود عکس ناموفق بود: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _logout() async {
    final ok = await pfConfirm(context, 'از حساب خود خارج می‌شوید؟', yes: 'خروج');
    if (!ok) return;
    final db = _db;
    final id = _uid;
    try {
      await db.from('profiles').update({
        'is_online': false,
        'last_seen': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    await db.auth.signOut();
  }

  Widget _tile(IconData icon, String title, {String? sub, VoidCallback? onTap, bool danger = false}) {
    final disabled = onTap == null;
    final color = danger ? C.danger : (disabled ? C.muted : C.text);
    return PfCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(children: [
        Icon(icon, size: 21, color: danger ? C.danger : (disabled ? C.muted : C.redLight)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
            if (sub != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(sub, style: const TextStyle(color: C.muted, fontSize: 11.5)),
              ),
          ]),
        ),
        if (disabled && !danger)
          const Text('به‌زودی', style: TextStyle(color: C.muted, fontSize: 11))
        else
          const Icon(Icons.chevron_left, color: C.muted),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PfPage(
      title: 'پروفایل من',
      child: RefreshIndicator(
        color: C.red,
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ProfileCardView(
              p: _p,
              followers: _followers,
              following: _following,
              posts: _posts,
              uploading: _uploading,
              onAvatarTap: _changeAvatar,
              onFollowers: () =>
                  _open(FollowListScreen(viewer: _p, userId: _uid, mode: 'followers')),
              onFollowing: () =>
                  _open(FollowListScreen(viewer: _p, userId: _uid, mode: 'following')),
            ),
            const PfTitle('حساب کاربری'),
            _tile(Icons.edit_outlined, 'ویرایش پروفایل',
                sub: 'نام، آیدی، بیو، رزومه، مهارت‌ها و ...',
                onTap: () => _open(EditProfileScreen(profile: _p))),
            _tile(Icons.badge_outlined, 'نقش‌های من',
                sub: 'افزودن، حذف و تغییر نقش فعال',
                onTap: () => _open(RolesScreen(profile: _p))),
            _tile(Icons.search, 'جستجوی مهندس',
                sub: 'پیدا کردن پروفایل با کد نظام مهندسی یا آیدی',
                onTap: () => _open(SearchEngineerScreen(viewer: _p))),
            const PfTitle('تنظیمات'),
            _tile(Icons.lock_outline, 'حریم خصوصی و امنیت',
                sub: 'رمز دو مرحله‌ای، نشست‌ها، کاربران مسدود',
                onTap: () => _open(PrivacySecurityScreen(profile: _p))),
            _tile(Icons.notifications_none, 'اعلان‌ها',
                sub: 'پیام‌های جدید و اطلاعیه‌های پروژه',
                onTap: () => _open(NotificationSettingsScreen(profile: _p))),
            _tile(Icons.palette_outlined, 'ظاهر',
                sub: 'تم، اندازه متن و پس‌زمینه چت',
                onTap: () => _open(AppearanceScreen(profile: _p))),
            _tile(Icons.sd_storage_outlined, 'داده و ذخیره‌سازی',
                sub: 'دانلود خودکار رسانه',
                onTap: () => _open(DataStorageScreen(profile: _p))),
            _tile(Icons.person_add_alt_1_outlined, 'دعوت دوستان',
                sub: 'اشتراک‌گذاری لینک دعوت',
                onTap: () => _open(InviteScreen(profile: _p))),
            const PfTitle('به‌زودی'),
            _tile(Icons.bookmark_border, 'ذخیره‌شده‌ها'),
            _tile(Icons.workspace_premium_outlined, 'اشتراک'),
            _tile(Icons.account_balance_wallet_outlined, 'کیف پول'),
            const SizedBox(height: 6),
            _tile(Icons.logout, 'خروج از حساب', danger: true, onTap: _logout),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
