import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/api.dart';
import '../core/theme.dart';
import 'chat_thread_screen.dart';

class MessengerTab extends StatefulWidget {
  final Map<String, dynamic> profile;
  const MessengerTab({super.key, required this.profile});

  @override
  State<MessengerTab> createState() => _MessengerTabState();
}

class _MessengerTabState extends State<MessengerTab> {
  SupabaseClient get _db => Supabase.instance.client;
  String get _uid => widget.profile['id'].toString();

  List<Map<String, dynamic>>? _chats;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await _db
          .from('conversation_members')
          .select(
              'is_muted, is_pinned, is_archived, role, conversations(id, type, name, avatar_url, created_at)')
          .eq('user_id', _uid);

      final chats = <Map<String, dynamic>>[];
      for (final row in rows) {
        final c = row['conversations'];
        if (c is Map && row['is_archived'] != true) {
          final m = Map<String, dynamic>.from(c);
          m['is_pinned'] = row['is_pinned'] == true;
          m['is_muted'] = row['is_muted'] == true;
          chats.add(m);
        }
      }

      final directIds = chats
          .where((c) => c['type'] == 'direct')
          .map((c) => c['id'])
          .toList();
      final others = <String, Map<String, dynamic>>{};
      if (directIds.isNotEmpty) {
        final od = await _db
            .from('conversation_members')
            .select('conversation_id, user_id')
            .inFilter('conversation_id', directIds)
            .neq('user_id', _uid);
        final userIds = od.map((o) => o['user_id']).toSet().toList();
        final profs = <String, Map<String, dynamic>>{};
        if (userIds.isNotEmpty) {
          final ps = await _db
              .from('profiles')
              .select('id, name, avatar_url')
              .inFilter('id', userIds);
          for (final p in ps) {
            profs[p['id'].toString()] = Map<String, dynamic>.from(p);
          }
        }
        for (final o in od) {
          final p = profs[o['user_id'].toString()];
          if (p != null) others[o['conversation_id'].toString()] = p;
        }
      }
      
      await Future.wait(chats.map((c) async {
        try {
          final last = await _db
              .from('messages')
              .select('content, type, created_at, is_deleted')
              .eq('conversation_id', c['id'])
              .order('created_at', ascending: false)
              .limit(1);
          if (last.isNotEmpty) c['last'] = last.first;
        } catch (_) {}
        if (c['type'] == 'direct') {
          final o = others[c['id'].toString()];
          c['title'] = (o?['name'] ?? 'گفتگو').toString();
          c['avatar'] = o?['avatar_url'];
        } else {
          c['title'] = (c['name'] ?? 'گروه').toString();
          c['avatar'] = c['avatar_url'];
        }
      }));

      String stamp(Map<String, dynamic> c) {
        final last = c['last'];
        if (last is Map && last['created_at'] != null) {
          return last['created_at'].toString();
        }
        return (c['created_at'] ?? '').toString();
      }

      chats.sort((a, b) {
        if (a['is_pinned'] != b['is_pinned']) {
          return a['is_pinned'] == true ? -1 : 1;
        }
        return stamp(b).compareTo(stamp(a));
      });

