// lib/views/notifications/notifications_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/notification_model.dart';
import '../../viewmodels/notification_viewmodel.dart';
import '../../widgets/common/empty_state_widget.dart';

const _kGreen = Color(0xFF2E7D32);
const _kBg    = Color(0xFFF4F6F9);

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && mounted) {
        context.read<NotificationViewModel>().listenToNotifications(uid);
      }
    });
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'report_assigned':
        return Icons.assignment_turned_in_rounded;
      case 'status_update':
        return Icons.sync_rounded;
      case 'escalation':
        return Icons.warning_rounded;
      case 'help_request':
        return Icons.support_agent_rounded;
      case 'feedback_received':
        return Icons.rate_review_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'report_assigned':
        return const Color(0xFF1565C0);
      case 'status_update':
        return _kGreen;
      case 'escalation':
        return const Color(0xFFC62828);
      case 'help_request':
        return const Color(0xFFE65100);
      case 'feedback_received':
        return const Color(0xFF6A1B9A);
      default:
        return Colors.grey;
    }
  }

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NotificationViewModel>();
    final notifications = vm.notifications;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text('Notifications',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        backgroundColor: _kGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (vm.unreadCount > 0)
            TextButton(
              onPressed: () => vm.markAllAsRead(),
              child: const Text('Mark all read',
                  style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: vm.isLoading && notifications.isEmpty
          ? const Center(child: CircularProgressIndicator(color: _kGreen))
          : notifications.isEmpty
          ? const EmptyStateWidget(
        title: 'No notifications yet',
        subtitle:
        'Updates about your reports, assignments, and alerts will show up here.',
        icon: Icons.notifications_none_rounded,
      )
          : ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: notifications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final n = notifications[i];
          return _NotificationTile(
            notification: n,
            icon: _iconFor(n.type),
            color: _colorFor(n.type),
            timeAgo: _timeAgo(n.timestamp),
            onTap: () {
              if (!n.isRead) {
                context.read<NotificationViewModel>().markAsRead(n.notificationId);
              }
            },
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final IconData icon;
  final Color color;
  final String timeAgo;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.icon,
    required this.color,
    required this.timeAgo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    return Material(
      color: unread ? color.withValues(alpha: 0.06) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: unread ? color.withValues(alpha: 0.25) : Colors.grey.shade200,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notification.body,
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      timeAgo,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              if (unread)
                Container(
                  margin: const EdgeInsets.only(top: 4, left: 4),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}