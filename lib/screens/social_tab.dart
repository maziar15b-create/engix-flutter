import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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
  return _fa('${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}');
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
    if (l.endsWith('.mp4')) return 'video/mp4';
    if (l.endsWith('.mov')) return 'video/quicktime';
    if (l.endsWith('.webm')) return 'video/webm';
    if (l.endsWith('.3gp')) return 'video/3gpp';
    return l.endsWith('.jpg') || l.endsWith('.jpeg') ? 'image/jpeg' : 'application/octet-stream';
  }

  static Future<Map<String, String>> uploadMedia(String uid, File file, String name, bool isVideo) async {
    final size = await file.length();
    if (size > kMaxMediaBytes) {
      throw Exception('حجم هر فایل باید کمتر از ۵۰ مگابایت باشد.');
    }
    final dot = name.lastIndexOf('.');
    final ext = dot >= 0 ? name.substring(dot + 1).toLowerCase() : (isVideo ? 'mp4' : 'jpg');
    final rnd = Random().nextInt(0xFFFFF).toRadixString(36);
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}-$rnd.$ext';
    var mime = _mime(name);
    if (mime == 'application/octet-stream') mime = isVideo ? 'video/mp4' : 'image/jpeg';
    await db.storage.from('post-images').upload(
          path,
          file,
          fileOptions: FileOptions(contentType: mime, upsert: false),
        );
    return {'type': isVideo ? 'video' : 'image', 'url': db.storage.from('post-images').getPublicUrl(path)};
  }

  static Future<void> createPost(String uid, String text, List<Map<String, String>> media) async {
    final t = text.trim();
    if (t.isEmpty && media.isEmpty) throw Exception('متن یا رسانه‌ی پست خالی است.');
    String? firstImage;
    for (final m in media) {
      if (m['type'] == 'image') {
        firstImage = m['url'];
        break;
      }
    }
    await db.from('posts').insert({
      'author_id': uid,
      'type': 'post',
      'content': t,
      'media_url': firstImage,
      'media': media,
    });
  }

  static Future<void> updatePost(dynamic id, String text) async {
    final t = text.trim();
    if (t.isEmpty) throw Exception('متن پست خالی است.');
    await db
        .from('posts')
        .update({'content': t, 'updated_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
  }

  static Future<void> deletePost(dynamic id) => db.from('posts').delete().eq('id', id);

  static Future<void> like(dynamic postId, String uid, bool currentlyLiked) async {
    try {
      if (currentlyLiked) {
        await db.from('post_likes').delete().eq('post_id', postId).eq('user_id', uid);
      } else {
        await db.from('post_likes').insert({'post_id': postId, 'user_id': uid});
      }
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow;
    }
  }

  static Future<void> save(dynamic postId, String uid, bool save) async {
    try {
      if (save) {
        await db.from('saved_posts').insert({'user_id': uid, 'post_id': postId});
      } else {
        await db.from('saved_posts').delete().eq('user_id', uid).eq('post_id', postId);
      }
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow;
    }
  }

  static Future<void> follow(String uid, String target, bool follow) async {
    if (uid == target) return;
    try {
      if (follow) {
        await db.from('follows').insert({'follower_id': uid, 'following_id': target});
      } else {
        await db.from('follows').delete().eq('follower_id', uid).eq('following_id', target);
      }
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> comments(dynamic postId) async {
    final rows = await db
        .from('post_comments')
        .select()
        .eq('post_id', postId)
        .order('created_at', ascending: true);
    final list = List<Map<String, dynamic>>.from(rows);
    final ids = list.map((c) => c['author_id']).toSet().toList();
    final names = <String, String>{};
    if (ids.isNotEmpty) {
      final ps = await db.from('profiles').select('id, name').inFilter('id', ids);
      for (final p in ps) {
        names[p['id'].toString()] = (p['name'] ?? '—').toString();
      }
    }
    for (final c in list) {
      c['authorName'] = names[c['author_id'].toString()] ?? '—';
    }
    return list;
  }
}

// ============================================================ تب شبکه

class SocialTab extends StatefulWidget {
  final Map<String, dynamic> profile;
  const SocialTab({super.key, required this.profile});

  @override
  State<SocialTab> createState() => _SocialTabState();
}

class _SocialTabState extends State<SocialTab> {
  String get _uid => widget.profile['id'].toString();

  bool _following = true;
  int _limit = 50;
  List<Map<String, dynamic>>? _posts;
  String? _error;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _load() async {
    try {
      final data = await SocialApi.feed(_uid, following: _following, limit: _limit);
      if (!mounted) return;
      setState(() {
        _posts = data;
        _error = null;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _posts = _posts ?? [];
        _error = '$e';
        _loadingMore = false;
      });
    }
  }

  void _switchTab(bool following) {
    if (_following == following) return;
    setState(() {
      _following = following;
      _posts = null;
      _limit = 50;
    });
    _load();
  }

  Future<void> _newPost() async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg2,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _NewPostSheet(uid: _uid),
      ),
    );
    if (done == true) _load();
  }

  void _openSaved() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SavedPostsScreen(profile: widget.profile),
    ));
  }

  void _onFollowChange(String authorId, bool next) {
    setState(() {
      for (final p in _posts ?? <Map<String, dynamic>>[]) {
        if (p['author_id'].toString() == authorId) p['isFollowingAuthor'] = next;
      }
    });
  }

  Widget _chip(String label, bool active, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            color: active ? const Color(0x33C50337) : C.bg1,
            border: Border.all(color: active ? C.red : const Color(0x1AFFFFFF)),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? C.redLight : C.muted)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final posts = _posts;
    return RefreshIndicator(
      color: C.red,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('شبکه اجتماعی',
                    style: TextStyle(
                        color: C.redLight, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
                SizedBox(height: 4),
                Text('با مهندسان دیگر در ارتباط باشید.',
                    style: TextStyle(color: C.muted, fontSize: 12.5)),
              ]),
            ),
            IconButton(
              tooltip: 'پست‌های ذخیره‌شده',
              onPressed: _openSaved,
              icon: const Icon(Icons.bookmark_border, color: C.soft),
            ),
            const SizedBox(width: 2),
            Material(
              color: C.red,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _newPost,
                child: const Padding(
                  padding: EdgeInsets.all(11),
                  child: Icon(Icons.add_a_photo_outlined, color: Colors.white, size: 20),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            _chip('دنبال‌شده‌ها', _following, () => _switchTab(true)),
            const SizedBox(width: 8),
            _chip('اکسپلور', !_following, () => _switchTab(false)),
          ]),
          const SizedBox(height: 14),
          if (_error != null) ErrorText(_error),
          if (posts == null)
            const Padding(
              padding: EdgeInsets.all(30),
              child: Center(child: CircularProgressIndicator(color: C.red)),
            ),
          if (posts != null && posts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                _following ? 'هنوز کسی را دنبال نکرده‌اید یا پستی وجود ندارد.' : 'هنوز پستی منتشر نشده.',
                style: const TextStyle(color: C.muted, fontSize: 13),
              ),
            ),
          if (posts != null)
            for (final p in posts)
              PostCard(
                key: ValueKey('post-${p['id']}'),
                post: p,
                profile: widget.profile,
                onChanged: () => setState(() {}),
                onDeleted: () => setState(() => _posts?.remove(p)),
                onFollowChange: _onFollowChange,
                onError: _snack,
              ),
          if (posts != null && posts.length >= _limit)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: _loadingMore
                    ? null
                    : () {
                        setState(() {
                          _loadingMore = true;
                          _limit += 50;
                        });
                        _load();
                      },
                child: Text(_loadingMore ? 'در حال بارگذاری...' : 'نمایش پست‌های بیشتر'),
              ),
            ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