      if (!mounted) return;
      setState(() {
        _chats = chats;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chats = _chats ?? [];
        _error = e.toString();
      });
    }
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  void _openThread(String id, String title) {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => ChatThreadScreen(
            profile: widget.profile,
            conversationId: id,
            title: title,
          ),
        ))
        .then((_) => _load());
  }

  Future<String?> _userIdByPhone(String raw) async {
    final ten = normalizePhone(raw);
    if (ten.length < 10) return null;
    final r = await _db
        .from('profiles')
        .select('id')
        .inFilter('phone', ['0$ten', ten, '+98$ten', '98$ten'])
        .limit(1)
        .maybeSingle();
    return r?['id']?.toString();
  }

  Future<String?> _askText(String title, String label,
      {bool phone = false, int lines = 1}) async {
    final ctl = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.bg2,
        title: Text(title),
        content: TextField(
          controller: ctl,
          autofocus: true,
          minLines: lines,
          maxLines: lines,
          keyboardType: phone ? TextInputType.phone : TextInputType.text,
          textDirection: phone ? TextDirection.ltr : null,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(ctl.text),
            child: const Text('تایید'),
          ),
        ],
      ),
    );
    ctl.dispose();
    if (res == null || res.trim().isEmpty) return null;
    return res.trim();
  }

  Future<void> _newDirect() async {
    final phone = await _askText('گفتگوی جدید', 'شماره موبایل', phone: true);
    if (phone == null) return;
    try {
      final otherId = await _userIdByPhone(phone);
      if (otherId == null) {
        _snack('کاربری با این شماره پیدا نشد.');
        return;
      }
      if (otherId == _uid) {
        _snack('این شماره خودتان است.');
        return;
      }
      final other = await _db
          .from('profiles')
          .select('name')
          .eq('id', otherId)
          .maybeSingle();
      final convId = await _db.rpc(
        'get_or_create_direct_conversation',
        params: {'other_user_id': otherId},
      );
      if (!mounted) return;
      _openThread(convId.toString(), (other?['name'] ?? 'گفتگو').toString());
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _newGroup() async {
    final name = await _askText('گروه جدید', 'نام گروه');
    if (name == null) return;
    final phones = await _askText(
      'افزودن عضو (اختیاری)',
      'شماره‌ها با ویرگول جدا شوند',
      lines: 3,
    );
    try {
      final convId = 'group_${DateTime.now().microsecondsSinceEpoch}_$_uid';
      await _db.from('conversations').insert({
        'id': convId,
        'type': 'group',
        'name': name,
        'created_by': _uid,
      });
      final rows = <Map<String, dynamic>>[
        {'conversation_id': convId, 'user_id': _uid, 'role': 'owner'},
      ];
      var notFound = 0;
      if (phones != null) {
        final seen = <String>{_uid};
        for (final p in phones.split(RegExp(r'[,\n،]'))) {
          if (p.trim().isEmpty) continue;
          final id = await _userIdByPhone(p);
          if (id == null) {
            notFound++;
          } else if (seen.add(id)) {
            rows.add({
              'conversation_id': convId,
              'user_id': id,
              'role': 'member',
            });
          }
        }
      }
      await _db.from('conversation_members').insert(rows);
      if (notFound > 0) _snack('$notFound شماره پیدا نشد.');
      if (!mounted) return;
      _openThread(convId, name);
    } catch (e) {
      _snack(e.toString());
    }
  }

  void _showNewMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: C.bg2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_add_alt_1, color: C.redLight),
              title: const Text('گفتگوی خصوصی'),
              onTap: () {
                Navigator.of(ctx).pop();
                _newDirect();
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_add, color: C.redLight),
              title: const Text('گروه جدید'),
              onTap: () {
                Navigator.of(ctx).pop();
                _newGroup();
              },
            ),
          ],
        ),
      ),
    );
  }

  String _preview(Map<String, dynamic> c) {
    final last = c['last'];
    if (last is! Map) return 'بدون پیام';
    if (last['is_deleted'] == true) return 'پیام حذف شد';
    switch ((last['type'] ?? 'text').toString()) {
      case 'image':
        return 'تصویر';
      case 'pdf':
        return 'فایل PDF';
      case 'word':
        return 'فایل Word';
      case 'voice':
        return 'پیام صوتی';
      default:
        return (last['content'] ?? '').toString();
    }
  }

  String _time(Map<String, dynamic> c) {
    final last = c['last'];
    if (last is! Map || last['created_at'] == null) return '';
    final d = DateTime.tryParse(last['created_at'].toString())?.toLocal();
    if (d == null) return '';
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Widget _avatar(Map<String, dynamic> c) {
    final url = (c['avatar'] ?? '').toString();
    final title = (c['title'] ?? '').toString();
    return CircleAvatar(
      radius: 24,
      backgroundColor: C.bg3,
      backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
      child: url.isEmpty
          ? Text(
              title.isEmpty ? '?' : title.substring(0, 1),
              style: const TextStyle(color: C.redLight, fontWeight: FontWeight.w700),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = _chats;
    List<Map<String, dynamic>> shown = [];
    if (all != null) {
      shown = all
          .where((c) =>
              _query.isEmpty ||
              (c['title'] ?? '').toString().contains(_query))
          .toList();
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: C.red,
        foregroundColor: Colors.white,
        onPressed: _showNewMenu,
        child: const Icon(Icons.edit),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: const InputDecoration(
                hintText: 'جستجوی گفتگو...',
                prefixIcon: Icon(Icons.search, color: C.muted),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: all == null
                  ? const Center(child: CircularProgressIndicator())
                  : (shown.isEmpty
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
                                        : (_query.isNotEmpty
                                            ? 'گفتگویی پیدا نشد.'
                                            : 'هنوز گفتگویی ندارید.\nبا دکمه پایین یکی شروع کنید.'),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: C.muted, height: 1.8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.only(bottom: 90),
                          itemCount: shown.length,
                          separatorBuilder: (_, __) => const Divider(
                            height: 1,
                            color: Color(0x14FFFFFF),
                          ),
                          itemBuilder: (_, i) {
                            final c = shown[i];
                            return ListTile(
                              onTap: () => _openThread(
                                c['id'].toString(),
                                (c['title'] ?? '').toString(),
                              ),
                              leading: _avatar(c),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      (c['title'] ?? '').toString(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  if (c['is_pinned'] == true)
                                    const Icon(Icons.push_pin,
                                        size: 14, color: C.muted),
                                  if (c['is_muted'] == true)
                                    const Icon(Icons.volume_off,
                                        size: 14, color: C.muted),
                                ],
                              ),
                              subtitle: Text(
                                _preview(c),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: C.soft),
                              ),
                              trailing: Text(
                                _time(c),
                                style: const TextStyle(
                                    color: C.muted, fontSize: 11),
                              ),
                            );
                          },
                        )),
            ),
          ),
        ],
      ),
    );
  }
}
