// lib/views/support/chat_thread_screen.dart
//
// Yeh SHARED chat screen hai — dono worker aur admin use karte hain
// isAdminView: false  → worker dekh raha hai
// isAdminView: true   → admin dekh raha hai
//
// Firestore structure:
//   worker_messages/{messageId}/replies/{replyId}
//     senderId, senderName, role ('worker'/'admin'), message,
//     timestamp, seenByWorker

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';

const _kGreen        = Color(0xFF2E7D32);
const _kGreenDark    = Color(0xFF1B5E20);
const _kGreenSurface = Color(0xFFE8F5E9);
const _kBg           = Color(0xFFF4F6F9);
const _kBlue         = Color(0xFF1565C0);
const _kRed          = Color(0xFFC62828);

class ChatThreadScreen extends StatefulWidget {
  final String messageId;
  final String reportId;
  final String workerId;
  final bool   isAdminView;

  const ChatThreadScreen({
    super.key,
    required this.messageId,
    required this.reportId,
    required this.workerId,
    required this.isAdminView,
  });

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final TextEditingController _msgCtrl   = TextEditingController();
  final ScrollController      _scrollCtrl = ScrollController();
  bool _sending = false;

  // Firestore refs
  late final DocumentReference _threadRef;
  late final CollectionReference _repliesRef;

  @override
  void initState() {
    super.initState();
    _threadRef  = FirebaseFirestore.instance
        .collection('worker_messages')
        .doc(widget.messageId);
    _repliesRef = _threadRef.collection('replies');

    // Mark all admin replies as seen when worker opens the chat
    if (!widget.isAdminView) {
      _markAdminRepliesSeen();
    }
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // Mark admin replies as seen by worker
  Future<void> _markAdminRepliesSeen() async {
    final snap = await _repliesRef
        .where('role', isEqualTo: 'admin')
        .where('seenByWorker', isEqualTo: false)
        .get();
    for (final doc in snap.docs) {
      await doc.reference.update({'seenByWorker': true});
    }
  }

  // Send a reply
  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _msgCtrl.clear();

    try {
      final authVM    = Provider.of<AuthViewModel>(context, listen: false);
      final uid       = authVM.currentUser?.uid ?? '';
      final role      = widget.isAdminView ? 'admin' : 'worker';
      final senderName = widget.isAdminView ? 'Admin' : 'Worker';

      await _repliesRef.add({
        'senderId':      uid,
        'senderName':    senderName,
        'role':          role,
        'message':       text,
        'timestamp':     FieldValue.serverTimestamp(),
        'seenByWorker':  widget.isAdminView ? false : true,
      });

      // If admin replies, mark main thread as "has reply"
      if (widget.isAdminView) {
        await _threadRef.update({
          'hasAdminReply':    true,
          'lastReplyAt':      FieldValue.serverTimestamp(),
          'lastReplyMessage': text,
        });
      }

      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to send: $e'),
          backgroundColor: _kRed,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shortId = widget.reportId.length > 8
        ? widget.reportId.substring(0, 8)
        : widget.reportId;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isAdminView ? 'Worker Chat' : 'Admin Support',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 15),
            ),
            Text(
              'Report: $shortId…',
              style: const TextStyle(
                  fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: _kGreenDark,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Original worker message (first message context)
          _OriginalMessageBanner(threadRef: _threadRef),

          // Chat replies stream
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _repliesRef
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: _kGreen));
                }

                final docs = snap.data?.docs ?? [];

                if (docs.isEmpty) {
                  return _NoRepliesYet(
                      isAdminView: widget.isAdminView);
                }

                // Auto-scroll to bottom when new message arrives
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollCtrl.hasClients) {
                    _scrollCtrl.animateTo(
                      _scrollCtrl.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                    );
                  }
                });

                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) {
                    final d    = docs[i].data() as Map<String, dynamic>;
                    final role = d['role'] as String? ?? 'worker';

                    // Bubble alignment:
                    // Worker view: worker=right, admin=left
                    // Admin view:  admin=right, worker=left
                    final isMe = widget.isAdminView
                        ? role == 'admin'
                        : role == 'worker';

                    return _ChatBubble(
                      data:  d,
                      isMe:  isMe,
                      role:  role,
                    );
                  },
                );
              },
            ),
          ),

          // Input bar
          _InputBar(
            controller: _msgCtrl,
            sending:    _sending,
            onSend:     _send,
            isAdminView: widget.isAdminView,
          ),
        ],
      ),
    );
  }
}

