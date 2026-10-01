import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme.dart';
import '../core/widgets.dart';

String timeAgo(dynamic iso) {
  final d = DateTime.tryParse(iso.toString())?.toLocal();
  if (d == null) return '';
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'همین الان';
  if (diff.inMinutes < 60) return '${diff.inMinutes} دقیقه پیش';
  if (diff.inHours < 24) return '${diff.inHours} ساعت پیش';
  if (diff.inDays < 30) return '${diff.inDays} روز پیش';
  return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
}

Widget _avatar(String? url, String name, double radius) {
  final u = url ?? '';
  return CircleAvatar(
    radius: radius,
    backgroundColor: C.bg3,
    backgroundImage: u.isNotEmpty ? NetworkImage(u) : null,
    child: u.isEmpty
        ? Text(
            name.isEmpty ? '?' : name.substring(0, 1),
            style: const TextStyle(
                color: C.redLight, fontWeight: FontWeight.w700),
          )
        : null,
  );
}

class SocialTab extends StatefulWidget {
  final Map<String, dynamic> profile;
  const SocialTab({super.key, required this.profile});

  @override
  State<SocialTab> createState() => _SocialTabState();
}

class _SocialTabState extends State<SocialTab> {
  SupabaseClient get _db => Supabase.instance.client;
  String get _uid => widget.profile['id'].toString();

  bool _explore = true;
  List<Map<String, dynamic>>? _posts;
  Set<String> _following = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _load() async {
    try {
      final blockedRows =
          await _db.from('blocks').select('blocked_id').eq('blocker_id', _uid);
      final blocked =
          blockedRows.map((b) => b['blocked_id'].toString()).toList();

      final followRows = await _db
          .from('follows')
          .select('following_id')
          .eq('follower_id', _uid);
      final following =
          followRows.map((f) => f['following_id'].toString()).toSet();

      var q = _db.from('posts').select();
      if (!_explore) {
        final ids = <String>{...following, _uid}.toList();
        q = q.inFilter('author_id', ids);
      }
      if (blocked.isNotEmpty) {
        q = q.not('author_id', 'in', '(${blocked.join(',')})');
      }
      final data = await q.order('created_at', ascending: false).limit(50);
      final posts = List<Map<String, dynamic>>.from(data);

      if (posts.isNotEmpty) {
        final postIds = posts.map((p) => p['id']).toList();
        final authorIds = posts.map((p) => p['author_id']).toSet().toList();
        final likes = await _db
            .from('post_likes')
            .select('post_id, user_id')
            .inFilter('post_id', postIds);
        final comments = await _db
            .from('post_comments')
            .select('post_id')
            .inFilter('post_id', postIds);
        final profs = await _db
            .from('profiles')
            .select('id, name, avatar_url')
            .inFilter('id', authorIds);

        final likeCount = <String, int>{};
        final likedByMe = <String>{};
        for (final l in likes) {
          final pid = l['post_id'].toString();
          likeCount[pid] = (likeCount[pid] ?? 0) + 1;
          if (l['user_id'].toString() == _uid) likedByMe.add(pid);
        }
        final commentCount = <String, int>{};
        for (final c in comments) {
          final pid = c['post_id'].toString();
          commentCount[pid] = (commentCount[pid] ?? 0) + 1;
        }
        final pmap = <String, Map<String, dynamic>>{
          for (final p in profs) p['id'].toString(): Map<String, dynamic>.from(p),
        };
        for (final p in posts) {
          final pid = p['id'].toString();
          final author = pmap[p['author_id'].toString()];
          p['authorName'] = (author?['name'] ?? '—').toString();
          p['authorAvatar'] = author?['avatar_url'];
          p['likeCount'] = likeCount[pid] ?? 0;
          p['likedByMe'] = likedByMe.contains(pid);
          p['commentCount'] = commentCount[pid] ?? 0;
        }
      }

      if (!mounted) return;
      setState(() {
        _posts = posts;
        _following = following;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _posts = _posts ?? [];
        _error = e.toString();
      });
    }
  }

