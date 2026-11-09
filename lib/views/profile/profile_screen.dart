// lib/views/profile/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/citizen_dashboard_viewmodel.dart';
import '../../viewmodels/complaint_viewmodel.dart';
import '../../services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ── Design tokens — same as rest of app ──────────────────────────────────────
const _kGreen        = Color(0xFF2E7D32);
const _kGreenDark    = Color(0xFF1B5E20);
const _kGreenLight   = Color(0xFF66BB6A);
const _kGreenSurface = Color(0xFFE8F5E9);
const _kBg           = Color(0xFFF4F6F9);
const _kOrange       = Color(0xFFE65100);
const _kRed          = Color(0xFFC62828);
const _kBlue         = Color(0xFF1565C0);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    Provider.of<ProfileViewModel>(context, listen: false).loadUserProfile();

    // ── Load live complaint counts + civic points ───────────────────────────
    // Runs after first frame so we can safely read AuthViewModel via context.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final userId =
          Provider.of<AuthViewModel>(context, listen: false).currentUser?.uid;
      if (userId != null) {
        // Civic points (still comes from user doc)
        Provider.of<CitizenDashboardViewModel>(context, listen: false)
            .loadDashboardStats(userId);
        // Real-time complaint counts — same source Dashboard uses.
        // Safe to call even if Dashboard already started listening;
        // listenToUserComplaints() no-ops if already subscribed for this user.
        Provider.of<ComplaintViewModel>(context, listen: false)
            .listenToUserComplaints(userId);
      }
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Civic rank from points ─────────────────────────────────────────────────
  Map<String, dynamic> _rankInfo(int points) {
    if (points >= 500) {
      return {'title': 'EcoChampion', 'icon': '🏆', 'color': const Color(0xFFFFD700)};
    } else if (points >= 200) {
      return {'title': 'EcoGuardian', 'icon': '🌿', 'color': _kGreen};
    } else if (points >= 50) {
      return {'title': 'EcoHelper', 'icon': '⭐', 'color': _kBlue};
    }
    return {'title': 'EcoStarter', 'icon': '🌱', 'color': _kOrange};
  }

  @override
  Widget build(BuildContext context) {
    final profileVM   = Provider.of<ProfileViewModel>(context);
    final authVM      = Provider.of<AuthViewModel>(context);
    final citizenVM   = Provider.of<CitizenDashboardViewModel>(context);
    final complaintVM = Provider.of<ComplaintViewModel>(context);

    if (profileVM.isLoading) {
      return const Scaffold(
        backgroundColor: _kBg,
        body: Center(child: CircularProgressIndicator(color: _kGreen)),
      );
    }

    final user   = profileVM.userData;
    final points = citizenVM.civicPoints;
    final rank   = _rankInfo(points);

    // ── Live counts — same source as Dashboard (ComplaintViewModel stream) ───
    final total     = complaintVM.totalComplaints;
    final resolved  = complaintVM.resolvedComplaints;
    final pending   = complaintVM.pendingComplaints;
    final statsLoading = complaintVM.isLoading && complaintVM.userComplaints.isEmpty;

    return Scaffold(
      backgroundColor: _kBg,
      body: user == null
          ? _NoProfileState(onRetry: profileVM.loadUserProfile)
          : FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          slivers: [
            // ── Hero header ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: _ProfileHero(
                user:    user,
                points:  points,
                rank:    rank,
                authVM:  authVM,
                onEdit:  () => _showEditSheet(profileVM),
              ),
            ),

            // ── Stats row ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _StatsRow(
                total:     total,
                resolved:  resolved,
                pending:   pending,
                isLoading: statsLoading,
              ),
            ),

            // ── Info section ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: _InfoSection(user: user),
            ),

            // ── Civic rank card ──────────────────────────────────────
            SliverToBoxAdapter(
              child: _RankCard(points: points, rank: rank),
            ),

            // ── Action buttons ───────────────────────────────────────
            SliverToBoxAdapter(
              child: _ActionButtons(
                onEdit:   () => _showEditSheet(profileVM),
                onLogout: () => _confirmLogout(authVM),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  // ── Edit profile bottom sheet ──────────────────────────────────────────────
  void _showEditSheet(ProfileViewModel profileVM) {
    final user        = profileVM.userData;
    if (user == null) return;

    final nameCtrl  = TextEditingController(text: user.name);
    final phoneCtrl = TextEditingController(text: user.phone ?? '');
    final areaCtrl  = TextEditingController(
        text: user.residentialArea ?? user.workingArea ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditSheet(
        nameCtrl:  nameCtrl,
        phoneCtrl: phoneCtrl,
        areaCtrl:  areaCtrl,
        onSave: (name, phone, area) async {
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid == null) return;
          await FirestoreService().updateUserData(uid, {
            'name':            name,
            'phone':           phone,
            'residentialArea': area,
          });
          await profileVM.loadUserProfile();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('✅ Profile updated successfully'),
                backgroundColor: _kGreen,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
        },
      ),
    );
  }

  // ── Logout confirm dialog ──────────────────────────────────────────────────
  Future<void> _confirmLogout(AuthViewModel authVM) async {
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
    if (ok == true && mounted) authVM.logout();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Hero header
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.user,
    required this.points,
    required this.rank,
    required this.authVM,
    required this.onEdit,
  });

  final dynamic  user;
  final int      points;
  final Map<String, dynamic> rank;
  final AuthViewModel authVM;
  final VoidCallback  onEdit;

  @override
  Widget build(BuildContext context) {
    final initial = (user.name as String).isNotEmpty
        ? (user.name as String)[0].toUpperCase()
        : 'U';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kGreenDark, _kGreen, _kGreenLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            children: [
              // Top row — title + edit button
              Row(
                children: [
                  const Text(
                    'My Profile',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3),
                  ),
                  const Spacer(),
                  // Edit icon
                  GestureDetector(
                    onTap: onEdit,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.edit_outlined,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Avatar
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.6),
                      width: 3),
                ),
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  child: Text(
                    initial,
                    style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Name
              Text(
                user.name as String,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),

              // Email
              Text(
                user.email as String,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13),
              ),
              const SizedBox(height: 12),

              // Role + rank badges
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _HeroBadge(
                    icon: Icons.verified_user_outlined,
                    label: (user.role as String).toUpperCase(),
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                  const SizedBox(width: 10),
                  _HeroBadge(
                    emoji: rank['icon'],
                    label: rank['title'],
                    color: (rank['color'] as Color).withValues(alpha: 0.3),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({
    this.icon,
    this.emoji,
    required this.label,
    required this.color,
  });

  final IconData? icon;
  final String?   emoji;
  final String    label;
  final Color     color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, color: Colors.white, size: 13)
          else
            Text(emoji!, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Stats row
// ─────────────────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.total,
    required this.resolved,
    required this.pending,
    this.isLoading = false,
  });

  final int  total;
  final int  resolved;
  final int  pending;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: isLoading
          ? const SizedBox(
        height: 78,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: _kGreen),
          ),
        ),
      )
          : Row(
        children: [
          _StatCell(
            value: total.toString(),
            label: 'Total\nReports',
            color: _kBlue,
            icon: Icons.assignment_outlined,
          ),
          _Divider(),
          _StatCell(
            value: resolved.toString(),
            label: 'Resolved',
            color: _kGreen,
            icon: Icons.check_circle_outline,
          ),
          _Divider(),
          _StatCell(
            value: pending.toString(),
            label: 'Pending',
            color: _kOrange,
            icon: Icons.hourglass_empty_rounded,
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.value,
    required this.label,
    required this.color,
    required this.icon,
  });

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
          Text(
            value,
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
                height: 1.3),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 50,
      color: Colors.grey[200],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Info section
// ─────────────────────────────────────────────────────────────────────────────
class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.user});
  final dynamic user;

  @override
  Widget build(BuildContext context) {
    final area = (user.residentialArea as String?) ??
        (user.workingArea as String?) ??
        'Not provided';
    final joined = (user.createdAt as DateTime?) != null
        ? _formatDate(user.createdAt as DateTime)
        : 'N/A';

    return Container(
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
          // Section title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _kGreenSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.person_outline,
                    color: _kGreen, size: 16),
              ),
              const SizedBox(width: 8),
              const Text(
                'Personal Information',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _InfoRow(
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: (user.phone as String?) ?? 'Not provided',
            iconColor: _kBlue,
          ),
          const _RowDivider(),
          _InfoRow(
            icon: Icons.location_on_outlined,
            label: 'Area',
            value: area,
            iconColor: _kOrange,
          ),
          const _RowDivider(),
          _InfoRow(
            icon: Icons.shield_outlined,
            label: 'Role',
            value: (user.role as String).toUpperCase(),
            iconColor: _kGreen,
            isChip: true,
          ),
          const _RowDivider(),
          _InfoRow(
            icon: Icons.calendar_today_outlined,
            label: 'Member Since',
            value: joined,
            iconColor: Colors.purple,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
    this.isChip = false,
  });

  final IconData icon;
  final String   label;
  final String   value;
  final Color    iconColor;
  final bool     isChip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                isChip
                    ? Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: _kGreenSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    value,
                    style: const TextStyle(
                        fontSize: 12,
                        color: _kGreen,
                        fontWeight: FontWeight.w700),
                  ),
                )
                    : Text(
                  value,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();
  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, color: Colors.grey[100]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Civic rank card
// ─────────────────────────────────────────────────────────────────────────────
class _RankCard extends StatelessWidget {
  const _RankCard({required this.points, required this.rank});

  final int                  points;
  final Map<String, dynamic> rank;

  // Next rank threshold
  int get _nextTarget {
    if (points < 50)  return 50;
    if (points < 200) return 200;
    if (points < 500) return 500;
    return 500;
  }

  @override
  Widget build(BuildContext context) {
    final color    = rank['color'] as Color;
    final progress = (points / _nextTarget).clamp(0.0, 1.0);
    final isDone   = points >= 500;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.12),
            color.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(rank['icon'] as String,
                  style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rank['title'] as String,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: color),
                  ),
                  Text(
                    '$points Civic Points',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$points pts',
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Progress bar
          if (!isDone) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Progress to next rank',
                  style:
                  TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
                Text(
                  '$points / $_nextTarget',
                  style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: color.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded, color: color, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Maximum rank achieved! You are an EcoChampion 🏆',
                    style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Action buttons
// ─────────────────────────────────────────────────────────────────────────────
class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.onEdit,
    required this.onLogout,
  });

  final VoidCallback onEdit;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        children: [
          // Edit profile button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text(
                'Edit Profile',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Logout button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text(
                'Logout',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kRed,
                side: BorderSide(color: _kRed.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Edit profile bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
class _EditSheet extends StatefulWidget {
  const _EditSheet({
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.areaCtrl,
    required this.onSave,
  });

  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController areaCtrl;
  final Future<void> Function(String name, String phone, String area) onSave;

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _kGreenSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit_outlined,
                    color: _kGreen, size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'Edit Profile',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Name field
          _SheetField(
            controller: widget.nameCtrl,
            label: 'Full Name',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 12),

          // Phone field
          _SheetField(
            controller: widget.phoneCtrl,
            label: 'Phone Number',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),

          // Area field
          _SheetField(
            controller: widget.areaCtrl,
            label: 'Residential Area',
            icon: Icons.location_on_outlined,
          ),
          const SizedBox(height: 20),

          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving
                  ? null
                  : () async {
                final name  = widget.nameCtrl.text.trim();
                final phone = widget.phoneCtrl.text.trim();
                final area  = widget.areaCtrl.text.trim();
                if (name.isEmpty) return;

                setState(() => _saving = true);
                await widget.onSave(name, phone, area);
                if (mounted) Navigator.pop(context);
              },
              icon: _saving
                  ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded, size: 18),
              label: Text(
                _saving ? 'Saving…' : 'Save Changes',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  const _SheetField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String                label;
  final IconData              icon;
  final TextInputType?        keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller:   controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText:  label,
        prefixIcon: Icon(icon, size: 20, color: _kGreen),
        filled:     true,
        fillColor:  const Color(0xFFF4F6F9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: _kGreen, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  No profile fallback
// ─────────────────────────────────────────────────────────────────────────────
class _NoProfileState extends StatelessWidget {
  const _NoProfileState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_off_outlined,
              size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('Profile data not found',
              style:
              TextStyle(fontSize: 16, color: Colors.grey[500])),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}