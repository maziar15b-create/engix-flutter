import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import '../core/widgets.dart';
import 'academy_screen.dart';
import 'chat_thread_screen.dart';
import 'jobs_screen.dart';

const _supportPhone = '09180152153';

String _fa(Object? v) {
  const d = '۰۱۲۳۴۵۶۷۸۹';
  return (v ?? '').toString().replaceAllMapped(RegExp(r'\d'), (m) => d[int.parse(m[0]!)]);
}

String _jalali(dynamic iso) {
  final d = DateTime.tryParse((iso ?? '').toString())?.toLocal();
  if (d == null) return '';
  final gdm = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
  final gy2 = d.month > 2 ? d.year + 1 : d.year;
  var days = 355666 +
      (365 * d.year) +
      ((gy2 + 3) ~/ 4) -
      ((gy2 + 99) ~/ 100) +
      ((gy2 + 399) ~/ 400) +
      d.day +
      gdm[d.month - 1];
  var jy = -1595 + (33 * (days ~/ 12053));
  days %= 12053;
  jy += 4 * (days ~/ 1461);
  days %= 1461;
  if (days > 365) {
    jy += (days - 1) ~/ 365;
    days = (days - 1) % 365;
  }
  final jm = days < 186 ? 1 + (days ~/ 31) : 7 + ((days - 186) ~/ 30);
  final jd = 1 + (days < 186 ? days % 31 : (days - 186) % 30);
  return _fa('$jy/${jm.toString().padLeft(2, '0')}/${jd.toString().padLeft(2, '0')}');
}

class HomeTab extends StatefulWidget {
  final Map<String, dynamic> profile;
  final String roleLabel;
  const HomeTab({super.key, required this.profile, required this.roleLabel});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  SupabaseClient get _db => Supabase.instance.client;
  String get _uid => widget.profile['id'].toString();

