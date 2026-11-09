// lib/widgets/common/notification_bell.dart
//
// Drop this into any AppBar / header row:
//   NotificationBell(userId: authVM.currentUser?.uid ?? '')
//
// It starts listening to that user's notifications the moment it's built,
// shows a red badge with the unread count, and opens NotificationsScreen
// on tap.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/notification_viewmodel.dart';
import '../../views/notifications/notifications_screen.dart';

class NotificationBell extends StatefulWidget {
  final String userId;
  final Color iconColor;

  const NotificationBell({
    super.key,
    required this.userId,
    this.iconColor = Colors.white70,
  });

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.userId.isEmpty) return;
      context.read<NotificationViewModel>().listenToNotifications(widget.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = context.watch<NotificationViewModel>().unreadCount;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(Icons.notifications_rounded, color: widget.iconColor),
          tooltip: 'Notifications',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            );
          },
        ),
        if (unreadCount > 0)
          Positioned(
            right: 6,
            top: 6,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: Text(
                  unreadCount > 9 ? '9+' : '$unreadCount',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}