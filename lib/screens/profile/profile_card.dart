import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import 'profile_common.dart';

List<String> _list(dynamic v) => v is List
    ? v.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList()
    : <String>[];

String profilePublicUrl(Map<String, dynamic> p) {
  final u = (p['username'] ?? '').toString();
  return u.isEmpty ? Config.apiBase : '${Config.apiBase}/u/$u';
}

class ProfileCardView extends StatelessWidget {
  final Map<String, dynamic> p;
  final int? followers;
  final int? following;
  final int? posts;
  final VoidCallback? onFollowers;
  final VoidCallback? onFollowing;
  final VoidCallback? onAvatarTap;
  final bool uploading;

  const ProfileCardView({
    super.key,
    required this.p,
    this.followers,
    this.following,
    this.posts,
    this.onFollowers,
    this.onFollowing,
    this.onAvatarTap,
    this.uploading = false,
  });

  Widget _stat(String label, int? v, VoidCallback? onTap) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Column(children: [
            Text(v == null ? '—' : faNum(v),
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800, color: C.redLight)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: C.muted, fontSize: 11.5)),
          ]),
        ),
      );

  Widget _section(String title, Widget body) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: PfCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    color: C.redLight, fontSize: 12.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            body,
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final name = (p['name'] ?? '').toString();
    final username = (p['username'] ?? '').toString();
    final roles = _list(p['roles']);
    final skills = _list(p['skills']);
    final certs = _list(p['certificates']);
    final portfolio = _list(p['portfolio']);
    final bio = (p['bio'] ?? '').toString();
    final resume = (p['resume'] ?? '').toString();
    final experience = (p['experience'] ?? '').toString();
    final url = profilePublicUrl(p);
    final activeRole = ((p['active_role'] as Map?)?['label'] ?? '').toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PfCard(
          child: Column(children: [
            Row(children: [
              GestureDetector(
                onTap: onAvatarTap,
                child: Stack(children: [
                  PfAvatar(url: p['avatar_url']?.toString(), name: name, size: 68),
                  if (onAvatarTap != null)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: C.red, shape: BoxShape.circle),
                        child: uploading
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                      ),
                    ),
                ]),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name,
                      style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
                  if (username.isNotEmpty)
                    Text('@$username',
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(color: C.redLight, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if ((p['code'] ?? '').toString().isNotEmpty) 'کد: ${p['code']}',
                      if ((p['field'] ?? '').toString().isNotEmpty) p['field'].toString(),
                    ].join(' · '),
                    style: const TextStyle(color: C.soft, fontSize: 12),
                  ),
                  if (activeRole.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('نقش فعال: $activeRole',
                          style: const TextStyle(color: C.muted, fontSize: 11.5)),
                    ),
                ]),
              ),
            ]),
            if (roles.isNotEmpty) ...[
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final r in roles) PfBadge(r),
                ]),
              ),
            ],
            if (bio.isNotEmpty) ...[
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(bio,
                    style: const TextStyle(color: C.soft, fontSize: 13, height: 1.9)),
              ),
            ],
            const SizedBox(height: 14),
            const Divider(color: Color(0x22FFFFFF), height: 1),
            const SizedBox(height: 12),
            Row(children: [
              _stat('دنبال‌کننده', followers, onFollowers),
              _stat('دنبال‌شونده', following, onFollowing),
              _stat('پست', posts, null),
            ]),
          ]),
        ),
        PfCard(
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.network(
                'https://api.qrserver.com/v1/create-qr-code/?size=180x180&data=${Uri.encodeComponent(url)}',
                width: 170,
                height: 170,
                errorBuilder: (_, __, ___) => const SizedBox(
                  width: 170,
                  height: 170,
                  child: Center(child: Icon(Icons.qr_code_2, size: 60, color: Colors.black54)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: url));
                toast(context, 'لینک پروفایل کپی شد.');
              },
              child: Text(url,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: C.muted, fontSize: 11.5)),
            ),
          ]),
        ),
        if (resume.isNotEmpty)
          _section('رزومه',
              Text(resume, style: const TextStyle(color: C.soft, fontSize: 13, height: 1.9))),
        if (experience.isNotEmpty)
          _section('سوابق کاری',
              Text(experience, style: const TextStyle(color: C.soft, fontSize: 13, height: 1.9))),
        if (skills.isNotEmpty)
          _section('مهارت‌ها',
              Wrap(spacing: 6, runSpacing: 6, children: [for (final s in skills) PfBadge(s)])),
        if (certs.isNotEmpty)
          _section(
              'گواهینامه‌ها',
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final c in certs)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('• $c',
                        style: const TextStyle(color: C.soft, fontSize: 13, height: 1.8)),
                  ),
              ])),
        if (portfolio.isNotEmpty)
          _section(
              'نمونه‌کار',
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final c in portfolio)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('• $c',
                        style: const TextStyle(color: C.soft, fontSize: 13, height: 1.8)),
                  ),
              ])),
      ],
    );
  }
}
