import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme.dart';
import '../core/widgets.dart';
import 'projects_tab.dart';

class Shell extends StatefulWidget {
  final Map<String, dynamic> profile;
  final VoidCallback onProfileChanged;
  const Shell({super.key, required this.profile, required this.onProfileChanged});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;

  static const _tabs = <_TabInfo>[
    _TabInfo('خانه', Icons.home_outlined, Icons.home),
    _TabInfo('پیام‌رسان', Icons.chat_bubble_outline, Icons.chat_bubble),
    _TabInfo('پروژه‌ها', Icons.engineering_outlined, Icons.engineering),
    _TabInfo('شبکه', Icons.groups_outlined, Icons.groups),
    _TabInfo('ابزارها', Icons.build_outlined, Icons.build),
  ];

  String get _roleLabel =>
      ((widget.profile['active_role'] as Map?)?['label'] ?? '').toString();

  void _openProfileSheet() {
    final p = widget.profile;
    showModalBottomSheet(
      context: context,
      backgroundColor: C.bg2,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _avatar(44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text((p['name'] ?? '').toString(),
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                        if (_roleLabel.isNotEmpty)
                          Text(_roleLabel,
                              style: const TextStyle(color: C.soft, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0x33C50337)),
              ListTile(
                leading: const Icon(Icons.logout, color: C.danger),
                title: const Text('خروج از حساب'),
                onTap: () async {
                  Navigator.pop(context);
                  await Supabase.instance.client.auth.signOut();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatar(double size) {
    final url = widget.profile['avatar_url'] as String?;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: C.bg3,
        border: Border.all(color: C.line),
        image: (url != null && url.isNotEmpty)
            ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
            : null,
      ),
      child: (url == null || url.isEmpty)
          ? Icon(Icons.person, size: size * 0.55, color: C.soft)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Backdrop(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Row(
                  children: [
                    const EngixLogo(size: 32),
                    const SizedBox(width: 10),
                    const Text('EngiX',
                        style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: C.redLight)),
                    const Spacer(),
                    GestureDetector(onTap: _openProfileSheet, child: _avatar(36)),
                  ],
                ),
              ),
              Expanded(
                child: IndexedStack(
                  index: _index,
                  children: [
                    _HomeTab(profile: widget.profile, roleLabel: _roleLabel),
                    const _ComingSoon(title: 'پیام‌رسان'),
                    ProjectsTab(profile: widget.profile),
                    const _ComingSoon(title: 'شبکه'),
                    const _ComingSoon(title: 'ابزارها'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final t in _tabs)
            NavigationDestination(
              icon: Icon(t.icon, color: C.muted),
              selectedIcon: Icon(t.selectedIcon, color: C.redLight),
              label: t.label,
            ),
        ],
      ),
    );
  }
}

class _TabInfo {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  const _TabInfo(this.label, this.icon, this.selectedIcon);
}

class _HomeTab extends StatelessWidget {
  final Map<String, dynamic> profile;
  final String roleLabel;
  const _HomeTab({required this.profile, required this.roleLabel});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        EngixPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('سلام ${(profile['name'] ?? '').toString()} 👋',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              if (roleLabel.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('نقش فعال: $roleLabel',
                    style: const TextStyle(color: C.soft, fontSize: 13)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        const EngixPanel(
          child: Text(
            'ورود و پروفایل با موفقیت به اپ نیتیو وصل شد. بخش‌های پروژه‌ها، پیام‌رسان، شبکه و ابزارها در مراحل بعد اضافه می‌شوند.',
            style: TextStyle(color: C.soft, height: 1.9, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _ComingSoon extends StatelessWidget {
  final String title;
  const _ComingSoon({required this.title});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.construction, size: 40, color: C.muted),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('به‌زودی', style: TextStyle(color: C.muted)),
        ],
      ),
    );
  }
}