// ======================================================= پست‌های ذخیره‌شده

class SavedPostsScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  const SavedPostsScreen({super.key, required this.profile});
  @override
  State<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends State<SavedPostsScreen> {
  List<Map<String, dynamic>>? _posts;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await SocialApi.savedPosts(widget.profile['id'].toString());
      if (mounted) setState(() => _posts = data);
    } catch (e) {
      if (mounted) {
        setState(() {
          _posts = [];
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final posts = _posts;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: C.bg1,
        title: const Text('پست‌های ذخیره‌شده', style: TextStyle(fontSize: 16)),
      ),
      body: Backdrop(
        child: posts == null
            ? const Center(child: CircularProgressIndicator(color: C.red))
            : RefreshIndicator(
                color: C.red,
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_error != null) ErrorText(_error),
                    if (posts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text('هنوز پستی ذخیره نکرده‌اید.',
                              style: TextStyle(color: C.muted)),
                        ),
                      ),
                    for (final p in posts)
                      PostCard(
                        key: ValueKey('saved-${p['id']}'),
                        post: p,
                        profile: widget.profile,
                        onChanged: () => setState(() {}),
                        onDeleted: () => setState(() => posts.remove(p)),
                        onUnsaved: () => setState(() => posts.remove(p)),
                        onFollowChange: (id, next) => setState(() {
                          for (final x in posts) {
                            if (x['author_id'].toString() == id) x['isFollowingAuthor'] = next;
                          }
                        }),
                        onError: (m) => ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(m))),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

// ============================================================ کارت پست

class PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final Map<String, dynamic> profile;
  final VoidCallback onChanged;
  final VoidCallback onDeleted;
  final VoidCallback? onUnsaved;
  final void Function(String authorId, bool next) onFollowChange;
  final void Function(String message) onError;
  const PostCard({
    super.key,
    required this.post,
    required this.profile,
    required this.onChanged,
    required this.onDeleted,
    required this.onFollowChange,
    required this.onError,
    this.onUnsaved,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  Map<String, dynamic> get p => widget.post;
  String get _uid => widget.profile['id'].toString();
  String get _authorId => p['author_id'].toString();
  bool get _mine => _authorId == _uid;

  void _openProfile() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PublicProfileScreen(viewer: widget.profile, userId: _authorId),
    ));
  }

  Future<void> _toggleLike() async {
    final liked = p['likedByMe'] == true;
    final count = (p['likeCount'] as int?) ?? 0;
    setState(() {
      p['likedByMe'] = !liked;
      p['likeCount'] = liked ? (count > 0 ? count - 1 : 0) : count + 1;
    });
    widget.onChanged();
    try {
      await SocialApi.like(p['id'], _uid, liked);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        p['likedByMe'] = liked;
        p['likeCount'] = count;
      });
      widget.onChanged();
      widget.onError('$e');
    }
  }

  Future<void> _toggleSave() async {
    final was = p['savedByMe'] == true;
    setState(() => p['savedByMe'] = !was);
    widget.onChanged();
    try {
      await SocialApi.save(p['id'], _uid, !was);
      if (was) widget.onUnsaved?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() => p['savedByMe'] = was);
      widget.onChanged();
      widget.onError('$e');
    }
  }

  Future<void> _toggleFollow() async {
    final was = p['isFollowingAuthor'] == true;
    widget.onFollowChange(_authorId, !was);
    try {
      await SocialApi.follow(_uid, _authorId, !was);
    } catch (e) {
      widget.onFollowChange(_authorId, was);
      widget.onError('$e');
    }
  }

  Future<void> _share() async {
    final text = (p['content'] ?? '').toString();
    final shareText = text.isEmpty ? 'یک پست در EngiX' : (text.length > 120 ? text.substring(0, 120) : text);
    try {
      await Share.share('$shareText\n\n— ${p['authorName']} در EngiX');
    } catch (_) {}
  }

  Future<void> _edit() async {
    final ctl = TextEditingController(text: (p['content'] ?? '').toString());
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.bg2,
        title: const Text('ویرایش پست'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          minLines: 3,
          maxLines: 8,
          decoration: const InputDecoration(hintText: 'متن پست'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctl.text.trim()), child: const Text('ذخیره')),
        ],
      ),
    );
    ctl.dispose();
    if (text == null || text.isEmpty) return;
    try {
      await SocialApi.updatePost(p['id'], text);
      if (!mounted) return;
      setState(() {
        p['content'] = text;
        p['updated_at'] = DateTime.now().toUtc().toIso8601String();
      });
      widget.onChanged();
    } catch (e) {
      widget.onError('$e');
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.bg2,
        title: const Text('حذف پست'),
        content: const Text('این پست حذف شود؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف', style: TextStyle(color: C.danger))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await SocialApi.deletePost(p['id']);
      widget.onDeleted();
    } catch (e) {
      widget.onError('$e');
    }
  }

  void _openComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg2,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _CommentsSheet(
          postId: p['id'],
          uid: _uid,
          onDelta: (d) {
            if (!mounted) return;
            setState(() {
              final c = (p['commentCount'] as int?) ?? 0;
              p['commentCount'] = (c + d) < 0 ? 0 : c + d;
            });
            widget.onChanged();
          },
        ),
      ),
    );
  }

  void _openViewer(List<Map<String, dynamic>> media, int start) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _MediaViewer(media: media, initial: start),
    ));
  }

  Widget _mediaTile(List<Map<String, dynamic>> media, int i, {double? height}) {
    final m = media[i];
    final isVideo = m['type'] == 'video';
    return GestureDetector(
      onTap: () {
        if (isVideo) {
          launchUrl(Uri.parse(m['url'].toString()), mode: LaunchMode.externalApplication);
        } else {
          _openViewer(media, i);
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: isVideo
              ? Container(
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: const Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.play_circle_fill, size: 52, color: Colors.white70),
                    SizedBox(height: 4),
                    Text('پخش ویدیو', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ]),
                )
              : Image.network(
                  m['url'].toString(),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: C.bg3,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image, color: C.muted),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _mediaGrid() {
    final media = List<Map<String, dynamic>>.from(p['mediaList'] ?? const []);
    if (media.isEmpty) return const SizedBox.shrink();
    if (media.length == 1) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: _mediaTile(media, 0, height: 240),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 1.15,
        children: [for (var i = 0; i < media.length; i++) _mediaTile(media, i)],
      ),
    );
  }

  Widget _action(IconData icon, String label, Color color, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 20, color: color),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 5),
              Text(label, style: TextStyle(color: color, fontSize: 12.5)),
            ],
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final name = (p['authorName'] ?? '—').toString();
    final content = (p['content'] ?? '').toString();
    final liked = p['likedByMe'] == true;
    final saved = p['savedByMe'] == true;
    final likes = (p['likeCount'] as int?) ?? 0;
    final comments = (p['commentCount'] as int?) ?? 0;
    final following = p['isFollowingAuthor'] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: EngixPanel(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            GestureDetector(
              onTap: _openProfile,
              child: _avatar(p['authorAvatar']?.toString(), name, 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: _openProfile,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  Text('${timeAgo(p['created_at'])}${wasEdited(p) ? ' · ویرایش شده' : ''}',
                      style: const TextStyle(color: C.muted, fontSize: 11)),
                ]),
              ),
            ),
            if (!_mine)
              following
                  ? OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 12)),
                      onPressed: _toggleFollow,
                      child: const Text('لغو دنبال کردن', style: TextStyle(fontSize: 11.5)),
                    )
                  : FilledButton(
                      style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 12)),
                      onPressed: _toggleFollow,
                      child: const Text('دنبال کردن', style: TextStyle(fontSize: 11.5)),
                    ),
            if (_mine)
              PopupMenuButton<String>(
                color: C.bg2,
                icon: const Icon(Icons.more_vert, color: C.soft, size: 20),
                onSelected: (v) {
                  if (v == 'edit') _edit();
                  if (v == 'delete') _delete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('ویرایش')),
                  PopupMenuItem(
                      value: 'delete', child: Text('حذف', style: TextStyle(color: C.danger))),
                ],
              ),
          ]),
          if (content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(content, style: const TextStyle(fontSize: 13.5, height: 1.9)),
            ),
          _mediaGrid(),
          const SizedBox(height: 8),
          const Divider(color: Color(0x24C50337), height: 1),
          const SizedBox(height: 4),
          Row(children: [
            _action(liked ? Icons.favorite : Icons.favorite_border, likes > 0 ? _fa(likes) : '',
                liked ? C.redLight : C.muted, _toggleLike),
            _action(Icons.chat_bubble_outline, comments > 0 ? _fa(comments) : '', C.muted,
                _openComments),
            _action(saved ? Icons.bookmark : Icons.bookmark_border, '',
                saved ? C.redLight : C.muted, _toggleSave),
            const Spacer(),
            _action(Icons.share_outlined, '', C.muted, _share),
          ]),
        ]),
      ),
    );
  }
}

