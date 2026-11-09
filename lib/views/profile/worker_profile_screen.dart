// lib/views/profile/worker_profile_screen.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/worker_dashboard_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../services/storage_service.dart';

// ── Design tokens — same as rest of app ──────────────────────────────────────
const _kGreen        = Color(0xFF2E7D32);
const _kGreenDark    = Color(0xFF1B5E20);
const _kGreenLight   = Color(0xFF66BB6A);
const _kGreenSurface = Color(0xFFE8F5E9);
const _kBg           = Color(0xFFF4F6F9);
const _kOrange       = Color(0xFFE65100);
const _kRed          = Color(0xFFC62828);
const _kBlue         = Color(0xFF1565C0);

class WorkerProfileScreen extends StatefulWidget {
  final String workerId;
  final WorkerDashboardViewModel workerVM;

  const WorkerProfileScreen({
    super.key,
    required this.workerId,
    required this.workerVM,
  });

  @override
  State<WorkerProfileScreen> createState() => _WorkerProfileScreenState();
}

class _WorkerProfileScreenState extends State<WorkerProfileScreen> {
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _formKey   = GlobalKey<FormState>();

  Uint8List?  _profileImage;
  bool   _isEditing = false;
  bool   _isSaving  = false;
  final  StorageService _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    _populateFields();
  }

  void _populateFields() {
    final profile = widget.workerVM.workerProfile;
    if (profile != null) {
      _nameCtrl.text  = profile['name']  ?? '';
      _phoneCtrl.text = profile['phone'] ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final result = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: _kGreen),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: _kGreen),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    final picked = await picker.pickImage(source: result, imageQuality: 60, maxWidth: 1024, maxHeight: 1024);
    if (picked != null) {
      // XFile.readAsBytes() works on Android, iOS, AND Web.
      final bytes = await picked.readAsBytes();
      setState(() => _profileImage = bytes);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      String? imageUrl;
      if (_profileImage != null) {
        imageUrl = await _storageService.uploadComplaintImage(
            _profileImage!, widget.workerId);
      }

      final data = <String, dynamic>{
        'name':  _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
      };
      if (imageUrl != null) data['profileImageUrl'] = imageUrl;

      // IMPORTANT: 'workers' documents are keyed by their own random
      // Firestore doc ID, NOT by the worker's Auth UID — those are two
      // different values in this schema (see WorkerDashboardViewModel /
      // AdminDashboardViewModel). widget.workerId here is the Auth UID
      // (passed from WorkerDashboardScreen), so update() must target the
      // resolved profile doc ID instead, or it hits a non-existent
      // document and silently fails.
      final docId =
          widget.workerVM.workerProfile?['id'] as String? ?? widget.workerId;
      final ok = await widget.workerVM.updateProfile(docId, data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? '✅ Profile updated!' : 'Update failed'),
          backgroundColor: ok ? _kGreen : _kRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ));
        if (ok) setState(() => _isEditing = false);
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
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: _kRed),
            child: const Text('Logout',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      Provider.of<AuthViewModel>(context, listen: false).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.workerVM.workerProfile;
    final name    = profile?['name']            as String? ?? 'Worker';
    final email   = profile?['email']           as String? ?? '';
    final phone   = profile?['phone']           as String? ?? '';
    final imgUrl  = profile?['profileImageUrl'] as String?;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'W';

    return Container(
      color: _kBg,
      child: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // ── Hero header (green gradient — matches app theme) ────────
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_kGreenDark, _kGreen, _kGreenLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(32)),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                    child: Column(
                      children: [
                        // Profile image
                        Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    width: 3),
                              ),
                              child: GestureDetector(
                                onTap: _isEditing ? _pickProfileImage : null,
                                child: CircleAvatar(
                                  radius: 44,
                                  backgroundColor:
                                  Colors.white.withValues(alpha: 0.25),
                                  backgroundImage: _profileImage != null
                                      ? MemoryImage(_profileImage!)
                                      : (imgUrl != null
                                      ? NetworkImage(imgUrl)
                                  as ImageProvider
                                      : null),
                                  child: (_profileImage == null &&
                                      imgUrl == null)
                                      ? Text(initial,
                                      style: const TextStyle(
                                          fontSize: 40,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white))
                                      : null,
                                ),
                              ),
                            ),
                            if (_isEditing)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: _pickProfileImage,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: _kGreen, width: 2),
                                    ),
                                    child: const Icon(Icons.camera_alt,
                                        color: _kGreen, size: 16),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        if (email.isNotEmpty)
                          Text(email,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 13)),
                        const SizedBox(height: 12),
                        // Role badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_user_outlined,
                                  color: Colors.white, size: 13),
                              SizedBox(width: 5),
                              Text('FIELD WORKER',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Stats card ───────────────────────────────────────────
              Container(
                margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Row(
                  children: [
                    _StatCell(
                      value: widget.workerVM.totalAssigned.toString(),
                      label: 'Assigned',
                      color: _kBlue,
                      icon: Icons.assignment_outlined,
                    ),
                    _divider(),
                    _StatCell(
                      value: widget.workerVM.totalPending.toString(),
                      label: 'Active',
                      color: _kOrange,
                      icon: Icons.hourglass_empty_rounded,
                    ),
                    _divider(),
                    _StatCell(
                      value: widget.workerVM.totalCompleted.toString(),
                      label: 'Completed',
                      color: _kGreen,
                      icon: Icons.check_circle_outline,
                    ),
                  ],
                ),
              ),

              // ── Profile information card ──────────────────────────────
              Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
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
                          child: const Icon(Icons.person_outline,
                              color: _kGreen, size: 16),
                        ),
                        const SizedBox(width: 8),
                        const Text('Personal Information',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14)),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isEditing = !_isEditing;
                              if (!_isEditing) _populateFields();
                            });
                          },
                          child: Text(
                            _isEditing ? 'Cancel' : 'Edit',
                            style: TextStyle(
                                color: _isEditing ? _kRed : _kGreen,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Name field
                    _FieldLabel('Full Name'),
                    const SizedBox(height: 6),
                    _isEditing
                        ? TextFormField(
                      controller: _nameCtrl,
                      decoration: _inputDec(
                          'Enter your name', Icons.person_outline),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Name is required'
                          : null,
                    )
                        : _FieldValue(name, icon: Icons.badge_outlined),
                    const SizedBox(height: 16),

                    // Phone field
                    _FieldLabel('Phone Number'),
                    const SizedBox(height: 6),
                    _isEditing
                        ? TextFormField(
                      controller: _phoneCtrl,
                      decoration: _inputDec(
                          'Enter phone number', Icons.phone_outlined),
                      keyboardType: TextInputType.phone,
                    )
                        : _FieldValue(
                      phone.isNotEmpty ? phone : 'Not set',
                      icon: Icons.phone_outlined,
                      iconColor: _kBlue,
                    ),

                    const SizedBox(height: 16),

                    // Email (read-only)
                    _FieldLabel('Email'),
                    const SizedBox(height: 6),
                    _FieldValue(
                      email.isNotEmpty ? email : 'Not set',
                      icon: Icons.email_outlined,
                      iconColor: _kOrange,
                    ),

                    // Save button
                    if (_isEditing) ...[
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveProfile,
                          icon: _isSaving
                              ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.save_rounded, size: 18),
                          label: Text(
                            _isSaving ? 'Saving…' : 'Save Changes',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kGreen,
                            foregroundColor: Colors.white,
                            padding:
                            const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Logout button ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _confirmLogout,
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Logout',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kRed,
                      side: BorderSide(color: _kRed.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() => Container(
    width: 1,
    height: 50,
    color: Colors.grey[200],
  );

  InputDecoration _inputDec(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon, size: 20, color: _kGreen),
    filled: true,
    fillColor: _kBg,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _kGreen, width: 1.5),
    ),
    contentPadding:
    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}

// ── Small helpers ─────────────────────────────────────────────────────────

class _StatCell extends StatelessWidget {
  const _StatCell(
      {required this.value,
        required this.label,
        required this.color,
        required this.icon});
  final String   value;
  final String   label;
  final Color    color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: color)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11, color: Colors.grey[500], height: 1.3)),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.grey[600]),
  );
}

class _FieldValue extends StatelessWidget {
  const _FieldValue(this.text, {this.icon, this.iconColor = _kGreen});
  final String    text;
  final IconData? icon;
  final Color     iconColor;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    decoration: BoxDecoration(
      color: _kBg,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500)),
        ),
      ],
    ),
  );
}