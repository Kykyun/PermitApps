import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/notification_provider.dart';
import 'permit_detail_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().loadNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final notif = context.watch<NotificationProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (notif.unreadCount > 0)
            TextButton.icon(
              onPressed: () => notif.markAllRead(),
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Read All'),
            ),
        ],
      ),
      body: notif.notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.white24),
                  const SizedBox(height: 16),
                  const Text('No notifications', style: TextStyle(color: Colors.white38)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: notif.notifications.length,
              itemBuilder: (context, index) {
                final n = notif.notifications[index];
                final isRead = n['is_read'] == true;
                final dateFormat = DateFormat('dd MMM, HH:mm');

                return Card(
                  color: isRead ? const Color(0xFF162A3E) : const Color(0xFF1C3550),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isRead ? Colors.white10 : const Color(0xFF4FC3F7).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        n['title']?.toString().contains('Approved') == true
                            ? Icons.check_circle
                            : n['title']?.toString().contains('Rejected') == true
                                ? Icons.cancel
                                : Icons.notifications,
                        color: n['title']?.toString().contains('Approved') == true
                            ? const Color(0xFF66BB6A)
                            : n['title']?.toString().contains('Rejected') == true
                                ? const Color(0xFFEF5350)
                                : const Color(0xFF4FC3F7),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      n['title'] ?? 'Notification',
                      style: TextStyle(
                        fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(n['message'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          n['created_at'] != null ? dateFormat.format(DateTime.parse(n['created_at'])) : '',
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                    onTap: () {
                      if (!isRead) notif.markRead(n['id']);
                      if (n['permit_id'] != null) {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => PermitDetailScreen(permitId: n['permit_id']),
                        ));
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}
