import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme.dart';
import '../chat_thread_screen.dart';
import 'profile_card.dart';
import 'profile_common.dart';

SupabaseClient get _db => Supabase.instance.client;

Future<void> _openChat(BuildContext context, Map<String, dynamic> viewer, Map<String, dynamic> other) async {
  try {
    final conv = await _db.rpc('get_or_create_direct_conversation',
        params: {'other_user_id': other['id'].toString()});
    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatThreadScreen(
        profile: viewer,
        conversationId: conv.toString(),
        title: (other['name'] ?? 'گفتگو').toString(),
      ),
    ));
  } catch (e) {
    if (context.mounted) toast(context, 'خطا در شروع گفتگو: $e');
  }
}

// ------------------------------------------------------------ پروفایل عمومی

class PublicProfileScreen extends StatefulWidget {
  final Map<String, dynamic> viewer;
  final String userId;
  final Map<String, dynamic>? preloaded;
  const PublicProfileScreen({
    super.key,
    required this.viewer,
    required this.userId,
    this.preloaded,
  });

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  Map<String, dynamic>? _p;
  int? _followers;
  int? _following;
  int? _posts;
  bool _isFollowing = false;
  bool _isBlocked = false;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  String get _me => widget.viewer['id'].toString();
  bool get _isOwn => widget.userId == _me;