  List<Map<String, dynamic>>? _ads;
  List<Map<String, dynamic>>? _jobs;
  List<Map<String, dynamic>>? _notifs;
  List<Map<String, dynamic>>? _news;
  int _adIndex = 0;
  Timer? _adTimer;
  RealtimeChannel? _channel;
  final Set<String> _impressed = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
    _channel = _db
        .channel('home-notifs:$_uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: _uid,
          ),
          callback: (_) => _loadNotifs(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _adTimer?.cancel();
    final ch = _channel;
    if (ch != null) _db.removeChannel(ch);
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadAds(), _loadJobs(), _loadNotifs(), _loadNews()]);
  }

  // ---------------------------------------------------------------- تبلیغات

  Future<void> _loadAds() async {
    try {
      final rows = await _db
          .from('ads')
          .select()
          .eq('active', true)
          .order('priority', ascending: false)
          .order('created_at', ascending: false)
          .limit(30);
      final roles = List<dynamic>.from(widget.profile['roles'] ?? [])
          .map((e) => e.toString())
          .toList();
      final list = List<Map<String, dynamic>>.from(rows).where((ad) {
        final t = ad['target_roles'];
        if (t is! List || t.isEmpty) return true;
        return t.any((r) => roles.contains(r.toString()));
      }).toList();
      if (!mounted) return;
      setState(() {
        _ads = list;
        _adIndex = 0;
      });
      _adTimer?.cancel();
      if (list.length > 1) {
        _adTimer = Timer.periodic(const Duration(seconds: 6), (_) {
          if (!mounted) return;
          setState(() => _adIndex = (_adIndex + 1) % list.length);
          _recordImpression();
        });
      }
      _recordImpression();
    } catch (_) {
      if (mounted) setState(() => _ads = []);
    }
  }

  void _stat(dynamic id, String stat) {
    _db.rpc('increment_ad_stat', params: {'ad_id': id, 'stat': stat}).then((_) {}, onError: (_) {});
  }

  void _recordImpression() {
    final ads = _ads;
    if (ads == null || ads.isEmpty) return;
    final id = ads[_adIndex % ads.length]['id'];
    if (id != null && _impressed.add(id.toString())) _stat(id, 'impression');
  }

  Future<void> _openAd(Map<String, dynamic> ad) async {
    _stat(ad['id'], 'click');
    final url = (ad['target_url'] ?? '').toString();
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // ------------------------------------------------------------ فرصت شغلی

  Future<void> _loadJobs() async {
    try {
      final rows = await _db
          .from('job_listings')
          .select()
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(5);
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
      if (mounted) setState(() => _jobs = list);
    } catch (_) {
      if (mounted) setState(() => _jobs = []);
    }
  }

  // --------------------------------------------------------------- اعلان‌ها

  Future<void> _loadNotifs() async {
    try {
      final rows = await _db
          .from('notifications')
          .select()
          .eq('user_id', _uid)
          .order('created_at', ascending: false)
          .limit(15);
      if (mounted) setState(() => _notifs = List<Map<String, dynamic>>.from(rows));
    } catch (_) {
      if (mounted) setState(() => _notifs = []);
    }
  }

  Future<void> _markRead(Map<String, dynamic> n) async {
    if (n['is_read'] == true) return;
    setState(() => n['is_read'] = true);
    try {
      await _db.from('notifications').update({'is_read': true}).eq('id', n['id']);
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    setState(() {
      for (final n in _notifs ?? []) {
        n['is_read'] = true;
      }
    });
    try {
      await _db
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', _uid)
          .eq('is_read', false);
    } catch (_) {}
  }

  // ------------------------------------------------------------------ اخبار

  Future<void> _loadNews() async {
    try {
      final rows = await _db
          .from('news')
          .select('id, title, summary, importance, published_at, created_at, news_categories(label)')
          .order('created_at', ascending: false)
          .limit(6);
      if (mounted) setState(() => _news = List<Map<String, dynamic>>.from(rows));
    } catch (_) {
      if (mounted) setState(() => _news = []);
    }
  }

  void _sheet(Widget Function(BuildContext) builder) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg2,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: builder,
    );
  }

  void _openNews(Map<String, dynamic> n) {
    _sheet((ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text((n['title'] ?? '').toString(),
                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, height: 1.7)),
                const SizedBox(height: 10),
                Flexible(
                  child: SingleChildScrollView(
                    child: Text((n['summary'] ?? '').toString(),
                        style: const TextStyle(color: C.soft, height: 1.9)),
                  ),
                ),
                const SizedBox(height: 8),
                Text(_jalali(n['published_at'] ?? n['created_at']),
                    style: const TextStyle(color: C.muted, fontSize: 11.5)),
              ],
            ),
          ),
        ));
  }

  Future<void> _messageAuthor(Map<String, dynamic> j) async {
    try {
      final conv = await _db.rpc('get_or_create_direct_conversation',
          params: {'other_user_id': j['author_id'].toString()});
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChatThreadScreen(
          profile: widget.profile,
          conversationId: conv.toString(),
          title: (j['authorName'] ?? 'گفتگو').toString(),
        ),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطا در شروع گفتگو: $e')));
    }
  }

  Future<void> _openJobs([String? folder]) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => JobsScreen(profile: widget.profile, initialFolder: folder),
    ));
    _loadJobs();
  }

  Widget _jobFolder(String icon, String label, String key) => Expanded(
        child: GestureDetector(
          onTap: () => _openJobs(key),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: _cardDeco(border: const Color(0x40C50337)),
            child: Column(children: [
              Text(icon, style: const TextStyle(fontSize: 26)),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );

  void _openJob(Map<String, dynamic> j) {
    final phone = (j['phone'] ?? '').toString();
    _sheet((ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text((j['title'] ?? '').toString(),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final k in ['role', 'location', 'work_type', 'salary'])
                    if ((j[k] ?? '').toString().isNotEmpty) _chip(j[k].toString()),
                ]),
                if ((j['description'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(j['description'].toString(),
                      style: const TextStyle(color: C.soft, height: 1.9)),
                ],
                const SizedBox(height: 8),
                Text('ثبت‌کننده: ${j['authorName'] ?? '—'}',
                    style: const TextStyle(color: C.muted, fontSize: 12)),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () => launchUrl(Uri.parse('tel:$phone')),
                    icon: const Icon(Icons.call),
                    label: Text('تماس: ${_fa(phone)}'),
                  ),
                ],
                if (j['author_id'].toString() != _uid) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _messageAuthor(j);
                    },
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('ارسال پیام'),
                  ),
                ],
              ],
            ),
          ),
        ));
  }

  // ----------------------------------------------------------------- رابط

  Widget _chip(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0x22C50337),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x44C50337)),
        ),
        child: Text(t, style: const TextStyle(fontSize: 11)),
      );

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 5) return 'شب بخیر';
    if (h < 12) return 'صبح بخیر';
    if (h < 18) return 'ظهر بخیر';
    return 'عصر بخیر';
  }

  Widget _heading(IconData icon, String text, {Widget? trailing}) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 6),
        child: Row(children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0x47C50337)),
              color: const Color(0x14FF3D63),
            ),
            child: Icon(icon, size: 14, color: C.redLight),
          ),
          const SizedBox(width: 9),
          Text(text,
              style: const TextStyle(color: C.redLight, fontSize: 12.5, fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          if (trailing != null) trailing,
          const Expanded(child: Divider(color: Color(0x4DC50337), indent: 10, height: 1)),
        ]),
      );

  Widget _skeleton(int n) => Column(children: [
        for (var i = 0; i < n; i++)
          Container(
            height: 58,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(color: C.bg2, borderRadius: BorderRadius.circular(10)),
          ),
      ]);

  Widget _empty(String t) => EngixPanel(
        padding: const EdgeInsets.all(14),
        child: Text(t, style: const TextStyle(fontSize: 13, color: C.soft, height: 1.8)),
      );

  BoxDecoration _cardDeco({Color border = const Color(0x29C50337)}) => BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF1D1B22), Color(0xFF141318)],
        ),
      );

  Widget _adBanner() {
    final ads = _ads;
    if (ads == null || ads.isEmpty) return const SizedBox.shrink();
    final ad = ads[_adIndex % ads.length];
    final img = (ad['image_url'] ?? '').toString();
    final btn = (ad['button_text'] ?? '').toString();
    return GestureDetector(
      onTap: () => _openAd(ad),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: Container(
          key: ValueKey(ad['id']),
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.all(14),
          decoration: _cardDeco(border: const Color(0x52C50337)),
          child: Row(children: [
            if (img.isNotEmpty)
              Container(
                width: 62,
                height: 62,
                margin: const EdgeInsetsDirectional.only(end: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  image: DecorationImage(image: NetworkImage(img), fit: BoxFit.cover),
                ),
              ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text((ad['title'] ?? '').toString(),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  ),
                  const Text('تبلیغ', style: TextStyle(color: C.muted, fontSize: 10)),
                ]),
                if ((ad['body'] ?? '').toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(ad['body'].toString(),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: C.soft, fontSize: 12, height: 1.7)),
                  ),
                if (btn.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(color: C.red, borderRadius: BorderRadius.circular(6)),
                      child: Text(btn, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                    ),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _jobsSection() {
    final jobs = _jobs;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _heading(Icons.work_outline, 'کاریابی و درخواست نیرو'),
      Row(children: [
        _jobFolder('🧑‍💼', 'درخواست کار', 'job_seeking'),
        const SizedBox(width: 10),
        _jobFolder('🏗️', 'درخواست نیرو', 'hiring'),
      ]),
      const SizedBox(height: 10),
      if (jobs == null) _skeleton(2),
      if (jobs != null && jobs.isEmpty) _empty('آگهی فعالی ثبت نشده است.'),
      if (jobs != null)
        for (final j in jobs)
          GestureDetector(
            onTap: () => _openJob(j),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: _cardDeco(),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text((j['title'] ?? '').toString(),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    const SizedBox(height: 3),
                    Text(
                      [
                        j['listing_type'] == 'hiring' ? 'درخواست نیرو' : 'درخواست کار',
                        if ((j['location'] ?? '').toString().isNotEmpty) j['location'].toString(),
                        if ((j['role'] ?? '').toString().isNotEmpty) j['role'].toString(),
                      ].join(' • '),
                      style: const TextStyle(color: C.muted, fontSize: 11.5),
                    ),
                  ]),
                ),
                const Icon(Icons.chevron_left, color: C.muted),
              ]),
            ),
          ),
      Align(
        alignment: AlignmentDirectional.centerEnd,
        child: TextButton(
          onPressed: () => _openJobs(),
          child: const Text('مشاهده‌ی همه و ثبت آگهی', style: TextStyle(fontSize: 12)),
        ),
      ),
    ]);
  }

  Widget _notifSection() {
    final list = _notifs;
    final unread = (list ?? []).where((n) => n['is_read'] != true).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _heading(
        Icons.notifications_none,
        'اعلان‌ها',
        trailing: unread > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [C.redLight, C.red]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${_fa(unread)} جدید',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800)),
              )
            : null,
      ),
      if (unread > 1)
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(
            onPressed: _markAllRead,
            child: const Text('علامت‌گذاری همه به‌عنوان خوانده‌شده', style: TextStyle(fontSize: 11.5)),
          ),
        ),
      if (list == null) _skeleton(2),
      if (list != null && list.isEmpty)
        _empty('به EngiX خوش آمدید — اولین پروژه خود را بسازید یا با کد به یکی بپیوندید.'),
      if (list != null)
        for (final n in list)
          GestureDetector(
            onTap: () => _markRead(n),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: n['is_read'] == true ? const Color(0x1FC50337) : const Color(0x73C50337)),
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: n['is_read'] == true
                      ? const [Color(0xFF1D1B22), Color(0xFF141318)]
                      : const [Color(0x24C50337), Color(0x147A0224)],
                ),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  if (n['is_read'] != true)
                    Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsetsDirectional.only(end: 8),
                      decoration: const BoxDecoration(color: C.redLight, shape: BoxShape.circle),
                    ),
                  Expanded(
                    child: Text((n['title'] ?? '').toString(),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                  Text(_jalali(n['created_at']),
                      style: const TextStyle(color: C.muted, fontSize: 10.5)),
                ]),
                if ((n['body'] ?? '').toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(n['body'].toString(),
                        style: const TextStyle(fontSize: 12.5, color: C.soft, height: 1.7)),
                  ),
              ]),
            ),
          ),
    ]);
  }

  Widget _academy() => GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AcademyScreen(profile: widget.profile),
        )),
        child: Container(
          margin: const EdgeInsets.only(top: 14, bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x59C50337)),
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFF26232C), Color(0xFF1D1B22), Color(0xFF141318)],
            ),
          ),
          child: Row(children: [
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('EngiX Academy', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                SizedBox(height: 4),
                Text('دوره‌ها، آزمون آزمایشی، بانک سوالات و گواهینامه',
                    style: TextStyle(color: C.muted, fontSize: 12)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                gradient: const LinearGradient(colors: [C.redLight, C.red, C.redDeep]),
              ),
              child: const Text('ورود ›', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      );

  Widget _newsSection() {
    final news = _news;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _heading(Icons.article_outlined, 'اخبار مهندسی'),
      if (news == null) _skeleton(3),
      if (news != null && news.isEmpty) _empty('هنوز خبری همگام‌سازی نشده است.'),
      if (news != null)
        for (final n in news)
          GestureDetector(
            onTap: () => _openNews(n),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: const Border(
                  right: BorderSide(color: C.red, width: 3),
                  top: BorderSide(color: Color(0x29C50337)),
                  bottom: BorderSide(color: Color(0x29C50337)),
                  left: BorderSide(color: Color(0x29C50337)),
                ),
                gradient: const LinearGradient(colors: [Color(0xFF1D1B22), Color(0xFF141318)]),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text((n['title'] ?? '').toString(),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, height: 1.7)),
                if ((n['summary'] ?? '').toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(n['summary'].toString(),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: C.soft, height: 1.7)),
                  ),
                if (n['news_categories'] is Map &&
                    (n['news_categories']['label'] ?? '').toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0x26C50337),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0x59C50337)),
                      ),
                      child: Text(n['news_categories']['label'].toString(),
                          style: const TextStyle(fontSize: 11, color: C.redLight)),
                    ),
                  ),
              ]),
            ),
          ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.profile['name'] ?? '').toString();
    return RefreshIndicator(
      color: C.red,
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(_greeting,
              style: const TextStyle(
                  fontSize: 11, letterSpacing: 1.5, color: C.red, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(name.isEmpty ? 'مهندس' : name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          if (widget.roleLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('نقش فعال: ${widget.roleLabel}',
                  style: const TextStyle(color: C.soft, fontSize: 12.5)),
            ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => launchUrl(Uri.parse('tel:$_supportPhone')),
            child: Text.rich(TextSpan(
              style: const TextStyle(color: C.muted, fontSize: 11.5, height: 1.8),
              children: [
                const TextSpan(text: 'جهت ارتباط با پشتیبانی و ثبت تبلیغات با شماره زیر تماس بگیرید: '),
                TextSpan(
                  text: _fa(_supportPhone),
                  style: const TextStyle(color: C.redLight, fontWeight: FontWeight.w700),
                ),
              ],
            )),
          ),
          const SizedBox(height: 18),
          _adBanner(),
          _jobsSection(),
          const SizedBox(height: 10),
          _notifSection(),
          _academy(),
          _newsSection(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
