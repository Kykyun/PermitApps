import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import 'dashboard_screen.dart';
import 'permit_list_screen.dart';
import 'permit_form_screen.dart';
import 'notification_screen.dart';
import 'user_management_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  String? _permitStatusFilter;
  bool _userMenuExpanded = false;

  List<Widget> get _pages => [
    DashboardScreen(onStatTap: (filter) {
      setState(() {
        _permitStatusFilter = filter;
        _currentIndex = 1;
      });
    }),
    PermitListScreen(
      key: ValueKey('permits_$_permitStatusFilter'),
      initialStatusFilter: _permitStatusFilter,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().loadNotifications();
    });
  }

  Widget _buildUserMenuPanel(BuildContext context, dynamic user, AuthProvider auth) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF162A3E),
        border: Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 2),
              Text(user.email, style: const TextStyle(fontSize: 12, color: Colors.white54)),
              const SizedBox(height: 2),
              Text(user.roleLabel, style: const TextStyle(fontSize: 12, color: Color(0xFF4FC3F7))),
            ],
          ),
          const Divider(height: 20, color: Colors.white12),
          if (user.role == 'admin')
            InkWell(
              onTap: () {
                setState(() => _userMenuExpanded = false);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const UserManagementScreen()));
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.manage_accounts_outlined, size: 18, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Manage Users'),
                  ],
                ),
              ),
            ),
          InkWell(
            onTap: () {
              setState(() => _userMenuExpanded = false);
              auth.logout();
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.logout, size: 18, color: Color(0xFFEF5350)),
                  SizedBox(width: 8),
                  Text('Logout', style: TextStyle(color: Color(0xFFEF5350))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final notif = context.watch<NotificationProvider>();
    final user = auth.user!;
    final isWide = MediaQuery.of(context).size.width > 768;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A5F), Color(0xFF4FC3F7)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.work_outline, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 12),
            if (isWide)
              const Text('LNK StPOM - Works Permit', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          // Notifications bell
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {
                  Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const NotificationScreen()));
                },
              ),
              if (notif.unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF5350),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${notif.unreadCount}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          // User menu - tap toggles expandable panel (no overlay, so content is not covered)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _userMenuExpanded = !_userMenuExpanded),
            child: Container(
              color: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF4FC3F7),
                    child: Text(
                      user.name[0].toUpperCase(),
                      style: const TextStyle(color: Color(0xFF0F1923), fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (isWide) ...[
                    const SizedBox(width: 8),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        Text(user.roleLabel, style: const TextStyle(fontSize: 11, color: Colors.white54)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_userMenuExpanded) _buildUserMenuPanel(context, user, auth),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_userMenuExpanded) setState(() => _userMenuExpanded = false);
              },
              child: _pages[_currentIndex],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() {
          if (i == 1 && _currentIndex != 1) _permitStatusFilter = null;
          _currentIndex = i;
        }),
        backgroundColor: const Color(0xFF162A3E),
        indicatorColor: const Color(0xFF4FC3F7).withValues(alpha: 0.2),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.description_outlined), selectedIcon: Icon(Icons.description), label: 'Permits'),
        ],
      ),
      floatingActionButton: user.role == 'supervisor' || user.role == 'admin'
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PermitFormScreen()));
              },
              backgroundColor: const Color(0xFF4FC3F7),
              foregroundColor: const Color(0xFF0F1923),
              icon: const Icon(Icons.add),
              label: const Text('New Permit', style: TextStyle(fontWeight: FontWeight.w600)),
            )
          : null,
    );
  }
}
