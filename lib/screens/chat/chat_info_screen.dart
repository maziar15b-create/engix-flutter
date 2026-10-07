import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

class ChatInfoScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  final String conversationId;
  const ChatInfoScreen(
      {super.key, required this.profile, required this.conversationId});

  @override
  State<ChatInfoScreen> createState() => _ChatInfoScreenState();
}

class _ChatInfoScreenState extends State<ChatInfoScreen> {
  SupabaseClient get _db => Supabase.instance.client;
  String get _uid => widget.profile['id'].toString();

  Map<String, dynamic>? _conv;
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;
  bool _muted = false;
  bool _isProject = false;
  String _myRole = 'member';

  bool get _isAdmin => _myRole == 'owner' || _myRole == 'admin';
  String get _type => (_conv?['type'] ?? 'group').toString();
  String get _kind => _type == 'channel' ? 'کانال' : 'گروه';

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
      final conv = await _db
          .from('conversations')
          .select()
          .eq('id', widget.conversationId)
          .maybeSingle();
      final rows = await _db
          .from('conversation_members')
          .select('user_id, role, is_muted')
          .eq('conversation_id', widget.conversationId);
      final ids = rows.map((r) => r['user_id']).toList();
      final profs = <String, Map<String, dynamic>>{};
      if (ids.isNotEmpty) {
        final ps = await _db
            .from('profiles')
            .select('id, name, avatar_url')
            .inFilter('id', ids);
        for (final p in ps) {
          profs[p['id'].toString()] = Map<String, dynamic>.from(p);
        }
      }
      var role = 'member';
      var muted = false;
      final list = <Map<String, dynamic>>[];
      for (final r in rows) {
        final uid = r['user_id'].toString();
        if (uid == _uid) {
          role = (r['role'] ?? 'member').toString();
          muted = r['is_muted'] == true;
        }
        list.add({
          'user_id': uid,
          'role': (r['role'] ?? 'member').toString(),
          'name': (profs[uid]?['name'] ?? 'کاربر').toString(),
          'avatar_url': profs[uid]?['avatar_url'],
        });
      }
      const order = {'owner': 0, 'admin': 1, 'member': 2};
      list.sort((a, b) => (order[a['role']] ?? 3).compareTo(order[b['role']] ?? 3));

      var isProject = conv?['project_id'] != null ||
          widget.conversationId.startsWith('proj_');
      if (!isProject) {
        try {
          final p = await _db
              .from('projects')
              .select('id')
              .eq('chat_conversation_id', widget.conversationId)
              .maybeSingle();
          isProject = p != null;
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _conv = conv;
        _members = list;
        _myRole = role;
        _muted = muted;
        _isProject = isProject;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('خطا: $e');
    }
  }

  Future<void> _toggleMute() async {
    try {
      await _db
          .from('conversation_members')
          .update({'is_muted': !_muted})
          .eq('conversation_id', widget.conversationId)
          .eq('user_id', _uid);
      setState(() => _muted = !_muted);
    } catch (e) {
      _snack('خطا: $e');
    }
  }

