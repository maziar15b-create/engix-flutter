import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme.dart';
import '../core/widgets.dart';

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

  // جدیدترین پیام اول (برای ListView معکوس)
  final List<Map<String, dynamic>> _messages = [];
  final Map<String, String> _names = {};
  final _input = TextEditingController();
  final _scroll = ScrollController();
  RealtimeChannel? _channel;
  bool _loading = true;
  bool _sending = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients &&
          _scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
        _loadMore();
      }
    });
    _load();
    _subscribe();
  }

  @override
  void dispose() {
    final ch = _channel;
    if (ch != null) _db.removeChannel(ch);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
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
    } catch (_) {
      // خطای صفحه‌های قدیمی مهم نیست
    } finally {
      _loadingMore = false;
    }
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
            final exists = _messages
                .any((m) => m['id'].toString() == rec['id'].toString());
            if (exists) return;
            setState(() => _messages.insert(0, rec));
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
        .subscribe();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final row = await _db
          .from('messages')
          .insert({
            'conversation_id': widget.conversationId,
            'sender_id': _uid,
            'type': 'text',
            'content': text,
          })
          .select()
          .single();
      _input.clear();
      if (!mounted) return;
      final exists =
          _messages.any((m) => m['id'].toString() == row['id'].toString());
      if (!exists) {
        setState(() => _messages.insert(0, Map<String, dynamic>.from(row)));
      }
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deleteMessage(Map<String, dynamic> m) async {
    try {
      await _db
          .from('messages')
          .update({'is_deleted': true})
          .eq('id', m['id'])
          .eq('sender_id', _uid);
      if (!mounted) return;
      final i = _messages
          .indexWhere((x) => x['id'].toString() == m['id'].toString());
      if (i >= 0) {
        setState(() => _messages[i] = {..._messages[i], 'is_deleted': true});
      }
    } catch (e) {
      _snack(e.toString());
    }
  }

  void _messageMenu(Map<String, dynamic> m) {
    if (m['is_deleted'] == true) return;
    final mine = m['sender_id'].toString() == _uid;
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

  String _bodyText(Map<String, dynamic> m) {
    if (m['is_deleted'] == true) return 'این پیام حذف شد';
    final content = (m['content'] ?? '').toString();
    switch ((m['type'] ?? 'text').toString()) {
      case 'image':
        return content.isEmpty ? 'تصویر' : 'تصویر: $content';
      case 'pdf':
        return content.isEmpty ? 'فایل PDF' : 'PDF: $content';
      case 'word':
        return content.isEmpty ? 'فایل Word' : 'Word: $content';
      case 'voice':
        return 'پیام صوتی';
      default:
        return content;
    }
  }

  Widget _bubble(Map<String, dynamic> m) {
    final mine = m['sender_id'].toString() == _uid;
    final deleted = m['is_deleted'] == true;
    final name = _names[m['sender_id'].toString()] ?? '';
    return Align(
      alignment: mine ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
      child: GestureDetector(
        onLongPress: () => _messageMenu(m),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          decoration: BoxDecoration(
            color: mine ? C.redDeep : C.bg3,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!mine && name.isNotEmpty)
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
              Text(
                _bodyText(m),
                style: TextStyle(
                  height: 1.6,
                  fontStyle: deleted ? FontStyle.italic : FontStyle.normal,
                  color: deleted ? C.muted : C.text,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${_hhmm(m['created_at'])}${m['is_edited'] == true ? '  (ویرایش‌شده)' : ''}',
                style: const TextStyle(color: C.soft, fontSize: 10.5),
              ),
            ],
          ),
        ),
      ),
    );
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
      body = const Center(
        child: Text('هنوز پیامی نیست. اولین پیام را بفرستید.',
            style: TextStyle(color: C.muted)),
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
        title: Text(widget.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
      body: Backdrop(
        child: Column(
          children: [
            Expanded(child: body),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 5,
                        decoration: const InputDecoration(hintText: 'پیام...'),
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