// ======================================================= نمایشگر تصویر

class _MediaViewer extends StatefulWidget {
  final List<Map<String, dynamic>> media;
  final int initial;
  const _MediaViewer({required this.media, required this.initial});
  @override
  State<_MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<_MediaViewer> {
  late final PageController _ctl;
  late int _index;

  @override
  void initState() {
    super.initState();
    final images = widget.media.where((m) => m['type'] != 'video').toList();
    final start = images.indexWhere((m) => m['url'] == widget.media[widget.initial]['url']);
    _index = start < 0 ? 0 : start;
    _ctl = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.media.where((m) => m['type'] != 'video').toList();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('${_fa(_index + 1)} از ${_fa(images.length)}',
            style: const TextStyle(fontSize: 14)),
      ),
      body: PageView.builder(
        controller: _ctl,
        itemCount: images.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) => InteractiveViewer(
          child: Center(child: Image.network(images[i]['url'].toString())),
        ),
      ),
    );
  }
}

// ======================================================= ایجاد پست

class _PickedItem {
  final File file;
  final String name;
  final bool isVideo;
  _PickedItem(this.file, this.name, this.isVideo);
}

class _NewPostSheet extends StatefulWidget {
  final String uid;
  const _NewPostSheet({required this.uid});
  @override
  State<_NewPostSheet> createState() => _NewPostSheetState();
}