  Future<String?> _ask(String title, String label,
      {bool phone = false, String initial = ''}) async {
    final ctl = TextEditingController(text: initial);
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.bg2,
        title: Text(title),
        content: TextField(
          controller: ctl,
          autofocus: true,
          keyboardType: phone ? TextInputType.phone : TextInputType.text,
          textDirection: phone ? TextDirection.ltr : null,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(), child: const Text('انصراف')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(ctl.text),
              child: const Text('تایید')),
        ],
      ),
    );
    ctl.dispose();
    if (res == null || res.trim().isEmpty) return null;
    return res.trim();
  }

  Future<bool> _confirm(String text) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.bg2,
        content: Text(text),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('انصراف')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('بله', style: TextStyle(color: C.danger))),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _addMember() async {
    final raw = await _ask('افزودن عضو', 'شماره موبایل', phone: true);
    if (raw == null) return;
    try {
      final ten = normalizePhone(raw);
      if (ten.length < 10) {
        _snack('شماره معتبر نیست.');
        return;
      }
      final p = await _db
          .from('profiles')
          .select('id')
          .inFilter('phone', ['0$ten', ten, '+98$ten', '98$ten'])
          .limit(1)
          .maybeSingle();
      if (p == null) {
        _snack('کاربری با این شماره پیدا نشد.');
        return;
      }
      if (_members.any((m) => m['user_id'] == p['id'].toString())) {
        _snack('قبلاً عضو است.');
        return;
      }
      await _db.from('conversation_members').insert({
        'conversation_id': widget.conversationId,
        'user_id': p['id'],
        'role': 'member',
      });
      _snack('عضو اضافه شد.');
      _load();
    } catch (e) {
      _snack('خطا: $e');
    }
  }

  Future<void> _rename() async {
    final name = await _ask('نام جدید $_kind', 'نام',
        initial: (_conv?['name'] ?? '').toString());
    if (name == null) return;
    try {
      await _db
          .from('conversations')
          .update({'name': name}).eq('id', widget.conversationId);
      _load();
    } catch (e) {
      _snack('خطا: $e');
    }
  }

  Future<void> _remove(Map<String, dynamic> m) async {
    if (!await _confirm('${m['name']} از $_kind حذف شود؟')) return;
    try {
      await _db
          .from('conversation_members')
          .delete()
          .eq('conversation_id', widget.conversationId)
          .eq('user_id', m['user_id']);
      _load();
    } catch (e) {
      _snack('خطا: $e');
    }
  }

  Future<void> _setRole(Map<String, dynamic> m, String role) async {
    try {
      await _db
          .from('conversation_members')
          .update({'role': role})
          .eq('conversation_id', widget.conversationId)
          .eq('user_id', m['user_id']);
      _load();
    } catch (e) {
      _snack('خطا: $e');
    }
  }

  Future<void> _leave() async {
    if (!await _confirm('از این $_kind خارج می‌شوید؟')) return;
    try {
      await _db
          .from('conversation_members')
          .delete()
          .eq('conversation_id', widget.conversationId)
          .eq('user_id', _uid);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      _snack('خطا: $e');
    }
  }

  void _memberMenu(Map<String, dynamic> m) {
    if (m['user_id'] == _uid || !_isAdmin || m['role'] == 'owner') return;
    showModalBottomSheet(
      context: context,
      backgroundColor: C.bg2,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_myRole == 'owner')
            ListTile(
              leading: const Icon(Icons.admin_panel_settings, color: C.redLight),
              title: Text(m['role'] == 'admin' ? 'برداشتن از مدیریت' : 'مدیر کردن'),
              onTap: () {
                Navigator.pop(ctx);
                _setRole(m, m['role'] == 'admin' ? 'member' : 'admin');
              },
            ),
          if (!_isProject)
            ListTile(
              leading: const Icon(Icons.person_remove, color: C.danger),
              title: const Text('حذف از گروه'),
              onTap: () {
                Navigator.pop(ctx);
                _remove(m);
              },
            ),
        ]),
      ),
    );
  }

  String _roleLabel(String r) =>
      r == 'owner' ? 'مالک' : (r == 'admin' ? 'مدیر' : '');

  @override
  Widget build(BuildContext context) {
    final name = (_conv?['name'] ?? _kind).toString();
    final canManage = _isAdmin && !_isProject;
    return Scaffold(
      appBar: AppBar(backgroundColor: C.bg1, title: Text('اطلاعات $_kind')),
      body: Backdrop(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: C.bg3,
                      backgroundImage: (_conv?['avatar_url'] ?? '').toString().isNotEmpty
                          ? NetworkImage(_conv!['avatar_url'].toString())
                          : null,
                      child: (_conv?['avatar_url'] ?? '').toString().isNotEmpty
                          ? null
                          : Icon(
                              _type == 'channel' ? Icons.campaign : Icons.groups,
                              size: 38,
                              color: C.redLight),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(name,
                        style: const TextStyle(
                            fontSize: 19, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                        '${_isProject ? 'گروه پروژه' : _kind} • ${_members.length} عضو',
                        style: const TextStyle(color: C.soft, fontSize: 12.5)),
                  ),
                  if (_isProject)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text(
                        'اعضای این گروه به‌صورت خودکار با اعضای پروژه یکی هستند؛ برای افزودن یا حذف، از بخش «اعضای پروژه» اقدام کنید.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: C.muted, fontSize: 12, height: 1.7),
                      ),
                    ),
                  const SizedBox(height: 16),
                  EngixPanel(
                    padding: EdgeInsets.zero,
                    child: Column(children: [
                      SwitchListTile(
                        value: _muted,
                        onChanged: (_) => _toggleMute(),
                        secondary: Icon(
                            _muted ? Icons.volume_off : Icons.volume_up,
                            color: C.redLight),
                        title: const Text('بی‌صدا کردن'),
                      ),
                      if (canManage)
                        ListTile(
                          leading: const Icon(Icons.edit, color: C.redLight),
                          title: Text('تغییر نام $_kind'),
                          onTap: _rename,
                        ),
                      if (canManage)
                        ListTile(
                          leading: const Icon(Icons.person_add, color: C.redLight),
                          title: const Text('افزودن عضو'),
                          onTap: _addMember,
                        ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  Text('اعضا (${_members.length})',
                      style: const TextStyle(
                          color: C.redLight, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  for (final m in _members)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      onLongPress: () => _memberMenu(m),
                      onTap: () => _memberMenu(m),
                      leading: CircleAvatar(
                        backgroundColor: C.bg3,
                        backgroundImage: (m['avatar_url'] ?? '').toString().isNotEmpty
                            ? NetworkImage(m['avatar_url'].toString())
                            : null,
                        child: (m['avatar_url'] ?? '').toString().isNotEmpty
                            ? null
                            : Text(
                                m['name'].toString().isEmpty
                                    ? '?'
                                    : m['name'].toString().substring(0, 1),
                                style: const TextStyle(color: C.redLight)),
                      ),
                      title: Text(m['user_id'] == _uid ? '${m['name']} (شما)' : m['name'].toString()),
                      trailing: _roleLabel(m['role']).isEmpty
                          ? null
                          : Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                  color: const Color(0x33C50337),
                                  borderRadius: BorderRadius.circular(8)),
                              child: Text(_roleLabel(m['role']),
                                  style: const TextStyle(
                                      fontSize: 11, color: C.redLight)),
                            ),
                    ),
                  const SizedBox(height: 16),
                  if (!_isProject || _myRole != 'owner')
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: C.danger,
                          side: const BorderSide(color: C.danger),
                          minimumSize: const Size.fromHeight(46)),
                      onPressed: _leave,
                      icon: const Icon(Icons.exit_to_app),
                      label: Text('خروج از $_kind'),
                    ),
                ],
              ),
      ),
    );
  }
}
