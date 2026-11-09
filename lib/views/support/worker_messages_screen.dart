// lib/views/support/worker_messages_screen.dart
//
// Yeh screen worker ke liye hai:
// - Apne bheje hue saare messages dekh sakta hai
// - Kisi bhi message pe tap kare to full chat thread khulta hai
// - Admin ke replies real-time dikhte hain

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';
import 'chat_thread_screen.dart';

const _kGreen        = Color(0xFF2E7D32);
const _kGreenDark    = Color(0xFF1B5E20);
const _kGreenSurface = Color(0xFFE8F5E9);
const _kBg           = Color(0xFFF4F6F9);
const _kRed          = Color(0xFFC62828);

class WorkerMessagesScreen extends StatelessWidget {
  const WorkerMessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authVM  = Provider.of<AuthViewModel>(context, listen: false);
    final uid     = authVM.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text('My Messages',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        backgroundColor: _kGreenDark,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: uid.isEmpty
          ? const Center(child: Text('Not logged in'))
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('worker_messages')
            .where('workerId', isEqualTo: uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _kGreen));
          }

          final docs = snap.data?.docs ?? [];

          if (docs.isEmpty) {
            return _EmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final msgId = docs[i].id;
              return _MessageThreadTile(
                messageId: msgId,
                data:      data,
                workerId:  uid,
              );
            },
          );
        },
      ),
    );
  }
}

// ── Single thread tile ────────────────────────────────────────────────────────
class _MessageThreadTile extends StatelessWidget {
  const _MessageThreadTile({
    required this.messageId,
    required this.data,
    required this.workerId,
  });

  final String             messageId;
  final Map<String, dynamic> data;
  final String             workerId;

  @override
  Widget build(BuildContext context) {
    final message   = data['message']    as String? ?? '';
    final reportId  = data['reportId']   as String? ?? '';
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
    final shortId   = reportId.length > 8 ? reportId.substring(0, 8) : reportId;

    return StreamBuilder<QuerySnapshot>(
      // Listen to replies count — to show "X replies" badge
      stream: FirebaseFirestore.instance
          .collection('worker_messages')
          .doc(messageId)
          .collection('replies')
          .snapshots(),
      builder: (ctx, replySnap) {
        final replies    = replySnap.data?.docs ?? [];
        final replyCount = replies.length;

        // Check if there's any unread admin reply
        final hasNewReply = replies.any((r) {
          final d = r.data() as Map<String, dynamic>;
          return d['role'] == 'admin' &&
              (d['seenByWorker'] == null || d['seenByWorker'] == false);
        });

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatThreadScreen(
                messageId:   messageId,
                reportId:    reportId,
                workerId:    workerId,
                isAdminView: false,
              ),
            ),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: hasNewReply
                  ? const Color(0xFFFFF8E1)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasNewReply
                    ? const Color(0xFFFFCC02)
                    : Colors.grey.shade200,
              ),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: _kGreenSurface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.support_agent_rounded,
                          color: _kGreen, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Message to Admin',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                          Text('Report: $shortId…',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[500])),
                        ],
                      ),
                    ),
                    if (hasNewReply)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _kRed,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('New Reply',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                    const SizedBox(width: 6),
                    if (timestamp != null)
                      Text(_timeAgo(timestamp),
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[400])),
                  ],
                ),

                const SizedBox(height: 10),

                // Message preview
                Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),

                const SizedBox(height: 8),

                // Footer — reply count + open arrow
                Row(
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded,
                        size: 13, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(
                      replyCount == 0
                          ? 'No replies yet'
                          : '$replyCount ${replyCount == 1 ? "reply" : "replies"}',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[500]),
                    ),
                    const Spacer(),
                    Text('Open chat →',
                        style: TextStyle(
                            fontSize: 11,
                            color: _kGreen,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inDays > 0) return '${d.inDays}d ago';
    if (d.inHours > 0) return '${d.inHours}h ago';
    if (d.inMinutes > 0) return '${d.inMinutes}m ago';
    return 'just now';
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _kGreenSurface,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mark_chat_read_outlined,
                size: 48, color: _kGreen),
          ),
          const SizedBox(height: 16),
          const Text('No messages sent yet',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87)),
          const SizedBox(height: 6),
          Text(
            'When you need help on a task,\nuse the "Message Admin" button.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}