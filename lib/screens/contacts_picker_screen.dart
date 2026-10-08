import 'package:flutter/material.dart';

import '../core/contacts_service.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

/// انتخاب از مخاطبین دفترچه‌ی تلفن که در EngiX عضو هستند.
/// خروجی: List<AppContact> (در حالت تکی فقط یک عضو)
class ContactsPickerScreen extends StatefulWidget {
  final String selfId;
  final String title;
  final bool multi;
  final Set<String> excludeIds;
  const ContactsPickerScreen({
    super.key,
    required this.selfId,
    this.title = 'انتخاب از مخاطبین',
    this.multi = false,
    this.excludeIds = const {},
  });

  @override
  State<ContactsPickerScreen> createState() => _ContactsPickerScreenState();
}

class _ContactsPickerScreenState extends State<ContactsPickerScreen> {
  List<AppContact>? _all;
  String? _error;
  bool _denied = false;
  bool _syncing = false;
  String _query = '';
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _load(force: false);
  }

  Future<void> _load({required bool force}) async {
    setState(() {
      _syncing = true;
      _error = null;
      _denied = false;
    });
    try {
      final list = await ContactsService.sync(widget.selfId, force: force);
      if (!mounted) return;
      setState(() {
        _all = list.where((c) => !widget.excludeIds.contains(c.id)).toList();
        _syncing = false;
      });
    } on ContactsPermissionException {
      if (!mounted) return;
      setState(() {
        _denied = true;
        _syncing = false;
        _all = [];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'همگام‌سازی مخاطبین ناموفق بود: $e';
        _syncing = false;
        _all = _all ?? [];
      });
    }
  }

  void _tap(AppContact c) {
    if (!widget.multi) {
      Navigator.pop(context, [c]);
      return;
    }
    setState(() {
      if (!_selected.add(c.id)) _selected.remove(c.id);
    });
  }

  void _done() {
    final chosen = (_all ?? []).where((c) => _selected.contains(c.id)).toList();
    Navigator.pop(context, chosen);
  }

  @override
  Widget build(BuildContext context) {
    final all = _all;
    final shown = all == null
        ? <AppContact>[]
        : all
            .where((c) =>
                _query.isEmpty ||
                c.contactName.contains(_query) ||
                c.name.contains(_query))
            .toList();

    Widget body;
    if (all == null || (_syncing && all.isEmpty)) {
      body = const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(),
        SizedBox(height: 12),
        Text('در حال همگام‌سازی مخاطبین...', style: TextStyle(color: C.muted)),
      ]));
    } else if (_denied) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.contacts_outlined, size: 48, color: C.muted),
            const SizedBox(height: 12),
            const Text(
              'برای همگام‌سازی، اجازه‌ی دسترسی به مخاطبین لازم است.\nاگر قبلاً رد کرده‌اید، از تنظیمات گوشی ← برنامه‌ها ← EngiX ← مجوزها اجازه بدهید.',
              textAlign: TextAlign.center,
              style: TextStyle(color: C.muted, height: 1.8),
            ),
            const SizedBox(height: 14),
            FilledButton(
                onPressed: () => _load(force: true), child: const Text('تلاش دوباره')),
          ]),
        ),
      );
    } else if (shown.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error ??
                (_query.isNotEmpty
                    ? 'مخاطبی پیدا نشد.'
                    : 'هیچ‌کدام از مخاطبین شما هنوز در EngiX عضو نیستند.'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: C.muted, height: 1.8),
          ),
        ),
      );
    } else {
      body = ListView.separated(
        itemCount: shown.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: Color(0x14FFFFFF)),
        itemBuilder: (_, i) {
          final c = shown[i];
          final sel = _selected.contains(c.id);
          final url = c.avatarUrl ?? '';
          return ListTile(
            onTap: () => _tap(c),
            leading: CircleAvatar(
              backgroundColor: C.bg3,
              backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
              child: url.isNotEmpty
                  ? null
                  : Text(c.contactName.isEmpty ? '?' : c.contactName.substring(0, 1),
                      style: const TextStyle(color: C.redLight)),
            ),
            title: Text(c.contactName,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: c.name == c.contactName
                ? null
                : Text(c.name, style: const TextStyle(color: C.soft, fontSize: 12)),
            trailing: widget.multi
                ? Icon(sel ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: sel ? C.red : C.muted)
                : null,
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: C.bg1,
        title: Text(widget.title, style: const TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            tooltip: 'همگام‌سازی مجدد',
            icon: _syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync),
            onPressed: _syncing ? null : () => _load(force: true),
          ),
          if (widget.multi)
            TextButton(
              onPressed: _selected.isEmpty ? null : _done,
              child: Text('تایید (${_selected.length})'),
            ),
        ],
      ),
      body: Backdrop(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: const InputDecoration(
                hintText: 'جستجو در مخاطبین...',
                prefixIcon: Icon(Icons.search, color: C.muted),
              ),
            ),
          ),
          Expanded(child: body),
        ]),
      ),
    );
  }
}
