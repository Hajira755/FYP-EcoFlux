// lib/views/complaint/report_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';                    // NEW
import '../../models/complaint_model.dart';
import '../../viewmodels/feedback_viewmodel.dart';           // NEW
import '../../core/navigation/app_routes.dart';
import '../../widgets/smart_image.dart';

const _kGreen        = Color(0xFF2E7D32);
const _kGreenSurface = Color(0xFFE8F5E9);

/// Pass a [ComplaintModel] as route arguments:
/// ```dart
/// Navigator.pushNamed(context, AppRoutes.reportDetail, arguments: report);
/// ```
class ReportDetailScreen extends StatefulWidget {
  const ReportDetailScreen({super.key});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  // ── NEW: report-specific feedback state ──────────────────────────────────
  bool _feedbackAlreadyGiven = false;
  bool _checkedFeedback = false;

  Future<void> _checkFeedbackStatus(String reportId) async {
    if (_checkedFeedback) return;
    _checkedFeedback = true;
    final feedbackVM = Provider.of<FeedbackViewModel>(context, listen: false);
    final given = await feedbackVM.hasFeedbackForReport(reportId);
    if (mounted) setState(() => _feedbackAlreadyGiven = given);
  }
  // ── END NEW ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final report =
    ModalRoute.of(context)!.settings.arguments as ComplaintModel;

