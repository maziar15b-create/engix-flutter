import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/jalali.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'profile/people_screens.dart' show PublicProfileScreen;

const int kMaxPostMedia = 6;
const int kMaxMediaBytes = 50 * 1024 * 1024;

String _fa(Object? v) {
  const d = '۰۱۲۳۴۵۶۷۸۹';
  return (v ?? '').toString().replaceAllMapped(RegExp(r'\d'), (m) => d[int.parse(m[0]!)]);
}

String timeAgo(dynamic iso) {
  final d = DateTime.tryParse(iso.toString())?.toLocal();
  if (d == null) return '';
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'همین الان';
  if (diff.inMinutes < 60) return '${_fa(diff.inMinutes)} دقیقه پیش';
  if (diff.inHours < 24) return '${_fa(diff.inHours)} ساعت پیش';
  if (diff.inDays < 30) return '${_fa(diff.inDays)} روز پیش';
  return faDate(d);
}

bool wasEdited(Map<String, dynamic> m) {
  final u = DateTime.tryParse((m['updated_at'] ?? '').toString());
  final c = DateTime.tryParse((m['created_at'] ?? '').toString());
  if (u == null || c == null) return false;
  return u.difference(c).inSeconds > 5;
}

Widget _avatar(String? url, String name, double radius) {
  final u = url ?? '';
  return CircleAvatar(
    radius: radius,
    backgroundColor: C.bg3,
    backgroundImage: u.isNotEmpty ? NetworkImage(u) : null,
    child: u.isEmpty
        ? Text(name.isEmpty ? '?' : name.substring(0, 1),
            style: const TextStyle(color: C.redLight, fontWeight: FontWeight.w700))
        : null,
  );
}

// ============================================================ لایه‌ی داده

class SocialApi {
  static SupabaseClient get db => Supabase.instance.client;

  static Future<List<String>> blockedIds(String uid) async {
    final rows = await db.from('blocks').select('blocked_id').eq('blocker_id', uid);
    return rows.map((b) => b['blocked_id'].toString()).toList();
  }

  static Future<Set<String>> followingSet(String uid) async {
    final rows = await db.from('follows').select('following_id').eq('follower_id', uid);
    return rows.map((f) => f['following_id'].toString()).toSet();
  }

  static List<Map<String, dynamic>> _mediaOf(Map<String, dynamic> p) {
    final m = p['media'];
    if (m is List && m.isNotEmpty) {
      return [
        for (final e in m)
          if (e is Map && (e['url'] ?? '').toString().isNotEmpty)
            {'type': (e['type'] ?? 'image').toString(), 'url': e['url'].toString()}
      ];
    }
    final single = (p['media_url'] ?? '').toString();
    return single.isEmpty ? [] : [{'type': 'image', 'url': single}];
  }

  static Future<List<Map<String, dynamic>>> attachMeta(
      List<Map<String, dynamic>> posts, String viewerId) async {
    if (posts.isEmpty) return [];
    final postIds = posts.map((p) => p['id']).toList();
    final authorIds = posts.map((p) => p['author_id']).toSet().toList();
    final likes = await db.from('post_likes').select('post_id, user_id').inFilter('post_id', postIds);
    final comments = await db.from('post_comments').select('post_id').inFilter('post_id', postIds);
    final saved = await db
        .from('saved_posts')
        .select('post_id')
        .eq('user_id', viewerId)
        .inFilter('post_id', postIds);
    final profs = await db
        .from('profiles')
        .select('id, name, code, avatar_url')
        .inFilter('id', authorIds);
    final following = await followingSet(viewerId);

    final likeCount = <String, int>{};
    final likedByMe = <String>{};
    for (final l in likes) {
      final pid = l['post_id'].toString();
      likeCount[pid] = (likeCount[pid] ?? 0) + 1;
      if (l['user_id'].toString() == viewerId) likedByMe.add(pid);
    }
    final commentCount = <String, int>{};
    for (final c in comments) {
      final pid = c['post_id'].toString();
      commentCount[pid] = (commentCount[pid] ?? 0) + 1;
    }
    final savedSet = saved.map((s) => s['post_id'].toString()).toSet();
    final pmap = {
      for (final p in profs) p['id'].toString(): Map<String, dynamic>.from(p),
    };

    for (final p in posts) {
      final pid = p['id'].toString();
      final author = pmap[p['author_id'].toString()];
      p['authorName'] = (author?['name'] ?? '—').toString();
      p['authorCode'] = author?['code'];
      p['authorAvatar'] = author?['avatar_url'];
      p['likeCount'] = likeCount[pid] ?? 0;
      p['likedByMe'] = likedByMe.contains(pid);
      p['commentCount'] = commentCount[pid] ?? 0;
      p['savedByMe'] = savedSet.contains(pid);
      p['isFollowingAuthor'] = following.contains(p['author_id'].toString());
      p['mediaList'] = _mediaOf(p);
    }
    return posts;
  }

  static Future<List<Map<String, dynamic>>> feed(String uid,
      {required bool following, int limit = 50}) async {
    final blocked = await blockedIds(uid);
    var q = db.from('posts').select();
    if (following) {
      final ids = <String>{...await followingSet(uid), uid}.toList();
      q = q.inFilter('author_id', ids);
    }
    if (blocked.isNotEmpty) {
      q = q.not('author_id', 'in', '(${blocked.join(',')})');
    }
    final data = await q.order('created_at', ascending: false).limit(limit);
    return attachMeta(List<Map<String, dynamic>>.from(data), uid);
  }

  static Future<List<Map<String, dynamic>>> savedPosts(String uid) async {
    final rows = await db
        .from('saved_posts')
        .select('post_id, created_at')
        .eq('user_id', uid)
        .order('created_at', ascending: false);
    final ids = rows.map((s) => s['post_id']).toList();
    if (ids.isEmpty) return [];
    final data = await db.from('posts').select().inFilter('id', ids);
    final withMeta = await attachMeta(List<Map<String, dynamic>>.from(data), uid);
    final order = {for (var i = 0; i < ids.length; i++) ids[i].toString(): i};
    withMeta.sort((a, b) => (order[a['id'].toString()] ?? 0).compareTo(order[b['id'].toString()] ?? 0));
    return withMeta;
  }

  static String _mime(String name) {
    final l = name.toLowerCase();
    if (l.endsWith('.png')) return 'image/png';
    if (l.endsWith('.webp')) return 'image/webp';
    if (l.endsWith('.gif')) return 'image/gif';
    if