// ── Original message banner ───────────────────────────────────────────────────
class _OriginalMessageBanner extends StatelessWidget {
  const _OriginalMessageBanner({required this.threadRef});
  final DocumentReference threadRef;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: threadRef.snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const SizedBox();
        final d       = snap.data!.data() as Map<String, dynamic>? ?? {};
        final msg     = d['message']    as String? ?? '';
        final name    = d['workerName'] as String? ?? 'Worker';
        final ts      = (d['timestamp'] as Timestamp?)?.toDate();
        final timeStr = ts != null ? _fmt(ts) : '';

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _kGreenSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: const Color(0xFF2E7D32).withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: _kGreen, size: 13),
                  const SizedBox(width: 5),
                  Text('Original message from $name',
                      style: const TextStyle(
                          fontSize: 11,
                          color: _kGreen,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text(timeStr,
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey[500])),
                ],
              ),
              const SizedBox(height: 4),
              Text(msg,
                  style: const TextStyle(fontSize: 13, height: 1.4)),
            ],
          ),
        );
      },
    );
  }

  String _fmt(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inDays > 0) return '${d.inDays}d ago';
    if (d.inHours > 0) return '${d.inHours}h ago';
    if (d.inMinutes > 0) return '${d.inMinutes}m ago';
    return 'just now';
  }
}

// ── Chat bubble ───────────────────────────────────────────────────────────────
class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.data,
    required this.isMe,
    required this.role,
  });

  final Map<String, dynamic> data;
  final bool   isMe;
  final String role;

  @override
  Widget build(BuildContext context) {
    final message    = data['message']    as String? ?? '';
    final senderName = data['senderName'] as String? ?? role;
    final ts         = (data['timestamp'] as Timestamp?)?.toDate();
    final timeStr    = ts != null ? _timeStr(ts) : '';
    final seenByWorker = data['seenByWorker'] as bool? ?? true;

    final bubbleColor  = isMe ? _kGreen : Colors.white;
    final textColor    = isMe ? Colors.white : Colors.black87;
    final nameColor    = role == 'admin' ? _kBlue : _kGreen;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
        isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar (only for other person)
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor:
              role == 'admin' ? Colors.blue[50] : _kGreenSurface,
              child: Text(
                senderName[0].toUpperCase(),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: role == 'admin' ? _kBlue : _kGreen),
              ),
            ),
            const SizedBox(width: 6),
          ],

          // Bubble
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft:     const Radius.circular(16),
                  topRight:    const Radius.circular(16),
                  bottomLeft:  Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Text(
                      senderName,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: nameColor),
                    ),
                  if (!isMe) const SizedBox(height: 3),
                  Text(message,
                      style: TextStyle(
                          fontSize: 14,
                          color: textColor,
                          height: 1.4)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeStr,
                        style: TextStyle(
                            fontSize: 10,
                            color: isMe
                                ? Colors.white.withValues(alpha: 0.7)
                                : Colors.grey[400]),
                      ),
                      // Read receipt (only for sent messages by admin)
                      if (isMe && role == 'admin') ...[
                        const SizedBox(width: 4),
                        Icon(
                          seenByWorker
                              ? Icons.done_all_rounded
                              : Icons.done_rounded,
                          size: 13,
                          color: seenByWorker
                              ? Colors.lightBlueAccent
                              : Colors.white.withValues(alpha: 0.7),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Avatar (only for me)
          if (isMe) ...[
            const SizedBox(width: 6),
            CircleAvatar(
              radius: 14,
              backgroundColor:
              role == 'admin' ? Colors.blue[50] : _kGreenSurface,
              child: Text(
                senderName[0].toUpperCase(),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: role == 'admin' ? _kBlue : _kGreen),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _timeStr(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ── Empty replies state ───────────────────────────────────────────────────────
class _NoRepliesYet extends StatelessWidget {
  const _NoRepliesYet({required this.isAdminView});
  final bool isAdminView;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline_rounded,
              size: 40, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text(
            isAdminView
                ? 'Reply to the worker below'
                : 'No reply yet from admin.\nWait or send another message.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

// ── Input bar ─────────────────────────────────────────────────────────────────
class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.isAdminView,
  });

  final TextEditingController controller;
  final bool         sending;
  final VoidCallback onSend;
  final bool         isAdminView;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          12, 10, 12, MediaQuery.of(context).viewInsets.bottom + 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 10,
              offset: const Offset(0, -3))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: 4,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: isAdminView
                    ? 'Reply to worker…'
                    : 'Write a message…',
                hintStyle:
                TextStyle(color: Colors.grey[400], fontSize: 14),
                filled:    true,
                fillColor: _kBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide:   BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: sending ? null : onSend,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width:  46,
              height: 46,
              decoration: BoxDecoration(
                color: sending
                    ? Colors.grey[300]
                    : isAdminView
                    ? _kBlue
                    : _kGreen,
                shape: BoxShape.circle,
              ),
              child: sending
                  ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}