  Future<void> _toggleLike(Map<String, dynamic> p) async {
    final liked = p['likedByMe'] == true;
    final count = (p['likeCount'] as int?) ?? 0;
    setState(() {
      p['likedByMe'] = !liked;
      p['likeCount'] = liked ? (count > 0 ? count - 1 : 0) : count + 1;
    });
    try {
      if (liked) {
        await _db
            .from('post_likes')
            .delete()
            .eq('post_id', p['id'])
            .eq('user_id', _uid);
      } else {
        await _db
            .from('post_likes')
            .insert({'post_id': p['id'], 'user_id': _uid});
      }
    } on PostgrestException catch (e) {
      if (e.code == '23505') return;
      if (!mounted) return;
      setState(() {
        p['likedByMe'] = liked;
        p['likeCount'] = count;
      });
      _snack(e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        p['likedByMe'] = liked;
        p['likeCount'] = count;
      });
      _snack(e.toString());
    }
  }

  Future<void> _toggleFollow(String authorId) async {
    final isFollowing = _following.contains(authorId);
    setState(() {
      if (isFollowing) {
        _following.remove(authorId);
      } else {
        _following.add(authorId);
      }
    });
    try {
      if (isFollowing) {
        await _db
            .from('follows')
            .delete()
            .eq('follower_id', _uid)
            .eq('following_id', authorId);
      } else {
        await _db
            .from('follows')
            .insert({'follower_id': _uid, 'following_id': authorId});
      }
    } on PostgrestException catch (e) {
      if (e.code == '23505') return;
      if (!mounted) return;
      setState(() {
        if (isFollowing) {
          _following.add(authorId);
        } else {
          _following.remove(authorId);
        }
      });
      _snack(e.message);
    }
  }

  Future<void> _delete(Map<String, dynamic> p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.bg2,
        title: const Text('حذف پست'),
        content: const Text('این پست حذف شود؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('حذف', style: TextStyle(color: C.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _db.from('posts').delete().eq('id', p['id']);
      if (!mounted) return;
      setState(() => _posts?.remove(p));
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _newPost() async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _NewPostSheet(uid: _uid),
    );
    if (done == true) _load();
  }

  void _openComments(Map<String, dynamic> p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CommentsSheet(
        postId: p['id'],
        uid: _uid,
        onCountChanged: (n) {
          if (mounted) setState(() => p['commentCount'] = n);
        },
      ),
    );
  }

  Widget _filterChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('کاوش'),
            selected: _explore,
            onSelected: (_) {
              if (_explore) return;
              setState(() {
                _explore = true;
                _posts = null;
              });
              _load();
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('دنبال‌شده‌ها'),
            selected: !_explore,
            onSelected: (_) {
              if (!_explore) return;
              setState(() {
                _explore = false;
                _posts = null;
              });
              _load();
            },
          ),
        ],
      ),
    );
  }

  Widget _postCard(Map<String, dynamic> p) {
    final authorId = p['author_id'].toString();
    final mine = authorId == _uid;
    final liked = p['likedByMe'] == true;
    final mediaUrl = (p['media_url'] ?? '').toString();
    final content = (p['content'] ?? '').toString();
    final name = (p['authorName'] ?? '—').toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: EngixPanel(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _avatar(p['authorAvatar']?.toString(), name, 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(timeAgo(p['created_at']),
                          style: const TextStyle(color: C.muted, fontSize: 11)),
                    ],
                  ),
                ),
                if (!mine)
                  TextButton(
                    onPressed: () => _toggleFollow(authorId),
                    child: Text(
                      _following.contains(authorId) ? 'دنبال‌شده' : 'دنبال کردن',
                      style: TextStyle(
                        fontSize: 12,
                        color: _following.contains(authorId)
                            ? C.muted
                            : C.redLight,
                      ),
                    ),
                  )
                else
                  IconButton(
                    onPressed: () => _delete(p),
                    icon: const Icon(Icons.delete_outline,
                        size: 20, color: C.muted),
                  ),
              ],
            ),
            if (content.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(content, style: const TextStyle(height: 1.8)),
            ],
            if (mediaUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  mediaUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                InkWell(
                  onTap: () => _toggleLike(p),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    child: Row(
                      children: [
                        Icon(
                          liked ? Icons.favorite : Icons.favorite_border,
                          size: 20,
                          color: liked ? C.redLight : C.soft,
                        ),
                        const SizedBox(width: 6),
                        Text('${p['likeCount'] ?? 0}',
                            style: const TextStyle(color: C.soft)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: () => _openComments(p),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.mode_comment_outlined,
                            size: 20, color: C.soft),
                        const SizedBox(width: 6),
                        Text('${p['commentCount'] ?? 0}',
                            style: const TextStyle(color: C.soft)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final posts = _posts;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: C.red,
        foregroundColor: Colors.white,
        onPressed: _newPost,
        child: const Icon(Icons.edit),
      ),
      body: Column(
        children: [
          _filterChips(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: posts == null
                  ? const Center(child: CircularProgressIndicator())
                  : (posts.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(
                              height: 320,
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    _error != null
                                        ? 'خطا در بارگذاری:\n$_error'
                                        : (_explore
                                            ? 'هنوز پستی منتشر نشده است.'
                                            : 'هنوز کسی را دنبال نکرده‌اید.\nاز بخش «کاوش» افراد را دنبال کنید.'),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: C.muted, height: 1.8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                          itemCount: posts.length,
                          itemBuilder: (_, i) => _postCard(posts[i]),
                        )),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewPostSheet extends StatefulWidget {
  final String uid;
  const _NewPostSheet({required this.uid});

  @override
  State<_NewPostSheet> createState() => _NewPostSheetState();
}

class _NewPostSheetState extends State<_NewPostSheet> {
  final _text = TextEditingController();
  bool _busy = false;
  String _error = '';

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final t = _text.text.trim();
    if (t.isEmpty) {
      setState(() => _error = 'متن پست خالی است.');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await Supabase.instance.client.from('posts').insert({
        'author_id': widget.uid,
        'type': 'post',
        'content': t,
        'media': [],
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('پست جدید',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          TextField(
            controller: _text,
            minLines: 4,
            maxLines: 8,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'چه خبر؟'),
          ),
          ErrorText(_error),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? '...' : 'انتشار'),
          ),
        ],
      ),
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  final dynamic postId;
  final String uid;
  final void Function(int) onCountChanged;
  const _CommentsSheet({
    required this.postId,
    required this.uid,
    required this.onCountChanged,
  });

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  SupabaseClient get _db => Supabase.instance.client;
  final _input = TextEditingController();
  List<Map<String, dynamic>>? _comments;
  bool _sending = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await _db
          .from('post_comments')
          .select()
          .eq('post_id', widget.postId)
          .order('created_at', ascending: true);
      final rows = List<Map<String, dynamic>>.from(data);
      final ids = rows.map((c) => c['author_id']).toSet().toList();
      final names = <String, String>{};
      if (ids.isNotEmpty) {
        final ps = await _db
            .from('profiles')
            .select('id, name')
            .inFilter('id', ids);
        for (final p in ps) {
          names[p['id'].toString()] = (p['name'] ?? '—').toString();
        }
      }
      for (final c in rows) {
        c['authorName'] = names[c['author_id'].toString()] ?? '—';
      }
      if (!mounted) return;
      setState(() {
        _comments = rows;
        _error = '';
      });
      widget.onCountChanged(rows.length);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _comments = _comments ?? [];
        _error = e.toString();
      });
    }
  }

  Future<void> _send() async {
    final t = _input.text.trim();
    if (t.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _db.from('post_comments').insert({
        'post_id': widget.postId,
        'author_id': widget.uid,
        'text': t,
      });
      _input.clear();
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> c) async {
    try {
      await _db.from('post_comments').delete().eq('id', c['id']);
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final comments = _comments;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text('نظرات',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            Expanded(
              child: comments == null
                  ? const Center(child: CircularProgressIndicator())
                  : (comments.isEmpty
                      ? const Center(
                          child: Text('هنوز نظری ثبت نشده است.',
                              style: TextStyle(color: C.muted)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: comments.length,
                          itemBuilder: (_, i) {
                            final c = comments[i];
                            final mine = c['author_id'].toString() == widget.uid;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _avatar(
                                      null, (c['authorName'] ?? '').toString(), 16),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              (c['authorName'] ?? '').toString(),
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(timeAgo(c['created_at']),
                                                style: const TextStyle(
                                                    color: C.muted,
                                                    fontSize: 10.5)),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text((c['text'] ?? '').toString(),
                                            style: const TextStyle(height: 1.7)),
                                      ],
                                    ),
                                  ),
                                  if (mine)
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _delete(c),
                                      icon: const Icon(Icons.delete_outline,
                                          size: 18, color: C.muted),
                                    ),
                                ],
                              ),
                            );
                          },
                        )),
            ),
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ErrorText(_error),
              ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        decoration:
                            const InputDecoration(hintText: 'نظر شما...'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: C.red,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _sending ? null : _send,
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