class _NewPostSheetState extends State<_NewPostSheet> {
  final _text = TextEditingController();
  final List<_PickedItem> _items = [];
  bool _busy = false;
  String _error = '';

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final left = kMaxPostMedia - _items.length;
    if (left <= 0) {
      setState(() => _error = 'حداکثر $kMaxPostMedia فایل (عکس یا ویدیو) می‌توانید اضافه کنید.');
      return;
    }
    final List<XFile> files;
    if (left >= 2) {
      files = await ImagePicker().pickMultiImage(imageQuality: 85, limit: left);
    } else {
      final one = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
      files = one == null ? <XFile>[] : <XFile>[one];
    }
    if (files.isEmpty) return;
    setState(() {
      _error = '';
      for (final x in files.take(left)) {
        _items.add(_PickedItem(File(x.path), x.name, false));
      }
    });
  }

  Future<void> _camera() async {
    if (_items.length >= kMaxPostMedia) {
      setState(() => _error = 'حداکثر $kMaxPostMedia فایل (عکس یا ویدیو) می‌توانید اضافه کنید.');
      return;
    }
    final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85);
    if (x == null) return;
    setState(() {
      _error = '';
      _items.add(_PickedItem(File(x.path), x.name, false));
    });
  }

  Future<void> _pickVideo() async {
    if (_items.length >= kMaxPostMedia) {
      setState(() => _error = 'حداکثر $kMaxPostMedia فایل (عکس یا ویدیو) می‌توانید اضافه کنید.');
      return;
    }
    final x = await ImagePicker()
        .pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 60));
    if (x == null) return;
    final f = File(x.path);
    if (await f.length() > kMaxMediaBytes) {
      setState(() => _error = 'حجم ویدیو باید کمتر از ۵۰ مگابایت باشد.');
      return;
    }
    setState(() {
      _error = '';
      _items.add(_PickedItem(f, x.name, true));
    });
  }

  void _menu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: C.bg2,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_camera, color: C.redLight),
            title: const Text('دوربین'),
            onTap: () {
              Navigator.pop(ctx);
              _camera();
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library, color: C.redLight),
            title: const Text('عکس از گالری (چندتایی)'),
            onTap: () {
              Navigator.pop(ctx);
              _pickImages();
            },
          ),
          ListTile(
            leading: const Icon(Icons.videocam, color: C.redLight),
            title: const Text('ویدیو (حداکثر ۶۰ ثانیه)'),
            onTap: () {
              Navigator.pop(ctx);
              _pickVideo();
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_text.text.trim().isEmpty && _items.isEmpty) {
      setState(() => _error = 'متن یا رسانه‌ی پست خالی است.');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final uploaded = <Map<String, String>>[];
      for (final it in _items) {
        uploaded.add(await SocialApi.uploadMedia(widget.uid, it.file, it.name, it.isVideo));
      }
      await SocialApi.createPost(widget.uid, _text.text, uploaded);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$e'.replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Center(
            child: Text('پست جدید', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _text,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(hintText: 'چه چیزی در ذهن دارید؟'),
          ),
          if (_items.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final it = _items[i];
                  return Stack(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 92,
                        height: 92,
                        child: it.isVideo
                            ? Container(
                                color: Colors.black,
                                child: const Icon(Icons.videocam, color: Colors.white70, size: 34))
                            : Image.file(it.file, fit: BoxFit.cover),
                      ),
                    ),
                    Positioned(
                      top: 3,
                      right: 3,
                      child: GestureDetector(
                        onTap: _busy ? null : () => setState(() => _items.removeAt(i)),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                              color: Color(0xCC0B0A0D), shape: BoxShape.circle),
                          child: const Icon(Icons.close, size: 14, color: C.redLight),
                        ),
                      ),
                    ),
                  ]);
                },
              ),
            ),
          ],
          if (_error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_error, style: const TextStyle(color: C.danger, fontSize: 12.5)),
            ),
          const SizedBox(height: 12),
          Row(children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
              onPressed: _busy ? null : _menu,
              icon: const Icon(Icons.image_outlined, size: 18),
              label: Text('عکس/ویدیو (${_fa(_items.length)}/${_fa(kMaxPostMedia)})'),
            ),
            const Spacer(),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(110, 46)),
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? 'در حال ارسال...' : 'انتشار پست'),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ============================================================== نظرات

