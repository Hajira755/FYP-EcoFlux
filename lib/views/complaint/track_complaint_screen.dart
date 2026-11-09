// lib/views/complaint/track_complaint_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../viewmodels/complaint_viewmodel.dart';
import '../../models/complaint_model.dart';
import '../../core/constants/app_constants.dart';
import '../../widgets/smart_image.dart';


const _kGreen        = Color(0xFF2E7D32);
const _kGreenSurface = Color(0xFFE8F5E9);
const _kBg           = Color(0xFFF4F6F9);

class TrackComplaintScreen extends StatelessWidget {
  /// If [complaintId] is provided  → single report tracking view.
  /// If [complaintId] is null       → full list of user's reports.
  final String? complaintId;

  const TrackComplaintScreen({super.key, this.complaintId});

  @override
  Widget build(BuildContext context) {
    return complaintId != null && complaintId!.isNotEmpty
        ? _SingleTrackView(complaintId: complaintId!)
        : const _AllReportsView();
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  MODE A — Single report real-time tracking
// ══════════════════════════════════════════════════════════════════════════════

class _SingleTrackView extends StatelessWidget {
  const _SingleTrackView({required this.complaintId});
  final String complaintId;

  @override
  Widget build(BuildContext context) {
    final complaintVM = Provider.of<ComplaintViewModel>(context, listen: false);

    return Scaffold(
      backgroundColor: _kBg,
      appBar: _buildAppBar('Track Report'),
      body: StreamBuilder<DocumentSnapshot>(
        stream: complaintVM.getComplaintStream(complaintId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _kGreen));
          }
          if (snapshot.hasError) {
            return _ErrorState(message: snapshot.error.toString());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const _ErrorState(message: 'Report not found.');
          }

          final report = ComplaintModel.fromMap(
            snapshot.data!.data() as Map<String, dynamic>,
            complaintId,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Status banner
                _StatusBanner(status: report.status),
                const SizedBox(height: 14),

                // Core info card
                _InfoCard(
                  icon: Icons.info_outline_rounded,
                  title: 'Report Details',
                  child: Column(
                    children: [
                      _DetailRow(
                        icon: Icons.category_outlined,
                        label: 'Category',
                        value: report.category,
                      ),
                      _DetailRow(
                        icon: Icons.flag_outlined,
                        label: 'Priority',
                        value: report.priority,
                        valueColor: _priorityColor(report.priority),
                      ),
                      _DetailRow(
                        icon: Icons.place_outlined,
                        label: 'Address',
                        value: report.address.isNotEmpty
                            ? report.address
                            : 'Not set',
                      ),
                      if (report.description.isNotEmpty)
                        _DetailRow(
                          icon: Icons.description_outlined,
                          label: 'Description',
                          value: report.description,
                          isLast: true,
                        )
                      else
                        _DetailRow(
                          icon: Icons.tag_rounded,
                          label: 'Report ID',
                          value:
                          '#${complaintId.length > 8 ? complaintId.substring(0, 8).toUpperCase() : complaintId.toUpperCase()}',
                          isLast: true,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Timeline
                _InfoCard(
                  icon: Icons.timeline_rounded,
                  title: 'Progress Timeline',
                  child: _buildTimeline(report),
                ),

                // Worker card
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
                                color: _kGreen,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(report.assignedWorkerName!,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
                            Text('Waste Collection Worker',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500])),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                // Completed image
                if (report.completedImageUrl != null &&
                    report.completedImageUrl!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _InfoCard(
                    icon: Icons.check_circle_outline_rounded,
                    title: 'Completion Photo',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SmartImage(
                        report.completedImageUrl!,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeline(ComplaintModel report) {
    final steps = [
      _TimelineStep(
        label: 'Submitted',
        subtitle: report.timestamp != null
            ? _formatDate(report.timestamp!.toDate())
            : '',
        isDone: true,
        color: Colors.blue,
      ),
      _TimelineStep(
        label: 'Assigned',
        subtitle: report.assignedWorkerName ?? 'Pending assignment',
        isDone: report.assignedWorkerId != null,
        color: Colors.orange,
      ),
      _TimelineStep(
        label: 'In Progress',
        subtitle: 'Worker is on the way',
        isDone: ['IN_PROGRESS', 'COMPLETED']
            .contains(report.status.toUpperCase()),
        color: Colors.blue[700]!,
      ),
      _TimelineStep(
        label: 'Resolved',
        subtitle: report.lastUpdated != null &&
            report.status.toUpperCase() == 'COMPLETED'
            ? _formatDate(report.lastUpdated!.toDate())
            : 'Not yet resolved',
        isDone: report.status.toUpperCase() == 'COMPLETED',
        color: _kGreen,
      ),
    ];

    return Column(
      children: List.generate(steps.length, (i) {
        final s = steps[i];
        return _TimelineRow(
          step: s,
          isFirst: i == 0,
          isLast: i == steps.length - 1,
        );
      }),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  MODE B — All reports list (when complaintId is null)
// ══════════════════════════════════════════════════════════════════════════════

class _AllReportsView extends StatefulWidget {
  const _AllReportsView();

  @override
  State<_AllReportsView> createState() => _AllReportsViewState();
}

class _AllReportsViewState extends State<_AllReportsView> {
  String _filter = 'All';
  final List<String> _filters = [
    'All', 'Pending', 'Assigned', 'In Progress', 'Completed', 'Escalated'
  ];

  @override
  Widget build(BuildContext context) {
    final complaintVM = Provider.of<ComplaintViewModel>(context);
    final all = complaintVM.userComplaints;

    final filtered = _filter == 'All'
        ? all
        : all.where((c) =>
    c.status.toUpperCase() ==
        _filter.toUpperCase().replaceAll(' ', '_')).toList();

    return Scaffold(
      backgroundColor: _kBg,
      appBar: _buildAppBar('My Reports'),
      body: Column(
        children: [
          // Filter chips
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final f = _filters[i];
                final selected = _filter == f;
                return GestureDetector(
                  onTap: () => setState(() => _filter = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? _kGreen : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: selected ? _kGreen : Colors.grey[300]!),
                    ),
                    child: Text(
                      f,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.grey[700],
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Count
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Text(
                  '${filtered.length} report${filtered.length != 1 ? 's' : ''}',
                  style:
                  TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: complaintVM.isLoading && all.isEmpty
                ? const Center(
                child: CircularProgressIndicator(color: _kGreen))
                : filtered.isEmpty
                ? _EmptyState(filter: _filter)
                : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: filtered.length,
              separatorBuilder: (_, __) =>
              const SizedBox(height: 10),
              itemBuilder: (_, i) =>
                  _ReportTile(report: filtered[i]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Report tile (tappable → ReportDetailScreen) ────────────────────────────

class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.report});
  final ComplaintModel report;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.pushNamed(
          context,
          AppConstants.reportDetailRoute,
          arguments: report,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Icon bubble
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: report.statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_categoryIcon(report.category),
                    color: report.statusColor, size: 22),
              ),
              const SizedBox(width: 12),
              // Title + address + date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(report.category,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 12, color: Colors.grey[400]),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            report.address.isNotEmpty
                                ? report.address
                                : 'Location not set',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[500]),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (report.timestamp != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        _formatDate(report.timestamp!.toDate()),
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[400]),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Status badge
              _StatusBadge(status: report.status),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'Overflowing Bin':   return Icons.delete_outline;
      case 'Illegal Dumping':   return Icons.warning_amber_outlined;
      case 'Uncollected Waste': return Icons.recycling;
      default:                  return Icons.report_gmailerrorred_outlined;
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Shared small widgets
// ══════════════════════════════════════════════════════════════════════════════

PreferredSizeWidget _buildAppBar(String title) => AppBar(
  title: Text(title,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
  backgroundColor: _kGreen,
  foregroundColor: Colors.white,
  elevation: 0,
  centerTitle: true,
);

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
      case 'ASSIGNED':    return 'A worker has been assigned to this report.';
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
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.isLast = false,
  });
  final IconData icon;
  final String   label;
  final String   value;
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

// ── Timeline ────────────────────────────────────────────────────────────────

class _TimelineStep {
  const _TimelineStep({
    required this.label,
    required this.subtitle,
    required this.isDone,
    required this.color,
  });
  final String label;
  final String subtitle;
  final bool   isDone;
  final Color  color;
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.step,
    required this.isFirst,
    required this.isLast,
  });
  final _TimelineStep step;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = step.isDone ? step.color : Colors.grey[300]!;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                if (!isFirst)
                  Expanded(
                      child: Container(
                          width: 2,
                          color: step.isDone
                              ? step.color.withValues(alpha: 0.4)
                              : Colors.grey[200]))
                else
                  const SizedBox(height: 4),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: step.isDone ? color : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: step.isDone
                      ? const Icon(Icons.check, size: 8, color: Colors.white)
                      : null,
                ),
                if (!isLast)
                  Expanded(
                      child: Container(
                          width: 2, color: Colors.grey[200]))
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
                  Text(step.label,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: step.isDone
                              ? Colors.black87
                              : Colors.grey[400])),
                  const SizedBox(height: 2),
                  Text(step.subtitle,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[500])),
                  if (!isLast) const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
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

  String get _label {
    switch (status.toUpperCase()) {
      case 'COMPLETED':   return 'Done';
      case 'IN_PROGRESS': return 'Active';
      case 'ASSIGNED':    return 'Assigned';
      case 'ESCALATED':   return 'Escalated';
      default:            return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Text(_label,
          style: TextStyle(
              color: _color,
              fontSize: 11,
              fontWeight: FontWeight.w700)),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter});
  final String filter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 56, color: Colors.grey[300]),
          const SizedBox(height: 14),
          Text(
            filter == 'All'
                ? 'No reports yet'
                : 'No $filter reports',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[500]),
          ),
          const SizedBox(height: 6),
          Text(
            filter == 'All'
                ? "Tap 'New Report' to submit your first report."
                : 'Try a different filter.',
            style: TextStyle(fontSize: 13, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 56, color: Colors.red[300]),
            const SizedBox(height: 14),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Color _priorityColor(String p) {
  switch (p.toLowerCase()) {
    case 'high':   return Colors.red[700]!;
    case 'medium': return Colors.orange[700]!;
    default:       return Colors.green[700]!;
  }
}

String _formatDate(DateTime dt) {
  const mo = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  final h    = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final min  = dt.minute.toString().padLeft(2, '0');
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
  return '${dt.day} ${mo[dt.month]} ${dt.year}, $h:$min $ampm';
}