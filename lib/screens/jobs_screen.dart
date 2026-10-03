import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import '../core/widgets.dart';
import 'chat_thread_screen.dart';

const _workTypes = {
  'full_time': 'تمام‌وقت',
  'part_time': 'پاره‌وقت',
  'project': 'پروژه‌ای',
};

const _folders = [
  {'key': 'job_seeking', 'label': 'درخواست کار', 'icon': '🧑‍💼', 'desc': 'افرادی که به‌دنبال کار هستند'},
  {'key': 'hiring', 'label': 'درخواست نیرو', 'icon': '🏗️', 'desc': 'کارفرماهایی که نیرو می‌خواهند'},
];

class JobsScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  final String? initialFolder;
  const JobsScreen({super.key, required this.profile, this.initialFolder});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  SupabaseClient get _db => Supabase.instance.client;
  String get _uid => widget.profile['id'].toString();

  String? _folder;
  List<Map<String, dynamic>>? _listings;
  bool _mine = false;
  String? _error;
  String? _contactingId;

  @override
  void initState() {
    super.initState();
    _folder = widget.initialFolder;
    if (_folder != null) _load();
  }

  Future<void> _load() async {
    setState(() {
      _listings = null;
      _error = null;
    });
    try {
      var q = _db.from('job_listings').select();
      if (_mine) {
        q = q.eq('author_id', _uid);
      } else {
        q = q.eq('status', 'active').eq('listing_type', _folder!);
      }
      final rows = await q.order('created_at', ascending: false).limit(100);
      final list = List<Map<String, dynamic>>.from(rows);
      final ids = list.map((r) => r['author_id']).whereType<Object>().toSet().toList();
      final names = <String, String>{};
      if (ids.isNotEmpty) {
        final ps = await _db.from('profiles').select('id, name').inFilter('id', ids);
        for (final p in ps) {
          names[p['id'].toString()] = (p['name'] ?? '').toString();
        }
      }
      for (final r in list) {
        r['authorName'] = names[r['author_id']?.toString()] ?? '—';
      }
      if (mounted) setState(() => _listings = list);
    } catch (e) {
      if (mounted) {
        setState(() {
          _listings = [];
          _error = e.toString();
        });
      }
    }
  }

  void _openFolder(String key) {
    setState(() {
      _folder = key;
      _mine = false;
    });
    _load();
  }

  Future<void> _contact(Map<String, dynamic> item) async {
    final authorId = item['author_id'].toString();
    setState(() => _contactingId = authorId);
    try {
      final conv = await _db.rpc('get_or_create_direct_conversation',
          params: {'other_user_id': authorId});
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChatThreadScreen(
          profile: widget.profile,
          conversationId: conv.toString(),
          title: (item['authorName'] ?? 'گفتگو').toString(),
        ),
      ));
    } catch (e) {
      if (mounted) setState(() => _error = 'خطا در شروع گفتگو: $e');
    } finally {
      if (mounted) setState(() => _contactingId = null);
    }
  }

  Future<void> _close(Map<String, dynamic> item) async {
    await _db.from('job_listings').update({'status': 'closed'}).eq('id', item['id']);
    _load();
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.bg2,
        content: const Text('این آگهی حذف شود؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف', style: TextStyle(color: C.danger))),
        ],
      ),
    );
    if (ok != true) return;
    await _db.from('job_listings').delete().eq('id', item['id']);
    _load();
  }

  Future<void> _newListing() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg2,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _ListingForm(
          authorId: _uid,
          initialType: _folder ?? 'job_seeking',
        ),
      ),
    );
    if (created == true) _load();
  }

  String _folderLabel(String? k) {
    for (final f in _folders) {
      if (f['key'] == k) return f['label']!;
    }
    return 'کاریابی';
  }

  Widget _folderCard(Map<String, String> f) => GestureDetector(
        onTap: () => _openFolder(f['key']!),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x40C50337)),
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFF26232C), Color(0xFF1D1B22), Color(0xFF141318)],
            ),
          ),
          child: Row(children: [
            Text(f['icon']!, style: const TextStyle(fontSize: 30)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(f['label']!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                const SizedBox(height: 2),
                Text(f['desc']!, style: const TextStyle(color: C.muted, fontSize: 12)),
              ]),
            ),
            const Icon(Icons.chevron_left, color: C.muted),
          ]),
        ),
      );

  Widget _card(Map<String, dynamic> item) {
    final mine = item['author_id'].toString() == _uid;
    final phone = (item['phone'] ?? '').toString();
    final type = item['listing_type'] == 'hiring' ? 'درخواست نیرو' : 'درخواست کار';
    final closed = item['status'] != 'active';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x29C50337)),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF1D1B22), Color(0xFF141318)],
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text((item['title'] ?? '').toString(),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          ),
          if (_mine) _pill(closed ? 'بسته‌شده' : type, closed ? C.muted : C.redLight),
        ]),
        if ((item['description'] ?? '').toString().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(item['description'].toString(),
                style: const TextStyle(color: C.soft, fontSize: 12.5, height: 1.8)),
          ),
        const SizedBox(height: 8),
        Wrap(spacing: 12, runSpacing: 4, children: [
          if ((item['location'] ?? '').toString().isNotEmpty) _meta('📍', item['location']),
          if ((item['role'] ?? '').toString().isNotEmpty) _meta('🛠', item['role']),
          if ((item['salary'] ?? '').toString().isNotEmpty) _meta('💰', item['salary']),
          if (_workTypes[item['work_type']] != null) _meta('🕒', _workTypes[item['work_type']]),
        ]),
        const SizedBox(height: 6),
        Text(item['authorName'].toString(), style: const TextStyle(color: C.muted, fontSize: 11)),
        const SizedBox(height: 10),
        if (!mine)
          Row(children: [
            if (phone.isNotEmpty)
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(40)),
                  onPressed: () => launchUrl(Uri.parse('tel:$phone')),
                  icon: const Icon(Icons.call, size: 18),
                  label: const Text('تماس'),
                ),
              ),
            if (phone.isNotEmpty) const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(40)),
                onPressed: _contactingId == item['author_id'].toString() ? null : () => _contact(item),
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: Text(_contactingId == item['author_id'].toString() ? '...' : 'پیام'),
              ),
            ),
          ]),
        if (mine)
          Row(children: [
            if (!closed)
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _close(item),
                  child: const Text('بستن آگهی'),
                ),
              ),
            if (!closed) const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: C.danger),
                onPressed: () => _delete(item),
                child: const Text('حذف'),
              ),
            ),
          ]),
      ]),
    );
  }

  Widget _meta(String icon, dynamic v) =>
      Text('$icon $v', style: const TextStyle(color: C.muted, fontSize: 11.5));

  Widget _pill(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: c.withOpacity(0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withOpacity(0.4)),
        ),
        child: Text(t, style: TextStyle(fontSize: 10.5, color: c, fontWeight: FontWeight.w700)),
      );

  @override
  Widget build(BuildContext context) {
    final inFolder = _folder != null || _mine;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: C.bg1,
        title: Text(_mine ? 'آگهی‌های من' : _folderLabel(_folder),
            style: const TextStyle(fontSize: 16)),
        leading: BackButton(onPressed: () {
          if (_mine) {
            setState(() => _mine = false);
            if (_folder != null) _load();
          } else if (_folder != null && widget.initialFolder == null) {
            setState(() {
              _folder = null;
              _listings = null;
            });
          } else {
            Navigator.pop(context);
          }
        }),
        actions: [
          if (!_mine)
            TextButton(
              onPressed: () {
                setState(() => _mine = true);
                _load();
              },
              child: const Text('آگهی‌های من'),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: C.red,
        onPressed: _newListing,
        icon: const Icon(Icons.add),
        label: const Text('ثبت آگهی'),
      ),
      body: Backdrop(
        child: !inFolder
            ? ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text('کاریابی',
                      style: TextStyle(color: C.redLight, fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text('آگهی‌های درخواست کار و درخواست نیرو',
                      style: TextStyle(color: C.muted, fontSize: 12.5)),
                  const SizedBox(height: 14),
                  for (final f in _folders) _folderCard(Map<String, String>.from(f)),
                ],
              )
            : RefreshIndicator(
                color: C.red,
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  children: [
                    ErrorText(_error),
                    if (_listings == null)
                      const Padding(
                        padding: EdgeInsets.all(30),
                        child: Center(child: CircularProgressIndicator(color: C.red)),
                      ),
                    if (_listings != null && _listings!.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 30),
                        child: Center(
                          child: Text('هنوز آگهی‌ای ثبت نشده.', style: TextStyle(color: C.muted)),
                        ),
                      ),
                    if (_listings != null) for (final i in _listings!) _card(i),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ListingForm extends StatefulWidget {
  final String authorId;
  final String initialType;
  const _ListingForm({required this.authorId, required this.initialType});
  @override
  State<_ListingForm> createState() => _ListingFormState();
}

class _ListingFormState extends State<_ListingForm> {
  final _db = Supabase.instance.client;
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _location = TextEditingController();
  final _role = TextEditingController();
  final _salary = TextEditingController();
  final _phone = TextEditingController();
  late String _type = widget.initialType;
  String _work = 'full_time';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_title, _desc, _location, _role, _salary, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _n(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'عنوان را وارد کنید.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _db.from('job_listings').insert({
        'author_id': widget.authorId,
        'listing_type': _type,
        'title': _title.text.trim(),
        'description': _n(_desc),
        'location': _n(_location),
        'role': _n(_role),
        'salary': _n(_salary),
        'work_type': _work,
        'phone': _n(_phone),
        'status': 'active',
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.toString();
        });
      }
    }
  }

  Widget _chips(Map<String, String> opts, String cur, ValueChanged<String> on) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final e in opts.entries)
            ChoiceChip(
              label: Text(e.value),
              selected: cur == e.key,
              selectedColor: const Color(0x55C50337),
              backgroundColor: C.bg1,
              onSelected: (_) => on(e.key),
            ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Center(
            child: Text('ثبت آگهی', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 14),
          _chips({'job_seeking': 'درخواست کار', 'hiring': 'درخواست نیرو'}, _type,
              (v) => setState(() => _type = v)),
          const SizedBox(height: 12),
          TextField(
              controller: _title,
              decoration: const InputDecoration(
                  hintText: 'عنوان (مثلاً: نیروی اجرایی برای پروژه اسکلت فلزی)')),
          const SizedBox(height: 10),
          TextField(
              controller: _desc,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(hintText: 'توضیحات')),
          const SizedBox(height: 10),
          TextField(
              controller: _location,
              decoration: const InputDecoration(hintText: 'محل (شهر/منطقه)')),
          const SizedBox(height: 10),
          TextField(
              controller: _role,
              decoration: const InputDecoration(hintText: 'نقش / تخصص موردنیاز')),
          const SizedBox(height: 10),
          TextField(
              controller: _salary,
              decoration: const InputDecoration(hintText: 'حقوق / دستمزد پیشنهادی (یا: توافقی)')),
          const SizedBox(height: 10),
          TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(hintText: 'شماره تماس (مثلاً: 09123456789)')),
          const SizedBox(height: 12),
          const Text('نوع همکاری', style: TextStyle(color: C.muted, fontSize: 12)),
          const SizedBox(height: 6),
          _chips(_workTypes, _work, (v) => setState(() => _work = v)),
          const SizedBox(height: 10),
          ErrorText(_error),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: Text(_saving ? 'در حال ثبت...' : 'ثبت آگهی'),
          ),
        ]),
      ),
    );
  }
}