class _CommentsSheet extends StatefulWidget {
  final dynamic postId;
  final String uid;
  final void Function(int delta) onDelta;
  const _CommentsSheet({required this.postId, required this.uid, required this.onDelta});
  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  List<Map<String, dynamic>>? _comments;
  final _ctl = TextEditingController();
  dynamic _editingId;
  bool _sending = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await SocialApi.comments(widget.postId);
      if (mounted) setState(() => _comments = data);
    } catch (e) {
      if (mounted) {
        setState(() {
          _comments = [];
          _error = '$e';
        });
      }
    }
  }

  Future<void> _send() async {
    final t = _ctl.text.trim();
    if (t.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = '';
    });
    try {
      if (_editingId != null) {
        await SocialApi.db.from('post_comments').update({
          'text': t,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', _editingId);
        _editingId = null;
      } else {
        await SocialApi.db
            .from('post_comments')
            .insert({'post_id': widget.postId, 'author_id': widget.uid, 'text': t});
        widget.onDelta(1);
      }
      _ctl.clear();
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> c) async {
    try {
      await SocialApi.db.from('post_comments').delete().eq('id', c['id']);
      widget.onDelta(-1);
      if (mounted) setState(() => _comments?.remove(c));
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final comments = _comments;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.68,
        child: Column(children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 16, 18, 8),
            child: Text('نظرات', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: comments == null
                ? const Center(child: CircularProgressIndicator(color: C.red))
                : comments.isEmpty
                    ? const Center(
                        child: Text('هنوز نظری ثبت نشده.', style: TextStyle(color: C.muted)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        itemCount: comments.length,
                        itemBuilder: (_, i) {
                          final c = comments[i];
                          final mine = c['author_id'].toString() == widget.uid;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Expanded(
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text.rich(TextSpan(children: [
                                        TextSpan(
                                            text: '${c['authorName']}  ',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700, fontSize: 12.5)),
                                        TextSpan(
                                            text: (c['text'] ?? '').toString(),
                                            style: const TextStyle(color: C.soft, fontSize: 12.5)),
                                      ])),
                                      Text(
                                          '${timeAgo(c['created_at'])}${wasEdited(c) ? ' · ویرایش شده' : ''}',
                                          style: const TextStyle(color: C.muted, fontSize: 10.5)),
                                    ]),
                              ),
                              if (mine) ...[
                                InkWell(
                                  onTap: () => setState(() {
                                    _editingId = c['id'];
                                    _ctl.text = (c['text'] ?? '').toString();
                                  }),
                                  child: const Padding(
                                    padding: EdgeInsets.all(5),
                                    child: Icon(Icons.edit_outlined, size: 16, color: C.soft),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => _delete(c),
                                  child: const Padding(
                                    padding: EdgeInsets.all(5),
                                    child: Icon(Icons.delete_outline, size: 16, color: C.danger),
                                  ),
                                ),
                              ],
                            ]),
                          );
                        },
                      ),
          ),
          if (_error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(_error, style: const TextStyle(color: C.danger, fontSize: 12)),
            ),
          if (_editingId != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
              child: Row(children: [
                const Text('در حال ویرایش نظر', style: TextStyle(color: C.muted, fontSize: 11.5)),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() {
                    _editingId = null;
                    _ctl.clear();
                  }),
                  child: const Text('انصراف', style: TextStyle(fontSize: 11.5)),
                ),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _ctl,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(hintText: 'نظر خود را بنویسید...'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: C.red, foregroundColor: Colors.white),
                onPressed: _sending ? null : _send,
                icon: Icon(_editingId != null ? Icons.check : Icons.send),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
