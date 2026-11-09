// lib/views/complaint/report_detail_admin_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../models/complaint_model.dart';
import '../../viewmodels/admin_dashboard_viewmodel.dart';
import '../../widgets/smart_image.dart';

const _kPrimary      = Color(0xFF1A237E);
const _kGreen        = Color(0xFF2E7D32);
const _kGreenSurface = Color(0xFFE8F5E9);
const _kOrange       = Color(0xFFE65100);
const _kRed          = Color(0xFFC62828);
const _kBlue         = Color(0xFF1565C0);
const _kBg           = Color(0xFFF0F2F8);

class ReportDetailAdminScreen extends StatefulWidget {
  final ComplaintModel report;
  final List<Map<String, dynamic>> workers;
  final void Function(String wId, String wName) onAssign;

  const ReportDetailAdminScreen({
    super.key,
    required this.report,
    required this.workers,
    required this.onAssign,
  });

  @override
  State<ReportDetailAdminScreen> createState() =>
      _ReportDetailAdminScreenState();
}

class _ReportDetailAdminScreenState extends State<ReportDetailAdminScreen> {
  bool _isUpdating = false;

  Future<void> _changeStatus(String status) async {
    setState(() => _isUpdating = true);
    final adminVM =
    Provider.of<AdminDashboardViewModel>(context, listen: false);
    final ok =
    await adminVM.updateStatus(widget.report.complaintId, status);
    setState(() => _isUpdating = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Status updated to $status' : 'Update failed'),
        backgroundColor: ok ? _kGreen : _kRed,
        behavior: SnackBarBehavior.floating,
      ));
      if (ok) Navigator.pop(context);
    }
  }

  void _showAssignSheet() {
    if (widget.workers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No workers available')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Assign Worker',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          ...widget.workers.map((w) => ListTile(
            leading: CircleAvatar(
              backgroundColor:
              _kPrimary.withValues(alpha: 0.1),
              child: Text(
                (w['name'] as String? ?? 'W')[0].toUpperCase(),
                style: const TextStyle(
                    color: _kPrimary,
                    fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(w['name'] ?? 'Unknown'),
            subtitle: Text(w['phone'] ?? ''),
            trailing: const Icon(Icons.arrow_forward_ios,
                size: 14, color: Colors.grey),
            onTap: () {
              Navigator.pop(context);
              widget.onAssign(
                  (w['effectiveAuthUid'] ?? w['id']) as String,
                  w['name'] ?? 'Worker');
              Navigator.pop(context); // also close detail screen
            },
          )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text('Report Detail',
            style:
            TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (_isUpdating)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Status banner
            _StatusBanner(status: r.status),
            const SizedBox(height: 14),

            // Photo evidence
            if (r.imageUrl != null && r.imageUrl!.isNotEmpty) ...[
              _InfoCard(
                icon: Icons.image_outlined,
                title: 'Photo Evidence',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SmartImage(
                    r.imageUrl!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Core details
            _InfoCard(
              icon: Icons.info_outline_rounded,
              title: 'Report Details',
              child: Column(
                children: [
                  _Row('Category',    r.category,     Icons.category_outlined),
                  _Row('Priority',    r.priority,     Icons.flag_outlined,
                      color: _priorityColor(r.priority)),
                  _Row('Description',
                      r.description.isNotEmpty
                          ? r.description
                          : 'No description',
                      Icons.description_outlined),
                  _Row('Report ID',
                      '#${r.complaintId.substring(0, 8).toUpperCase()}',
                      Icons.tag_rounded,
                      isLast: true),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Citizen info
            _InfoCard(
              icon: Icons.person_outline_rounded,
              title: 'Submitted By',
              child: _Row('User ID',
                  '${r.userId.substring(0, 12)}…',
                  Icons.account_circle_outlined,
                  isLast: true),
            ),
            const SizedBox(height: 14),

            // Location
            _InfoCard(
              icon: Icons.location_on_outlined,
              title: 'Location',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (r.address.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.place_outlined,
                              size: 16, color: _kGreen),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(r.address,
                                style: const TextStyle(
                                    fontSize: 13, height: 1.4)),
                          ),
                        ],
                      ),
                    ),
                  if (r.location != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 180,
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(
                              r.location!.latitude,
                              r.location!.longitude,
                            ),
                            initialZoom: 15,
                            interactionOptions:
                            const InteractionOptions(
                              flags: InteractiveFlag.none,
                            ),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName:
                              'com.example.ecoflux',
                            ),
                            MarkerLayer(markers: [
                              Marker(
                                point: LatLng(
                                  r.location!.latitude,
                                  r.location!.longitude,
                                ),
                                width: 40,
                                height: 40,
                                child: const Icon(
                                    Icons.location_pin,
                                    color: Colors.red,
                                    size: 40),
                              ),
                            ]),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Worker assignment
            _InfoCard(
              icon: Icons.engineering_outlined,
              title: 'Worker Assignment',
              child: r.assignedWorkerName != null
                  ? Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: _kGreenSurface,
                    child: Text(
                      r.assignedWorkerName![0].toUpperCase(),
                      style: const TextStyle(
                          color: _kGreen,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(r.assignedWorkerName!,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14)),
                        Text('Assigned Worker',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500])),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _showAssignSheet,
                    child: const Text('Reassign'),
                  ),
                ],
              )
                  : SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showAssignSheet,
                  icon: const Icon(Icons.person_add_rounded,
                      size: 18),
                  label: const Text('Assign a Worker'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kPrimary,
                    side:
                    const BorderSide(color: _kPrimary),
                    padding: const EdgeInsets.symmetric(
                        vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Completion photo (if resolved)
            if (r.completedImageUrl != null &&
                r.completedImageUrl!.isNotEmpty) ...[
              _InfoCard(
                icon: Icons.check_circle_outline_rounded,
                title: 'Resolution Photo',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SmartImage(
                    r.completedImageUrl!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Admin actions
            if (r.status.toUpperCase() != 'COMPLETED') ...[
              const Text('Admin Actions',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (r.status.toUpperCase() != 'ESCALATED')
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isUpdating
                            ? null
                            : () => _changeStatus('ESCALATED'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kRed,
                          side: const BorderSide(color: _kRed),
                          padding: const EdgeInsets.symmetric(
                              vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(12)),
                        ),
                        child: const Text('Mark Escalated'),
                      ),
                    ),
                  if (r.status.toUpperCase() != 'ESCALATED')
                    const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isUpdating
                          ? null
                          : () => _changeStatus('COMPLETED'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(12)),
                      ),
                      child: const Text('Mark Resolved'),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _imgError() => Container(
    height: 80,
    color: Colors.grey[100],
    child: const Center(
        child: Icon(Icons.broken_image_outlined,
            color: Colors.grey)),
  );

  Color _priorityColor(String p) {
    switch (p.toLowerCase()) {
      case 'high':   return _kRed;
      case 'medium': return _kOrange;
      default:       return _kGreen;
    }
  }
}

// ── Sub widgets ───────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});
  final String status;

  Color get _c {
    switch (status.toUpperCase()) {
      case 'COMPLETED':   return _kGreen;
      case 'IN_PROGRESS': return _kBlue;
      case 'ASSIGNED':    return Colors.blue[600]!;
      case 'ESCALATED':   return _kRed;
      default:            return _kOrange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _c.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, color: _c, size: 12),
          const SizedBox(width: 10),
          Text(
            status.toUpperCase().replaceAll('_', ' '),
            style: TextStyle(
                color: _c,
                fontWeight: FontWeight.w800,
                fontSize: 14,
                letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard(
      {required this.icon, required this.title, required this.child});
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
              offset: const Offset(0, 3))
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
                  borderRadius: BorderRadius.circular(8),
                ),
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

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, this.icon,
      {this.color, this.isLast = false});
  final String   label;
  final String   value;
  final IconData icon;
  final Color?   color;
  final bool     isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: Colors.grey[400]),
          const SizedBox(width: 8),
          SizedBox(
              width: 90,
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500))),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color ?? Colors.black87)),
          ),
        ]),
        if (!isLast) Divider(height: 20, color: Colors.grey[100]),
      ],
    );
  }
}