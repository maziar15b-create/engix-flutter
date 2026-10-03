import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme.dart';
import '../core/widgets.dart';
import 'home_tab.dart';
import 'messenger_tab.dart';
import 'social_tab.dart';
import 'tools_tab.dart';
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
                    HomeTab(profile: widget.profile, roleLabel: _roleLabel),
                    MessengerTab(profile: widget.profile),
                    ProjectsTab(profile: widget.profile),
                    SocialTab(profile: widget.profile),
                    const ToolsTab(),
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
