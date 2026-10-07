import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/chat_media.dart';
import '../core/config.dart';
import '../core/project_media.dart' show PickedMedia;
import '../core/push.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'chat/chat_info_screen.dart';
import 'chat/chat_input.dart';
import 'chat/chat_widgets.dart';

class ChatThreadScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  final String conversationId;
  final String title;
  const ChatThreadScreen({
    super.key,
    required this.profile,
    required this.conversationId,
    required this.title,
  });

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  static const _pageSize = 40;

  SupabaseClient get _db => Supabase.instance.client;
  String get _uid => widget.profile['id'].toString();

  final List<Map<String, dynamic>> _messages = [];
  final Map<String, String> _names = {};
  final Map<String, Set<String>> _reads = {};
  final _scroll = ScrollController();
  RealtimeChannel? _channel;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  final Set<String> _readIds = {};

  late String _title = widget.title;
  String _type = 'direct';
  String _myRole = 'member';
  int _memberCount = 2;
  bool _isProject = false;
  Map<String, dynamic>? _replyTo;

  bool get _canPost =>
      _type != 'channel' || _myRole == 'owner' || _myRole == 'admin';

  @override
  void initState() {
    super.initState();
    Push.activeConversation = widget.conversationId;
    _scroll.addListener(() {
      if (_scroll.hasClients &&
          _scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
        _loadMore();
      }
    });
    _loadMeta();
    _load();
    _subscribe();
  }

  @override
  void dispose() {
    if (Push.activeConversation == widget.conversationId) {
      Push.activeConversation = null;
    }
    final ch = _channel;
    if (ch != null) _db.removeChannel(ch);
    _scroll.dispose();
    super.dispose();
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _loadMeta() async {
    try {
      final conv = await _db
          .from('conversations')
          .select()
          .eq('id', widget.conversationId)
          .maybeSingle();
      final members = await _db
          .from('conversation_members')
          .select('user_id, role')
          .eq('conversation_id', widget.conversationId);
      if (conv == null) return;
      final type = (conv['type'] ?? 'direct').toString();
      var role = 'member';
      String? otherId;
      for (final r in members) {
        if (r['user_id'].toString() == _uid) {
          role = (r['role'] ?? 'member').toString();
        } else {
          otherId ??= r['user_id'].toString();
        }
      }
      var title = (conv['name'] ?? '').toString();
      if (type == 'direct' && otherId != null) {
        final p = await _db
            .from('profiles')
            .select('name')
            .eq('id', otherId)
            .maybeSingle();
        title = (p?['name'] ?? 'گفتگو').toString();
      }
      if (title.isEmpty) title = type == 'channel' ? 'کانال' : 'گروه';
      if (!mounted) return;
      setState(() {
        _type = type;
        _myRole = role;
        _memberCount = members.length;
        _title = title;
        _isProject = conv['project_id'] != null ||
            widget.conversationId.startsWith('proj_');
      });
    } catch (_) {}
  }

  Future<void> _fetchNames(Iterable<dynamic> ids) async {
    final missing = ids
        .map((e) => e.toString())
        .where((id) => !_names.containsKey(id))
        .toSet()
        .toList();
    if (missing.isEmpty) return;
    try {
      final ps =
          await _db.from('profiles').select('id, name').inFilter('id', missing);
      for (final p in ps) {
        _names[p['id'].toString()] = (p['name'] ?? 'کاربر').toString();
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      final data = await _db
          .from('messages')
          .select()
          .eq('conversation_id', widget.conversationId)
          .order('created_at', ascending: false)
          .limit(_pageSize);
      final list = List<Map<String, dynamic>>.from(data);
      await _fetchNames(list.map((m) => m['sender_id']));
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(list);
        _hasMore = list.length >= _pageSize;
        _loading = false;
        _error = null;
      });
      _markRead();
      _loadReads(list);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _messages.isEmpty) return;
    _loadingMore = true;
    try {
      final oldest = _messages.last['created_at'].toString();
      final data = await _db
          .from('messages')
          .select()
          .eq('conversation_id', widget.conversationId)
          .lt('created_at', oldest)
          .order('created_at', ascending: false)
          .limit(_pageSize);
      final list = List<Map<String, dynamic>>.from(data);
      await _fetchNames(list.map((m) => m['sender_id']));
      if (!mounted) return;
      setState(() {
        _messages.addAll(list);
        _hasMore = list.length >= _pageSize;
      });
      _loadReads(list);
    } catch (_) {
    } finally {
      _loadingMore = false;
    }
  }

  Future<void> _loadReads(List<Map<String, dynamic>> list) async {
    try {
      final mine = list
          .where((m) => m['sender_id'].toString() == _uid)
          .map((m) => m['id'].toString())
          .toList();
      if (mine.isEmpty) return;
      final rows = await _db
          .from('message_reads')
          .select('message_id, user_id')
          .inFilter('message_id', mine)
          .neq('user_id', _uid);
      if (!mounted) return;
      setState(() {
        for (final r in rows) {
          _reads
              .putIfAbsent(r['message_id'].toString(), () => <String>{})
              .add(r['user_id'].toString());
        }
      });
    } catch (_) {}
  }

  bool _isRead(Map<String, dynamic> m) {
    final got = _reads[m['id'].toString()]?.length ?? 0;
    final needed = (_type == 'direct' || _type == 'channel')
        ? 1
        : (_memberCount - 1).clamp(1, 100000);
    return got >= needed;
  }

  void _subscribe() {
    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'conversation_id',
      value: widget.conversationId,
    );
    _channel = _db
        .channel('thread:${widget.conversationId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: filter,
          callback: (payload) async {
            final rec = Map<String, dynamic>.from(payload.newRecord);
            await _fetchNames([rec['sender_id']]);
            if (!mounted) return;
            final i = _messages
                .indexWhere((m) => m['id'].toString() == rec['id'].toString());
            if (i >= 0) {
              setState(() => _messages[i] = rec);
              return;
            }
            setState(() => _messages.insert(0, rec));
            if (rec['sender_id'].toString() != _uid) _markRead();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          filter: filter,
          callback: (payload) {
            final rec = Map<String, dynamic>.from(payload.newRecord);
            if (!mounted) return;
            final i = _messages
                .indexWhere((m) => m['id'].toString() == rec['id'].toString());
            if (i >= 0) setState(() => _messages[i] = rec);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final id = payload.oldRecord['id']?.toString();
            if (id == null || !mounted) return;
            setState(() => _messages.removeWhere((m) => m['id'].toString() == id));
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'message_reads',
          callback: (p) => _onReadRow(p.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'message_reads',
          callback: (p) => _onReadRow(p.newRecord),
        )
        .subscribe();
  }

  void _onReadRow(Map<String, dynamic> rec) {
    final mid = rec['message_id']?.toString();
    final uid = rec['user_id']?.toString();
    if (mid == null || uid == null || uid == _uid || !mounted) return;
    final isMine = _messages.any(
        (m) => m['id'].toString() == mid && m['sender_id'].toString() == _uid);
    if (!isMine) return;
    setState(() => _reads.putIfAbsent(mid, () => <String>{}).add(uid));
  }

  Future<void> _markRead() async {
    try {
      final ids = _messages
          .where((m) =>
              m['sender_id'].toString() != _uid &&
              m['_pending'] != true &&
              !_readIds.contains(m['id'].toString()))
          .map((m) => m['id'])
          .toList();
      if (ids.isEmpty) return;
      final now = DateTime.now().toUtc().toIso8601String();
      await _db.from('message_reads').upsert([
        for (final id in ids) {'message_id': id, 'user_id': _uid, 'read_at': now}
      ], onConflict: 'message_id,user_id');
      _readIds.addAll(ids.map((e) => e.toString()));
    } catch (_) {}
  }

  Future<void> _pushMessage(String text) async {
    try {
      final token = _db.auth.currentSession?.accessToken;
      if (token == null) return;
      await http.post(
        Uri.parse('${Config.apiBase}/api/notifications/send-message-push'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'conversationId': widget.conversationId,
          'senderId': _uid,
          'text': text,
        }),
      );
    } catch (_) {}
  }

  Map<String, dynamic> _addLocal(
    String id,
    String type, {
    String content = '',
    String? fileUrl,
    Map<String, dynamic>? meta,
  }) {
    final local = <String, dynamic>{
      'id': id,
      'conversation_id': widget.conversationId,
      'sender_id': _uid,
      'type': type,
      'content': content,
      'file_url': fileUrl,
      'file_meta': meta,
      'reply_to': _replyTo?['id'],
      'is_deleted': false,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      '_pending': true,
    };
    setState(() {
      _messages.insert(0, local);
      _replyTo = null;
    });
    if (_scroll.hasClients) {
      _scroll.animateTo(0,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
    return local;
  }

  void _replaceById(String id, Map<String, dynamic> row) {
    if (!mounted) return;
    final i = _messages.indexWhere((m) => m['id'].toString() == id);
    setState(() {
      if (i >= 0) {
        _messages[i] = row;
      } else {
        _messages.insert(0, row);
      }
    });
  }

  void _markFailed(String id) {
    if (!mounted) return;
    final i = _messages.indexWhere((m) => m['id'].toString() == id);
    if (i >= 0) {
      setState(() => _messages[i] = {..._messages[i], '_pending': false, '_failed': true});
    }
  }

  Future<void> _insert(Map<String, dynamic> local, {
    String? type,
    String? fileUrl,
    Map<String, dynamic>? meta,
  }) async {
    final id = local['id'].toString();
    try {
      final row = await _db
          .from('messages')
          .insert({
            'id': id,
            'conversation_id': widget.conversationId,
            'sender_id': _uid,
            'type': type ?? local['type'],
            'content': local['content'],
            'file_url': fileUrl ?? local['file_url'],
            'file_meta': meta ?? local['file_meta'],
            if (local['reply_to'] != null) 'reply_to': local['reply_to'],
          })
          .select()
          .single();
      _replaceById(id, Map<String, dynamic>.from(row));
      _pushMessage(messagePreview(
          (row['type'] ?? 'text').toString(), row['content']?.toString()));
    } catch (e) {
      _markFailed(id);
      _snack('ارسال نشد: ${_short(e)}');
    }
  }

  String _short(Object e) {
    if (e is PostgrestException) return e.message;
    final s = e.toString();
    return s.length > 120 ? s.substring(0, 120) : s;
  }

  Future<void> _sendText(String text) async {
    final local = _addLocal(newMessageId(), 'text', content: text);
    await _insert(local);
  }

  Future<void> _sendMedia(PickedMedia f, {int? durationSec}) async {
    final mime = chatMime(f.name, f.mime);
    final guess = chatTypeFromMime(mime);
    final local = _addLocal(newMessageId(), guess,
        meta: {'name': f.name, 'size': f.bytes.length});
    try {
      final up = await uploadChatFile(f, widget.conversationId,
          durationSec: durationSec);
      await _insert(local, type: up.type, fileUrl: up.url, meta: up.meta);
    } catch (e) {
      _markFailed(local['id'].toString());
      _snack(_short(e).replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _sendLocation() async {
    try {
      final pos = await currentChatPosition();
      final local = _addLocal(newMessageId(), 'location',
          meta: {'lat': pos.latitude, 'lng': pos.longitude});
      await _insert(local);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _onAttach(String kind) async {
    try {
      switch (kind) {
        case 'gallery':
          final f = await pickChatImage();
          if (f != null) await _sendMedia(f);
          break;
        case 'camera':
          final f = await pickChatImage(camera: true);
          if (f != null) await _sendMedia(f);
          break;
        case 'video':
          final f = await pickChatVideo();
          if (f != null) await _sendMedia(f);
          break;
        case 'file':
          final f = await pickChatFile();
          if (f != null) await _sendMedia(f);
          break;
        case 'location':
          await _sendLocation();
          break;
      }
    } catch (e) {
      _snack(_short(e));
    }
  }

  void _retryOrRemove(Map<String, dynamic> m) {
    if (m['_failed'] != true) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: C.bg2,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if ((m['type'] ?? 'text') == 'text' || (m['type'] == 'location'))
            ListTile(
              leading: const Icon(Icons.refresh, color: C.redLight),
              title: const Text('ارسال دوباره'),
              onTap: () {
                Navigator.pop(ctx);
                final i = _messages.indexWhere((x) => x['id'] == m['id']);
                if (i >= 0) {
                  setState(() => _messages[i] = {..._messages[i], '_failed': false, '_pending': true});
                }
                _insert(m);
              },
            ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: C.danger),
            title: const Text('حذف'),
            onTap: () {
              Navigator.pop(ctx);
              setState(() => _messages.removeWhere((x) => x['id'] == m['id']));
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _deleteMessage(Map<String, dynamic> m) async {
    try {
      await _db
          .from('messages')
          .update({'is_deleted': true})
          .eq('id', m['id'])
          .eq('sender_id', _uid);
      if (!mounted) return;
      final i = _messages.indexWhere((x) => x['id'].toString() == m['id'].toString());
      if (i >= 0) {
        setState(() => _messages[i] = {..._messages[i], 'is_deleted': true});
      }
    } catch (e) {
      _snack(_short(e));
    }
  }

  void _messageMenu(Map<String, dynamic> m) {
    if (m['is_deleted'] == true || m['_pending'] == true || m['_failed'] == true) {
      return;
    }
    final mine = m['sender_id'].toString() == _uid;
    final isText = (m['type'] ?? 'text') == 'text';
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
            if (_canPost)
              ListTile(
                leading: const Icon(Icons.reply, color: C.soft),
                title: const Text('پاسخ'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  setState(() => _replyTo = m);
                },
              ),
            if (isText)
              ListTile(
                leading: const Icon(Icons.copy, color: C.soft),
                title: const Text('کپی متن'),
                onTap: () {
                  Clipboard.setData(
                      ClipboardData(text: (m['content'] ?? '').toString()));
                  Navigator.of(ctx).pop();
                  _snack('کپی شد.');
                },
              ),
            if (mine)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: C.danger),
                title: const Text('حذف پیام'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _deleteMessage(m);
                },
              ),
          ],
        ),
      ),
    );
  }

  String _hhmm(dynamic iso) {
    final d = DateTime.tryParse(iso.toString())?.toLocal();
    if (d == null) return '';
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _replyPreview(Map<String, dynamic> m) =>
      messagePreview((m['type'] ?? 'text').toString(), m['content']?.toString(),
          deleted: m['is_deleted'] == true);

  Widget _quote(String replyId) {
    final src = _messages.cast<Map<String, dynamic>?>().firstWhere(
          (x) => x!['id'].toString() == replyId,
          orElse: () => null,
        );
    final name = src == null ? '' : (_names[src['sender_id'].toString()] ?? '');
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      decoration: BoxDecoration(
        color: const Color(0x22000000),
        borderRadius: BorderRadius.circular(8),
        border: const Border(right: BorderSide(color: C.redLight, width: 3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (name.isNotEmpty)
          Text(name,
              style: const TextStyle(
                  color: C.redLight, fontSize: 11, fontWeight: FontWeight.w700)),
        Text(src == null ? 'پیام' : _replyPreview(src),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: C.soft, fontSize: 12)),
      ]),
    );
  }

  Widget _bubble(Map<String, dynamic> m) {
    final mine = m['sender_id'].toString() == _uid;
    final deleted = m['is_deleted'] == true;
    final name = _names[m['sender_id'].toString()] ?? '';
    final failed = m['_failed'] == true;
    final pending = m['_pending'] == true;
    final replyId = m['reply_to']?.toString();
    return Align(
      alignment: mine ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
      child: GestureDetector(
        onLongPress: () => _messageMenu(m),
        onTap: failed ? () => _retryOrRemove(m) : null,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
          ),
          decoration: BoxDecoration(
            color: mine ? C.redDeep : C.bg3,
            borderRadius: BorderRadius.circular(14),
            border: failed ? Border.all(color: C.danger) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!mine && name.isNotEmpty && _type != 'direct')
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: C.redLight,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (replyId != null && !deleted) _quote(replyId),
              if (deleted)
                const Text('این پیام حذف شد',
                    style: TextStyle(
                        fontStyle: FontStyle.italic, color: C.muted, height: 1.6))
              else
                MessageContent(m: m),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_hhmm(m['created_at'])}${m['is_edited'] == true ? '  (ویرایش‌شده)' : ''}',
                    style: const TextStyle(color: C.soft, fontSize: 10.5),
                  ),
                  if (mine && !deleted) ...[
                    const SizedBox(width: 4),
                    MessageTicks(
                      pending: pending,
                      failed: failed,
                      read: _isRead(m),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openInfo() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatInfoScreen(
        profile: widget.profile,
        conversationId: widget.conversationId,
      ),
    ));
    if (mounted) _loadMeta();
  }

  String get _subtitle {
    switch (_type) {
      case 'channel':
        return 'کانال • $_memberCount عضو';
      case 'group':
        return _isProject ? 'گروه پروژه • $_memberCount عضو' : 'گروه • $_memberCount عضو';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: C.muted, height: 1.7)),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  setState(() => _loading = true);
                  _load();
                },
                child: const Text('تلاش دوباره'),
              ),
            ],
          ),
        ),
      );
    } else if (_messages.isEmpty) {
      body = Center(
        child: Text(
            _canPost ? 'هنوز پیامی نیست. اولین پیام را بفرستید.' : 'هنوز پستی منتشر نشده است.',
            style: const TextStyle(color: C.muted)),
      );
    } else {
      body = ListView.builder(
        controller: _scroll,
        reverse: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _messages.length,
        itemBuilder: (_, i) => _bubble(_messages[i]),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: C.bg1,
        titleSpacing: 0,
        title: InkWell(
          onTap: _type == 'direct' ? null : _openInfo,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_title.isEmpty ? '...' : _title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                if (_subtitle.isNotEmpty)
                  Text(_subtitle,
                      style: const TextStyle(fontSize: 11.5, color: C.soft)),
              ],
            ),
          ),
        ),
        actions: [
          if (_type != 'direct')
            IconButton(
                icon: const Icon(Icons.info_outline), onPressed: _openInfo),
        ],
      ),
      body: Backdrop(
        child: Column(
          children: [
            Expanded(child: body),
            if (_canPost)
              ChatInput(
                onSendText: _sendText,
                onAttach: _onAttach,
                onSendVoice: (media, secs) => _sendMedia(media, durationSec: secs),
                replyText: _replyTo == null ? null : _replyPreview(_replyTo!),
                onCancelReply: () => setState(() => _replyTo = null),
              )
            else
              SafeArea(
                top: false,
                child: Container(
                  width: double.infinity,
                  color: C.bg1,
                  padding: const EdgeInsets.all(14),
                  child: const Text('فقط مدیران کانال می‌توانند پست بگذارند.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: C.muted, fontSize: 13)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