    // NEW — check once (per screen load) whether feedback already exists
    // for this specific report, but only if it's actually completed.
    if (report.status.toUpperCase() == 'COMPLETED') {
      _checkFeedbackStatus(report.complaintId);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('Report Details',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        backgroundColor: _kGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _StatusBanner(status: report.status),
            const SizedBox(height: 14),

            // ── Photo ──────────────────────────────────────────────────────
            if (report.imageUrl != null && report.imageUrl!.isNotEmpty) ...[
              _InfoCard(
                icon: Icons.image_outlined,
                title: 'Photo Evidence',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SmartImage(
                    report.imageUrl!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // ── Core details ───────────────────────────────────────────────
            _InfoCard(
              icon: Icons.info_outline_rounded,
              title: 'Report Details',
              child: Column(
                children: [
                  _DetailRow(
                    label: 'Category',
                    value: report.category,
                    icon: Icons.category_outlined,
                  ),
                  _DetailRow(
                    label: 'Description',
                    value: report.description.isNotEmpty
                        ? report.description
                        : 'No description provided.',
                    icon: Icons.description_outlined,
                  ),
                  _DetailRow(
                    label: 'Priority',
                    value: report.priority,
                    icon: Icons.flag_outlined,
                    valueColor: _priorityColor(report.priority),
                  ),
                  _DetailRow(
                    label: 'Report ID',
                    value:
                    '#${report.complaintId.length > 8 ? report.complaintId.substring(0, 8).toUpperCase() : report.complaintId.toUpperCase()}',
                    icon: Icons.tag_rounded,
                    isLast: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Location ───────────────────────────────────────────────────
            _InfoCard(
              icon: Icons.location_on_outlined,
              title: 'Location',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (report.address.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.place_outlined,
                              size: 16, color: _kGreen),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(report.address,
                                style: const TextStyle(
                                    fontSize: 13, height: 1.4)),
                          ),
                        ],
                      ),
                    ),
                  if (report.location != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 180,
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(
                              report.location!.latitude,
                              report.location!.longitude,
                            ),
                            initialZoom: 15,
                            interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.none,
                            ),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.example.ecoflux',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(
                                    report.location!.latitude,
                                    report.location!.longitude,
                                  ),
                                  width: 40,
                                  height: 40,
                                  child: const Icon(Icons.location_pin,
                                      color: Colors.red, size: 40),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text('Location not available',
                            style: TextStyle(color: Colors.grey)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Timeline ───────────────────────────────────────────────────
            _InfoCard(
              icon: Icons.timeline_rounded,
              title: 'Timeline',
              child: Column(
                children: [
                  _TimelineItem(
                    dot: Colors.blue,
                    title: 'Report Submitted',
                    subtitle: report.timestamp != null
                        ? _formatDate(report.timestamp!.toDate())
                        : 'Unknown',
                    isFirst: true,
                  ),
                  if (report.assignedWorkerName != null)
                    _TimelineItem(
                      dot: Colors.orange,
                      title: 'Assigned to Worker',
                      subtitle: report.assignedWorkerName!,
                    ),
                  if (report.status.toUpperCase() == 'COMPLETED')
                    _TimelineItem(
                      dot: _kGreen,
                      title: 'Resolved',
                      subtitle: report.lastUpdated != null
                          ? _formatDate(report.lastUpdated!.toDate())
                          : 'Completed',
                      isLast: true,
                    )
                  else
                    _TimelineItem(
                      dot: Colors.grey[300]!,
                      title: 'Awaiting Resolution',
                      subtitle: _statusDescription(report.status),
                      isLast: true,
                      isPending: true,
                    ),
                ],
              ),
            ),

            // ── Assigned worker ────────────────────────────────────────────
            if (report.assignedWorkerName != null) ...[
              const SizedBox(height: 14),
              _InfoCard(
                icon: Icons.engineering_outlined,
                title: 'Assigned Worker',
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: _kGreenSurface,
                      child: Text(
                        report.assignedWorkerName![0].toUpperCase(),
                        style: const TextStyle(
                            color: _kGreen, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(report.assignedWorkerName!,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        Text('Waste Collection Worker',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[500])),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            // ── NEW: Give Feedback (only when report is COMPLETED) ─────────
            if (report.status.toUpperCase() == 'COMPLETED') ...[
              const SizedBox(height: 14),
              if (_feedbackAlreadyGiven)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded,
                          color: Colors.grey, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'You already submitted feedback for this report.',
                        style: TextStyle(
                            color: Colors.grey, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.pushNamed(
                        context,
                        AppRoutes.feedback,
                        arguments: {
                          'reportId': report.complaintId,
                          'reportCategory': report.category,
                        },
                      );
                      // Re-check after returning, in case feedback was
                      // just submitted on the feedback screen.
                      setState(() => _checkedFeedback = false);
                    },
                    icon: const Icon(Icons.rate_review_rounded),
                    label: const Text('Give Feedback for This Report'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
            ],
            // ── END NEW ──────────────────────────────────────────────────────

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Color _priorityColor(String p) {
    switch (p.toLowerCase()) {
      case 'high':   return Colors.red[700]!;
      case 'medium': return Colors.orange[700]!;
      default:       return Colors.green[700]!;
    }
  }

  String _statusDescription(String s) {
    switch (s.toUpperCase()) {
      case 'PENDING':     return 'Waiting to be assigned';
      case 'ASSIGNED':    return 'A worker has been assigned';
      case 'IN_PROGRESS': return 'Worker is on the way';
      case 'ESCALATED':   return 'Escalated to supervisor';
      default:            return s;
    }
  }

  String _formatDate(DateTime dt) {
    const mo = ['','Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'];
    final h    = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min  = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day} ${mo[dt.month]} ${dt.year}, $h:$min $ampm';
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});
  final String status;

  Color get _color {
    switch (status.toUpperCase()) {
      case 'COMPLETED':   return Colors.green[700]!;
      case 'IN_PROGRESS': return Colors.blue[700]!;
      case 'ASSIGNED':    return Colors.blue[600]!;
      case 'ESCALATED':   return Colors.red[700]!;
      default:            return Colors.orange[700]!;
    }
  }

  IconData get _icon {
    switch (status.toUpperCase()) {
      case 'COMPLETED':   return Icons.check_circle_rounded;
      case 'IN_PROGRESS': return Icons.sync_rounded;
      case 'ASSIGNED':    return Icons.person_pin_circle_rounded;
      case 'ESCALATED':   return Icons.warning_rounded;
      default:            return Icons.pending_rounded;
    }
  }

  String get _message {
    switch (status.toUpperCase()) {
      case 'COMPLETED':   return 'This report has been resolved.';
      case 'IN_PROGRESS': return 'A worker is actively handling this.';
      case 'ASSIGNED':    return 'A worker has been assigned.';
      case 'ESCALATED':   return 'This report has been escalated.';
      default:            return 'Your report is in the queue.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(_icon, color: _color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.toUpperCase().replaceAll('_', ' '),
                  style: TextStyle(
                      color: _color,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 0.5),
                ),
                Text(_message,
                    style: TextStyle(
                        fontSize: 12,
                        color: _color.withValues(alpha: 0.8))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.child,
  });
  final IconData icon;
  final String   title;
  final Widget   child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: _kGreenSurface,
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: _kGreen, size: 16),
              ),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
    this.isLast = false,
  });
  final String   label;
  final String   value;
  final IconData icon;
  final Color?   valueColor;
  final bool     isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: Colors.grey[400]),
            const SizedBox(width: 8),
            SizedBox(
              width: 90,
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500)),
            ),
            Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: valueColor ?? Colors.black87)),
            ),
          ],
        ),
        if (!isLast) Divider(height: 20, color: Colors.grey[100]),
      ],
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.dot,
    required this.title,
    required this.subtitle,
    this.isFirst   = false,
    this.isLast    = false,
    this.isPending = false,
  });
  final Color  dot;
  final String title;
  final String subtitle;
  final bool   isFirst;
  final bool   isLast;
  final bool   isPending;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                if (!isFirst)
                  Expanded(
                      child: Container(width: 2, color: Colors.grey[200]))
                else
                  const SizedBox(height: 4),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isPending ? Colors.transparent : dot,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isPending ? Colors.grey[300]! : dot,
                      width: 2,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                      child: Container(width: 2, color: Colors.grey[200]))
                else
                  const SizedBox(height: 4),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: isPending
                              ? Colors.grey[400]
                              : Colors.black87)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style:
                      TextStyle(fontSize: 12, color: Colors.grey[500])),
                  if (!isLast) const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}