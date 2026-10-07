import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_settings.dart';
import '../core/push.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'home_tab.dart';
import 'messenger_tab.dart';
import 'profile/profile_common.dart';
import 'profile/profile_screen.dart';
import 'projects_tab.dart';
import 'social_tab.dart';
import 'tools_tab.dart';

class Shell extends StatefulWidget {
  final Map<String, dynamic> profile;
  final VoidCallback onProfileChanged;
  const Shell({super.key, required this.profile, required this.onProfileChanged});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;
  late Map<String, dynamic> _profile;

  static const _tabs = <_TabInfo>[
    _TabInfo('خانه', Icons.home_outlined, Icons.home),
    _TabInfo('پیام‌رسان', Icons.chat_bubble_outline, Icons.chat_bubble),
    _TabInfo('پروژه‌ها', Icons.engineering_outlined, Icons.engineering),
    _TabInfo('شبکه', Icons.groups_outlined, Icons.groups),
    _TabInfo('ابزارها', Icons.build_outlined, Icons.build),
  ];

  @override
  void initState() {
    super.initState();
    _profile = Map<String, dynamic>.from(widget.profile);
    AppSettings.applyFromProfile(_profile);
    Push.init(_profile);
  }

  @override
  void didUpdateWidget(covariant Shell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile != widget.profile) {
      _profile = Map<String, dynamic>.from(widget.profile);
      AppSettings.applyFromProfile(_profile);
    }
  }

  String get _roleLabel =>
      ((_profile['active_role'] as Map?)?['label'] ?? '').toString();

  Future<void> _reloadProfile() async {
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('*, active_role:roles!active_role_id(label)')
          .eq('id', _profile['id'])
          .maybeSingle();
      if (data != null && mounted) {
        setState(() => _profile = Map<String, dynamic>.from(data));
        AppSettings.applyFromProfile(_profile);
      }
    } catch (_) {}
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProfileScreen(profile: _profile)),
    );
    if (mounted) _reloadProfile();
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
                    GestureDetector(
                      onTap: _openProfile,
                      child: PfAvatar(
                        url: _profile['avatar_url']?.toString(),
                        name: (_profile['name'] ?? '').toString(),
                        size: 36,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: IndexedStack(
                  index: _index,
                  children: [
                    HomeTab(profile: _profile, roleLabel: _roleLabel),
                    MessengerTab(profile: _profile),
                    ProjectsTab(profile: _profile),
                    SocialTab(profile: _profile),
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
