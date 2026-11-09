// lib/views/complaint/worker_report_detail_screen.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../models/complaint_model.dart';
import '../../viewmodels/worker_dashboard_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../services/storage_service.dart';
import '../../widgets/smart_image.dart';


const _kBlue         = Color(0xFF1565C0);
const _kBlueDark     = Color(0xFF0D47A1);
const _kGreen        = Color(0xFF2E7D32);
const _kGreenSurface = Color(0xFFE8F5E9);
const _kOrange       = Color(0xFFE65100);
const _kRed          = Color(0xFFC62828);
const _kBg           = Color(0xFFF0F4F8);

class WorkerReportDetailScreen extends StatefulWidget {
  final ComplaintModel report;
  const WorkerReportDetailScreen({super.key, required this.report});

  @override
  State<WorkerReportDetailScreen> createState() =>
      _WorkerReportDetailScreenState();
}

class _WorkerReportDetailScreenState
    extends State<WorkerReportDetailScreen> {
  bool _isUpdating = false;

  // Resolution images — both are now OPTIONAL
  Uint8List? _beforeImage;
  Uint8List? _afterImage;

  final StorageService _storageService = StorageService();

  // ── Pick image ─────────────────────────────────────────────────────────────
  Future<void> _pickImage(bool isBefore) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.camera, imageQuality: 60, maxWidth: 1024, maxHeight: 1024);
    if (picked != null) {
      // XFile.readAsBytes() works on Android, iOS, AND Web — unlike
      // dart:io File, which throws on Web.
      final bytes = await picked.readAsBytes();
      setState(() {
        if (isBefore) {
          _beforeImage = bytes;
        } else {
          _afterImage = bytes;
        }
      });
    }
  }

  // ── Update status ──────────────────────────────────────────────────────────
  Future<void> _updateStatus(String status) async {
    setState(() => _isUpdating = true);
    final workerVM =
    Provider.of<WorkerDashboardViewModel>(context, listen: false);
    final ok =
    await workerVM.updateReportStatus(widget.report.complaintId, status);
    setState(() => _isUpdating = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Status updated to $status' : 'Update failed'),
        backgroundColor: ok ? _kGreen : _kRed,
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      if (ok) Navigator.pop(context);
    }
  }

  // ── Resolve with optional images ───────────────────────────────────────────
  // Both before and after photos are now optional.
  // If an after photo is provided it is uploaded and stored.
  Future<void> _resolveReport() async {
    setState(() => _isUpdating = true);

    try {
      final authVM =
      Provider.of<AuthViewModel>(context, listen: false);
      final uid = authVM.currentUser?.uid ?? '';

      String? afterUrl;
      if (_afterImage != null) {
        afterUrl =
        await _storageService.uploadComplaintImage(_afterImage!, uid);
      }

      final workerVM =
      Provider.of<WorkerDashboardViewModel>(context, listen: false);
      final ok = await workerVM.resolveReport(
        reportId: widget.report.complaintId,
        completedImageUrl: afterUrl ?? '',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
          Text(ok ? '✅ Report resolved successfully!' : 'Failed to resolve'),
          backgroundColor: ok ? _kGreen : _kRed,
          behavior: SnackBarBehavior.floating,
        ));
        if (ok) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: _kRed,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  // ── Send help message to admin ─────────────────────────────────────────────
  // FIX: capture providers BEFORE opening the bottom sheet so the inner
  // builder callback uses the screen's context, not the sheet's anonymous _.
  // The sheet's _ context has no Provider ancestors and throws a
  // ProviderNotFoundException that was silently caught as "Failed to send".
  void _showHelpSheet() {
    // Capture providers from the screen context NOW, before the sheet opens.
    final authVM   = Provider.of<AuthViewModel>(context, listen: false);
    final workerVM = Provider.of<WorkerDashboardViewModel>(context, listen: false);
    final msgController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          bool sending = false;

          return Padding(
            padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(sheetCtx).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _kRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.support_agent_rounded,
                          color: _kRed, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Text('Request Admin Help',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Regarding: ${widget.report.category}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: msgController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Describe the issue you need help with…',
                    filled: true,
                    fillColor: const Color(0xFFF0F4F8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: sending
                        ? null
                        : () async {
                      final text = msgController.text.trim();
                      if (text.isEmpty) return;

                      setSheetState(() => sending = true);

                      // Use the pre-captured providers — no context lookup inside sheet
                      final ok = await workerVM.sendHelpMessage(
                        workerId:   authVM.currentUser?.uid ?? '',
                        workerName: workerVM.workerProfile?['name'] ??
                            authVM.currentUser?.uid ?? 'Worker',
                        reportId:   widget.report.complaintId,
                        message:    text,
                      );

                      if (mounted) {
                        Navigator.pop(sheetCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok
                                ? '✅ Message sent to admin'
                                : workerVM.errorMessage ??
                                'Failed to send message'),
                            backgroundColor: ok ? _kGreen : _kRed,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    icon: sending
                        ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(sending ? 'Sending…' : 'Send to Admin'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ).whenComplete(() => msgController.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final r     = widget.report;
    final isDone = r.status.toUpperCase() == 'COMPLETED';

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text('Task Detail',
            style:
            TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        backgroundColor: _kBlueDark,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.support_agent_rounded),
            tooltip: 'Get Help',
            onPressed: _showHelpSheet,
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            child: Column(
              children: [
                // Status banner
                _StatusBanner(status: r.status),
                const SizedBox(height: 14),

                // Priority / escalation alert
                if (r.status.toUpperCase() == 'ESCALATED' ||
                    r.priority.toLowerCase() == 'high') ...[
                  _AlertBanner(
                    message: r.status.toUpperCase() == 'ESCALATED'
                        ? '⚠ This report has been escalated. Please handle immediately.'
                        : '🔴 High priority report. Handle as soon as possible.',
                    color: r.status.toUpperCase() == 'ESCALATED'
                        ? _kRed
                        : _kOrange,
                  ),
                  const SizedBox(height: 14),
                ],

                // Report photo
                if (r.imageUrl != null && r.imageUrl!.isNotEmpty) ...[
                  _InfoCard(
                    icon: Icons.image_outlined,
                    title: 'Reported Photo',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SmartImage(
                        r.imageUrl!,
                        height: 190,
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
                      _DetailRow('Category', r.category,
                          Icons.category_outlined),
                      _DetailRow('Priority', r.priority,
                          Icons.flag_outlined,
                          color: _priorityColor(r.priority)),
                      _DetailRow(
                          'Description',
                          r.description.isNotEmpty
                              ? r.description
                              : 'No description provided',
                          Icons.description_outlined,
                          isLast: true),
                    ],
                  ),
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

                // ── Resolution Photos (only when not completed) ─────────────
                // Both before and after photos are OPTIONAL.
                // Uploading an after photo is recommended but not required.
                if (!isDone) ...[
                  _InfoCard(
                    icon: Icons.photo_camera_outlined,
                    title: 'Resolution Photos (Optional)',
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                                child: _ImageUploadBox(
                                  label: 'Before',
                                  image: _beforeImage,
                                  onTap: () => _pickImage(true),
                                )),
                            const SizedBox(width: 10),
                            Expanded(
                                child: _ImageUploadBox(
                                  label: 'After',
                                  image: _afterImage,
                                  onTap: () => _pickImage(false),
                                )),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Photos are optional but help document your work',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Completion photo (shown when report is done)
                if (isDone &&
                    r.completedImageUrl != null &&
                    r.completedImageUrl!.isNotEmpty) ...[
                  _InfoCard(
                    icon: Icons.check_circle_outline_rounded,
                    title: 'Completion Photo',
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
                ],
              ],
            ),
          ),

          // ── Bottom action bar ───────────────────────────────────────────
          if (!isDone)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (r.status.toUpperCase() == 'ASSIGNED')
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isUpdating
                              ? null
                              : () => _updateStatus('IN_PROGRESS'),
                          icon: const Icon(Icons.play_arrow_rounded,
                              size: 20),
                          label: const Text('Start Task',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    if (r.status.toUpperCase() == 'IN_PROGRESS') ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed:
                          _isUpdating ? null : _resolveReport,
                          icon: _isUpdating
                              ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white))
                              : const Icon(
                              Icons.check_circle_rounded,
                              size: 20),
                          label: const Text('Mark as Resolved',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _showHelpSheet,
                        icon: const Icon(
                            Icons.support_agent_rounded,
                            size: 18),
                        label: const Text('Need Help? Message Admin'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kRed,
                          side: const BorderSide(color: _kRed),
                          padding: const EdgeInsets.symmetric(
                              vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _priorityColor(String p) {
    switch (p.toLowerCase()) {
      case 'high':   return _kRed;
      case 'medium': return _kOrange;
      default:       return _kGreen;
    }
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _AlertBanner extends StatelessWidget {
  const _AlertBanner({required this.message, required this.color});
  final String message;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(message,
          style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600)),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});
  final String status;

  Color get _c {
    switch (status.toUpperCase()) {
      case 'COMPLETED':   return _kGreen;
      case 'IN_PROGRESS': return _kBlue;
      case 'ESCALATED':   return _kRed;
      default:            return _kOrange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _c.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, color: _c, size: 10),
          const SizedBox(width: 8),
          Text(status.toUpperCase().replaceAll('_', ' '),
              style: TextStyle(
                  color: _c,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5)),
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
  const _DetailRow(this.label, this.value, this.icon,
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

class _ImageUploadBox extends StatelessWidget {
  const _ImageUploadBox({
    required this.label,
    required this.image,
    required this.onTap,
  });
  final String       label;
  final Uint8List?    image;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: image != null ? null : const Color(0xFFF0F4F8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: image != null
                  ? _kGreen
                  : Colors.grey[300]!),
          image: image != null
              ? DecorationImage(
              image: MemoryImage(image!), fit: BoxFit.cover)
              : null,
        ),
        child: image == null
            ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined,
                color: Colors.grey[400], size: 28),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text('Optional',
                style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 10)),
          ],
        )
            : Align(
          alignment: Alignment.bottomLeft,
          child: Container(
            margin: const EdgeInsets.all(6),
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _kGreen,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}