  @override
  void initState() {
    super.initState();
    _p = widget.preloaded;
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await _db
          .from('profiles')
          .select('*, active_role:roles!active_role_id(label)')
          .eq('id', widget.userId)
          .maybeSingle();
      final a = await _db.from('follows').select('follower_id').eq('following_id', widget.userId);
      final b = await _db.from('follows').select('following_id').eq('follower_id', widget.userId);
      final c = await _db.from('posts').select('id').eq('author_id', widget.userId);
      var f = false;
      var bl = false;
      if (!_isOwn) {
        final fr = await _db
            .from('follows')
            .select('follower_id')
            .eq('follower_id', _me)
            .eq('following_id', widget.userId)
            .maybeSingle();
        final br = await _db
            .from('blocks')
            .select('blocker_id')
            .eq('blocker_id', _me)
            .eq('blocked_id', widget.userId)
            .maybeSingle();
        f = fr != null;
        bl = br != null;
      }
      if (!mounted) return;
      setState(() {
        if (p != null) _p = Map<String, dynamic>.from(p);
        _followers = a.length;
        _following = b.length;
        _posts = c.length;
        _isFollowing = f;
        _isBlocked = bl;
        _loading = false;
        _error = p == null && _p == null ? 'کاربر پیدا نشد.' : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'خطا در دریافت پروفایل: $e';
      });
    }
  }

  Future<void> _toggleFollow() async {
    if (_busy) return;
    final next = !_isFollowing;
    setState(() {
      _busy = true;
      _isFollowing = next;
      _followers = (_followers ?? 0) + (next ? 1 : -1);
    });
    try {
      if (next) {
        await _db.from('follows').insert({'follower_id': _me, 'following_id': widget.userId});
      } else {
        await _db
            .from('follows')
            .delete()
            .eq('follower_id', _me)
            .eq('following_id', widget.userId);
      }
    } on PostgrestException catch (e) {
      if (e.code != '23505') {
        if (mounted) {
          setState(() {
            _isFollowing = !next;
            _followers = (_followers ?? 0) + (next ? -1 : 1);
          });
          toast(context, e.message);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFollowing = !next;
          _followers = (_followers ?? 0) + (next ? -1 : 1);
        });
        toast(context, 'خطا: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleBlock() async {
    if (_busy) return;
    final name = (_p?['name'] ?? 'این کاربر').toString();
    if (!_isBlocked) {
      final ok = await pfConfirm(
          context, '$name مسدود شود؟ دیگر پست‌ها و پیام‌های او را نخواهید دید.',
          yes: 'مسدود کردن');
      if (!ok) return;
    }
    setState(() => _busy = true);
    try {
      if (_isBlocked) {
        await _db.from('blocks').delete().eq('blocker_id', _me).eq('blocked_id', widget.userId);
        if (mounted) setState(() => _isBlocked = false);
      } else {
        try {
          await _db.from('blocks').insert({'blocker_id': _me, 'blocked_id': widget.userId});
        } on PostgrestException catch (e) {
          if (e.code != '23505') rethrow;
        }
        await _db.from('follows').delete().eq('follower_id', _me).eq('following_id', widget.userId);
        await _db.from('follows').delete().eq('follower_id', widget.userId).eq('following_id', _me);
        if (mounted) {
          setState(() {
            _isBlocked = true;
            _isFollowing = false;
          });
        }
      }
      _load();
    } catch (e) {
      if (mounted) toast(context, 'خطا: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openList(String mode) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FollowListScreen(viewer: widget.viewer, userId: widget.userId, mode: mode),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return PfPage(
      title: (p?['name'] ?? 'پروفایل').toString(),
      child: _loading && p == null
          ? const PfLoading()
          : p == null
              ? Center(child: Text(_error ?? 'کاربر پیدا نشد.', style: const TextStyle(color: C.muted)))
              : RefreshIndicator(
                  color: C.red,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      ProfileCardView(
                        p: p,
                        followers: _followers,
                        following: _following,
                        posts: _posts,
                        onFollowers: () => _openList('followers'),
                        onFollowing: () => _openList('following'),
                      ),
                      if (!_isOwn) ...[
                        Row(children: [
                          Expanded(
                            child: _isFollowing
                                ? OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                                    onPressed: _busy || _isBlocked ? null : _toggleFollow,
                                    icon: const Icon(Icons.person_remove_outlined, size: 18),
                                    label: const Text('لغو دنبال کردن'),
                                  )
                                : FilledButton.icon(
                                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                                    onPressed: _busy || _isBlocked ? null : _toggleFollow,
                                    icon: const Icon(Icons.person_add_alt_1, size: 18),
                                    label: const Text('دنبال کردن'),
                                  ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                              onPressed: _isBlocked ? null : () => _openChat(context, widget.viewer, p),
                              icon: const Icon(Icons.chat_bubble_outline, size: 18),
                              label: const Text('پیام'),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(46),
                            foregroundColor: _isBlocked ? const Color(0xFF22C55E) : C.danger,
                          ),
                          onPressed: _busy ? null : _toggleBlock,
                          icon: Icon(_isBlocked ? Icons.shield_outlined : Icons.block, size: 18),
                          label: Text(_isBlocked ? 'رفع مسدودیت' : 'مسدود کردن'),
                        ),
                      ],
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
    );
  }
}

// ------------------------------------------------------------ جستجوی مهندس

class SearchEngineerScreen extends StatefulWidget {
  final Map<String, dynamic> viewer;
  const SearchEngineerScreen({super.key, required this.viewer});

  @override
  State<SearchEngineerScreen> createState() => _SearchEngineerScreenState();
}

class _SearchEngineerScreenState extends State<SearchEngineerScreen> {
  final _ctl = TextEditingController();
  List<Map<String, dynamic>>? _results;
  bool _busy = false;
  String _msg = '';

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _ctl.text.trim().replaceAll('@', '');
    if (q.isEmpty) {
      setState(() => _msg = 'کد نظام مهندسی، آیدی یا نام را وارد کنید.');
      return;
    }
    setState(() {
      _busy = true;
      _msg = '';
      _results = null;
    });
    try {
      final byCode = await _db.from('profiles').select('id, name, username, code, field, avatar_url').eq('code', q);
      final byUser = await _db
          .from('profiles')
          .select('id, name, username, code, field, avatar_url')
          .eq('username', q.toLowerCase());
      final byName = await _db
          .from('profiles')
          .select('id, name, username, code, field, avatar_url')
          .ilike('name', '%$q%')
          .limit(20);
      final map = <String, Map<String, dynamic>>{};
      for (final r in [...byCode, ...byUser, ...byName]) {
        map[r['id'].toString()] = Map<String, dynamic>.from(r);
      }
      if (!mounted) return;
      setState(() {
        _results = map.values.toList();
        _msg = map.isEmpty ? 'مهندسی با این مشخصات پیدا نشد.' : '';
      });
    } catch (e) {
      if (mounted) setState(() => _msg = 'خطا در جستجو: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PfPage(
      title: 'جستجوی مهندس',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const PfTitle('جستجوی مهندس',
              sub: 'با کد نظام مهندسی، آیدی یا نام، پروفایل عمومی یک مهندس را ببینید.'),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _ctl,
                onSubmitted: (_) => _search(),
                decoration: const InputDecoration(hintText: 'کد، آیدی یا نام'),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(80, 50)),
              onPressed: _busy ? null : _search,
              child: Text(_busy ? '...' : 'جستجو'),
            ),
          ]),
          const SizedBox(height: 14),
          if (_msg.isNotEmpty)
            Text(_msg, style: const TextStyle(color: C.soft, fontSize: 12.5)),
          if (_results != null)
            for (final r in _results!)
              PfCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PublicProfileScreen(
                    viewer: widget.viewer,
                    userId: r['id'].toString(),
                  ),
                )),
                child: Row(children: [
                  PfAvatar(url: r['avatar_url']?.toString(), name: (r['name'] ?? '').toString(), size: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text((r['name'] ?? '').toString(),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                        [
                          if ((r['username'] ?? '').toString().isNotEmpty) '@${r['username']}',
                          if ((r['code'] ?? '').toString().isNotEmpty) 'کد: ${r['code']}',
                          if ((r['field'] ?? '').toString().isNotEmpty) r['field'].toString(),
                        ].join(' · '),
                        style: const TextStyle(color: C.muted, fontSize: 11.5),
                      ),
                    ]),
                  ),
                  const Icon(Icons.chevron_left, color: C.muted),
                ]),
              ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------- دنبال‌کنندگان/شونده

class FollowListScreen extends StatefulWidget {
  final Map<String, dynamic> viewer;
  final String userId;
  final String mode; // followers | following
  const FollowListScreen({
    super.key,
    required this.viewer,
    required this.userId,
    required this.mode,
  });

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  List<Map<String, dynamic>>? _list;
  String get _me => widget.viewer['id'].toString();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final isFollowers = widget.mode == 'followers';
      final rows = await _db
          .from('follows')
          .select(isFollowers ? 'follower_id' : 'following_id')
          .eq(isFollowers ? 'following_id' : 'follower_id', widget.userId);
      final ids = rows
          .map((r) => (isFollowers ? r['follower_id'] : r['following_id']).toString())
          .toSet()
          .toList();
      if (ids.isEmpty) {
        if (mounted) setState(() => _list = []);
        return;
      }
      final profs = await _db
          .from('profiles')
          .select('id, name, code, username, avatar_url')
          .inFilter('id', ids);
      final myFollows =
          await _db.from('follows').select('following_id').eq('follower_id', _me);
      final myBlocks = await _db.from('blocks').select('blocked_id').eq('blocker_id', _me);
      final followed = {for (final r in myFollows) r['following_id'].toString()};
      final blocked = {for (final r in myBlocks) r['blocked_id'].toString()};
      final list = [
        for (final p in profs)
          {
            ...Map<String, dynamic>.from(p),
            'isFollowedByMe': followed.contains(p['id'].toString()),
            'isBlockedByMe': blocked.contains(p['id'].toString()),
          }
      ];
      if (mounted) setState(() => _list = list);
    } catch (_) {
      if (mounted) setState(() => _list = []);
    }
  }

  Future<void> _toggleFollow(Map<String, dynamic> person) async {
    final id = person['id'].toString();
    final was = person['isFollowedByMe'] == true;
    setState(() => person['isFollowedByMe'] = !was);
    try {
      if (was) {
        await _db.from('follows').delete().eq('follower_id', _me).eq('following_id', id);
      } else {
        await _db.from('follows').insert({'follower_id': _me, 'following_id': id});
      }
    } on PostgrestException catch (e) {
      if (e.code != '23505') _load();
    } catch (_) {
      _load();
    }
  }

  Future<void> _toggleBlock(Map<String, dynamic> person) async {
    final id = person['id'].toString();
    final was = person['isBlockedByMe'] == true;
    if (!was) {
      final ok = await pfConfirm(
          context, '${person['name']} مسدود شود؟ دیگر پست‌ها و پیام‌های او را نخواهید دید.',
          yes: 'مسدود کردن');
      if (!ok) return;
    }
    setState(() {
      person['isBlockedByMe'] = !was;
      if (!was) person['isFollowedByMe'] = false;
    });
    try {
      if (was) {
        await _db.from('blocks').delete().eq('blocker_id', _me).eq('blocked_id', id);
      } else {
        try {
          await _db.from('blocks').insert({'blocker_id': _me, 'blocked_id': id});
        } on PostgrestException catch (e) {
          if (e.code != '23505') rethrow;
        }
        await _db.from('follows').delete().eq('follower_id', _me).eq('following_id', id);
        await _db.from('follows').delete().eq('follower_id', id).eq('following_id', _me);
      }
    } catch (_) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    return PfPage(
      title: widget.mode == 'followers' ? 'دنبال‌کنندگان' : 'دنبال‌شونده‌ها',
      child: list == null
          ? const PfLoading()
          : list.isEmpty
              ? const Center(child: Text('موردی وجود ندارد.', style: TextStyle(color: C.muted)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final person in list)
                      PfCard(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(children: [
                          GestureDetector(
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => PublicProfileScreen(
                                viewer: widget.viewer,
                                userId: person['id'].toString(),
                              ),
                            )),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              PfAvatar(
                                  url: person['avatar_url']?.toString(),
                                  name: (person['name'] ?? '').toString(),
                                  size: 40),
                              const SizedBox(width: 10),
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                    maxWidth: MediaQuery.of(context).size.width * 0.38),
                                child: Text((person['name'] ?? '').toString(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                              ),
                            ]),
                          ),
                          const Spacer(),
                          if (person['id'].toString() != _me) ...[
                            IconButton(
                              tooltip: person['isFollowedByMe'] == true ? 'لغو دنبال کردن' : 'دنبال کردن',
                              onPressed: person['isBlockedByMe'] == true ? null : () => _toggleFollow(person),
                              icon: Icon(
                                person['isFollowedByMe'] == true
                                    ? Icons.person_remove_outlined
                                    : Icons.person_add_alt_1,
                                size: 20,
                              ),
                            ),
                            IconButton(
                              tooltip: person['isBlockedByMe'] == true ? 'رفع مسدودیت' : 'مسدود کردن',
                              onPressed: () => _toggleBlock(person),
                              icon: Icon(
                                person['isBlockedByMe'] == true ? Icons.shield_outlined : Icons.block,
                                size: 20,
                                color: person['isBlockedByMe'] == true
                                    ? const Color(0xFF22C55E)
                                    : C.danger,
                              ),
                            ),
                          ],
                        ]),
                      ),
                  ],
                ),
    );
  }
}
